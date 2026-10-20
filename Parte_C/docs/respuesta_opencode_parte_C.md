# Respuesta completa de OpenCode — Parte C

**Fuente:** contenido textual y captura suministrados por el estudiante el 20/10/2026.
**Instrucción al asistente:** analizar únicamente `docs/log_simulacro_anonimizado.txt` sin contexto adicional y sin ejecutar cambios.
**Captura parcial de la respuesta:** `docs/evidencias/44_respuesta_opencode_parte_C.png`.

A continuación se conserva la respuesta facilitada por el estudiante. Se ajusta únicamente la presentación Markdown; los hechos y afirmaciones son los de OpenCode y **no están necesariamente validados**.

## 1. Reconstrucción cronológica

| Hora (-03) | Evento | Resultado descrito por OpenCode |
|---|---|---|
| 23:50:34 | `fn_autenticar('USUARIO_SIMULADO', 'CLAVE_A')` | `fallo_1` |
| 23:50:51 | `fn_autenticar(..., 'CLAVE_B')` | `fallo_2` |
| 23:51:07 | `fn_autenticar(..., 'CLAVE_C')` | `fallo_3` |
| 23:51:25 | `fn_autenticar(..., 'CLAVE_D')` | `acierto` (4.º intento, ~17 s entre intentos) |
| 23:53:43 | `SET ROLE app_web` y chequeo de privilegios sobre `public.usuario` | Sin error registrado |
| 23:56:08 | `SELECT COUNT ... CROSS JOIN generate_series(1,1000)` sobre `public.usuario` | ERROR: permiso denegado a la tabla usuario |
| 23:58:08 | `SELECT current_user` | Sin error |
| 23:58:27 | `GRANT admin_datos TO app_web` | ERROR: permiso denegado para otorgar el rol |

Según OpenCode, todo proviene de la misma sesión de backend: PID 44660, usuario DBA_LAB, base BD_LAB, origen LOCAL.

## 2. Operaciones sospechosas

- Fuerza bruta / prueba de credenciales (23:50–23:51): cuatro llamadas consecutivas a la misma función con claves distintas y nombres de ensayo (`fallo_1`…`acierto`); la cuarta «acierta» según OpenCode.
- Escalada de privilegios intentada (23:58): `GRANT admin_datos TO app_web` falla porque, según OpenCode, DBA_LAB no tiene ADMIN OPTION sobre ese rol.
- Reconocimiento de permisos (23:53): chequeo con `has_table_privilege` y luego intento de lectura masiva (1000 copias cruzadas) sobre `public.usuario`; patrón de sondeo/volumen de extracción.
- Cambio de rol (`SET ROLE app_web`): el actor opera bajo rol de aplicación, no bajo su identidad efectiva.

## 3. Hipótesis de contención propuestas por OpenCode

- Revocar/resetear credenciales de USUARIO_SIMULADO y rotar la clave expuesta CLAVE_D de inmediato.
- Cerrar la sesión backend PID 44660 y bloquear origen LOCAL si no es esperado a esa hora.
- Auditar `fn_autenticar`: evitar registrar claves en texto plano e implementar bloqueo/backoff tras varios fallos.
- Revisar el rol de inicio de sesión y aplicar mínimo privilegio.
- Verificar las membresías de `admin_datos` y los `GRANT` vigentes.
- Monitorear concesiones fallidas y llamadas repetidas de autenticación.

## 4. Hechos comprobables vs. suposiciones, según OpenCode

**Hechos que señaló:** cuatro intentos de autenticación y «acierto» al cuarto; misma sesión PID 44660, usuario DBA_LAB, base BD_LAB y origen LOCAL; lectura masiva y GRANT denegados; comillas mal decodificadas `Â«admin_datosÂ»` en el último error.

**Suposiciones que declaró:** si el cuarto intento fue un descifrado frente a una prueba legítima; si DBA_LAB fue comprometido o realizó un simulacro; si efectivamente se cambió al rol `app_web` (no está el resultado del SELECT); intención maliciosa frente a simulacro.

## 5. Información que el log no permite determinar, según OpenCode

- Qué devuelve `fn_autenticar` y si «acierto» es solo el alias `AS acierto`.
- El rol efectivo resultante del `SET ROLE`.
- Si hubo intentos de red (el origen es LOCAL).
- El contenido de `public.usuario`, su esquema o el volumen real de datos.
- Quién ejecutó la sesión, el cliente o script, la versión de PostgreSQL y la configuración completa de logging.
- Si hubo actividad posterior al fragmento.
- Si CLAVE_D es una contraseña real o un placeholder.

> Nota de conservación: El propio análisis de OpenCode contiene una contradicción: clasifica «acierto» como hecho, pero a la vez reconoce que no puede distinguir si es solo un alias. La evaluación crítica se documenta en `docs/informe_incidente.md`.
