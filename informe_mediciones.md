# Informe de Mediciones y Optimización de Índices (Parte A)

Este documento registra el análisis de rendimiento de consultas en PostgreSQL, la comparación de tiempos reales antes y después de aplicar índices optimizados, la evaluación del costo de mantenimiento en operaciones de escritura y el criterio de descarte de índices no efectivos.

---

## 1. Plan de Indexación y Optimización de Consultas

### Consulta 1 — Búsqueda de Pedidos por Rango de Fechas

**Consulta SQL:**

```sql
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';
```

**Índice aplicado:** `idx_pedido_fecha` sobre `pedido(fecha)`  
**Spec de Kiro:** `specs/spec_pedidos_fecha.md`

**Resultados de mediciones:**

| Escenario | Plan de ejecución | Tiempo real | Costo estimado |
|-----------|-------------------|-------------|----------------|
| Sin índice | Seq Scan | 36.468 ms | 0.00..4471.05 |
| Con índice | Index Scan | 0.021 ms | 0.42..8.44 |

**Mejora:** ~1736x más rápido (de 36.468 ms a 0.021 ms).

**Análisis de impacto:** La inclusión del índice B-Tree eliminó el barrido secuencial completo (Seq Scan) de la tabla `pedido`, logrando reducir el tiempo de respuesta drásticamente. El optimizador pasó a navegar directamente por el árbol B-Tree hasta las entradas que caen dentro del rango solicitado, sin leer filas fuera del intervalo.

---

### Consulta 2 — Filtrado y Ordenamiento de Productos por Precio

**Consulta SQL:**

```sql
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;
```

**Índice aplicado:** `idx_producto_precio_desc` sobre `producto(precio DESC)`  
**Spec de Kiro:** `specs/spec_producto_precio.md`

**Resultados de mediciones:**

| Escenario | Plan de ejecución | Tiempo real | Detalle |
|-----------|-------------------|-------------|---------|
| Sin índice | Seq Scan + Quicksort | 3.898 ms | Ordenamiento en memoria (42 kB) |
| Con índice | Bitmap Index Scan | 0.346 ms | Costo: 589.91..590.75 |

**Mejora:** ~11x más rápido (de 3.898 ms a 0.346 ms).

**Análisis de impacto:** El optimizador utilizó un Bitmap Index Scan evitando recorrer las 50.000 filas descartadas por el filtro. Se eliminó el nodo Sort explícito en memoria (Quicksort de 42 kB), ya que el índice descendente entrega las filas en el orden requerido por `ORDER BY precio DESC` directamente desde la estructura B-Tree.

---

### Consulta 3 — Historial de Detalle de Producto por Cantidad

**Consulta SQL:**

```sql
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;
```

**Índice aplicado:** `idx_detalle_pedido_producto_cant` (índice compuesto) sobre `detalle_pedido(id_producto, cantidad DESC)`  
**Spec de Kiro:** `specs/spec_detalle_producto.md`

**Resultados de mediciones:**

| Escenario | Plan de ejecución | Tiempo real | Detalle |
|-----------|-------------------|-------------|---------|
| Sin índice | Parallel Seq Scan + Sort | 35.268 ms | 2 workers paralelos, 200.000 filas recorridas |
| Con índice | Index Scan | 0.060 ms | Costo: 0.42..20.10 |

**Mejora:** ~588x más rápido (de 35.268 ms a 0.060 ms). La mayor mejora de las tres consultas.

**Análisis de impacto:** Al ser un índice compuesto `(id_producto, cantidad DESC)`, el motor filtró y ordenó los datos directamente desde el árbol B-Tree sin necesidad de ejecutar un nodo Sort adicional ni recurrir a escaneos paralelos en disco. La primera columna `id_producto` actúa como seek exacto al valor `150`; la segunda columna `cantidad DESC` entrega las filas del producto ya ordenadas descendentemente, eliminando por completo el paso de Sort.

---

## 2. Análisis del Costo de Mantenimiento (Prueba de Inserción Masiva)

Para evaluar el impacto de los índices sobre las operaciones de escritura (`INSERT`), se realizó una prueba masiva de inserción de 1.000 registros mediante `generate_series(100000, 101000)`.

