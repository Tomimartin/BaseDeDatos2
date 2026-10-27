-- Food Store - Unidad 5, Parte A - Verificacion en pgAdmin 4
-- Ejecutar cada consulta por separado para guardar evidencia de cada salida.

-- 1. Estado de roles (alternativa a \du, que es comando de psql).
SELECT rolname, rolcanlogin, rolsuper, rolcreaterole
FROM pg_roles
WHERE rolname IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte',
                  'rol_reportes', 'app_web', 'admin_datos')
ORDER BY rolname;

-- 2. Privilegios a nivel de tabla (no incluye los de columna).
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
                  'rol_reportes','app_web','admin_datos')
ORDER BY grantee, table_name, privilege_type;

-- 3. Privilegios sobre columnas: incluye los que aplican a toda la tabla.
SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name IN ('usuario','cliente','producto')
  AND grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
                  'rol_reportes','app_web','admin_datos')
ORDER BY grantee, table_name, column_name, privilege_type;

-- 4. Validaciones booleanas del principio de minimo privilegio.
SELECT
    has_column_privilege('rol_soporte', 'public.usuario', 'id', 'SELECT')
        AS soporte_puede_ver_id,
    has_column_privilege('rol_soporte', 'public.usuario', 'nombre', 'SELECT')
        AS soporte_puede_ver_nombre,
    has_table_privilege('app_web', 'public.pedido', 'INSERT')
        AS app_puede_insertar_pedido,
    has_table_privilege('app_web', 'public.pedido', 'DELETE')
        AS app_puede_borrar_pedido,
    has_column_privilege('app_web', 'public.producto', 'stock', 'UPDATE')
        AS app_puede_actualizar_stock,
    has_column_privilege('app_web', 'public.producto', 'precio', 'UPDATE')
        AS app_puede_actualizar_precio,
    has_table_privilege('app_web', 'public.lote', 'SELECT')
        AS app_puede_ver_lote;

-- 5. Membresias, incluido el parametro INHERIT de PG16.
SELECT r.rolname AS rol_otorgado, m.rolname AS miembro,
       am.inherit_option
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE r.rolname IN ('rol_app_lectura','rol_app_escritura')
ORDER BY r.rolname, m.rolname;
