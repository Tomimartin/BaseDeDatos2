# Parte C — Informe del simulacro de incidente y análisis crítico de OpenCode

**Asignatura:** Base de Datos II — Unidad 5 · Food Store  
**Entorno:** instancia propia de desarrollo, PostgreSQL 17, base `foodstorecopia`  
**Fecha de pruebas:** 19/10/2026 (horario -03 según las marcas de log)  
**Estado:** evidencia de las pruebas y análisis crítico documentados. El episodio es **simulado**, no un incidente real.

## 1. Propósito y alcance

Reconstruir una secuencia controlada de intentos de autenticación, intento de lectura no autorizada y escalada de privilegios. Se usaron credenciales ficticias en una tabla separada y una función `fn_autenticar` de laboratorio, sin cambiar los dos registros preexistentes de `public.usuario`. El log fue anonimizado antes de compartirlo con OpenCode.

**Alcance importante:** los intentos de autenticación a `fn_autenticar` son **llamadas SQL**, no cuatro intentos independientes de conexión a PostgreSQL. Esta simulación no acredita ataque externo, extracción de datos ni compromiso del sistema.

## 2. Evidencias técnicas y secuencia temporal

| Hora (-03) | Hecho registrado | Resultado contrastado fuera del log |
|---|---|---|
| 23:50:34 | `fn_autenticar(... 'CLAVE_A') AS fallo_1` | `false` (captura 32) |
| 23:50:51 | `fn_autenticar(... 'CLAVE_B') AS fallo_2` | `false` (captura 33) |
| 23:51:07 | `fn_autenticar(... 'CLAVE_C') AS fallo_3` | `false` (captura 34) |
| 23:51:25 | `fn_autenticar(... 'CLAVE_D') AS acierto` | `true` (captura 35) |
| 23:53:43 | `SET ROLE app_web` y chequeo de permisos a `usuario` | `current_user=app_web`, `session_user=postgres`, sin `SELECT` sobre usuario (captura 36) |
| 23:56:08 | `SELECT COUNT(u.id) ... CROSS JOIN generate_series(1,1000)` | Rechazada con SQLSTATE `42501`: permiso denegado a `usuario` (captura 37) |
| 23:58:08 | `SELECT current_user` | El rol efectivo era `app_web` (captura 38) |
| 23:58:27 | `GRANT admin_datos TO app_web` | Rechazada con SQLSTATE `42501` (captura 39); membresía inexistente en comprobación posterior (captura 40) |

Fuente técnica del log: `docs/log_simulacro_anonimizado.txt` (10 entradas) y CSV anonimizado conservado en `docs/evidencias/43_fragmentos_reales_simulacro_anonimizados.csv`. Los valores de retorno y membresía se contrastaron con las **capturas**, no con el texto del log. La comprobación de membresía posterior no forma parte de las 10 entradas exportadas.

Todas las entradas anonimizadas comparten PID **44660**, nombre de sesión `DBA_LAB`, base `BD_LAB` y origen `LOCAL`. Son **etiquetas sintéticas**, excepto el PID técnico. La etiqueta de usuario en el prefijo del log representa la identidad de conexión anonimizada; no prueba por sí sola el rol efectivo después de `SET ROLE`.

## 3. Reconstrucción de OpenCode: aciertos

OpenCode identificó correctamente la secuencia de cuatro llamadas a la función de autenticación, el chequeo de permisos, la lectura masiva intentada y denegada, y el `GRANT` rechazado. Detectó que los eventos son de una única sesión técnica y propuso hipótesis de contención. Además reconoció en su sección de limitaciones que el log no muestra las respuestas reales de `fn_autenticar` ni los resultados de `SELECT current_user`.

Respuesta completa suministrada por el estudiante: `docs/respuesta_opencode_parte_C.md`. Captura: `docs/evidencias/44_respuesta_opencode_parte_C.png`.

## 4. Imprecisiones y afirmaciones no respaldadas por el log

