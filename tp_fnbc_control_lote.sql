-- TP Unidad 4 - Parte 1 - FNBC
-- PostgreSQL / base foodstorecopia / esquema public.
-- Requiere las tablas maestras lote(id), deposito(id) y usuario(id) existentes.
-- Deben existir los lotes 501, 502, 503, los depositos 30, 31 y los usuarios 801, 802.
-- IF NOT EXISTS permite reutilizar las tablas del ejercicio ya creadas.

BEGIN;

-- 1. Esquema original del ejercicio.
CREATE TABLE IF NOT EXISTS public.control_lote_almacen (
    lote_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    CONSTRAINT pk_control_lote_almacen PRIMARY KEY (lote_id, deposito_id),
    CONSTRAINT fk_control_almacen_lote FOREIGN KEY (lote_id)
        REFERENCES public.lote(id),
    CONSTRAINT fk_control_almacen_deposito FOREIGN KEY (deposito_id)
        REFERENCES public.deposito(id),
    CONSTRAINT fk_control_almacen_usuario FOREIGN KEY (responsable_control_id)
        REFERENCES public.usuario(id)
);

-- 2. Instancia de ejemplo provista por la consigna.
INSERT INTO public.control_lote_almacen
    (lote_id, deposito_id, responsable_control_id)
VALUES (501, 30, 801), (502, 30, 801), (503, 31, 802)
ON CONFLICT (lote_id, deposito_id) DO NOTHING;

-- 3. Tablas descompuestas con claves primarias y claves foraneas (4.2(e)).
CREATE TABLE IF NOT EXISTS public.responsable_deposito (
    responsable_control_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    CONSTRAINT pk_responsable_deposito PRIMARY KEY (responsable_control_id),
    CONSTRAINT fk_responsable_usuario FOREIGN KEY (responsable_control_id)
        REFERENCES public.usuario(id),
    CONSTRAINT fk_responsable_deposito FOREIGN KEY (deposito_id)
        REFERENCES public.deposito(id)
);

CREATE TABLE IF NOT EXISTS public.control_lote (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    CONSTRAINT pk_control_lote PRIMARY KEY (lote_id, responsable_control_id),
    CONSTRAINT fk_control_lote_lote FOREIGN KEY (lote_id)
        REFERENCES public.lote(id),
    CONSTRAINT fk_control_lote_responsable FOREIGN KEY (responsable_control_id)
        REFERENCES public.responsable_deposito(responsable_control_id)
);

-- 4. Migracion hacia las tablas descompuestas (4.2(f)).
INSERT INTO public.responsable_deposito
    (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM public.control_lote_almacen
ON CONFLICT (responsable_control_id) DO NOTHING;

INSERT INTO public.control_lote (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM public.control_lote_almacen
ON CONFLICT (lote_id, responsable_control_id) DO NOTHING;

-- 5. Vista de compatibilidad mediante reunion natural (4.2(e)).
CREATE OR REPLACE VIEW public.control_lote_almacen_compat AS
SELECT cl.lote_id, rd.deposito_id, responsable_control_id
FROM public.control_lote AS cl
NATURAL JOIN public.responsable_deposito AS rd;

COMMIT;

-- 6. Mostrar la relacion reconstruida y verificar la migracion (4.2(f)).
SELECT lote_id, deposito_id, responsable_control_id
FROM public.control_lote_almacen_compat
ORDER BY lote_id, deposito_id;

-- Resultado esperado: filas_diferentes = 0.
WITH diferencias AS (
    (SELECT lote_id, deposito_id, responsable_control_id
     FROM public.control_lote_almacen
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id
     FROM public.control_lote_almacen_compat)
    UNION ALL
    (SELECT lote_id, deposito_id, responsable_control_id
     FROM public.control_lote_almacen_compat
     EXCEPT
     SELECT lote_id, deposito_id, responsable_control_id
     FROM public.control_lote_almacen)
)
SELECT COUNT(*) AS filas_diferentes
FROM diferencias;
