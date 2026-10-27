# SPEC_U6 — Mantenimiento y respaldo de `foodstorecopia`

**Motor:** PostgreSQL 16 · **Base productiva:** `foodstorecopia` · **Base de pruebas:** `foodstore_restore_test`
**Alcance:** tareas mínimas de mantenimiento, reglas de seguridad y criterio único de confirmación.

## 1. Tareas mínimas de mantenimiento

| Tarea | Frecuencia | Evidencia esperada |
|---|---|---|
| Respaldo diario con formato custom (`pg_dump -Fc`) de `foodstorecopia` | Diaria | Archivo `foodstorecopia_AAAAMMDD.dump` no vacío, salida de `pg_restore --list` sin errores y registro con fecha, hora, tamaño y código de salida en el log de respaldos. |
| Chequeo de salud de la base | Diaria | Salida de `pg_isready`, conexión exitosa a `foodstorecopia`, versión del servidor y resultados de las consultas de control (conexiones activas, transacciones largas y espacio en disco) guardados en el log con fecha y estado `OK`/`FALLA`. |
| Revisión de mantenimiento semanal | Semanal | Informe que consolide estado de `VACUUM`/`ANALYZE`, actividad de autovacuum, crecimiento de tablas e índices, espacio libre, errores relevantes del log del servidor y acciones correctivas aplicadas o pendientes. |
| Restauración de prueba en `foodstore_restore_test` | Semanal | Base `foodstore_restore_test` recreada desde el último respaldo con `pg_restore`, sin errores; verificación de objetos restaurados (tablas, secuencias, vistas, funciones), consultas de conteo exitosas y log de la prueba con fecha, duración y resultado. |

## 2. Reglas de seguridad

1. **Prohibición estricta de contraseñas en scripts:** ningún archivo `.sql`, `.sh`, `.bat`, `.ps1`, `.env` ni el repositorio debe contener contraseñas, cadenas de conexión con credenciales ni tokens. Esta regla no admite excepciones.
2. **Credenciales por variables de entorno o `.pgpass`:** usar `PGUSER`, `PGHOST`, `PGPORT` y `PGDATABASE`; la contraseña se tomará de `PGPASSWORD` solo en el entorno de ejecución o de `~/.pgpass` con permisos restrictivos (`0600` en Unix). Nunca imprimir, registrar ni capturar en pantalla el valor de las credenciales.
3. **Pruebas destructivas solo en `foodstore_restore_test`:** toda restauración con `--clean`, `DROP`, recreación de base, borrado de objetos o modificación masiva de datos se ejecutará exclusivamente sobre `foodstore_restore_test`. Queda prohibido ejecutar acciones destructivas sobre `foodstorecopia`; los scripts deberán validar el nombre de la base antes de operar y abortar si no coincide con `foodstore_restore_test`.

## 3. Condición de éxito global

Una tarea se considera **confirmada** únicamente cuando: (a) finaliza sin errores, con código de salida `0` y sin mensajes `ERROR`/`FATAL` en su salida; (b) genera y conserva la evidencia indicada en la tabla, identificada con fecha y hora; y (c) la evidencia es revisada y validada por el responsable. Si falla cualquiera de las tres condiciones, la tarea se registra como **no confirmada** y debe repetirse o corregirse, sin sustituir la evidencia anterior.
