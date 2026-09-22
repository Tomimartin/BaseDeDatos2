--
-- Vistas para Food Store (PostgreSQL)
--

-- PRIMER VISTA PRODUCTOS MÁS VENDIDOS
CREATE OR REPLACE VIEW vista_productos_mas_vendidos AS
SELECT 
    p.id_producto,
    p.nombre AS nombre_producto,
    c.nombre AS categoria,
    SUM(dp.cantidad) AS total_unidades_vendidas,
    SUM(dp.subtotal) AS monto_total_recaudado
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON p.id_producto = dp.id_producto
GROUP BY p.id_producto, p.nombre, c.nombre
ORDER BY total_unidades_vendidas DESC;

--PRUEBA VERIFICACIÓN
SELECT * FROM vista_productos_mas_vendidos LIMIT 10;

-- SEGUNDA VISTA RESUMEN DE VENTAS MENSUAL POR USUARIO
CREATE OR REPLACE VIEW vista_ventas_usuario_mes AS
SELECT 
    c.id_cliente AS id_usuario,
    c.nombre || ' ' || c.apellido AS nombre_usuario,
    DATE_TRUNC('month', p.fecha) AS mes_anio,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.subtotal) AS total_gastado
FROM cliente c
JOIN pedido p ON c.id_cliente = p.id_cliente
JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
GROUP BY c.id_cliente, c.nombre, c.apellido, DATE_TRUNC('month', p.fecha)
ORDER BY mes_anio DESC, total_gastado DESC;

--PRUEBA VERIFICACIÓN
SELECT * FROM vista_ventas_usuario_mes LIMIT 10;

-- TERCER VISTA STOCK CRTÍCO
CREATE OR REPLACE VIEW vista_stock_critico AS
SELECT 
    p.id_producto,
    p.nombre AS nombre_producto,
    c.nombre AS categoria,
    p.stock,
    p.precio
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.stock <= 10 AND p.activo = TRUE
ORDER BY p.stock ASC;

-VERIFIACIÓN

SELECT * FROM vista_stock_critico;

