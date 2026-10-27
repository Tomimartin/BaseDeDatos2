-- health_check.sql
-- Chequeo de salud para la base de datos 'foodstorecopia' (PostgreSQL 16)
-- Ejecutar conectado a la base foodstorecopia (o con conexión a ella)

-- 1) Tamaño de la base de datos (pg_size_pretty)
SELECT
  datname AS database_name,
  pg_size_pretty(pg_database_size(datname)) AS database_size_pretty,
  pg_database_size(datname) AS database_size_bytes
FROM pg_database
WHERE datname = 'foodstorecopia';

-- 2) Actividad de conexiones en pg_stat_database
SELECT
  datname AS database_name,
  numbackends AS current_connections,
  xact_commit AS transactions_committed,
  xact_rollback AS transactions_rolled_back,
  blks_read AS blocks_read,
  blks_hit AS blocks_hit,
  tup_returned AS tuples_returned,
  tup_fetched AS tuples_fetched,
  tup_inserted AS tuples_inserted,
  tup_updated AS tuples_updated,
  tup_deleted AS tuples_deleted,
  conflicts,
  deadlocks,
  stats_reset
FROM pg_stat_database
WHERE datname = 'foodstorecopia';

-- 3) Estado de tuplas muertas/vivas en pg_stat_user_tables
SELECT
  schemaname,
  relname AS table_name,
  n_live_tup AS live_tuples,
  n_dead_tup AS dead_tuples,
  CASE 
    WHEN n_live_tup = 0 THEN 0
    ELSE ROUND((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0)) * 100, 2)
  END AS dead_tuple_percent,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  autovacuum_count,
  autoanalyze_count
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, schemaname, relname;

-- 4) Consultas activas no-idle en pg_stat_activity
SELECT
  pid,
  usename AS username,
  application_name,
  client_addr,
  state,
  query_start,
  now() - query_start AS query_duration,
  wait_event_type,
  wait_event,
  left(query, 100) AS query_preview
FROM pg_stat_activity
WHERE datname = 'foodstorecopia'
  AND state IS DISTINCT FROM 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start;
