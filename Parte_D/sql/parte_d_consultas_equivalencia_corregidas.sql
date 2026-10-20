-- Food Store - TP Unidad 5 - Parte D
-- Revisión humana de las consultas propuestas por OpenCode.
-- Base: foodstorecopia, solo lectura. NO mostrar nombres ni datos identificables.
-- IMPORTANTE: cada WITH aplica UNICAMENTE a la sentencia siguiente.

-- 1) Agregación por paridad de posición en la tabla anonimizada
WITH posiciones AS (
    SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM public.usuario_anon
)
SELECT (rn % 2 = 0) AS es_par,
       COUNT(*) AS cantidad
FROM posiciones
GROUP BY (rn % 2 = 0)
ORDER BY es_par;

-- 2) Agregación equivalente en la tabla real, sin acceder a nombres
WITH posiciones AS (
    SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM public.usuario
)
SELECT (rn % 2 = 0) AS es_par,
       COUNT(*) AS cantidad
FROM posiciones
GROUP BY (rn % 2 = 0)
ORDER BY es_par;

-- 3) Comparación por grupo y resultado global EN UNA SOLA SENTENCIA
-- Corrige el error de alcance de la CTE `comparacion` de OpenCode.
WITH anon AS (
    SELECT (rn % 2 = 0) AS es_par, COUNT(*) AS cantidad
    FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
        FROM public.usuario_anon
    ) p
    GROUP BY (rn % 2 = 0)
),
real AS (
    SELECT (rn % 2 = 0) AS es_par, COUNT(*) AS cantidad
    FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
        FROM public.usuario
    ) p
    GROUP BY (rn % 2 = 0)
),
comparacion AS (
    SELECT COALESCE(a.es_par, r.es_par) AS es_par,
           COALESCE(r.cantidad, 0) AS cantidad_real,
           COALESCE(a.cantidad, 0) AS cantidad_anonima,
           COALESCE(a.cantidad = r.cantidad, FALSE) AS coinciden
    FROM anon a
    FULL OUTER JOIN real r ON r.es_par = a.es_par
)
SELECT CASE WHEN es_par THEN 'par' ELSE 'impar' END AS grupo,
       cantidad_real,
       cantidad_anonima,
       coinciden,
       BOOL_AND(coinciden) OVER () AS todos_los_grupos_coinciden
FROM comparacion
ORDER BY es_par;

-- LIMITACIÓN: agrupar por posición (no por una variable de negocio) hace que la
-- distribución sea función del total de filas. La equivalencia esperada con
-- 2 registros es 1 impar y 1 par, pero no demuestra anonimización irreversible.
