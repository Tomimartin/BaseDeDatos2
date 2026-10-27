-- Food Store - Unidad 5, Parte A - Verificacion DESPUES de ajustes
-- Ejecutar por separado y guardar las capturas de Data Output.

-- 1. Permisos efectivos: comparar con la politica acordada.
SELECT
    has_column_privilege('app_web', 'public.pedido', 'eliminado', 'UPDATE')
        AS app_cancela_pedido,
    has_column_privilege('app_web', 'public.pedido', 'forma_pago', 'UPDATE')
        AS app_cambia_forma_pago,
    has_table_privilege('app_web', 'public.pedido', 'DELETE')
        AS app_borra_pedido_fisicamente,
    has_column_privilege('app_web', 'public.detalle_pedido', 'precio_unitario', 'UPDATE')
        AS app_modifica_precio_unitario,
    has_column_privilege('app_web', 'public.detalle_pedido', 'cantidad', 'UPDATE')
        AS app_modifica_cantidad,
    has_column_privilege('app_web', 'public.detalle_pedido', 'eliminado', 'UPDATE')
        AS app_anula_linea,
    has_schema_privilege('app_web', 'public', 'USAGE')
        AS app_usa_esquema;
-- Esperado: true, true, false, false, true, false, true.

-- 2. Evaluar si quedaron USAGE sobre secuencias (esperado false si IDENTITY).
SELECT
    has_sequence_privilege('app_web', 'public.pedido_id_pedido_seq', 'USAGE')
        AS app_usa_seq_pedido,
    has_sequence_privilege('admin_datos', 'public.producto_id_producto_seq', 'USAGE')
        AS admin_usa_seq_producto;

-- 3. Ver el usuario conectado y la politica de privilegios futuros.
SELECT current_user AS rol_creador, current_database() AS base_actual;
SELECT
    defaclrole::regrole AS rol_creador,
    CASE WHEN defaclnamespace = 0 THEN '(global)' ELSE defaclnamespace::regnamespace::text END AS alcance,
    defaclobjtype AS tipo_objeto,
    defaclacl AS permisos_por_defecto
FROM pg_default_acl
WHERE defaclobjtype IN ('f', 'r', 'S')
ORDER BY rol_creador, tipo_objeto, alcance;
-- Para funciones: confirmar que PUBLIC (=) no tenga EXECUTE (X).

-- 4. Confirma si las columnas son IDENTITY.
SELECT c.relname AS tabla, a.attname AS columna,
       CASE a.attidentity WHEN 'a' THEN 'ALWAYS'
                          WHEN 'd' THEN 'BY DEFAULT'
                          ELSE 'NO ES IDENTITY' END AS identity_tipo
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
WHERE n.nspname = 'public'
  AND (c.relname, a.attname) IN (
     ('pedido','id_pedido'), ('cliente','id_cliente'),
     ('categoria','id_categoria'), ('producto','id_producto')
  )
ORDER BY tabla;

-- 5. Revisar si OpenCode dejo una categoria de prueba, SIN BORRARLA.
SELECT id_categoria, nombre FROM public.categoria
WHERE id_categoria = 3008 AND nombre = 'tmp';

-- 6. Prueba FUNCIONAL opcional (SOLO DESARROLLO). Ejecutar como admin
-- en Query Tool, con una venta de prueba que admita cancelacion:
-- BEGIN;
-- SET LOCAL ROLE app_web;
-- UPDATE public.pedido SET eliminado = TRUE
-- WHERE id_pedido = <ID_DE_PEDIDO_DE_PRUEBA>;
-- ROLLBACK;
-- Si hay triggers en detalles, comprobar que se comporten correctamente.
