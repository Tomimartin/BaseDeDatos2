-- Parte C: Vista Materializada para Reporte Analítico

-- 1. Creación de la vista materializada con datos iniciales

``` sql
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

-- 2. Índice único requerido para permitir REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes_pk 
ON mv_facturacion_categoria_mes (id_categoria, mes_anio);

## 7. Parte C: Vista Materializada para Reporte Analítico

### 1. Elección del Reporte Costoso
Se identificó la necesidad de consultar periódicamente la **Facturación Total y Unidades Vendidas por Categoría y Mes**. Esta consulta sobre tablas en caliente requiere ejecutar múltiples `JOIN` entre `categoria`, `producto`, `detalle_pedido` y `pedido`, agrupando y procesando más de 200.000 registros con un ordenamiento intermedio en disco (`external merge` de 11 MB).

### 2. Definición e Índice Único
Se implementó la vista materializada `mv_facturacion_categoria_mes` poblada con datos iniciales (`WITH DATA`) y con un índice único sobre `(id_categoria, mes_anio)` para habilitar el refresco no bloqueante:

Comparativa de Tiempos de Ejecución
Consulta Directa (Sin Materializar): 537.597 ms

Detalle: El motor requirió ejecutar 3 nodos Hash Join, un GroupAggregate y un ordenamiento external merge en disco consumiendo 11.472 kB.

Consulta a Vista Materializada: 0.057 ms

Detalle: Recorre únicamente las 52 filas precalculadas mediante un Seq Scan directo en memoria.

Conclusión de Impacto: La respuesta mejoró en aproximadamente 9.430 veces (~9400x más rápida), liberando CPU y memoria I/O en la base de datos.