WITH pedidos_migrados AS (
    SELECT
        id_pedido,
        CASE
            WHEN eliminado IS TRUE THEN 'ELIMINADO'
            WHEN eliminado IS FALSE THEN 'ACTIVO'
            ELSE 'SIN_DEFINIR'
        END AS estado
    FROM public.pedido
    WHERE id_pedido IN (
        180991, 181008, 181019, 181036, 181045
    )
)
SELECT
    'Estado ACTIVO' AS consulta,
    COUNT(*) AS cantidad,
    COALESCE(
        array_agg(id_pedido ORDER BY id_pedido),
        '{}'::bigint[]
    ) AS ids
FROM pedidos_migrados
WHERE estado = 'ACTIVO'

UNION ALL

SELECT
    'Producto 30998' AS consulta,
    COUNT(*) AS cantidad,
    COALESCE(
        array_agg(p.id_pedido ORDER BY p.id_pedido),
        '{}'::bigint[]
    ) AS ids
FROM pedidos_migrados p
WHERE EXISTS (
    SELECT 1
    FROM public.detalle_pedido dp
    WHERE dp.id_pedido = p.id_pedido
      AND dp.id_producto = 30998
)
ORDER BY consulta;
