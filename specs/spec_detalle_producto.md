# Spec: Optimización del Historial de Ventas por Producto — Índice compuesto sobre `detalle_pedido(id_producto, cantidad)`

## 1. Objetivo

Optimizar las búsquedas del historial de ventas de un producto específico. Reemplazar el `Seq Scan` sobre la tabla `detalle_pedido` — que crece de forma masiva con el volumen de transacciones — por un `Index Scan` o `Bitmap Heap Scan` que acceda directamente a las filas del producto solicitado, eliminando además el nodo `Sort` explícito al aprovechar el orden del índice.

---

## 2. Contexto del Esquema

**Tabla afectada:** `public.detalle_pedido`

```sql
CREATE TABLE public.detalle_pedido (
    id_pedido        bigint NOT NULL,           -- FK → pedido (parte de PK compuesta)
    id_producto      bigint NOT NULL,           -- FK → producto (parte de PK compuesta)
    cantidad         integer NOT NULL,
    precio_unitario  numeric(12,2) NOT NULL,
    subtotal         numeric(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    CONSTRAINT pk_detalle_pedido       PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT ck_detalle_cantidad_positiva   CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio_no_negativo  CHECK (precio_unitario >= 0)
);
```

**Columnas proyectadas por la consulta:**

| Columna     | Tipo            | Existe en tabla          |
|-------------|-----------------|--------------------------|
| `id_pedido` | `bigint`        | ✅ Sí                    |
| `cantidad`  | `integer`       | ✅ Sí                    |
| `subtotal`  | `numeric(14,2)` | ✅ Sí (columna generada) |

**Índices existentes antes de la optimización:**

| Nombre              | Columna(s)                  | Tipo   | Propósito                              |
|---------------------|-----------------------------|--------|----------------------------------------|
| `pk_detalle_pedido` | `(id_pedido, id_producto)`  | B-tree | Clave primaria compuesta               |

> **Diagnóstico:** La PK está ordenada por `(id_pedido, id_producto)`. Buscar por `id_producto` solo **no puede usar esta PK** porque `id_producto` es la segunda columna y no hay un predicado sobre `id_pedido`. Toda consulta que filtre únicamente por `id_producto` genera un Seq Scan completo.

---

## 3. Consulta Afectada

```sql
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;
```

**Frecuencia de uso:** Alta — ejecutada cada vez que se consulta el historial de ventas de un producto.  
**Tabla de alto volumen:** `detalle_pedido` acumula una fila por cada línea de cada pedido; en operación real puede contener millones de registros.  
**Motor de base de datos:** PostgreSQL 17.11

---

## 4. Análisis del Problema

Sin índice sobre `id_producto`, el plan actual tiene dos nodos problemáticos:

```
Sort  (cost=...) (key: cantidad DESC)
  ->  Seq Scan on detalle_pedido
        Filter: (id_producto = 150)
```

| Nodo     | Problema                                                                                          |
|----------|---------------------------------------------------------------------------------------------------|
| Seq Scan | Recorre **todas** las filas de `detalle_pedido` para encontrar las del producto 150. Costo O(n).  |
| Sort     | Ordena el subconjunto filtrado por `cantidad DESC` en memoria o en disco. Costo O(k log k).       |

La PK `(id_pedido, id_producto)` no ayuda porque la búsqueda iguala solo la segunda columna del índice — PostgreSQL no puede hacer un range scan eficiente sobre ella.

---

## 5. Solución Propuesta

### Opción A — Índice compuesto con orden explícito (recomendada)

```sql
CREATE INDEX idx_detalle_producto_cantidad
    ON public.detalle_pedido (id_producto, cantidad DESC);
```

- La primera columna `id_producto` permite localizar exactamente las filas del producto solicitado mediante un **Index Scan** con predicado de igualdad.
- La segunda columna `cantidad DESC` ordena las filas dentro de ese producto en el mismo orden que pide la consulta, **eliminando el nodo Sort**.

### Opción B — Índice cubriente (máximo rendimiento)

```sql
CREATE INDEX idx_detalle_producto_covering
    ON public.detalle_pedido (id_producto, cantidad DESC)
    INCLUDE (id_pedido, subtotal);
```

Las cuatro columnas proyectadas (`id_pedido`, `cantidad`, `subtotal`) quedan en el índice junto con `id_producto`. PostgreSQL puede resolver la consulta con un **Index Only Scan** sin acceder a la tabla heap.

> **Nota sobre `subtotal`:** Es una columna generada (`GENERATED ALWAYS AS ... STORED`). PostgreSQL almacena su valor físicamente en la tabla, por lo que puede incluirse en un `INCLUDE` de índice normalmente.

**Recomendación:** implementar la Opción B. Las columnas proyectadas son fijas y el beneficio del Index Only Scan es especialmente valioso en una tabla de alto volumen.

---

## 6. Columnas Candidatas

| Columna      | Rol en la consulta | Tipo      | Cardinalidad esperada                   | Adecuada para B-tree |
|--------------|--------------------|-----------|-----------------------------------------|----------------------|
| `id_producto`| Filtro (igualdad)  | `bigint`  | Media (N productos distintos)           | ✅ Sí — primera columna del índice |
| `cantidad`   | Ordenamiento DESC  | `integer` | Baja-media (valores enteros pequeños)   | ✅ Sí — segunda columna del índice |

