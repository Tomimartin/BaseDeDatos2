# Requisitos: Sistema de Roles y Permisos — Food Store (Unidad 5, Parte A)

## 1. Objetivo

Diseñar e implementar un sistema de control de acceso basado en roles (RBAC) sobre la base de datos **Food Store** en PostgreSQL, aplicando el principio de **mínimo privilegio**: cada rol recibe únicamente los permisos estrictamente necesarios para cumplir su función, y ninguno más.

El sistema debe garantizar:

- Que ningún rol de aplicación pueda escalar privilegios por encima de su función.
- Que los datos sensibles de la tabla `usuario` (columna `nombre`) sean accesibles solo a quienes los necesiten.
- Que las operaciones destructivas (`DELETE`, `TRUNCATE`, `DROP`) queden restringidas a roles de administración explícitamente autorizados.
- Que `GRANT ALL` y privilegios de superusuario queden prohibidos en todos los roles de aplicación.

---

## 2. Esquema de Tablas

### Tablas del dominio principal (Food Store)

| Tabla | Descripción | Sensibilidad |
|---|---|---|
| `categoria` | Categorías de productos | Baja |
| `cliente` | Clientes registrados (nombre, apellido, email, teléfono) | Media — contiene email y teléfono |
| `producto` | Catálogo de productos con precio y stock | Media |
| `pedido` | Cabecera de pedidos con fecha y forma de pago | Media |
| `detalle_pedido` | Líneas de pedido (cantidad, subtotal) | Media |

### Tablas del dominio de control de almacén (Unidad 4)

| Tabla | Descripción | Sensibilidad |
|---|---|---|
| `lote` | Lotes de mercadería (`id`) | Baja |
| `deposito` | Depósitos físicos (`id`) | Baja |
| `usuario` | Usuarios del sistema (`id`, `nombre`) | **Alta** — identifica personas responsables |
| `control_lote_almacen` | Relación lote–depósito–responsable (tabla original pre-FNBC) | Media |
| `control_lote` | Relación lote–responsable (tabla descompuesta FNBC) | Media |
| `responsable_deposito` | Relación responsable–depósito (tabla descompuesta FNBC) | Media |

---

## 3. Roles Requeridos

### 3.1 `rol_app_lectura`

**Función:** Rol base de solo lectura para la aplicación web. Permite consultar el catálogo, stock y pedidos sin posibilidad de modificar ningún dato.

**Necesita:**
- `SELECT` sobre tablas del catálogo público: `categoria`, `producto`, `pedido`, `detalle_pedido`.
- `SELECT` limitado sobre `cliente` (sin exponer columnas sensibles directamente — ver diseño).
- `SELECT` sobre `lote`, `deposito`.

**No debe poder:**
- `INSERT`, `UPDATE`, `DELETE` sobre ninguna tabla.
- Acceder a `usuario.nombre` directamente (dato de identidad interna).
- Acceder a `control_lote`, `control_lote_almacen`, `responsable_deposito`.

---

### 3.2 `rol_app_escritura`

**Función:** Rol de escritura transaccional para la aplicación web. Registra pedidos, actualiza stock y gestiona clientes. Hereda de `rol_app_lectura`.

**Necesita:**
- Todo lo de `rol_app_lectura`.
- `INSERT`, `UPDATE` sobre `pedido`, `detalle_pedido`.
- `UPDATE` sobre `producto` (columna `stock` únicamente).
- `INSERT`, `UPDATE` sobre `cliente`.

**No debe poder:**
- `DELETE` sobre ninguna tabla.
- `UPDATE` sobre columnas de precio (`producto.precio`) — esa es responsabilidad del administrador.
- Acceder a `usuario`, `control_lote`, `responsable_deposito`, `control_lote_almacen`.
- `TRUNCATE` ni DDL de ningún tipo.

---

### 3.3 `rol_soporte`

