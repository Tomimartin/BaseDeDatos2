-- ============================================================
--  queries.sql — Food Store (PostgreSQL 17)
--  Todas las consultas del proyecto organizadas por parte.
--  Ejecutar sobre la base de datos food_store luego de haber
--  corrido base_food_store.sql, indices.sql y views.sql.
-- ============================================================


-- ============================================================
--  PARTE A — OPTIMIZACIÓN DE ÍNDICES
--  Medición de rendimiento antes y después de los índices.
--  Ver: informe_mediciones.md | specs/spec_pedidos_fecha.md
--       specs/spec_producto_precio.md | specs/spec_detalle_producto.md
-- ============================================================


-- ------------------------------------------------------------
--  CONSULTA 1 — Búsqueda de pedidos por rango de fechas
--  Índice: idx_pedido_fecha ON pedido(fecha)
--  Antes:  Seq Scan  — 36.468 ms  | costo 0.00..4471.05
--  Después: Index Scan — 0.021 ms | costo 0.42..8.44
--  Mejora: ~1736x
-- ------------------------------------------------------------

-- Plan ANTES del índice (baseline):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';

-- Consulta de producción:
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';


-- ------------------------------------------------------------
--  CONSULTA 2 — Filtrado y ordenamiento de productos por precio
--  Índice: idx_producto_precio_desc ON producto(precio DESC)
--  Antes:  Seq Scan + Quicksort en memoria (42 kB) — 3.898 ms
--  Después: Bitmap Index Scan — 0.346 ms | costo 589.91..590.75
--  Mejora: ~11x
-- ------------------------------------------------------------

-- Plan ANTES del índice (baseline):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;

-- Consulta de producción:
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;


-- ------------------------------------------------------------
--  CONSULTA 3 — Historial de ventas de un producto por cantidad
--  Índice: idx_detalle_pedido_producto_cant
--          ON detalle_pedido(id_producto, cantidad DESC)
--  Antes:  Parallel Seq Scan + Sort — 35.268 ms (200.000 filas)
--  Después: Index Scan — 0.060 ms | costo 0.42..20.10
--  Mejora: ~588x
-- ------------------------------------------------------------

-- Plan ANTES del índice (baseline):
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;

-- Consulta de producción:
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;


-- ------------------------------------------------------------
--  PRUEBA DE COSTO DE MANTENIMIENTO — Inserción masiva
--  Mide la penalización en escrituras con índices activos.
--  Ejecutar primero CON índices (estado normal) y luego
--  sin ellos (drop + recrear) para comparar tiempos.
--  Resultado: sin índices 3.337 ms | con índices 9.501 ms (~184% más lento)
--  NOTA: el ROLLBACK garantiza que no quedan datos residuales.
-- ------------------------------------------------------------

BEGIN;
INSERT INTO categoria (nombre)
SELECT 'Categoria_' || i
FROM generate_series(100000, 101000) AS i;
ROLLBACK;


-- ------------------------------------------------------------
--  ÍNDICE DESCARTADO — Baja cardinalidad (no ejecutar)
--  Columna booleana activo: solo TRUE/FALSE.
--  El optimizador siempre preferirá Seq Scan sobre este índice.
--  Penaliza escrituras sin aportar ninguna ganancia en lecturas.
-- ------------------------------------------------------------

-- CREATE INDEX idx_producto_activo ON producto(activo);  -- DESCARTADO


-- ============================================================
--  PARTE B — VISTAS RELACIONALES
--  Ver: views.sql | specs/spec_vista_stock_critico.md
--       specs/spec_vista_ventas_usuario_mes.md
--       specs/spec_vista_producots_mas_vendidos
-- ============================================================


-- ------------------------------------------------------------
--  VISTA 1 — Productos más vendidos
--  Ranking por unidades vendidas y monto total recaudado.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW vista_productos_mas_vendidos AS
SELECT
    p.id_producto,
    p.nombre            AS nombre_producto,
    c.nombre            AS categoria,
    SUM(dp.cantidad)    AS total_unidades_vendidas,
    SUM(dp.subtotal)    AS monto_total_recaudado
FROM producto p
JOIN categoria     c  ON p.id_categoria  = c.id_categoria
JOIN detalle_pedido dp ON p.id_producto  = dp.id_producto
GROUP BY p.id_producto, p.nombre, c.nombre
ORDER BY total_unidades_vendidas DESC;

-- Verificación:
SELECT * FROM vista_productos_mas_vendidos LIMIT 10;


