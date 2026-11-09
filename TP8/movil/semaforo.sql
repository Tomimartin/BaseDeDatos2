-- TP8 | Consigna 2.b | SQLite >= 3.37
-- Compara solamente las solicitudes PENDIENTE con snapshot_servidor.
-- Soporta los booleanos exportados por PostgreSQL como t/f, true/false o 1/0.
-- PRIORIDAD: RECHAZADO > CONFLICTO > SIMULADO_APROBADO.
-- NO escribe en PostgreSQL y NO confirma ninguna venta.
WITH conteos AS (
    SELECT c.solicitud_uuid,
           COUNT(i.producto_id) AS n_items,
           SUM(CASE WHEN i.producto_id IS NOT NULL AND s.producto_id IS NULL THEN 1 ELSE 0 END) AS ausentes,
           SUM(CASE WHEN s.producto_id IS NOT NULL
                     AND (LOWER(TRIM(CAST(s.eliminado AS TEXT))) IN ('true','t','1')
                          OR s.eliminado IS NULL)
                    THEN 1 ELSE 0 END) AS bajas,
           SUM(CASE WHEN s.producto_id IS NOT NULL
                     AND (s.disponible IS NULL
                          OR LOWER(TRIM(CAST(s.disponible AS TEXT))) NOT IN ('true','t','1'))
                    THEN 1 ELSE 0 END) AS no_disponibles,
           SUM(CASE WHEN s.producto_id IS NOT NULL AND (CAST(s.stock AS INTEGER) IS NULL
                          OR i.cantidad > CAST(s.stock AS INTEGER))
                    THEN 1 ELSE 0 END) AS sin_stock,
           SUM(CASE WHEN s.producto_id IS NOT NULL
                     AND (CAST(s.precio_centavos AS INTEGER) IS NULL
                          OR i.precio_centavos_visto <> CAST(s.precio_centavos AS INTEGER))
                    THEN 1 ELSE 0 END) AS cambios_precio
    FROM cola_sync c
    LEFT JOIN item_borrador i ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.producto_id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
), decisiones AS (
    SELECT solicitud_uuid,
           CASE WHEN n_items = 0 OR ausentes > 0 OR bajas > 0
                     OR no_disponibles > 0 OR sin_stock > 0 THEN 'RECHAZADO'
                WHEN cambios_precio > 0 THEN 'CONFLICTO'
                ELSE 'SIMULADO_APROBADO' END AS nuevo_estado,
           CASE WHEN n_items = 0 THEN 'Borrador sin items'
                WHEN ausentes > 0 THEN 'Producto inexistente en el servidor'
                WHEN bajas > 0 THEN 'Producto dado de baja en el servidor'
                WHEN no_disponibles > 0 THEN 'Producto no disponible'
                WHEN sin_stock > 0 THEN 'Stock insuficiente en el servidor'
                WHEN cambios_precio > 0 THEN 'El precio cambio en el servidor'
                ELSE 'Datos coinciden con la instantanea' END AS nuevo_motivo
    FROM conteos
)
UPDATE cola_sync AS c
SET estado = d.nuevo_estado,
    motivo = d.nuevo_motivo
FROM decisiones AS d
WHERE c.solicitud_uuid = d.solicitud_uuid
  AND c.estado = 'PENDIENTE';

SELECT solicitud_uuid, estado, motivo
FROM cola_sync ORDER BY creada_en, solicitud_uuid;
