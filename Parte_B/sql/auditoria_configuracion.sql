-- Food Store / Unidad 5 / Parte B
-- SOLO para instancia de desarrollo; servidor completo, no solo una base.
-- Guardar primero los valores iniciales de pg_settings (evidencia 15).
-- Ejecutar conectado con superusuario PostgreSQL (p. ej., postgres).
-- IMPORTANTE: ejecutar las 4 sentencias ALTER SYSTEM POR SEPARADO (seleccionar una linea
-- por vez y presionar F5), sin BEGIN/COMMIT. No enviar todo el archivo en una sola
-- ejecucion, porque ciertos clientes agrupan sentencias en una transaccion implícita.
-- Luego, ejecutar SELECT pg_reload_conf() por separado.

ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_statement = 'mod';
ALTER SYSTEM SET log_line_prefix = '%m [%p] usuario=%u db=%d origen=%r ';

-- Enviar orden al servidor para releer configuracion.
SELECT pg_reload_conf() AS senal_de_recarga_enviada;

-- Para los ajustes superuser-backend, verificar abriendo una CONEXION NUEVA a pgAdmin.
-- Ejecutar esta SELECT en una sesion nueva, no necesariamente en la misma.
SELECT name AS parametro, setting AS valor, source AS origen_configuracion,
       pending_restart AS reinicio_pendiente
FROM pg_settings
WHERE name IN ('logging_collector', 'log_destination', 'log_connections',
               'log_disconnections', 'log_statement', 'log_line_prefix')
ORDER BY name;

-- Localizar el log activo (puede devolver NULL si el colector no dispone de ruta actual):
SELECT pg_current_logfile() AS log_actual;

-- NOTA: 'mod' registra INSERT/UPDATE/DELETE y DDL, pero NO SELECT.
-- En la prueba de lectura se usara, temporalmente, SET log_statement = 'all';
-- en una sesion supervisada. No usar datos sensibles ni claves SQL literales.