1. **Cuarta autenticación supuestamente exitosa.** OpenCode afirmó «la cuarta acierta» y también reconoció que `AS acierto` podría ser solo un alias. **El log no contiene el valor booleano retornado.** La cuarta llamada sí fue exitosa en la prueba real, pero exclusivamente porque la captura 35 muestra `true`; no puede deducirse del log por sí solo.
2. **Motivo y sujeto del rechazo de `GRANT`.** OpenCode atribuyó el fallo a que `DBA_LAB` carecía de `ADMIN OPTION`. `DBA_LAB` es una etiqueta ficticia de usuario de conexión. Las capturas 38–39 muestran que la sentencia se ejecutó bajo el rol efectivo `app_web`, que no podía conceder `admin_datos`. No se debe concluir, a partir del prefijo anonimizado, que el usuario de conexión original carecía de privilegios.
3. **«Fuerza bruta», compromiso o intención maliciosa.** Son hipótesis a partir del patrón repetido, no conclusiones sustentadas. La ejecución conocida fue una práctica voluntaria y controlada.
4. **«Clave expuesta» y bloqueo del origen.** Los valores CLAVE_A a CLAVE_D son sustituciones ficticias y `LOCAL` es un origen anonimizado. No hay evidencia de contraseña productiva expuesta ni de dirección remota maliciosa.
5. **Cambio de rol comprobado en el log.** El archivo contiene la instrucción `SET ROLE app_web`, pero no su resultado; el rol efectivo se verificó aparte con `SELECT current_user` y su captura.

**Corrección adicional de contexto:** la consulta masiva generaría un conteo hipotético sobre copias si hubiera permisos, pero la ejecución fue denegada. Nunca se obtuvieron nombres, filas ni resultado agregado por esa operación.

## 5. Omisiones y limitaciones que importa documentar

- El análisis no podía verificar resultados booleanos ni devolver la captura del estado posterior; fue necesario contrastar las evidencias 32–40.
- No informa cantidades reales de datos expuestos: **no hay extracción demostrada**.
- La configuración `log_statement='all'` puede dejar contraseñas escritas en SQL visibles en el log; en nuestro entorno fueron valores de prueba, pero en un caso real habría que evitar el registro de credenciales en texto y restringir acceso a archivos de log.
- El error de codificación `Â«admin_datosÂ»` es un artefacto de representación de caracteres, no cambia el hecho del rechazo.
- El fragmento no permite determinar actividad previa o posterior a esas 10 entradas, ni la identidad física de quien ejecutó la sesión.
- Las pruebas se hicieron con `SET ROLE app_web` desde una conexión administrativa `postgres`; esto valida la autorización con ese rol efectivo, pero **no equivale** a una prueba de autenticación independiente mediante `LOGIN app_web`.

## 6. Propuesta de decisión humana de contención

**Decisión propuesta para que el estudiante/equipo la apruebe:** dar por contenida la secuencia dentro del entorno de desarrollo, **sin bloquear `LOCAL`, revocar usuarios ni terminar a la fuerza el backend**, porque el episodio fue simulado, las credenciales son ficticias y los controles de acceso impidieron leer `usuario` y otorgar `admin_datos`. Mantener las restricciones de mínimo privilegio y conservar la evidencia anonimizada con acceso limitado.

**En un caso real comparable:** preservar registros; confirmar identidad/origen, credenciales comprometidas y privilegios efectivos; revocar o rotar credenciales **solo cuando la evidencia lo justifique**; terminar sesiones no autorizadas siguiendo el procedimiento de respuesta; verificar que la membresía administrativa siga ausente; revisar el manejo de secretos en `fn_autenticar` y la auditoría; alertar sobre intentos repetidos y concesiones denegadas. Bloquear todo tráfico LOCAL sin investigar podría afectar operaciones legítimas.

**La aprobación final debe ser del estudiante/equipo; OpenCode únicamente generó hipótesis. Ninguna medida real de bloqueo, revocación o terminación se ejecutó por sugerencia automática de IA.**

## 7. Conclusión

La política RBAC resistió los intentos del laboratorio: autenticación ficticia controlada, lectura masiva **denegada** y escalamiento **denegado**. OpenCode ayudó a identificar secuencia y riesgos, pero requirió contraste humano para no tratar alias SQL como resultados ni confundir el usuario de conexión con el rol efectivo. Se conserva el log anonimizado, la respuesta íntegra de IA y las capturas de verificación.