**Función:** Personal de soporte técnico que necesita diagnosticar problemas de datos sin poder modificarlos. Acceso de lectura amplio, incluido el dominio de almacén.

**Necesita:**
- `SELECT` sobre todas las tablas del dominio principal.
- `SELECT` sobre `control_lote`, `control_lote_almacen`, `responsable_deposito`, `deposito`, `lote`.
- `SELECT (id)` sobre `usuario` (puede ver el identificador para correlacionar, no el nombre).

**No debe poder:**
- `INSERT`, `UPDATE`, `DELETE` sobre ninguna tabla.
- Ver `usuario.nombre` — dato de identidad sensible.
- Ejecutar `TRUNCATE`, DDL ni funciones administrativas.

---

### 3.4 `rol_reportes`

**Función:** Rol analítico para generación de reportes de negocio (ventas, stock, facturación). Acceso de lectura sobre datos agregables. Puede consultar vistas materializadas.

**Necesita:**
- `SELECT` sobre `categoria`, `producto`, `pedido`, `detalle_pedido`.
- `SELECT` sobre vistas: `vista_productos_mas_vendidos`, `vista_ventas_usuario_mes`, `vista_stock_critico`.
- `SELECT` sobre la vista materializada `mv_facturacion_categoria_mes`.

**No debe poder:**
- Acceder directamente a `cliente` (solo a través de vistas que ya ocultan datos sensibles).
- Acceder a `usuario`, `lote`, `deposito`, `control_lote`, `responsable_deposito`.
- `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` ni DDL.
- Ejecutar `REFRESH MATERIALIZED VIEW` — esa operación corresponde a `admin_datos`.

---

### 3.5 `app_web`

**Función:** Usuario de conexión de la aplicación web (login de la app). Agrupa los permisos operacionales de lectura y escritura necesarios para el funcionamiento normal del sistema. Hereda de `rol_app_lectura` y `rol_app_escritura`.

**Necesita:**
- Todo lo de `rol_app_lectura` y `rol_app_escritura`.
- Uso de las secuencias asociadas a las tablas sobre las que hace `INSERT` (`pedido_id_pedido_seq`, `cliente_id_cliente_seq`).

**No debe poder:**
- Acceder al dominio de almacén (`lote`, `deposito`, `usuario`, `control_lote`, etc.).
- `DELETE`, `TRUNCATE` ni DDL.
- Ver datos internos de `usuario`.

---

### 3.6 `admin_datos`

**Función:** Administrador de datos de negocio. Gestiona el catálogo de productos, precios, categorías, usuarios del sistema de almacén y puede ejecutar mantenimiento de vistas materializadas. **No es superusuario.**

**Necesita:**
- `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre `categoria`, `producto`, `lote`, `deposito`.
- `SELECT`, `INSERT`, `UPDATE` sobre `usuario` (gestión de responsables de depósito).
- `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre `control_lote`, `responsable_deposito`, `control_lote_almacen`.
- `SELECT` sobre todas las tablas del dominio principal (auditoría y verificación).
- `TRIGGER` sobre tablas que lo requieran.
- Ejecutar `REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes`.

**No debe poder:**
- `DELETE` sobre `pedido`, `detalle_pedido`, `cliente` — operaciones de negocio críticas que requieren proceso formal.
- `TRUNCATE` sobre ninguna tabla.
- DDL (`CREATE`, `ALTER`, `DROP`) — reservado al DBA.
- Privilegios de superusuario.

---

## 4. Permisos por Tabla — Resumen

