-- maintenance.sql
-- Mantenimiento para la base de datos 'foodstorecopia' (PostgreSQL 16)
-- Ejecutar conectado a la base foodstorecopia, preferentemente fuera de horas pico
-- NOTA: NO usar VACUUM FULL para mantenimiento habitual (ver comentarios abajo)

-- ===========================================================
-- 1) REVISIÓN DE ESTADO DE AUTOVACUUM / ANALYZE
-- ===========================================================

-- 1a) Estado de autovacuum por tabla (configuración efectiva y actividad reciente)
SELECT
  schemaname,
  relname AS table_name,
  n_live_tup AS live_tuples,
  n_dead_tup AS dead_tuples,
  CASE 
    WHEN n_live_tup = 0 THEN 0
    ELSE ROUND((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)) * 100, 2)
  END AS dead_tuple_percent,
  last_autovacuum,
  last_autoanalyze,
  autovacuum_count,
  autoanalyze_count,
  pg_size_pretty(pg_table_size(quote_ident(schemaname)||'.'||quote_ident(relname))) AS table_size
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, schemaname, relname;

-- 1b) Tablas que podrían requerir VACUUM/ANALYZE (umbral orientativo)
-- Umbral ilustrativo: >10% de tuplas muertas o sin autovacuum reciente
SELECT
  schemaname,
  relname AS table_name,
  n_live_tup,
  n_dead_tup,
  CASE 
    WHEN n_live_tup = 0 THEN 0
    ELSE ROUND((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)) * 100, 2)
  END AS dead_tuple_percent,
  last_autovacuum,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE (n_live_tup + n_dead_tup) > 0
  AND (
    n_dead_tup > 1000  -- muchas tuplas muertas
    OR (n_live_tup > 0 AND n_dead_tup::numeric / (n_live_tup + n_dead_tup) > 0.10)  -- >10% muertas
    OR last_autovacuum IS NULL  -- nunca ha hecho autovacuum
  )
ORDER BY dead_tuple_percent DESC NULLS LAST;

-- 1c) Estado general de autovacuum en el cluster
SELECT
  name,
  setting,
  unit,
  source
FROM pg_settings
WHERE name IN (
  'autovacuum',
  'autovacuum_vacuum_threshold',
  'autovacuum_vacuum_scale_factor',
  'autovacuum_analyze_threshold',
  'autovacuum_analyze_scale_factor',
  'autovacuum_max_workers',
  'autovacuum_naptime',
  'maintenance_work_mem',
  'vacuum_cost_limit',
  'vacuum_cost_delay'
)
ORDER BY name;

-- ===========================================================
-- 2) INSTRUCCIÓN DE MANTENIMIENTO SEGURA
-- ===========================================================

-- INSTRUCCIÓN RECOMENDADA PARA MANTENIMIENTO HABITUAL:
-- VACUUM ANALYZE actualiza estadísticas del planificador (ANALYZE) y recupera espacio
-- ocupado por tuplas muertas sin bloquear lecturas/escrituras de forma intensiva (VACUUM).
-- Es seguro para uso periódico en producción y es la opción por defecto.
VACUUM ANALYZE;

-- JUSTIFICACIÓN DEL USO DE VACUUM ANALYZE (NO VACUUM FULL):
--
-- - VACUUM (normal): marca el espacio como reutilizable dentro de la tabla, previene
--   el wraparound de XID y no requiere ACCESS EXCLUSIVE bloqueando DML por largos periodos
--   en la mayoría de los casos. Es compatible con operación continua.
-- - ANALYZE: actualiza las estadísticas de pg_statistic para que el planificador elija
--   mejores planes de ejecución.
-- - VACUUM ANALYZE: combina ambos efectos con un solo comando, ideal para mantenimiento
--   rutinario (diario/semanal según crecimiento).
--
-- ¿POR QUÉ DESCARTAR VACUUM FULL PARA MANTENIMIENTO HABITUAL?
--
-- - VACUUM FULL reescribe completamente la tabla y sus índices en un nuevo archivo,
--   lo cual requiere un bloqueo ACCESS EXCLUSIVE sobre la tabla durante toda la operación
--   (bloquea SELECT, INSERT, UPDATE, DELETE).
-- - Genera una mayor carga de I/O, necesita espacio temporal adicional (aprox. tamaño
--   de tabla+índices) y es considerablemente más lento en tablas grandes.
-- - Solo debe considerarse en casos excepcionales: bloat severo que no se corrige
--   con VACUUM normal/autovacuum, o necesidad de recuperar espacio al sistema operativo
--   de forma drástica tras borrar volúmenes masivos. Incluso entonces, evaluar con
--   herramientas como pgstattuple/pg_repack (si están disponibles) como alternativas
--   menos invasivas.
-- - Para mantenimiento habitual, NUNCA es la opción recomendada; usar VACUUM ANALYZE
--   o dejar que autovacuum gestione la limpieza de forma automática.
