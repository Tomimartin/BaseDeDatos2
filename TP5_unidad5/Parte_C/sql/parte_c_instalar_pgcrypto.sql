-- Unidad 5, Parte C — Extensión para autenticación sintética.
-- Ejecutar solo en la base de desarrollo foodstorecopia con permisos adecuados.
-- Instala la extensión en esta base de datos; no modifica los registros de public.usuario.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- Verificación: se espera pgcrypto y versión 1.3 (según disponibilidad comprobada).
SELECT extname AS extension, extversion AS version_instalada
FROM pg_extension
WHERE extname = 'pgcrypto';
