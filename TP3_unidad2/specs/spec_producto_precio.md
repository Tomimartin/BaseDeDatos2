# Spec: Optimización de Filtro y Ordenamiento por Precio — Índice sobre `producto.precio`

## 1. Objetivo

Acelerar el filtro y ordenamiento por precio en el catálogo de productos. Eliminar el nodo `Seq Scan` y el nodo `Sort` (en disco o memoria) que ocurren al filtrar productos por precio con orden descendente, sustituyéndolos por un `Index Scan` que recorre el índice B-tree en orden inverso, devolviendo las filas ya ordenadas sin un paso de Sort adicional.

---

## 2. Contexto del Esquema

**Tabla afectada:** `public.producto`

```sql
CREATE TABLE public.producto (
    id_producto bigint NOT NULL,              -- PK, GENERATED ALWAYS AS IDENTITY
    nombre      character varying(120) NOT NULL,
    descripcion character varying(500),
    precio      numeric(12,2) NOT NULL,
    stock       integer DEFAULT 0 NOT NULL,
    activo      boolean DEFAULT true NOT NULL,
    id_categoria bigint NOT NULL,             -- FK → categoria
    CONSTRAINT ck_producto_precio_positivo    CHECK (precio > 0),
    CONSTRAINT ck_producto_stock_no_negativo  CHECK (stock >= 0)
);
```

**Columnas proyectadas por la consulta:**

| Columna      | Tipo                  | Existe en tabla |
|--------------|-----------------------|-----------------|
| `id_producto`| `bigint`              | ✅ Sí           |
| `nombre`     | `character varying`   | ✅ Sí           |
| `precio`     | `numeric(12,2)`       | ✅ Sí           |

**Índices existentes antes de la optimización:**

| Nombre                       | Columna(s)              | Tipo   | Propósito                              |
|------------------------------|-------------------------|--------|----------------------------------------|
| `producto_pkey`              | `id_producto`           | B-tree | Clave primaria                         |
| `idx_producto_categoria_activo` | `id_categoria` (WHERE activo = true) | B-tree parcial | Filtros por categoría en productos activos |

> **Diagnóstico:** No existe ningún índice sobre la columna `precio`. Toda consulta que filtre o ordene por precio genera un Seq Scan seguido de un nodo Sort explícito.

---

## 3. Consulta Afectada

```sql
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;
```

**Frecuencia de uso:** Alta — consulta del catálogo de productos, ejecutada en cada listado con filtro de precio.  
**Motor de base de datos:** PostgreSQL 17.11

---

## 4. Análisis del Problema

Sin índice sobre `precio`, el plan de ejecución actual tiene dos nodos problemáticos:

```
Sort  (cost=...) (key: precio DESC)
  ->  Seq Scan on producto
        Filter: (precio > 4970)
```

| Nodo     | Problema                                                                                  |
|----------|-------------------------------------------------------------------------------------------|
| Seq Scan | Recorre todas las filas de la tabla para evaluar `precio > 4970`. Costo O(n).            |
| Sort     | Ordena el resultado en memoria (o en disco si supera `work_mem`). Costo adicional O(k log k) donde k = filas que pasan el filtro. |

Un índice B-tree sobre `precio DESC` permite que PostgreSQL recorra el índice en orden descendente y devuelva las filas ya ordenadas, **eliminando ambos nodos** de un solo paso.

---

## 5. Solución Propuesta

### Opción A — Índice descendente simple (recomendada como punto de partida)

```sql
CREATE INDEX idx_producto_precio_desc
    ON public.producto USING btree (precio DESC);
```

PostgreSQL recorre el índice de mayor a menor, satisfaciendo `ORDER BY precio DESC` sin Sort. Requiere heap fetch para recuperar `nombre`.

### Opción B — Índice cubriente descendente (máximo rendimiento)

```sql
CREATE INDEX idx_producto_precio_covering
    ON public.producto USING btree (precio DESC)
    INCLUDE (id_producto, nombre);
```

Las tres columnas proyectadas (`id_producto`, `nombre`, `precio`) quedan en el índice. PostgreSQL puede resolver la consulta con un **Index Only Scan** sin tocar la tabla heap — máximo rendimiento posible.

**Recomendación:** implementar la Opción B directamente. Las columnas proyectadas son fijas y conocidas.

**¿Por qué B-tree con `DESC`?**  
Un B-tree puede recorrerse en ambas direcciones, pero declarar `precio DESC` en el índice permite que PostgreSQL use un **forward scan** del índice (más eficiente en cache) para satisfacer `ORDER BY precio DESC`, en lugar de un backward scan sobre un índice `ASC`.

---

## 6. Columna Candidata al Filtro

| Columna  | Tipo            | Cardinalidad esperada                        | Operadores usados | Adecuada para B-tree |
|----------|-----------------|----------------------------------------------|-------------------|----------------------|
| `precio` | `numeric(12,2)` | Media-alta (precios con variedad suficiente) | `>` (rango) + `ORDER BY DESC` | ✅ Sí |

