-- ============================================================================
-- data.sql: Carga de Datos de Prueba Sintéticos e Integración de Dominio
-- ============================================================================

BEGIN;

-- 1. Carga de Categorías
INSERT INTO categoria (id_categoria, nombre)
SELECT 
    g, 
    'Categoría ' || g
FROM generate_series(1, 100) AS g
ON CONFLICT (id_categoria) DO NOTHING;

-- 2. Carga de Productos (50.000 filas para pruebas de selectividad y precio)
INSERT INTO producto (id_producto, nombre, id_categoria, precio, stock, activo)
SELECT 
    g,
    'Producto ' || g,
    (g % 100) + 1,
    (random() * 10000)::numeric(10,2),
    (random() * 50)::int,              -- Incluye valores <= 10 para probar stock crítico
    (random() > 0.05)                  -- 95% productos activos
FROM generate_series(1, 50000) AS g
ON CONFLICT (id_producto) DO NOTHING;

-- 3. Carga de Clientes
INSERT INTO cliente (id_cliente, nombre, apellido, email)
SELECT 
    g,
    'Nombre_' || g,
    'Apellido_' || g,
    'cliente_' || g || '@mail.com'
FROM generate_series(1, 10000) AS g
ON CONFLICT (id_cliente) DO NOTHING;

-- 4. Carga de Pedidos (200.000 filas distribuidas en 2024)
INSERT INTO pedido (id_pedido, id_cliente, fecha)
SELECT 
    g,
    (random() * 9999 + 1)::int,
    '2024-01-01'::date + (random() * 365)::int * interval '1 day'
FROM generate_series(1, 200000) AS g
ON CONFLICT (id_pedido) DO NOTHING;

-- 5. Carga de Detalle de Pedidos (200.000 filas con subtotales calculados)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, subtotal)
SELECT 
    p,
    (random() * 49999 + 1)::int,
    cant,
    (cant * (random() * 500 + 10))::numeric(10,2)
FROM (
    SELECT 
        g AS p,
        (random() * 10 + 1)::int AS cant
    FROM generate_series(1, 200000) AS g
) sub
ON CONFLICT DO NOTHING;

COMMIT;