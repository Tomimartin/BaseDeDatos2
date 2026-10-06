-- TP Unidad 4 - Parte 2 - Desnormalizacion controlada
-- PostgreSQL / base foodstorecopia / esquema public.
-- Ejecutar los bloques en orden sobre las tablas y los datos existentes.
-- Requiere eliminado en pedido y detalle_pedido, como en la consulta del TP.
-- La fecha original es timestamptz: se filtra por el intervalo completo del dia.
-- El dia de venta se interpreta con la zona horaria de Argentina.

SET TIME ZONE 'America/Argentina/Buenos_Aires';

-- 5.2(c): columnas precalculadas y disparadores de sincronizacion.
BEGIN;
LOCK TABLE public.pedido, public.detalle_pedido,
    public.producto, public.categoria IN SHARE ROW EXCLUSIVE MODE;
ALTER TABLE public.detalle_pedido
    ADD COLUMN IF NOT EXISTS fecha_venta DATE,
    ADD COLUMN IF NOT EXISTS categoria_venta VARCHAR(80),
    ADD COLUMN IF NOT EXISTS pedido_eliminado BOOLEAN;

-- Completar las columnas redundantes con los datos existentes.
UPDATE public.detalle_pedido AS dp
SET fecha_venta = (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
    categoria_venta = c.nombre,
    pedido_eliminado = ped.eliminado
FROM public.pedido AS ped, public.producto AS pr, public.categoria AS c
WHERE ped.id_pedido = dp.id_pedido
  AND pr.id_producto = dp.id_producto
  AND c.id_categoria = pr.id_categoria;

ALTER TABLE public.detalle_pedido
    ALTER COLUMN fecha_venta SET NOT NULL,
    ALTER COLUMN categoria_venta SET NOT NULL,
    ALTER COLUMN pedido_eliminado SET NOT NULL;

CREATE OR REPLACE FUNCTION public.tp_u4_completar_detalle()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- Bloqueos de fila evitan copiar un padre mientras otro escritor lo cambia.
    SELECT (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
           ped.eliminado
    INTO STRICT NEW.fecha_venta, NEW.pedido_eliminado
    FROM public.pedido AS ped
    WHERE ped.id_pedido = NEW.id_pedido
    FOR SHARE OF ped;

    SELECT c.nombre INTO STRICT NEW.categoria_venta
    FROM public.producto AS pr
    JOIN public.categoria AS c ON c.id_categoria = pr.id_categoria
    WHERE pr.id_producto = NEW.id_producto
    FOR SHARE OF pr, c;
    RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER trg_tp_u4_completar_detalle
BEFORE INSERT OR UPDATE ON public.detalle_pedido
FOR EACH ROW EXECUTE FUNCTION public.tp_u4_completar_detalle();

CREATE OR REPLACE FUNCTION public.tp_u4_propagar_pedido()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.detalle_pedido
    SET fecha_venta = (NEW.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
        pedido_eliminado = NEW.eliminado
    WHERE id_pedido = NEW.id_pedido;
    RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER trg_tp_u4_propagar_pedido
AFTER UPDATE OF fecha, eliminado ON public.pedido
FOR EACH ROW
WHEN (OLD.fecha IS DISTINCT FROM NEW.fecha
   OR OLD.eliminado IS DISTINCT FROM NEW.eliminado)
EXECUTE FUNCTION public.tp_u4_propagar_pedido();

CREATE OR REPLACE FUNCTION public.tp_u4_propagar_producto()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- El disparador BEFORE de detalle_pedido recalcula desde las fuentes.
    UPDATE public.detalle_pedido
    SET categoria_venta = categoria_venta
    WHERE id_producto = NEW.id_producto;
    RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER trg_tp_u4_propagar_producto
AFTER UPDATE OF id_categoria ON public.producto
FOR EACH ROW WHEN (OLD.id_categoria IS DISTINCT FROM NEW.id_categoria)
EXECUTE FUNCTION public.tp_u4_propagar_producto();

CREATE OR REPLACE FUNCTION public.tp_u4_propagar_categoria()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE public.detalle_pedido AS dp
    SET categoria_venta = NEW.nombre
    FROM public.producto AS pr
    WHERE dp.id_producto = pr.id_producto
      AND pr.id_categoria = NEW.id_categoria;
    RETURN NEW;
END $$;
CREATE OR REPLACE TRIGGER trg_tp_u4_propagar_categoria
AFTER UPDATE OF nombre ON public.categoria
FOR EACH ROW WHEN (OLD.nombre IS DISTINCT FROM NEW.nombre)
EXECUTE FUNCTION public.tp_u4_propagar_categoria();

COMMIT;

-- 5.2(d): reporte desde la estructura desnormalizada con EXPLAIN ANALYZE.
-- Comparar Execution Time y el nodo dominante con el plan de 5.2(a).
EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria_venta AS categoria, SUM(subtotal) AS total_vendido
FROM public.detalle_pedido
WHERE fecha_venta = CURRENT_DATE
  AND eliminado = FALSE AND pedido_eliminado = FALSE
GROUP BY categoria_venta
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

-- 5.2(d): la misma consulta para ver las filas del reporte.
SELECT categoria_venta AS categoria, SUM(subtotal) AS total_vendido
FROM public.detalle_pedido
WHERE fecha_venta = CURRENT_DATE
  AND eliminado = FALSE AND pedido_eliminado = FALSE
GROUP BY categoria_venta
ORDER BY total_vendido DESC, categoria ASC
LIMIT 5;

-- 5.2(e): auditoria de las copias. Resultado esperado: cero filas.
SELECT dp.id_pedido, dp.id_producto,
       dp.fecha_venta AS fecha_guardada,
       (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha_real,
       dp.categoria_venta AS categoria_guardada, c.nombre AS categoria_real,
       dp.pedido_eliminado AS baja_guardada, ped.eliminado AS baja_real
FROM public.detalle_pedido AS dp
LEFT JOIN public.pedido AS ped ON ped.id_pedido = dp.id_pedido
LEFT JOIN public.producto AS pr ON pr.id_producto = dp.id_producto
LEFT JOIN public.categoria AS c ON c.id_categoria = pr.id_categoria
WHERE ped.id_pedido IS NULL OR pr.id_producto IS NULL OR c.id_categoria IS NULL
   OR dp.fecha_venta IS DISTINCT FROM
      (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
   OR dp.categoria_venta IS DISTINCT FROM c.nombre
   OR dp.pedido_eliminado IS DISTINCT FROM ped.eliminado;
