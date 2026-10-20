-- Trabajo Practico Unidad 5 - Parte C: simulacro de incidente - Food Store.
-- SOLAMENTE foodstorecopia en ambiente propio de desarrollo, PostgreSQL 17.
-- Ejecutar MANUALMENTE por bloques en pgAdmin conectado como postgres.
-- NO ejecutar todo con F5: dos instrucciones deben FALLAR intencionalmente;
-- el cliente puede detener la ejecucion ante un ERROR.
-- Requiere haber ejecutado parte_c_credenciales_y_autenticacion.sql.
-- Se usan exclusivamente credenciales sinteticas del laboratorio.
-- No copiar contrasenas reales a este script ni a la bitacora.
-- Recordatorio: log_statement='all' registra el TEXTO de las sentencias.

-- PASO 0 (ejecutar y verificar). Deben verse foodstorecopia y postgres.
SELECT current_database() AS base, current_user AS conexion,
       pg_backend_pid() AS sesion;

-- PASO 1 (ejecutar con postgres). Activar el registro de SELECT por sesion.
-- No cambiar log_statement a nivel global del servidor.
SET log_statement = 'all';

-- PASO 2 (ejecutar con postgres). Actuar con privilegios de la aplicacion.
SET ROLE app_web;
SELECT current_user AS rol_efectivo, session_user AS conexion_original;

-- PASO 3: cuatro intentos en el orden exigido, ejecutar uno por uno.
-- Tres credenciales falsas, despues una autentica. Todo es FICTICIO.
SELECT public.fn_autenticar('u5_usuario_prueba', 'clave_falsa_1') AS fallo_1;
SELECT public.fn_autenticar('u5_usuario_prueba', 'clave_falsa_2') AS fallo_2;
SELECT public.fn_autenticar('u5_usuario_prueba', 'clave_falsa_3') AS fallo_3;
SELECT public.fn_autenticar('u5_usuario_prueba', 'ClaveSoloTP_U5_2026!') AS acierto;
-- Esperados: false, false, false, true.

-- PASO 4: SIMULAR lectura masiva NO AUTORIZADA de la tabla usuario.
-- Ejecutar por separado. Se espera ERROR por falta de SELECT(usuario).
-- COUNT(id) requiere acceso a la columna id; no devuelve nombres ni datos.
SELECT COUNT(u.id) AS volumen_intentado
FROM public.usuario AS u
CROSS JOIN generate_series(1, 1000) AS copias;
-- Esperado: ERROR permission denied for table usuario.
-- IMPORTANTE: NO afirmes que los datos se leyeron exitosamente.

-- PASO 5: intento de escalada de privilegios NO AUTORIZADA.
-- Ejecutar por separado y esperar ERROR de membresia/administracion.
GRANT admin_datos TO app_web;
-- Esperado: ERROR, el rol app_web no puede conceder admin_datos.
-- Si se otorgara, interrumpir el simulacro: defecto grave de seguridad.

-- PASO 6: cerrar el contexto del rol y restaurar logging de la sesion.
RESET ROLE;
RESET log_statement;
SELECT current_user AS rol_restaurado,
       current_setting('log_statement') AS log_statement_restaurado;

-- OPCIONAL, otra sesion/control de administracion, NO es la misma identidad:
-- Un admin_datos legitimo puede consultar datos para comparar el resultado.
-- No confundir esta lectura autorizada con la lectura bloqueada de app_web.
-- SET ROLE admin_datos;
-- SELECT COUNT(u.id) AS total_simulado
-- FROM public.usuario u CROSS JOIN generate_series(1, 1000) AS x;
-- RESET ROLE;

-- IMPORTANTE: Para analizar el incidente recuperar el log verdadero.
-- Anonimizar direcciones, nombres/identificadores antes de enviarlo a OpenCode.
-- La salida de fn_autenticar por SELECT no se ve necesariamente en el log
-- aunque la sentencia aparezca registrada; conservar capturas true/false.