Colocar `id_producto` primero en el índice compuesto es fundamental: permite que PostgreSQL haga un **index seek** exacto sobre el valor `150` y luego recorra las entradas correspondientes ya ordenadas por `cantidad DESC`.

---

## 7. Plan de Implementación

### Paso 1 — Capturar el baseline

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;
```

Registrar: nodos presentes (`Seq Scan`, `Sort`), `cost=`, `actual time=`, `Sort Method` y `Buffers: shared read`.

### Paso 2 — Crear el índice

```sql
-- Desarrollo / entorno de prueba:
CREATE INDEX idx_detalle_producto_covering
    ON public.detalle_pedido (id_producto, cantidad DESC)
    INCLUDE (id_pedido, subtotal);

-- Producción (sin bloqueo de escrituras):
CREATE INDEX CONCURRENTLY idx_detalle_producto_covering
    ON public.detalle_pedido (id_producto, cantidad DESC)
    INCLUDE (id_pedido, subtotal);
```

### Paso 3 — Actualizar estadísticas

```sql
ANALYZE public.detalle_pedido;
```

### Paso 4 — Habilitar Index Only Scan (Opción B)

```sql
VACUUM public.detalle_pedido;
```

### Paso 5 — Verificar el nuevo plan

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;
```

El plan **no debe contener** `Seq Scan on detalle_pedido` ni `Sort`. Debe aparecer `Index Only Scan` (Opción B) o `Index Scan` / `Bitmap Heap Scan` (Opción A) sobre `idx_detalle_producto_covering`.

---

## 8. Criterios de Aceptación

| # | Criterio | Condición de éxito |
|---|----------|--------------------|
| 1 | **Eliminación del Seq Scan** | El nodo `Seq Scan on detalle_pedido` desaparece del plan de ejecución. |
| 2 | **Eliminación del nodo Sort** | El nodo `Sort` desaparece. Las filas se devuelven en orden `cantidad DESC` directamente desde el índice. |
| 3 | **Tipo de nodo esperado** | `EXPLAIN` muestra `Index Only Scan`, `Index Scan` o `Bitmap Heap Scan` sobre `idx_detalle_producto_covering`. |
| 4 | **Reducción de costo estimado** | El `cost=` total se reduce en al menos **80 %** respecto al baseline con Seq Scan + Sort. |
| 5 | **Reducción de tiempo real** | El `actual time=` se reduce en al menos **70 %** sobre datos de producción. |
| 6 | **Index Only Scan activo** | Con Opción B, `EXPLAIN` muestra `Heap Fetches: 0` tras `VACUUM public.detalle_pedido`. |
| 7 | **Sin regresiones** | Las consultas que usan la PK `(id_pedido, id_producto)` mantienen sus planes sin degradación. |
| 8 | **Integridad de datos** | `SELECT count(*) FROM detalle_pedido` devuelve el mismo valor antes y después de crear el índice. |
| 9 | **Disponibilidad en producción** | Con `CREATE INDEX CONCURRENTLY`, la tabla permanece disponible durante todo el proceso. |

---

## 9. Riesgos y Consideraciones

| Riesgo | Mitigación |
|--------|------------|
| Tabla de muy alto volumen → bloqueo largo en `CREATE INDEX` | Usar `CREATE INDEX CONCURRENTLY` en producción obligatoriamente |
| Producto con muchas ventas → resultado grande → planificador prefiere Bitmap Heap Scan | Es un comportamiento correcto y aceptado. El criterio #3 incluye Bitmap Heap Scan como resultado válido. |
| Baja selectividad de `id_producto` (pocos productos distintos con miles de filas cada uno) | El índice sigue siendo útil; el Bitmap Heap Scan agrupa las lecturas de heap en páginas, reduciendo I/O. |
| `subtotal` es columna generada STORED en el `INCLUDE` | PostgreSQL soporta columnas generadas STORED en cláusulas `INCLUDE`. No hay incompatibilidad. |
| Overhead de escritura en tabla masiva | Cada `INSERT` en `detalle_pedido` actualiza el índice. Evaluar impacto en throughput de carga masiva (`cargar_datos_masivos.sql`). Considerar deshabilitar el índice durante cargas batch y recrearlo después. |
| Visibilidad del Index Only Scan | Requiere `VACUUM`. En tabla de alto volumen el autovacuum puede tener retraso; programar `VACUUM` explícito post-creación. |

---

## 10. Definición de Listo (Definition of Done)

- [ ] Índice `idx_detalle_producto_covering` creado en el esquema de producción.
- [ ] `EXPLAIN ANALYZE` confirma ausencia de `Seq Scan` y ausencia de `Sort`.
- [ ] `EXPLAIN ANALYZE` muestra `Index Only Scan`, `Index Scan` o `Bitmap Heap Scan` sobre el nuevo índice.
- [ ] Tiempo de ejecución reducido ≥ 70 % frente al baseline medido.
- [ ] `ANALYZE public.detalle_pedido` ejecutado post-creación del índice.
- [ ] `VACUUM public.detalle_pedido` ejecutado para habilitar Index Only Scan (Opción B).
- [ ] Impacto del índice sobre `cargar_datos_masivos.sql` evaluado y documentado.
- [ ] DDL del índice incorporado al script de migración / `base_food_store.sql`.
