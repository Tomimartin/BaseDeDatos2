# SPEC_U6 - Plan de mantenimiento y recuperacion

**Entorno real:** Windows, PostgreSQL 17.11. **Origen:** `foodstorecopia`.
**Destino descartable del ensayo:** `foodstore_restore_test`.
El equipo conserva el nombre real del origen; la consigna lo denomina `foodstore`.

| Tarea | Frecuencia propuesta | Evidencia y criterio de exito |
|---|---|---|
| Respaldo custom | Diaria | `scripts/backup_foodstore.ps1`: archivo `.dump` con fecha y hora, no vacio; `pg_restore --list` correcto; log, metadatos y salida 0. |
| Chequeo de salud | Diaria | `health_check.sql`: tamano, conexiones, estado de tablas y consultas activas. Guardar la salida con fecha y base. |
| Revision de mantenimiento | Semanal | Revisar tuplas muertas, autovacuum y ANALYZE. Elegir una accion segun la observacion y guardar verificacion posterior. |
| Restauracion de prueba | Semanal | `scripts/restore_test.ps1`: creacion del destino, restauracion sin errores, conteos iguales a la linea base e integridad en cero; log y resultado JSON. |

## Reglas y metodo

- Las contrasenas se solicitan en ejecucion; no se guardan en scripts ni en Git. El restaurador usa `PGPASSWORD` solo durante el proceso y restablece su valor al terminar.
- La base de negocio se conserva. El restaurador tiene el destino fijo `foodstore_restore_test`; eliminarla y recrearla requiere `-RecreateTestDatabase`.
- Registrar los conteos exactos inmediatamente antes del respaldo, manteniendo los datos sin cambios durante esa comparacion. El restaurador entregado contiene la linea base real del 06/11/2026; actualizarla para ensayos con otros datos.
- RTO previsto: 300 segundos. Medir desde antes de crear la base de prueba hasta completar conteos y controles logicos; la eliminacion previa del destino pertenece a la preparacion.
- RPO previsto: 24 horas. Para este laboratorio se calcula la antiguedad del respaldo al iniciar el ensayo, tomando su hora de inicio. No representa perdida real medida de transacciones.
- No usar VACUUM FULL como tarea periodica. El ANALYZE manual se fundamenta con el estado previo de las estadisticas.
- Confirmar la version/ruta de los clientes antes de programar las tareas. Probar manualmente y revisar los resultados antes de aceptarlos.

**Condicion global:** salida 0, evidencias conservadas, cinco conteos coincidentes, cero productos y detalles invalidos y metricas observadas registradas. La lectura del listado de un dump no reemplaza la restauracion efectiva.
