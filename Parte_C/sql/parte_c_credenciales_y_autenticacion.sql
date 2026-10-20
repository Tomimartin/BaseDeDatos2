-- TP Unidad 5 - Parte C: credenciales de prueba y fn_autenticar.
-- SOLO ejecutar en la base LOCAL DE DESARROLLO foodstorecopia, como postgres.
-- Requiere pgcrypto 1.3 instalada; comprobado en la captura N.º 30.
-- No altera los 2 registros existentes de public.usuario.
-- CLAVE TOTALMENTE FICTICIA: se utiliza exclusivamente para el laboratorio.
-- ATENCION: no usar estas credenciales ni este esquema como autenticacion de produccion.

BEGIN;

-- Credenciales de un usuario ficticio, separadas de public.usuario.
CREATE TABLE IF NOT EXISTS public.u5_credenciales_prueba (
    usuario     TEXT PRIMARY KEY,
    clave_hash  TEXT NOT NULL,
    activo      BOOLEAN NOT NULL DEFAULT TRUE
);

REVOKE ALL ON TABLE public.u5_credenciales_prueba FROM PUBLIC;

-- El hash se calcula en el servidor con bcrypt (gen_salt('bf')).
INSERT INTO public.u5_credenciales_prueba (usuario, clave_hash, activo)
VALUES (
    'u5_usuario_prueba',
    public.crypt('ClaveSoloTP_U5_2026!', public.gen_salt('bf')),
    TRUE
)
ON CONFLICT (usuario) DO UPDATE
SET clave_hash = EXCLUDED.clave_hash,
    activo = EXCLUDED.activo;

-- Seguridad: se permite la ejecucion a app_web, pero NO leer la tabla
-- de hashes directamente. La consulta usa nombres totalmente calificados.
CREATE OR REPLACE FUNCTION public.fn_autenticar(
    p_usuario TEXT,
    p_clave TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $func$
    SELECT EXISTS (
        SELECT 1
        FROM public.u5_credenciales_prueba AS c
        WHERE c.usuario = p_usuario
          AND c.activo = TRUE
          AND c.clave_hash = public.crypt(p_clave, c.clave_hash)
    );
$func$;

REVOKE ALL ON FUNCTION public.fn_autenticar(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_autenticar(TEXT, TEXT) TO app_web;

COMMIT;

-- PRUEBA NO DESTRUCTIVA: resultado esperado true / false.
SELECT
    public.fn_autenticar('u5_usuario_prueba', 'ClaveSoloTP_U5_2026!') AS autenticacion_correcta,
    public.fn_autenticar('u5_usuario_prueba', 'clave_equivocada') AS autenticacion_incorrecta;
