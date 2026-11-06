-- U6 - Mantenimiento de foodstorecopia, PostgreSQL 17.11.
-- Ejecutar en foodstorecopia. Guardar las salidas antes y despues.
-- Con psql, utilizar -v ON_ERROR_STOP=1 para detenerse ante errores.
-- Observacion del 06/11/2026: los COUNT(*) previos fueron positivos,
-- pero n_live_tup aparecia en cero y last_analyze/last_autoanalyze en NULL.
-- Se eligio ANALYZE para actualizar las estadisticas del planificador.
-- No se interpreto un NULL como prueba de que nunca se hubiera analizado.
-- El resultado VERBOSE observo 1 version no vigente en categoria y 3 en
-- producto. No se justifico una limpieza manual general por ese volumen.
-- Autovacuum y track_counts se verificaron habilitados.
-- ANALYZE actualiza estadisticas; no elimina las versiones no vigentes.
-- No se utiliza VACUUM FULL como mantenimiento periodico.

-- 1. Confirmacion de entorno y configuracion.
SELECT current_database() AS base_actual,
       current_setting('track_counts') AS track_counts,
       current_setting('autovacuum') AS autovacuum;

-- 2. Observacion previa de autovacuum y estadisticas.
SELECT relname AS tabla, n_live_tup AS filas_estimadas,
       n_dead_tup AS tuplas_muertas,
       n_mod_since_analyze AS cambios_desde_analyze,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- 3. Accion aplicada y probada en el laboratorio.
ANALYZE VERBOSE public.categoria;
ANALYZE VERBOSE public.cliente;
ANALYZE VERBOSE public.producto;
ANALYZE VERBOSE public.pedido;
ANALYZE VERBOSE public.detalle_pedido;

-- 4. Verificacion posterior. En el ensayo, analyze_count fue 1 en las cinco.
SELECT relname AS tabla, n_live_tup AS filas_estimadas,
       last_analyze, analyze_count,
       current_setting('track_counts') AS track_counts,
       current_setting('autovacuum') AS autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND relname IN ('categoria', 'cliente', 'producto', 'pedido', 'detalle_pedido')
ORDER BY relname;
