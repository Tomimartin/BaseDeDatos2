-- Food Store - Unidad 5, Parte A - Ajustes tras auditoria de OpenCode
-- PostgreSQL 16+ (verificado conceptualmente; falta ejecucion en pgAdmin)
-- Este script es para la base de desarrollo con los 6 roles YA CREADOS.
-- NO ejecutar roles.sql otra vez: contiene CREATE ROLE.
-- Hacer backup y ejecutar conectado como usuario que pueda conceder/revocar.
-- Importante: si falla una sentencia, ejecutar ROLLBACK y revisar Messages.

BEGIN;

-- 1. Asegurar acceso al esquema, incluso si cambia la herencia futura.
GRANT USAGE ON SCHEMA public TO app_web;

-- 2. Pedido: permitir correcciones operativas y cancelacion logica.
-- Se revoca UPDATE a nivel de TABLA antes de darlo por COLUMNA.
REVOKE UPDATE ON TABLE public.pedido FROM rol_app_escritura;
GRANT UPDATE (forma_pago, id_cliente, eliminado)
    ON TABLE public.pedido TO rol_app_escritura;
-- No otorgamos DELETE; la cancelacion es UPDATE eliminado = TRUE.

-- 3. Detalle: impedir alteraciones posteriores del precio de la venta.
-- UPDATE de cantidad / id_producto solo si la aplicacion garantiza
-- consistencia del subtotal (por trigger o logica transaccional).
REVOKE UPDATE ON TABLE public.detalle_pedido FROM rol_app_escritura;
GRANT UPDATE (id_producto, cantidad)
    ON TABLE public.detalle_pedido TO rol_app_escritura;
-- No se concede UPDATE(eliminado) de detalle: la cancelacion pedida
-- se hace sobre pedido.eliminado, no por linea.

-- 4. Reforzar futuras funciones del rol ejecutor: sin EXECUTE PUBLIC.
-- Afecta nuevas funciones creadas por CURRENT_USER en esta base,
-- en cualquier esquema. No afecta funciones ya creadas ni otros roles.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- 5. Eliminar permisos USAGE de secuencias solo si las 4 PK son IDENTITY.
-- Si alguna no lo fuera, conservar USAGE para no romper los INSERT.
DO $plpgsql$
DECLARE
    pk_no_identity text;
BEGIN
    SELECT string_agg(v.tabla || '.' || v.columna, ', ')
      INTO pk_no_identity
      FROM (VALUES ('pedido', 'id_pedido'),
                   ('cliente', 'id_cliente'),
                   ('categoria', 'id_categoria'),
                   ('producto', 'id_producto')) AS v(tabla, columna)
     WHERE NOT EXISTS (
           SELECT 1
             FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
             JOIN pg_attribute a ON a.attrelid = c.oid
            WHERE n.nspname = 'public'
              AND c.relname = v.tabla
              AND a.attname = v.columna
              AND NOT a.attisdropped
              AND a.attidentity IN ('a', 'd')
     );

    IF pk_no_identity IS NULL THEN
        REVOKE USAGE ON SEQUENCE
            public.pedido_id_pedido_seq,
            public.cliente_id_cliente_seq
            FROM rol_app_escritura;
        REVOKE USAGE ON SEQUENCE
            public.categoria_id_categoria_seq,
            public.producto_id_producto_seq
            FROM admin_datos;
        RAISE NOTICE 'Se revoco USAGE de 4 secuencias IDENTITY';
    ELSE
        RAISE NOTICE 'NO se revoco USAGE. Columnas sin IDENTITY: %',
            pk_no_identity;
    END IF;
END
$plpgsql$;

COMMIT;

-- Fuera de transaccion: comprobar sql/verificacion_ajustes_parte_a.sql
-- Nota: NO revocamos USAGE ON SCHEMA public FROM PUBLIC para no afectar
-- a otros usuarios. Tampoco otorgamos MAINTAIN a admin_datos.