| Tabla | `rol_app_lectura` | `rol_app_escritura` | `rol_soporte` | `rol_reportes` | `app_web` | `admin_datos` |
|---|---|---|---|---|---|---|
| `categoria` | SELECT | SELECT | SELECT | SELECT | SELECT | SELECT, INSERT, UPDATE, DELETE |
| `cliente` | SELECT* | SELECT, INSERT, UPDATE | SELECT | — | SELECT, INSERT, UPDATE | SELECT |
| `producto` | SELECT | SELECT, UPDATE† | SELECT | SELECT | SELECT, UPDATE† | SELECT, INSERT, UPDATE, DELETE |
| `pedido` | SELECT | SELECT, INSERT, UPDATE | SELECT | SELECT | SELECT, INSERT, UPDATE | SELECT |
| `detalle_pedido` | SELECT | SELECT, INSERT, UPDATE | SELECT | SELECT | SELECT, INSERT, UPDATE | SELECT |
| `lote` | SELECT | — | SELECT | — | — | SELECT, INSERT, UPDATE, DELETE |
| `deposito` | SELECT | — | SELECT | — | — | SELECT, INSERT, UPDATE, DELETE |
| `usuario` | — | — | SELECT (id) | — | — | SELECT, INSERT, UPDATE |
| `control_lote_almacen` | — | — | SELECT | — | — | SELECT, INSERT, UPDATE, DELETE |
| `control_lote` | — | — | SELECT | — | — | SELECT, INSERT, UPDATE, DELETE |
| `responsable_deposito` | — | — | SELECT | — | — | SELECT, INSERT, UPDATE, DELETE |

> `*` Solo columnas no sensibles (ver sección 5).  
> `†` Solo columna `stock` — no `precio`.

---

## 5. Permisos a Nivel de Columna sobre `usuario`

La tabla `usuario` contiene únicamente `id` (BIGINT) y `nombre` (VARCHAR). Dado que `nombre` identifica directamente a una persona física responsable de operaciones de almacén, se aplica control de acceso a nivel de columna:

| Columna | `rol_soporte` | `admin_datos` | Resto de roles |
|---|---|---|---|
| `id` | SELECT | SELECT, INSERT, UPDATE | Sin acceso |
| `nombre` | **Sin acceso** | SELECT, INSERT, UPDATE | Sin acceso |

**Justificación:** `rol_soporte` puede correlacionar registros de `control_lote` y `responsable_deposito` usando el `id` sin necesidad de conocer la identidad del responsable. Solo `admin_datos` gestiona la identidad completa.

---

## 6. Política de Privilegios para Futuras Tablas

Toda tabla nueva que se incorpore al esquema deberá seguir estas reglas antes de pasar a producción:

1. **Sin acceso por defecto.** Una tabla recién creada no hereda permisos de ningún rol. El DBA debe asignar explícitamente los GRANTs necesarios.

2. **Clasificación obligatoria.** Antes de asignar permisos, la tabla debe clasificarse en una de tres categorías:
   - **Pública de negocio** (ej: catálogo, precios) → candidata a `rol_app_lectura` / `rol_reportes`.
   - **Transaccional** (ej: pedidos, movimientos) → candidata a `rol_app_escritura` / `app_web`.
   - **Sensible / operacional interna** (ej: usuarios, responsables) → acceso restringido a `admin_datos` y roles específicos.

3. **Prohibición de `GRANT ALL`.** Ningún script de migración debe usar `GRANT ALL`. Los permisos se otorgan verbo a verbo (`SELECT`, `INSERT`, etc.).

4. **Columnas sensibles.** Si la nueva tabla incluye columnas con datos personales (nombre, documento, contacto), se debe evaluar el uso de `GRANT SELECT (col1, col2)` en lugar de `GRANT SELECT` sobre la tabla completa.

5. **Revisión ante cada nueva columna.** Agregar una columna sensible a una tabla ya expuesta requiere revocar y volver a otorgar permisos explícitamente, ya que en PostgreSQL `GRANT SELECT ON tabla` otorga acceso a todas las columnas presentes y futuras de esa tabla en el momento del grant (no es dinámico, pero conviene revisar ante ALTER TABLE ADD COLUMN).

6. **Documentación.** Cada GRANT debe registrarse en el script de migración con un comentario que indique el rol destino, la operación y la justificación de negocio.
