-- U6 - Food Store. Ejecutar conectado a foodstorecopia.
-- Consultas de lectura. No eliminan ni modifican registros del negocio.

-- 1. Tamano de la base actual.
SELECT current_database() AS base,
       pg_size_pretty(pg_database_size(current_database())) AS tamano;

-- 2. Conexiones y actividad acumulada.
SELECT datname AS base, numbackends AS conexiones,
       xact_commit, xact_rollback, deadlocks
FROM pg_stat_database
WHERE datname = current_database();

-- 3. Estado de tablas y mantenimiento registrado.
SELECT current_database() AS base, schemaname, relname AS tabla,
       n_live_tup AS filas_estimadas,
       n_dead_tup AS tuplas_muertas,
       n_mod_since_analyze AS cambios_desde_analyze,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- 4. Otras consultas y sesiones que no estan inactivas.
SELECT pid, usename AS usuario, state AS estado,
       clock_timestamp() - query_start AS duracion,
       LEFT(query, 150) AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start;