-- ------------------------------------------------------------
--  VISTA 2 — Resumen de ventas mensual por cliente
--  Aplica principio de mínimo privilegio: omite columnas
--  sensibles de la tabla cliente (email, teléfono).
--  GRANT SELECT ON vista_ventas_usuario_mes TO rol_reportes;
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW vista_ventas_usuario_mes AS
SELECT
    c.id_cliente                            AS id_usuario,
    c.nombre || ' ' || c.apellido           AS nombre_usuario,
    DATE_TRUNC('month', p.fecha)            AS mes_anio,
    COUNT(DISTINCT p.id_pedido)             AS total_pedidos,
    SUM(dp.subtotal)                        AS total_gastado
FROM cliente c
JOIN pedido          p  ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp  ON p.id_pedido  = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido, DATE_TRUNC('month', p.fecha)
ORDER BY mes_anio DESC, total_gastado DESC;

-- Verificación:
SELECT * FROM vista_ventas_usuario_mes LIMIT 10;

-- Verificación de equivalencia (resultado debe coincidir exactamente con la vista):
SELECT
    c.id_cliente                            AS id_usuario,
    c.nombre || ' ' || c.apellido           AS nombre_usuario,
    DATE_TRUNC('month', p.fecha)            AS mes_anio,
    COUNT(DISTINCT p.id_pedido)             AS total_pedidos,
    SUM(dp.subtotal)                        AS total_gastado
FROM cliente c
JOIN pedido          p  ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp  ON p.id_pedido  = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido, DATE_TRUNC('month', p.fecha)
ORDER BY mes_anio DESC, total_gastado DESC
LIMIT 5;

-- Control de acceso seguro:
-- GRANT SELECT ON vista_ventas_usuario_mes TO rol_reportes;


-- ------------------------------------------------------------
--  VISTA 3 — Stock crítico
--  Productos activos con stock <= 10 unidades, ordenados ASC.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW vista_stock_critico AS
SELECT
    p.id_producto,
    p.nombre   AS nombre_producto,
    c.nombre   AS categoria,
    p.stock,
    p.precio
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.stock <= 10
  AND p.activo = TRUE
ORDER BY p.stock ASC;

-- Verificación:
SELECT * FROM vista_stock_critico;


-- ============================================================
--  PARTE C — VISTA MATERIALIZADA
--  Facturación total por categoría y mes.
--  Ver: materializadas.md | specs/spec_vista_materializada_facturacion.md
--  Antes (consulta directa): 537.597 ms (Hash Join + external merge 11 MB)
--  Después (vista materializada): 0.057 ms (~9400x más rápida)
-- ============================================================


-- ------------------------------------------------------------
--  Consulta directa (costosa) — baseline antes de materializar
-- ------------------------------------------------------------

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.id_categoria,
    c.nombre                        AS categoria,
    DATE_TRUNC('month', p.fecha)    AS mes_anio,
    COUNT(DISTINCT p.id_pedido)     AS total_pedidos,
    SUM(dp.cantidad)                AS total_unidades,
    SUM(dp.subtotal)                AS facturacion_total
FROM categoria c
JOIN producto      pr ON c.id_categoria  = pr.id_categoria
JOIN detalle_pedido dp ON pr.id_producto = dp.id_producto
JOIN pedido         p  ON dp.id_pedido   = p.id_pedido
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
ORDER BY mes_anio DESC, facturacion_total DESC;


-- ------------------------------------------------------------
--  Creación de la vista materializada con datos iniciales
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.id_categoria,
    c.nombre                        AS categoria,
    DATE_TRUNC('month', p.fecha)    AS mes_anio,
    COUNT(DISTINCT p.id_pedido)     AS total_pedidos,
    SUM(dp.cantidad)                AS total_unidades,
    SUM(dp.subtotal)                AS facturacion_total
FROM categoria c
JOIN producto      pr ON c.id_categoria  = pr.id_categoria
JOIN detalle_pedido dp ON pr.id_producto = dp.id_producto
JOIN pedido         p  ON dp.id_pedido   = p.id_pedido
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

-- Índice único (requerido para REFRESH CONCURRENTLY):
CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes_pk
    ON mv_facturacion_categoria_mes (id_categoria, mes_anio);


-- ------------------------------------------------------------
--  Consulta sobre la vista materializada (~0.057 ms)
-- ------------------------------------------------------------

SELECT *
FROM mv_facturacion_categoria_mes
ORDER BY mes_anio DESC, facturacion_total DESC;


-- ------------------------------------------------------------
--  Refresco de datos (ejecutar cuando cambien los pedidos)
-- ------------------------------------------------------------

-- Sin bloqueo (requiere el índice único creado arriba):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;

-- Con bloqueo (más rápido, bloquea lecturas durante el refresco):
-- REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes;
