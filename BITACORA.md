# BITÁCORA.md — Trabajo Práctico Unidad 5: Food Store

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación  
**Base de desarrollo:** `foodstorecopia`  
**Motor:** PostgreSQL 17.11  
**Alcance:** Partes A, B, C, D y cierre E; pruebas realizadas en una instancia local de desarrollo.  
**Herramientas:** Kiro (especificación), OpenCode (auditoría y análisis), pgAdmin 4/psql (ejecución y validación), Git (versionado). También se utilizó asistencia conversacional para preparar y revisar artefactos. 

> **Criterio de registro:** se describen las interacciones y resultados realmente aportados en el trabajo. Cuando no se conservó la transcripción literal del prompt, se indica que es un resumen. Las conclusiones sobre PostgreSQL provienen de consultas, capturas y logs, no de asumir que una respuesta de IA es correcta.

## 1. Registro de uso de IA (formato solicitado)

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| **Parte A — Kiro.** Diseñar `requirements` y `design` para seis roles de Food Store, con mínimo privilegio, permisos de tabla/columna y herencia. *Descripción del pedido; el prompt literal de Kiro no se conservó.* | Generó requisitos y diseño con `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, `app_web` y `admin_datos`. | Se comprobó el esquema de `foodstorecopia`: `usuario` solo tiene `id` y `nombre`; se verificaron tablas, secuencias y vistas. Se corrigieron diferencias del diseño (`admin_datos` como LOGIN, herencia INHERIT en el script efectivo y acceso de la aplicación al almacén). Los originales de Kiro se conservaron para trazabilidad. **Evidencias 01–10.** |
| **Parte A — OpenCode.** Auditar `roles.sql` por mínimo privilegio, `GRANT`/`REVOKE`, permisos por columna, herencia, `ALTER DEFAULT PRIVILEGES` y compatibilidad PostgreSQL; proponer mejoras sin ejecutar. *Resumen de la solicitud efectuada.* | Señaló `USAGE` innecesario sobre secuencias IDENTITY, `UPDATE` muy amplio sobre `detalle_pedido`, uso de `eliminado`, privilegios futuros de funciones y posibilidad de `GRANT MAINTAIN`. | Se restringió `UPDATE` de `detalle_pedido.precio_unitario`, manteniendo la cancelación por `pedido.eliminado` tras la decisión del estudiante. Se verificó que `app_web` puede cancelar y modificar cantidad, pero no editar precio ni ejecutar `DELETE`. No se otorgó `MAINTAIN` por su amplitud. **Evidencias 11–13.** |
| **Parte A — revisión crítica de OpenCode.** Examinar su propuesta para funciones futuras: `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`. | La propuesta aparentaba impedir la ejecución pública de futuras funciones. | Se detectó que la revocación limitada al esquema no cancela el `EXECUTE` que PostgreSQL concede globalmente por defecto. Se aplicó la variante global para el creador `postgres` y `pg_default_acl` mostró la ACL esperada. La política no alcanza automáticamente a otros roles creadores. **Evidencia 14.** |
| **Parte B — asistencia conversacional, no OpenCode.** Preparar una prueba de logging y resolver la lectura de un archivo de registro que fallaba por codificación. | Se propuso habilitar conexiones/desconexiones y `log_statement='mod'`; para lectura de `SELECT` se usó temporalmente `all`. Ante SQLSTATE 22021 se propuso leer el archivo como binario y convertirlo desde WIN1252. | Se comprobaron `on`, `on` y `mod` desde una nueva sesión psql. Se verificaron eventos reales de autenticación fallida y un bloque SQL de prueba en el log. **Limitación:** una entrada multilínea no demuestra el éxito individual de cada sentencia. No se atribuye a OpenCode una interacción que no ocurrió. **Evidencias 15–27 y CSV exportado.** |
| **Parte C — OpenCode.** Analizar **solo** `log_simulacro_anonimizado.txt`, reconstruir la secuencia, separar hechos de hipótesis y proponer contención sin ejecutar acciones. *La solicitud se conserva en `Parte_C/docs/prompt_opencode_parte_C.txt`; el texto disponible documenta el contenido solicitado.* | Reconstruyó cuatro llamadas a `fn_autenticar`, chequeo de privilegios, lectura masiva rechazada y `GRANT admin_datos TO app_web` rechazado. Propuso rotar credenciales, revisar roles y eventualmente cerrar la sesión. | Se comparó con pgAdmin: los booleanos fueron `false`, `false`, `false`, `true`; `current_user=app_web`; los dos intentos no autorizados fallaron con SQLSTATE 42501 y `pg_has_role` devolvió `false`. **Error de IA:** interpretó el alias `AS acierto` como prueba de autenticación exitosa; el log no contiene el booleano. **Otro error:** atribuyó el fallo al usuario de conexión anonimizado `DBA_LAB`, cuando el rol efectivo era `app_web`. **Evidencias 32–40 y 44.** |
| **Parte D — OpenCode.** Generar agregaciones equivalentes de `usuario` y `usuario_anon` por paridad de posición ordinal y una comparación con `FULL OUTER JOIN`, sin inventar rol/fecha ni mostrar nombres. *Solicitud conservada en `Parte_D/docs/prompt_opencode_parte_D.txt`.* | Generó dos consultas con `ROW_NUMBER()` y comparación por grupos, pero agregó un `SELECT EVERY(coinciden) FROM comparacion` después de finalizar la sentencia que definía esa CTE. | Se corrigió el alcance de la CTE usando `BOOL_AND(coinciden) OVER ()` dentro de la consulta de comparación. En pgAdmin se verificaron los grupos impar/par: **1 real y 1 anónimo en cada grupo**, con todas las comprobaciones en `true`. La prueba confirma esos conteos artificiales, no equivalencia estadística de variables de negocio ni anonimización irreversible. **Evidencias 45–47.** |

### Aclaraciones sobre las herramientas

- **Kiro:** produjo la especificación inicial de la Parte A. Los archivos originales están en `Parte_A/docs/kiro_roles_spec/`.
- **OpenCode:** participó en la auditoría de la Parte A y los análisis de las Partes C y D. Se conservaron sus respuestas; las capturas y comprobaciones de la base fueron la referencia para aceptar o rechazar las conclusiones.
- **Git:** registró la evolución mediante commits por partes (ver sección 4). Git no valida por sí solo que el SQL funcione.
- **Asistencia conversacional:** ayudó a elaborar SQL, extraer evidencia y preparar informes; **no se presenta falsamente como ejecución de OpenCode**.

## 2. Error de IA más significativo y cómo se detectó

Durante la Parte C, OpenCode describió la cuarta llamada a `fn_autenticar` como «acierto» a partir del alias SQL `AS acierto`. El registro de PostgreSQL mostraba **qué sentencia se ejecutó**, pero no el resultado booleano de esa función. Se detectó la inferencia indebida comparando el log anonimizado con la captura 35, donde pgAdmin sí devolvía `true`. La prueba de éxito existió, pero **no estaba sustentada únicamente por el log entregado a la IA**. También fue necesario distinguir la identidad de conexión (`DBA_LAB`, etiqueta anonimizada) del rol efectivo `app_web` bajo el que se denegó `GRANT admin_datos TO app_web`.

Esta revisión demuestra por qué la IA fue una ayuda para reconstruir hechos, pero no una fuente única para decidir sobre un incidente. Sus hipótesis se aceptaron solamente después de contrastarlas con resultados reales y límites del mecanismo de logging.

**Otro error identificado (Parte D):** una CTE no puede ser consultada por una segunda sentencia independiente. Se corrigió la consulta propuesta por OpenCode antes de ejecutarla, y el resultado quedó demostrado por la evidencia 47.

## 3. Evaluación humana del incidente y protección de datos

**Hechos comprobados del laboratorio:** se usaron credenciales ficticias; tres llamadas a `fn_autenticar` devolvieron `false` y una `true`; la lectura masiva de `usuario` fue denegada; el `GRANT` administrativo fue rechazado; y `app_web` siguió sin ser miembro de `admin_datos`. No se demostró extracción de datos ni acceso remoto. Las llamadas SQL a `fn_autenticar` **no son intentos de conexión separados al servidor**.

**Contención propuesta para el entorno de desarrollo (pendiente de ratificación expresa por el estudiante):** conservar la evidencia y mantener los permisos actuales, sin bloquear automáticamente `LOCAL`, revocar usuarios ficticios ni terminar sesiones. En un incidente real, correspondería preservar logs, validar identidad y origen, evaluar rotación de credenciales, revisar membresías y aplicar restricciones proporcionadas a la evidencia. No se ejecutaron medidas de contención sugeridas por OpenCode de forma automática. El análisis detallado figura en `Parte_C/docs/informe_incidente.md`.

**Datos que no deben entregarse sin tratamiento previo a una IA:** nombres y apellidos reales, correos, teléfonos, datos de clientes, contraseñas, hashes y logs que contengan información identificable. Se deben utilizar datos sintéticos, minimizar campos y evaluar el riesgo de reidentificación. En la Parte D se generaron dos registros con nombres e identificadores sintéticos y se verificó la igualdad de conteos ordinales; la muestra de dos usuarios y la correspondencia de orden impiden afirmar anonimización irreversible.

## 4. Verificación del historial de Git — Parte E

Se revisaron las capturas aportadas de `git status`, `git log --oneline -8` y `git ls-files` en el repositorio existente **BaseDeDatos2**.

| Commit observado | Parte | Mensaje del historial |
|---|---|---|
| `f1c26f5` | A | `Agrega Parte A: roles y permisos con evidencias` |
| `92e5f8a` | B | `Agrega Parte B: auditoria de logging y evidencias` |
| `e0100d7` | C | `Agrega Parte C: credenciales, pgcrypto y simulacro de incidente` |
| `4ef8f18` | D | `Agrega Parte D: anonimizacion y verificacion de equivalencia estadistica` |

En la captura de estado, la rama `main` figuraba sincronizada con `origin/main` **en ese momento**. `git ls-files` confirmó que los scripts, informes y evidencias de las cuatro partes estaban bajo `Parte_A/`, `Parte_B/`, `Parte_C/` y `Parte_D/`.

**Observaciones pendientes antes de entregar:**

1. El enunciado pide una estructura única `food-store-tp-u5/sql/`, `food-store-tp-u5/docs/` y `BITACORA.md` en la raíz de ese proyecto. El repositorio mostrado contiene carpetas `Parte_A/` a `Parte_D/` dentro de un repositorio mayor de la materia; por lo tanto **no coincide literalmente con la estructura solicitada**. Si se exige esa estructura, reorganizar los archivos conservando los commits existentes.
2. `git status` mostró `cargar_datos_masivos.sql` eliminado y los archivos `.kiro/`, `specs/u5_design.md` y `specs/u5_requirements.md` sin seguimiento. No incluir cambios ajenos al TP por accidente. Si el archivo SQL fue borrado sin querer, recuperarlo con `git restore -- cargar_datos_masivos.sql`.
3. Los cuatro commits históricos están acreditados. **El commit de la Parte E y el `git push` final todavía deben realizarse y comprobarse.** No se inventa ese commit.

**Qué se haría diferente la próxima vez:** crear el directorio exclusivo `food-store-tp-u5` desde el principio, conservar los prompts literales desde el primer uso de IA y separar los archivos de producción de diagnósticos temporales. Los commits por parte sí se realizaron con mensajes legibles.

## 5. Índice de respaldos

- **Parte A:** `Parte_A/sql/`, `Parte_A/docs/`, especificaciones de Kiro y capturas 01–14.
- **Parte B:** `Parte_B/sql/`, `Parte_B/docs/informe_auditoria.md`, `log_auditoria_prueba.txt`, capturas 15–27.
- **Parte C:** `Parte_C/sql/`, `Parte_C/docs/log_simulacro_anonimizado.txt`, `respuesta_opencode_parte_C.md`, `informe_incidente.md`, capturas 28–44.
- **Parte D:** `Parte_D/sql/`, `Parte_D/docs/verificacion_equivalencia.md`, `respuesta_opencode_parte_D.md`, capturas 45–47.

> Esta bitácora debe guardarse como `BITACORA.md` en la raíz del proyecto que se entregue. Registrar el último commit únicamente después de ejecutarlo realmente.
