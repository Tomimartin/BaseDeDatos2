# Spec: Optimización de Consulta de Alta Frecuencia — Índice sobre `pedido.fecha`

## 1. Objetivo

Eliminar el escaneo secuencial (Seq Scan) que ocurre al filtrar pedidos por rango de fechas, sustituyéndolo por un acceso basado en índice (Index Scan o Bitmap Index Scan). La consulta se ejecuta cientos de veces por día y representa una carga crítica sobre la base de datos. El objetivo es reducir drásticamente el tiempo de ejecución y el costo de I/O asociado.

---

## 2. Contexto del Esquema

**Tabla afectada:** `public.pedido`

```sql
CREATE TABLE public.pedido (
    id_pedido  bigint NOT NULL,                          -- PK, GENERATED ALWAYS AS IDENTITY
    fecha      timestamp with time zone DEFAULT now() NOT NULL,
    forma_pago public.forma_pago_enum NOT NULL,
    id_cliente bigint NOT NULL,                          -- FK → cliente
    CONSTRAINT ck_pedido_fecha_no_futura CHECK (fecha <= now())
);
```

**Columnas proyectadas por la consulta:**

| Columna     | Tipo                       | Existe en tabla |
|-------------|----------------------------|-----------------|
| `id_pedido` | `bigint`                   | ✅ Sí           |
| `fecha`     | `timestamp with time zone` | ✅ Sí           |

**Índices existentes antes de la optimización:**

| Nombre                  | Columna(s)   | Tipo   | Propósito                   |
|-------------------------|--------------|--------|-----------------------------|
| `pedido_pkey`           | `id_pedido`  | B-tree | Clave primaria              |
| `idx_pedido_id_cliente` | `id_cliente` | B-tree | Búsquedas/joins por cliente |

> **Diagnóstico:** No existe ningún índice sobre la columna `fecha`. Toda consulta que filtre por rango de fechas genera un Seq Scan completo de la tabla.

---

## 3. Consulta Afectada

```sql
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';
```

> **Nota técnica:** La columna `fecha` es de tipo `timestamp with time zone`. El límite superior `'2023-01-31'` se interpreta como `'2023-01-31 00:00:00'`, por lo que registros del 31 de enero con hora > 00:00 quedarían excluidos. Para capturar el día completo usar `fecha < '2023-02-01'` en lugar de `BETWEEN`.

**Frecuencia de ejecución estimada:** > 200 ejecuciones / día  
**Motor de base de datos:** PostgreSQL 17.11

---

## 4. Análisis del Problema

Sin índice sobre `fecha`, el plan de ejecución es:

```
Seq Scan on pedido
  Filter: ((fecha >= '2023-01-01') AND (fecha <= '2023-01-31'))
```

PostgreSQL recorre **cada fila** de la tabla para evaluar el filtro, sin importar cuántos registros coincidan. El costo escala linealmente con el volumen de datos — O(n) — lo que se vuelve prohibitivo cuando la tabla crece a cientos de miles o millones de filas.

---

## 5. Solución Propuesta

### Opción A — Índice simple (punto de partida)

```sql
CREATE INDEX idx_pedido_fecha
    ON public.pedido USING btree (fecha);
```

Habilita Index Scan o Bitmap Index Scan. PostgreSQL aún necesita un heap fetch para recuperar `id_pedido`.

### Opción B — Índice cubriente (recomendada)

```sql
CREATE INDEX idx_pedido_fecha_covering
    ON public.pedido USING btree (fecha)
    INCLUDE (id_pedido);
```

Dado que la consulta proyecta exactamente `(id_pedido, fecha)`, ambas columnas quedan en el índice y PostgreSQL puede resolverla con un **Index Only Scan** sin tocar la tabla heap — máximo rendimiento posible.

**Recomendación:** implementar la Opción B directamente.

**¿Por qué B-tree?**  
Es el tipo óptimo en PostgreSQL para operadores de rango (`BETWEEN`, `<`, `>`, `>=`, `<=`). GiST o SP-GiST no aportan ventajas para `timestamptz` con este patrón de acceso.

---

## 6. Columna Candidata al Filtro

| Columna | Tipo                       | Cardinalidad esperada                            | Operador usado    | Adecuada para B-tree |
|---------|----------------------------|--------------------------------------------------|-------------------|----------------------|
| `fecha` | `timestamp with time zone` | Alta (valores únicos o casi únicos por registro) | `BETWEEN` (rango) | ✅ Sí                |

