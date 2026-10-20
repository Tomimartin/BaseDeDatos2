-- Food Store - Unidad 5, Parte A
-- Roles y privilegios de minimo privilegio (PostgreSQL 16+)
-- EJECUTAR SOLO EN LA BASE DE DESARROLLO FOOD STORE,
-- CON UN ROL CON PERMISO PARA CREAR ROLES Y OTORGAR PRIVILEGIOS.
-- No guardar contrasenas en este archivo ni en el repositorio.
-- Los CREATE ROLE se ejecutan solo una vez. No volver a correr el script
-- completo despues de haber creado los roles.
-- NOTA: CREATE ROLE crea roles en el servidor PostgreSQL, no solo en esta base.

BEGIN;

-- 1. Roles de grupo: no pueden iniciar sesion directamente.
CREATE ROLE rol_app_lectura NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_app_escritura NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_soporte NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_reportes NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- 2. Roles de conexion: sin contrasenas embebidas en Git.
-- Las contrasenas se configuran por separado en pgAdmin / administrador.
CREATE ROLE app_web LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE admin_datos LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- 3. La aplicacion hereda lectura y escritura.
-- PostgreSQL 16+: especificamos herencia explicita en las membresias.
GRANT rol_app_lectura TO rol_app_escritura WITH INHERIT TRUE;
GRANT rol_app_escritura TO app_web WITH INHERIT TRUE;

-- 4. Acceso al esquema para consultar/operar objetos autorizados.
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura,
    rol_soporte, rol_reportes, admin_datos;

-- 5. El publico no recibe acceso a las tablas/secuencias del esquema.
-- Esto modifica privilegios existentes del grupo PUBLIC, si los hubiera.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- 6. Aplicacion: solo lectura operativa.
-- CORRECCION DE KIRO: no se da SELECT en lote/deposito a este rol,
-- porque app_web lo hereda y no debe ver datos de almacen.
GRANT SELECT ON TABLE public.categoria, public.producto,
    public.pedido, public.detalle_pedido TO rol_app_lectura;
GRANT SELECT (id_cliente, nombre, apellido)
    ON TABLE public.cliente TO rol_app_lectura;
GRANT SELECT ON TABLE public.vista_productos_mas_vendidos,
    public.vista_stock_critico TO rol_app_lectura;

-- 7. Aplicacion: escritura de pedidos/clientes y stock, sin borrado.
GRANT INSERT, UPDATE ON TABLE public.pedido, public.detalle_pedido,
    public.cliente TO rol_app_escritura;
GRANT UPDATE (stock) ON TABLE public.producto TO rol_app_escritura;
GRANT USAGE ON SEQUENCE public.pedido_id_pedido_seq,
    public.cliente_id_cliente_seq TO rol_app_escritura;

-- 8. Soporte: lectura para diagnostico, sin acceso a usuario.nombre.
GRANT SELECT ON TABLE public.categoria, public.producto, public.pedido,
    public.detalle_pedido, public.cliente, public.lote, public.deposito,
    public.control_lote_almacen, public.control_lote,
    public.responsable_deposito TO rol_soporte;
GRANT SELECT (id) ON TABLE public.usuario TO rol_soporte;

-- 9. Reportes: lectura de datos transaccionales y vistas.
GRANT SELECT ON TABLE public.categoria, public.producto, public.pedido,
    public.detalle_pedido, public.vista_productos_mas_vendidos,
    public.vista_ventas_usuario_mes, public.vista_stock_critico,
    public.mv_facturacion_categoria_mes TO rol_reportes;

-- 10. Administrador de DATOS, no DBA ni superusuario.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.categoria,
    public.producto, public.lote, public.deposito,
    public.control_lote_almacen, public.control_lote,
    public.responsable_deposito TO admin_datos;
GRANT SELECT ON TABLE public.cliente, public.pedido,
    public.detalle_pedido, public.vista_productos_mas_vendidos,
    public.vista_ventas_usuario_mes, public.vista_stock_critico,
    public.mv_facturacion_categoria_mes TO admin_datos;
GRANT SELECT, INSERT, UPDATE ON TABLE public.usuario TO admin_datos;
GRANT USAGE ON SEQUENCE public.categoria_id_categoria_seq,
    public.producto_id_producto_seq TO admin_datos;

-- REFRESH MATERIALIZED VIEW no se habilita con GRANT TRIGGER en PG16.
-- Queda reservado al propietario/DBA. Si fuese indispensable,
-- se disenaria y auditaria una funcion SECURITY DEFINER especifica.

-- 11. Privilegios por defecto para objetos FUTUROS creados por el
-- ROL QUE EJECUTA ESTE SCRIPT, exclusivamente en el esquema public.
-- Por defecto las tablas nuevas ya tienen cero permisos para PUBLIC;
-- se deja explicita esta politica y no se habilita acceso automatico.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- Otros propietarios/creadores deben configurar sus propios
-- ALTER DEFAULT PRIVILEGES; esto no cubre automaticamente todo el servidor.

COMMIT;
