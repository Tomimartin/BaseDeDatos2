PRAGMA foreign_keys = ON;
-- TP8 | Consigna 1.c. Ejecutar SOLO sobre una COPIA de la base SQLite.
-- En DB Browser, las transacciones internas pueden interferir con BEGIN.
-- Para prueba explicita BEGIN/COMMIT/ROLLBACK usar conexion Python sqlite3
-- sobre una copia, tal como se hizo durante el TP8.

-- C1: consultar el catalogo sin PostgreSQL.
SELECT producto_id, nombre, precio, stock_visto
FROM v_catalogo_disponible ORDER BY producto_id LIMIT 10;

-- PRUEBA BEGIN/COMMIT: borrador, item y solicitud en una transaccion.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('88888888-0000-4000-8000-000000000008', 1, 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('88888888-0000-4000-8000-000000000008', 1, 2, 250000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('88888888-0000-4000-8000-000000000018',
        '88888888-0000-4000-8000-000000000008', 'PENDIENTE');
COMMIT;
SELECT 'COMMIT pedido' AS prueba, COUNT(*) AS filas FROM pedido_borrador
WHERE id_local = '88888888-0000-4000-8000-000000000008';

-- PRUEBA BEGIN/ROLLBACK: los tres registros deben quedar en cero.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('99999999-0000-4000-8000-000000000009', 1, 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('99999999-0000-4000-8000-000000000009', 2, 1, 230000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado)
VALUES ('99999999-0000-4000-8000-000000000019',
        '99999999-0000-4000-8000-000000000009', 'PENDIENTE');
ROLLBACK;
SELECT 'pedido' AS registro, COUNT(*) AS cantidad FROM pedido_borrador
WHERE id_local = '99999999-0000-4000-8000-000000000009'
UNION ALL
SELECT 'item', COUNT(*) FROM item_borrador
WHERE id_local = '99999999-0000-4000-8000-000000000009'
UNION ALL
SELECT 'solicitud', COUNT(*) FROM cola_sync
WHERE solicitud_uuid = '99999999-0000-4000-8000-000000000019';

-- C7: ejecutar POR SEPARADO; se esperan errores y no se insertan filas.
-- Cantidad cero: SQLite error extendido 275 (SQLITE_CONSTRAINT_CHECK).
-- INSERT INTO item_borrador(id_local,producto_id,cantidad,precio_centavos_visto)
-- VALUES ('88888888-0000-4000-8000-000000000008', 3, 0, 120000);
-- Producto inexistente: SQLite error extendido 787 (SQLITE_CONSTRAINT_FOREIGNKEY).
-- INSERT INTO item_borrador(id_local,producto_id,cantidad,precio_centavos_visto)
-- VALUES ('88888888-0000-4000-8000-000000000008', -1, 2, 120000);
-- Control posterior: ninguno de los 2 intentos invalidados debe existir.
SELECT COUNT(*) AS items_invalidos FROM item_borrador
WHERE cantidad <= 0 OR producto_id = -1;

-- C6: ejecutar POR SEPARADO sobre una base donde ya se evaluó el caso C4
-- y su UUID permanece guardado como RECHAZADO. Esto provoca error 1555 (PK).
-- INSERT INTO cola_sync(solicitud_uuid,id_local,estado)
-- VALUES ('55555555-0000-4000-8000-000000000004',
--         '44444444-0000-4000-8000-000000000004','PENDIENTE');
-- NOTA: si se repite un UUID mientras el mismo borrador sigue PENDIENTE,
-- puede disparar el indice unico parcial (2067) antes que la PK; ambos impiden duplicados.
