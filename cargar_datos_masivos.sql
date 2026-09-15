-- =====================================================================
-- Carga masiva de datos para Food Store (PostgreSQL)
-- Generado con generate_series, sin PL/pgSQL.
-- Ejecutar solo sobre una copia de la base (nunca en producción):
--   psql -U postgres -h localhost -d "food_store-copia" -v ON_ERROR_STOP=1 -f cargar_datos_masivos.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) 50.000 productos nuevos, distribuidos de forma pareja entre las
--    categorías existentes. Precio entre 500 y 5000, stock 0..200.
--    Se usan ids explícitos (OVERRIDING SYSTEM VALUE) para poder
--    referenciarlos de forma determinística en detalle_pedido.
-- ---------------------------------------------------------------------

WITH cats AS (
    SELECT array_agg(id_categoria ORDER BY id_categoria) AS ids,
           count(*) AS n
    FROM public.categoria
),
base AS (
    SELECT COALESCE(max(id_producto), 0) AS b FROM public.producto
)
INSERT INTO public.producto (
    id_producto, nombre, descripcion, precio, stock, activo, id_categoria
)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    'Producto generado ' || (base.b + g.g),
    'Carga masiva de prueba',
    round((500 + random() * 4500)::numeric, 2),     -- CHECK precio > 0
    floor(random() * 201)::int,                      -- 0..200, CHECK stock >= 0
    true,
    cats.ids[((g.g - 1) % cats.n) + 1]              -- reparto equilibrado
FROM generate_series(1, 50000) AS g(g)
CROSS JOIN cats, base;

-- ---------------------------------------------------------------------
-- 2) 20.000 clientes nuevos. Emails únicos por construcción.
--    Se usan ids explícitos (OVERRIDING SYSTEM VALUE) para que la
--    secuencia no dependa de corridas previas.
-- ---------------------------------------------------------------------

WITH base AS (
    SELECT COALESCE(max(id_cliente), 0) AS b FROM public.cliente
)
INSERT INTO public.cliente (id_cliente, nombre, apellido, email, telefono)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    'Nombre ' || g.g,
    'Apellido ' || g.g,
    'cliente' || g.g || '@foodstore.com',            -- UNIQUE (email)
    '261' || lpad((floor(random() * 10000000)::bigint)::text, 7, '0')
FROM generate_series(1, 20000) AS g(g)
CROSS JOIN base;

-- ---------------------------------------------------------------------
-- 3) 200.000 pedidos nuevos. Fechas en el pasado (CHECK fecha <= now()),
--    forma de pago del enum e id_cliente existente.
-- ---------------------------------------------------------------------

WITH base AS (
    SELECT COALESCE(max(id_pedido), 0) AS b FROM public.pedido
)
INSERT INTO public.pedido (id_pedido, fecha, forma_pago, id_cliente)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    now() - (random() * interval '365 days'),
    (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']::public.forma_pago_enum[])[1 + floor(random() * 3)::int],
    1 + floor(random() * (SELECT max(id_cliente) FROM public.cliente))::bigint
FROM generate_series(1, 200000) AS g(g)
CROSS JOIN base;

-- ---------------------------------------------------------------------
-- 4) Detalles de pedido: 1 línea por cada pedido nuevo (200.000).
--    Producto asignado por mapeo determinístico para garantizar que
--    exista, cantidad > 0 y precio_unitario = precio real del producto.
--    No se duplica la PK (id_pedido, id_producto) porque cada pedido
--    tiene un único detalle.
-- ---------------------------------------------------------------------

INSERT INTO public.detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    p.id_pedido,
    pr.id_producto,
    1 + ((p.id_pedido - 1) % 20)::int,              -- cantidad 1..20
    pr.precio                                       -- precio_unitario >= 0
FROM public.pedido p
JOIN public.producto pr
  ON pr.id_producto = 11 + ((p.id_pedido - 4) % 50000)
WHERE p.id_pedido > 3;

-- ---------------------------------------------------------------------
-- 5) Resincronizar secuencias (los ids se insertaron con
--    OVERRIDING SYSTEM VALUE, por lo que las secuencias no avanzaron).
-- ---------------------------------------------------------------------

SELECT setval(
    pg_get_serial_sequence('public.producto', 'id_producto'),
    (SELECT max(id_producto) FROM public.producto)
);
SELECT setval(
    pg_get_serial_sequence('public.pedido', 'id_pedido'),
    (SELECT max(id_pedido) FROM public.pedido)
);
SELECT setval(
    pg_get_serial_sequence('public.cliente', 'id_cliente'),
    (SELECT max(id_cliente) FROM public.cliente)
);

COMMIT;

-- =====================================================================
-- Verificación rápida (después del commit) con psql:
--   SELECT count(*) FROM producto;          -- 50.010 (10 + 50.000)
--   SELECT count(*) FROM cliente;           -- 20.004 (4 + 20.000)
--   SELECT count(*) FROM pedido;            -- 200.003 (3 + 200.000)
--   SELECT count(*) FROM detalle_pedido;    -- 200.003
-- =====================================================================