# Informe de auditoría — Food Store (Unidad 5, Parte B)

**Base de pruebas:** `foodstorecopia` · **Motor observado:** PostgreSQL 17.11 · **Entorno:** desarrollo local en Windows.

**Estado:** pruebas y extracción de la muestra de log completadas; la evidencia disponible se analiza con las limitaciones indicadas. No se afirma que exista una auditoría exhaustiva fila por fila.

## 1. Configuración de auditoría

Se verificaron los siguientes parámetros, inicialmente y luego de modificar la configuración del servidor de desarrollo:

| Parámetro | Valor inicial | Valor configurado/verificado | Utilidad |
|---|---|---|---|
| `logging_collector` | `on` | `on` | Persistir registros del servidor en archivos |
| `log_destination` | `stderr` | `stderr` | Destino que utiliza el recolector |
| `log_connections` | `off` | `on` en una nueva sesión psql | Registrar intentos de conexión |
| `log_disconnections` | `off` | `on` en una nueva sesión psql | Registrar desconexiones |
| `log_statement` | `none` | `mod` | Registrar escrituras y DDL; `SELECT` no queda incluido normalmente |
| `log_line_prefix` | `%t` | `%m [%p] usuario=%u db=%d origen=%r ` | Fecha/hora, PID, usuario, base y conexión remota/local |

Las sentencias utilizadas en la instancia de desarrollo fueron `ALTER SYSTEM SET ...` y `SELECT pg_reload_conf();`. La señal de recarga devolvió `true`. Al principio, la sesión de pgAdmin (PID `29260`) seguía mostrando `off` para los dos parámetros de conexión; había comenzado a las 17:33, antes de la última recarga de las 17:55. En una **sesión independiente de psql**, PID `22636`, se verificaron los valores definitivos **`on`, `on`, `mod`**, con origen `configuration file` (evidencia 22). No fue necesario reiniciar el servidor por completo.

## 2. Operaciones de prueba y extracción

En una sesión de desarrollo se presentó un bloque con `SET log_statement='all'`, creación de una tabla temporal `auditoria_u5_prueba`, `INSERT` de un registro sintético, `UPDATE`, `SELECT`, `ROLLBACK` y `RESET log_statement`. El ajuste temporal de `log_statement` sirve para incluir lecturas en la prueba. La tabla era temporal y el bloque incluía `ROLLBACK`; no se pretendía conservar datos.

**Limitación de la evidencia:** pgAdmin transmitió el bloque como **una sola sentencia multilínea** registrada a las 23:09:25. El registro exportado prueba la presencia de esos comandos en el texto enviado al servidor, pero no contiene confirmación individual de éxito, filas afectadas o resultados de consulta para cada paso. Para una verificación más fuerte, ejecutar cada operación por separado y conservar los mensajes o los eventos de log independientes.

El intento de leer el log con `pg_read_file()` devolvió `SQLSTATE 22021` por bytes no válidos como UTF-8. La alternativa probada fue `pg_read_binary_file()` seguida de `convert_from(..., 'WIN1252')`, que permitió leer y exportar los eventos, sin modificar las tablas. El fragmento procede de `docs/log_auditoria_prueba_original.csv`, entregado desde pgAdmin. Se conservaron solo los **tres eventos pertinentes**; dos exportaciones idénticas no se cuentan como pruebas adicionales.

## 3. Eventos exportados del log

| Fecha y hora (`-03`) | PID | Rol | Base | Origen | Evento |
|---|---:|---|---|---|---|
| 19/10/2026 23:03:35.195 | 35688 | `postgres` | `foodstorecopia` | `::1(38945)` | Fallo de autenticación de contraseña (`FATAL`) |
| 19/10/2026 23:09:25.223 | 29260 | `postgres` | `foodstorecopia` | `::1(9310)` | Sentencia multilínea de pruebas, con operaciones `CREATE`, `INSERT`, `UPDATE` y `SELECT` |
| 19/10/2026 23:19:12.254 | 16284 | `postgres` | `foodstorecopia` | `::1(39981)` | Fallo de autenticación de contraseña (`FATAL`) |

`::1` es la dirección loopback local IPv6: los registros no demuestran un ataque remoto. Las entradas `FATAL` son rechazos, **no inicios de sesión exitosos**. La captura de SQL Shell y los eventos del servidor documentan el intento fallido, sin establecer si fue intencional o accidental.

**Archivos vinculados:** `docs/log_auditoria_prueba.txt`, `docs/log_auditoria_prueba_original.csv`, `sql/auditoria_test.sql`; capturas `docs/evidencias/15_...` a `27_...` y su índice.

## 4. Utilidad de la auditoría y límites

El prefijo registra **cuándo** ocurrió el evento, **quién** (rol de base), **en qué base** y **desde dónde** se originó (dirección/puerto); las entradas de sentencias describen **qué SQL se envió**. El texto por sí solo no garantiza quién era la persona física detrás del rol, ni indica las filas y valores modificados, ni confirma que cada comando de un bloque haya tenido éxito. `log_statement='mod'` tampoco registra consultas `SELECT` normales. La extensión `pgaudit` puede ampliar el detalle de auditoría de sentencias y objetos, pero no crea automáticamente un historial completo de valores anteriores/posteriores por fila; para ello son habituales triggers específicos con tablas de historial.

## 5. ¿El log es un activo sensible? ¿Quién debería leerlo?

Sí. El log puede incluir consultas, identificadores, correos, direcciones de origen y, si la aplicación registra SQL con literales, incluso información privada. Por eso debe tratarse como información sensible, reducir su retención al mínimo necesario y evitar publicarlo sin revisión y anonimización.

Solo administradores responsables de la base y personal de seguridad expresamente autorizado deberían acceder a los logs, con permisos de lectura restringidos en el sistema operativo y sin escritura para los usuarios comunes. No deben utilizarse permisos públicos ni dejar el directorio de logs accesible a los roles de la aplicación; también conviene proteger la integridad y controlar la rotación de los archivos.

## 6. Evaluación final de la Parte B

Se verificó la configuración de logging desde una nueva sesión, se exportó un fragmento auténtico del archivo del servidor con el bloque SQL de prueba y se documentaron **dos rechazos de autenticación**. La parte funcional queda respaldada en el alcance explicado. **No se acredita** auditoría de filas, éxito de cada operación por separado ni un historial completo de conexiones/desconexiones únicamente por estos tres eventos.
