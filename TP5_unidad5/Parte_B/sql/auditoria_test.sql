-- Food Store / Unidad 5 / Parte B — prueba controlada para psql 17.11
-- ESTADO: PREPARADO; pendiente de ejecución por el estudiante.
-- Ejecutar conectado a la base foodstorecopia como administrador en una sesión de desarrollo.
-- log_statement = mod no registra SELECT. Durante esta prueba, activar 'all'
-- solamente para esta sesión; restablecer con RESET al terminar.
-- No utilizar datos personales ni contraseñas en sentencias registradas.

SET log_statement = 'all';

BEGIN;

-- Tabla TEMPORAL de prueba en la base de desarrollo: no toca tablas reales.
CREATE TEMP TABLE auditoria_u5_prueba (
    id integer PRIMARY KEY,
    descripcion text NOT NULL
);

-- Inserción
INSERT INTO auditoria_u5_prueba (id, descripcion)
VALUES (1, 'registro_sintetico');

-- Actualización
UPDATE auditoria_u5_prueba
SET descripcion = 'registro_modificado'
WHERE id = 1;

-- Lectura (visible en los logs solo por SET log_statement = 'all')
SELECT id, descripcion FROM auditoria_u5_prueba;

-- Revertir todo el trabajo de prueba. La actividad ya queda registrada en log.
ROLLBACK;

-- Volver a la política general registrada previamente (mod).
RESET log_statement;

-- Ubicación relativa del archivo de log activo, para usar en el siguiente paso.
SELECT pg_current_logfile() AS archivo_log_actual;