| Escenario | Tiempo de ejecución |
|-----------|---------------------|
| Inserción masiva **sin** índices | 3.337 ms |
| Inserción masiva **con** índices activos | 9.501 ms |
| Penalización | ~184 % (~2.85x más lento) |

**Conclusión técnica:** Mantener índices activos incrementó el tiempo de inserción casi 3 veces. Esto demuestra cuantitativamente que cada índice B-Tree obliga al motor a actualizar no solo la tabla física (heap) sino también la estructura del árbol indexado por cada operación de modificación de datos (`INSERT` / `UPDATE` / `DELETE`). El trade-off es aceptable cuando la frecuencia de lecturas supera ampliamente a la de escrituras, como ocurre en el catálogo de productos y el historial de pedidos.

---

## 3. Criterio de Sobreindexación y Descarte de Índices

**Índice propuesto y descartado:**

```sql
CREATE INDEX idx_producto_activo ON producto(activo);
```

**Justificación técnica:** Se descarta por **baja cardinalidad y falta de selectividad**. La columna booleana `activo` posee únicamente dos valores posibles (`TRUE` / `FALSE`). Un índice B-Tree sobre una columna con tan poca variación no genera beneficios: el optimizador de PostgreSQL elegirá siempre un Seq Scan al tener que leer un porcentaje muy elevado de las páginas de disco. Mantenerlo solo provocaría una degradación inútil del rendimiento en escrituras sin ninguna ganancia en lecturas.

> **Nota:** El esquema ya cuenta con `idx_producto_categoria_activo`, un índice **parcial** (`WHERE activo = true`) que cubre el caso de uso legítimo de filtrar productos activos por categoría. Un índice simple sobre `activo` sería redundante e ineficiente.

---

## 4. Resumen Comparativo

| Consulta | Tiempo sin índice | Tiempo con índice | Mejora | Índice aplicado |
|---|---|---|---|---|
| Pedidos por rango de fechas | 36.468 ms | 0.021 ms | ~1736x | `idx_pedido_fecha` |
| Productos por precio (filtro + orden) | 3.898 ms | 0.346 ms | ~11x | `idx_producto_precio_desc` |
| Historial detalle por producto | 35.268 ms | 0.060 ms | ~588x | `idx_detalle_pedido_producto_cant` |
| Inserción masiva (1.000 registros) | 3.337 ms | 9.501 ms | −184 % | — (costo de mantenimiento) |

## 7. Parte C: Vista Materializada para Reporte Analítico

### 1. Elección del Reporte Costoso
Se identificó la necesidad de consultar periódicamente la **Facturación Total y Unidades Vendidas por Categoría y Mes**. Esta consulta sobre tablas en caliente requiere ejecutar múltiples `JOIN` entre `categoria`, `producto`, `detalle_pedido` y `pedido`, agrupando y procesando más de 200.000 registros con un ordenamiento intermedio en disco (`external merge` de 11 MB).

### 2. Definición e Índice Único
Se implementó la vista materializada `mv_facturacion_categoria_mes` poblada con datos iniciales (`WITH DATA`) y con un índice único sobre `(id_categoria, mes_anio)` para habilitar el refresco no bloqueante:

```sql
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT 
    c.id_categoria,
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha) AS mes_anio,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.cantidad) AS total_unidades,
    SUM(dp.subtotal) AS facturacion_total
FROM categoria c
JOIN producto pr ON c.id_categoria = pr.id_categoria
JOIN detalle_pedido dp ON pr.id_producto = dp.id_producto
JOIN pedido p ON dp.id_pedido = p.id_pedido
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes_pk 
ON mv_facturacion_categoria_mes (id_categoria, mes_anio);

Comparativa de Tiempos de Ejecución
Consulta Directa (Sin Materializar): 537.597 ms

Detalle: El motor requirió ejecutar 3 nodos Hash Join, un GroupAggregate y un ordenamiento external merge en disco consumiendo 11.472 kB.

Consulta a Vista Materializada: 0.057 ms

Detalle: Recorre únicamente las 52 filas precalculadas mediante un Seq Scan directo en memoria.

Conclusión de Impacto: La respuesta mejoró en aproximadamente 9.430 veces (~9400x más rápida), liberando CPU y memoria I/O en la base de datos.
