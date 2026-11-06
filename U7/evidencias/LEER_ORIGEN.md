# Origen de las evidencias

- `pedidos_postgresql_origen.csv`: archivo original exportado por el equipo, conservado sin cambios.
- `resultado_mongodb_20261106_194409.json` y `mongodb_salida_20261106_194409.txt`: transcripciones del objeto JSON y de la salida de consola aportados por el equipo. La consola integrada no exportó archivos automáticamente.
- `03_comparacion_postgresql.png`: captura original de la ejecución de las dos consultas equivalentes. `comparacion_postgresql_transcrita.csv` transcribe las dos filas de esa captura.
- Las otras capturas muestran la estructura real, los cinco pedidos seleccionados y el error inicial de `load()`.
- `documentos_fuente_preparados.json` reproduce los datos preparados desde el CSV para el script. La ejecución comprobó su igualdad con los documentos leídos de MongoDB; este archivo no se presenta como un export directo de MongoDB.
- `resultados_esperados_desde_csv.json` contiene controles calculados antes de ejecutar, diferenciados de los resultados posteriores de MongoDB y PostgreSQL.

Los horarios terminados en `Z` de la salida MongoDB están en UTC. 19:44:09 UTC del 06/11/2026 corresponde a 16:44:09 UTC-03:00.
