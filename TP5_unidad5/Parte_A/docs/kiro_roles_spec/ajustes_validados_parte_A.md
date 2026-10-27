# Ajustes al diseño de Kiro — Parte A

Este complemento **no reemplaza los archivos originales de Kiro**, que se conservan como evidencia. Documenta las decisiones después de comprobar el esquema de Food Store en pgAdmin y revisar la auditoría de OpenCode.

- **Herencia:** `rol_app_lectura` → `rol_app_escritura` → `app_web`, usando `INHERIT` y membresías `WITH INHERIT TRUE`; no se utiliza el diseño `NOINHERIT` del borrador.
- **Acceso a almacén:** `lote` y `deposito` no se conceden a `rol_app_lectura`, porque `app_web` heredaría ese acceso y el requisito de aislamiento no lo permite.
- **Usuarios:** `rol_soporte` solo puede consultar `usuario.id`; `usuario.nombre` queda reservado al administrador de datos.
- **Cancelaciones:** decisión expresa del usuario: `app_web` puede realizar borrado **lógico** de pedidos mediante `UPDATE public.pedido SET eliminado = TRUE`. No recibe `DELETE` físico; se permite editar `forma_pago`, `id_cliente`, `eliminado`, pero no `id_pedido` ni `fecha`.
- **Detalle de pedido:** se limita `UPDATE` a `id_producto` y `cantidad`. No se otorga actualización de `precio_unitario`, `subtotal` ni de columnas derivadas. Hay que comprobar que las modificaciones de cantidad conservan la coherencia de subtotal.
- **IDENTITY:** los permisos `USAGE` de secuencias se revocan solo cuando se compruebe que las 4 columnas son `IDENTITY` y la aplicación no use `nextval()` explícitamente.
- **Funciones futuras:** se usa `ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` (global para las nuevas funciones del rol ejecutor en esta base); una revocación limitada `IN SCHEMA` no elimina las concesiones globales.
- **Vista materializada:** no se otorga `MAINTAIN` (PG17) ni `TRIGGER` para `REFRESH` de manera indiscriminada. Queda reservado a su propietario/DBA.
- **Esquema:** `app_web` recibe `USAGE ON SCHEMA public` explícito. No se revoca `USAGE` global a `PUBLIC` sin antes evaluar otros usuarios y aplicaciones.

**Estado verificado:** las capturas 13 y 14 acreditan cuatro permisos efectivos ajustados y los privilegios por defecto de funciones. La prueba funcional de cancelación con triggers permanece pendiente; no se considera validada por estos resultados de ACL.
