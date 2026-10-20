# Auditoría de OpenCode — Parte A (Food Store)

**Fecha:** 14/10/2026  
**Fuente:** Respuesta de OpenCode aportada por el estudiante; evidencia visual en `evidencias/11_auditoria_opencode_resumen.png`.  
**Estado:** análisis recibido; se preparó el script de ajustes a raíz de la decisión funcional, pero NO consta que se haya ejecutado en PostgreSQL.

## Configuración corroborada en el TP

- Existen los seis roles esperados; `app_web` y `admin_datos` tienen `LOGIN`, los demás `NOLOGIN`; ninguno es superusuario.
- Cadena de membresía con herencia: `app_web` → `rol_app_escritura` → `rol_app_lectura`, sin administración de roles por miembros.
- Soporte puede consultar `usuario.id`, pero no `usuario.nombre`.
- `app_web` puede insertar pedidos y actualizar `producto.stock`, pero no eliminar pedidos ni actualizar `producto.precio`.

**Evidencia:** capturas 06 a 10 del directorio `docs/evidencias/`.

## Hallazgos de OpenCode y decisión humana

| Hallazgo | Evaluación | Decisión / seguimiento |
|---|---|---|
| A. `USAGE` sobre las cuatro secuencias asociadas a columnas IDENTITY | OpenCode comprobó que el `INSERT` normal funciona sin `USAGE`; es un privilegio prescindible mientras no se use `nextval()` directamente. | **Aceptar condicionalmente:** comprobar identidad de las columnas y si la aplicación usa la secuencia explícitamente antes de revocar. |
| B. `UPDATE` sobre toda la tabla `detalle_pedido` | Permite actualizar `precio_unitario`; el objetivo de restringir precios quedaría incompleto. | **Aceptar:** sustituir por permisos de actualización por columna, según operaciones de negocio reales. |
| C. `UPDATE` completo sobre `pedido`/`detalle_pedido`, incluido `eliminado` | Puede habilitar bajas lógicas a pesar de prohibirse `DELETE` físico. | **Decisión funcional confirmada:** la aplicación debe poder cancelar pedidos marcando `pedido.eliminado = TRUE`, sin `DELETE` físico. La columna `detalle_pedido.eliminado` no se incluye en las operaciones permitidas; hay que verificar que los triggers mantengan la consistencia. |
| D. Privilegios por defecto para funciones | Las sentencias previas para tablas y secuencias no protegen funciones futuras de su permiso inicial de `EXECUTE` a `PUBLIC`. | **Aceptar con corrección:** `ALTER DEFAULT PRIVILEGES FOR ROLE creador REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` **sin** `IN SCHEMA`, aplicado al creador pertinente y evaluando el efecto en toda la base. |
| E. `MAINTAIN` sobre vista materializada en PG17 | En PostgreSQL 17 permite `REFRESH`, pero también otras operaciones de mantenimiento; en PG16 no existe ese privilegio. | **No aplicar por ahora:** conservar operación de refresco bajo el dueño/DBA, o diseñar una función `SECURITY DEFINER` de alcance restringido si hiciera falta. |
| F. Roles `LOGIN` sin contraseñas | Por diseño el script no expone contraseñas; deben configurarse fuera del repositorio. | **Pendiente operacional:** configurar credenciales seguras y parámetros de conexión cuando vayan a utilizarse. |
| G. `PUBLIC` conserva `USAGE` en esquema `public` | Es posible reforzar el aislamiento con `REVOKE USAGE ON SCHEMA public FROM PUBLIC`. | **Evaluar impacto:** puede afectar otras sesiones, extensiones o usuarios de la base; no ejecutarlo automáticamente. |
| H. Vista `vista_ventas_usuario_mes` expone nombres indirectamente | Las vistas ejecutadas con privilegios de su propietario pueden mostrar datos derivados aunque el rol no acceda a la tabla fuente. | **Documentar:** no describir esta vista como anónima sin verificar sus columnas y datos. |
| I. `CREATE ROLE` no es idempotente | Reejecutar el script de creación de roles falla si ya existen. | **Aceptar como mejora de mantenimiento** sin reejecutar el script original en el entorno con los seis roles creados. |
| Divergencia Kiro vs SQL | Kiro usó `NOINHERIT` y mencionó `lote`/`deposito` en lectura; el script real implementa herencia y excluye almacén de `app_web`. | **Corregir especificaciones derivadas** conservando originales de Kiro como evidencia. |

## Corrección adicional al análisis de OpenCode

OpenCode recomendó `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`. **No alcanza:** PostgreSQL concede `EXECUTE` a `PUBLIC` globalmente para funciones por defecto y una revocación predeterminada limitada al esquema no revoca concesiones globales.

En consecuencia, para el rol que crea futuras funciones se debe usar la modalidad global, por ejemplo, *solo si el creador es postgres*: 

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```

Este ajuste aplica a futuras funciones creadas por ese rol en la base actual, en cualquier esquema. **No** modifica funciones existentes ni las creadas por otros roles. Referencia: https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html

## Advertencia sobre la prueba de OpenCode

La respuesta declara que se ejecutó un `INSERT` de prueba en `categoria` con nombre `'tmp'` e identificador `3008`. Hay que verificar si ese registro persiste antes de limpiar datos. No se considera probado que se haya eliminado o revertido.

```sql
SELECT id_categoria, nombre
FROM public.categoria
WHERE id_categoria = 3008 AND nombre = 'tmp';
```

No borrar datos sin confirmar que corresponden a esta prueba.

## Actividades pendientes para cerrar la Parte A

1. **Confirmado:** permitir `pedido.eliminado` a `app_web`; no se autorizó editar `detalle_pedido.eliminado`.
2. Preparar un **script de ajuste** específico para una base donde los roles **ya existen**; no volver a ejecutar `roles.sql` completo.
3. Aplicar el ajuste en la base de desarrollo tras revisarlo, verificar permisos de columna y nuevos privilegios por defecto, y capturar evidencias.
4. Consolidar la bitácora con los prompts **efectivamente enviados** y la validación humana; dejar commits de Git reales.