La combinación de filtro de rango (`>`) y ordenamiento (`ORDER BY DESC`) sobre la misma columna es el caso de uso ideal para un índice B-tree: satisface ambas necesidades en un único recorrido ordenado del árbol.

---

## 7. Plan de Implementación

### Paso 1 — Capturar el baseline

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;
```

Registrar: nodos presentes (`Seq Scan`, `Sort`), `cost=`, `actual time=`, `Sort Method` (quicksort/external merge) y `Buffers: shared read`.

### Paso 2 — Crear el índice

```sql
-- Desarrollo / entorno de prueba:
CREATE INDEX idx_producto_precio_covering
    ON public.producto USING btree (precio DESC)
    INCLUDE (id_producto, nombre);

-- Producción (sin bloqueo de escrituras):
CREATE INDEX CONCURRENTLY idx_producto_precio_covering
    ON public.producto USING btree (precio DESC)
    INCLUDE (id_producto, nombre);
```

### Paso 3 — Actualizar estadísticas

```sql
ANALYZE public.producto;
```

### Paso 4 — Habilitar Index Only Scan (Opción B)

```sql
VACUUM public.producto;
```

### Paso 5 — Verificar el nuevo plan

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;
```

El plan **no debe contener** los nodos `Seq Scan on producto` ni `Sort`. Debe aparecer `Index Only Scan` (Opción B) o `Index Scan` (Opción A) sobre `idx_producto_precio_covering`.

---

## 8. Criterios de Aceptación

| # | Criterio | Condición de éxito |
|---|----------|--------------------|
| 1 | **Eliminación del Seq Scan** | El nodo `Seq Scan on producto` desaparece del plan de ejecución. |
| 2 | **Eliminación del nodo Sort** | El nodo `Sort` (en memoria o en disco) desaparece del plan. PostgreSQL obtiene las filas ya ordenadas directamente del índice. |
| 3 | **Tipo de nodo esperado** | `EXPLAIN` muestra `Index Only Scan` o `Index Scan` sobre `idx_producto_precio_covering` con dirección de recorrido `Backward` o forward según el optimizador. |
| 4 | **Reducción de costo estimado** | El `cost=` total se reduce en al menos **80 %** respecto al baseline con Seq Scan + Sort. |
| 5 | **Reducción de tiempo real** | El `actual time=` se reduce en al menos **70 %** sobre datos de producción. |
| 6 | **Index Only Scan activo** | Con Opción B, `EXPLAIN` muestra `Heap Fetches: 0` tras `VACUUM public.producto`. |
| 7 | **Sin regresiones** | Las consultas que filtran por `id_producto`, `id_categoria` o `activo` mantienen sus planes sin degradación. |
| 8 | **Integridad de datos** | `SELECT count(*) FROM producto` devuelve el mismo valor antes y después de crear el índice. |
| 9 | **Disponibilidad en producción** | Con `CREATE INDEX CONCURRENTLY`, la tabla permanece disponible para lectura y escritura durante todo el proceso. |

---

## 9. Riesgos y Consideraciones

| Riesgo | Mitigación |
|--------|------------|
| Bloqueo en tabla grande durante `CREATE INDEX` | Usar `CREATE INDEX CONCURRENTLY` en producción |
| Baja cardinalidad de `precio` (muchos productos con el mismo precio) | Con poca selectividad el optimizador puede preferir Seq Scan. Verificar con `SET enable_seqscan = off`. Si el umbral `> 15000` selecciona más del ~20 % de filas, el Seq Scan puede ser la elección correcta del planificador. |
| Overhead en operaciones de escritura | Cada `INSERT` o `UPDATE` sobre `precio` actualiza el índice. Aceptable dado que el catálogo de productos se actualiza con baja frecuencia respecto a las lecturas. |
| Columna `nombre` en el `INCLUDE` ocupa espacio en índice | `nombre` es `varchar(120)`. El tamaño del índice aumenta. Evaluar si el Index Only Scan justifica el espacio adicional en tablas muy grandes. |
| Visibilidad del Index Only Scan | Requiere `VACUUM` sobre la tabla. Programar post-creación o confiar en el autovacuum. |

---

## 10. Definición de Listo (Definition of Done)

- [ ] Índice `idx_producto_precio_covering` creado en el esquema de producción.
- [ ] `EXPLAIN ANALYZE` confirma ausencia de `Seq Scan` y ausencia de `Sort`.
- [ ] `EXPLAIN ANALYZE` muestra `Index Only Scan` o `Index Scan` sobre el nuevo índice.
- [ ] Tiempo de ejecución reducido ≥ 70 % frente al baseline medido.
- [ ] `ANALYZE public.producto` ejecutado post-creación del índice.
- [ ] `VACUUM public.producto` ejecutado para habilitar Index Only Scan (Opción B).
- [ ] DDL del índice incorporado al script de migración / `base_food_store.sql`.
