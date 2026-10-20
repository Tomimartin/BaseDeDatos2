-- Food Store - TP Unidad 5 - Parte D
-- Anonimizacion determinista de la tabla usuario.
-- Ejecutar en la base de desarrollo foodstorecopia como administrador.
-- NO cambia ninguna fila de public.usuario.
-- La tabla destino conserva cantidad de filas, NO los identificadores originales.

BEGIN;

CREATE TABLE IF NOT EXISTS public.usuario_anon (
    id BIGINT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
);

-- Solo se vacia la tabla anonima generada para el TP.
TRUNCATE TABLE public.usuario_anon;

-- ROW_NUMBER crea identificadores sinteticos de manera reproducible
-- para el estado actual de la tabla. Ningun nombre ni ID original se copia.
INSERT INTO public.usuario_anon (id, nombre)
SELECT
    ROW_NUMBER() OVER (ORDER BY u.id)::BIGINT AS id,
    'Usuario_Anon_' || LPAD(
        (ROW_NUMBER() OVER (ORDER BY u.id))::TEXT, 4, '0'
    ) AS nombre
FROM public.usuario AS u;

COMMIT;

-- Salida de prueba: SOLO DATOS SINTETICOS.
SELECT id, nombre
FROM public.usuario_anon
ORDER BY id;

-- Comparacion global de cantidades (sin mostrar nombres reales).
SELECT
    (SELECT COUNT(*) FROM public.usuario) AS cantidad_real,
    (SELECT COUNT(*) FROM public.usuario_anon) AS cantidad_anonima,
    (SELECT COUNT(*) FROM public.usuario) =
      (SELECT COUNT(*) FROM public.usuario_anon) AS cantidades_coinciden;
