# Respuesta de OpenCode — Parte D

El estudiante entregó el siguiente código y explicación como respuesta de OpenCode. Se conserva para trazabilidad.

**Nota de revisión humana:** La última consulta `SELECT EVERY(coinciden) ... FROM comparacion` falla porque la CTE `comparacion` solo existe en la sentencia inmediatamente anterior. La corrección está en `sql/parte_d_consultas_equivalencia_corregidas.sql`. Los resultados agrupados se ejecutaron y verificaron posteriormente; ver `docs/evidencias/47_parte_D_equivalencia_grupos_confirmada.png` y `docs/verificacion_equivalencia.md`.

```sql
-- Respuesta proporcionada por el estudiante, generada en OpenCode para la Parte D.
-- Conservada sin ejecutarla ni corregirla; la revisión se encuentra en BITACORA.md.

-- 1. Agregación sobre usuario_anon por paridad de posición ordinal
WITH pos AS (
  SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM public.usuario_anon
)
SELECT (rn % 2 = 0) AS es_par,
       COUNT(*)     AS cantidad
FROM pos
GROUP BY rn % 2
ORDER BY es_par;

-- 2. Equivalente sobre usuario (recalculando ROW_NUMBER)
WITH pos AS (
  SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM public.usuario
)
SELECT (rn % 2 = 0) AS es_par,
       COUNT(*)     AS cantidad
FROM pos
GROUP BY rn % 2
ORDER BY es_par;

-- 3. Comparación de ambos agrupamientos
WITH a AS (
  SELECT (rn % 2 = 0) AS es_par, COUNT(*) AS cantidad
  FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM public.usuario_anon
  ) pos
  GROUP BY rn % 2
),
u AS (
  SELECT (rn % 2 = 0) AS es_par, COUNT(*) AS cantidad
  FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM public.usuario
  ) pos
  GROUP BY rn % 2
),
comparacion AS (
  SELECT COALESCE(a.es_par, u.es_par) AS es_par,
         COALESCE(a.cantidad, 0)      AS cant_anon,
         COALESCE(u.cantidad, 0)      AS cant_usuario,
         COALESCE(a.cantidad, 0) = COALESCE(u.cantidad, 0) AS coinciden
  FROM a
  FULL OUTER JOIN u ON a.es_par = u.es_par
)
-- 3a. Detalle por grupo
SELECT * FROM comparacion ORDER BY es_par;

-- 3b. Bandera global: ¿coinciden todos los grupos?
SELECT EVERY(coinciden) AS todos_los_grupos_coinciden
FROM comparacion; 
```

**Limitaciones indicadas por OpenCode:** con n=2 no hay base para una prueba chi-cuadrado; la agrupación por paridad solo compara cantidades artificiales y no demuestra preservación de información de negocio.