La alta cardinalidad de `fecha` garantiza alta selectividad del índice, haciendo que PostgreSQL lo prefiera sobre el Seq Scan para rangos de días o semanas.

---

## 7. Plan de Implementación

### Paso 1 — Capturar el baseline

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';
```

Registrar: tipo de nodo (`Seq Scan`), `cost=`, `actual time=` y `Buffers: shared read`.

### Paso 2 — Crear el índice

```sql
-- Desarrollo / entorno de prueba:
CREATE INDEX idx_pedido_fecha_covering
    ON public.pedido USING btree (fecha)
    INCLUDE (id_pedido);

-- Producción (sin bloqueo de escrituras):
CREATE INDEX CONCURRENTLY idx_pedido_fecha_covering
    ON public.pedido USING btree (fecha)
    INCLUDE (id_pedido);
```

### Paso 3 — Actualizar estadísticas

```sql
ANALYZE public.pedido;
```

### Paso 4 — Verificar el nuevo plan

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';
```

El nodo de ejecución debe ser `Index Only Scan` (Opción B) o al menos `Index Scan` / `Bitmap Index Scan` (Opción A). `Seq Scan on pedido` no debe aparecer.

---

## 8. Criterios de Aceptación

| # | Criterio | Condición de éxito |
|---|----------|--------------------|
| 1 | **Cambio de plan de ejecución** | `EXPLAIN` muestra `Index Only Scan`, `Index Scan` o `Bitmap Index Scan` sobre `idx_pedido_fecha_covering`. El nodo `Seq Scan on pedido` desaparece del plan. |
| 2 | **Reducción de costo estimado** | El `cost=` se reduce en al menos **80 %** respecto al baseline con Seq Scan. |
| 3 | **Reducción de tiempo real** | El `actual time=` se reduce en al menos **70 %** para rangos de 30 días o menos sobre datos de producción. |
| 4 | **Reducción de I/O** | `Buffers: shared read` decrece proporcionalmente a la fracción de filas seleccionadas sobre el total de la tabla. |
| 5 | **Index Only Scan activo** | Con la Opción B, `EXPLAIN` muestra `Heap Fetches: 0` tras ejecutar `VACUUM public.pedido`. |
| 6 | **Sin regresiones** | Las consultas que filtran por `id_pedido` o `id_cliente` mantienen sus planes y tiempos sin degradación. |
| 7 | **Integridad de datos** | `SELECT count(*) FROM pedido` devuelve el mismo valor antes y después de crear el índice. |
| 8 | **Disponibilidad en producción** | Con `CREATE INDEX CONCURRENTLY`, la tabla permanece disponible para lectura y escritura durante todo el proceso. |

---

## 9. Riesgos y Consideraciones

| Riesgo | Mitigación |
|--------|------------|
| Bloqueo en tabla grande durante `CREATE INDEX` | Usar `CREATE INDEX CONCURRENTLY` en producción |
| Optimizador prefiere Seq Scan para rangos muy amplios | Esperado si el rango supera ~20 % de las filas. Verificar con `SET enable_seqscan = off` para confirmar que el índice es usable; si el planificador elige Seq Scan para rangos amplios, es un comportamiento correcto. |
| Overhead en operaciones de escritura | Cada `INSERT` sobre `pedido` actualiza el índice. Impacto mínimo dado que `fecha` usa `DEFAULT now()` y raramente se modifica con `UPDATE`. |
| Visibilidad del Index Only Scan | Requiere `VACUUM` ejecutado sobre la tabla. Programar `VACUUM` post-creación o confiar en el autovacuum. |
| Límite superior `BETWEEN '2023-01-31'` excluye registros con hora > 00:00 | Documentar el comportamiento y ajustar el literal si se requiere el día completo. |

---

## 10. Definición de Listo (Definition of Done)

- [ ] Índice `idx_pedido_fecha_covering` creado en el esquema de producción.
- [ ] `EXPLAIN ANALYZE` confirma `Index Only Scan`, `Index Scan` o `Bitmap Index Scan` (sin `Seq Scan`).
- [ ] Tiempo de ejecución reducido ≥ 70 % frente al baseline medido.
- [ ] `ANALYZE` ejecutado post-creación del índice.
- [ ] `VACUUM public.pedido` ejecutado para habilitar Index Only Scan (Opción B).
- [ ] DDL del índice incorporado al script de migración / `base_food_store.sql`.
- [ ] Comportamiento del límite superior de `BETWEEN` documentado y validado con el equipo.
