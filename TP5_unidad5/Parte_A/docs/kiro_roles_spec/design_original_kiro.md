# Diseño Técnico: Sistema de Roles y Permisos — Food Store (Unidad 5, Parte A)

## 1. Arquitectura del Sistema de Roles

### Jerarquía de herencia

```
rol_app_lectura
      │
      └──► rol_app_escritura
                  │
                  └──► app_web
                  
rol_soporte        (independiente, lectura ampliada)
rol_reportes       (independiente, lectura analítica)
admin_datos        (independiente, administración de datos)
```

`app_web` hereda de `rol_app_escritura`, que a su vez hereda de `rol_app_lectura`. Los demás roles son independientes y no heredan entre sí para evitar escalada accidental de privilegios.

---

## 2. Creación de Roles

```sql
-- Roles base (sin LOGIN — son roles de permisos, no usuarios de conexión)
CREATE ROLE rol_app_lectura  NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_app_escritura NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_soporte      NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE rol_reportes     NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE ROLE admin_datos      NOLOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Usuario de conexión de la aplicación web (tiene LOGIN)
CREATE ROLE app_web LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE
    PASSWORD 'cambiar_en_produccion';

-- Herencia de membresías
GRANT rol_app_lectura   TO rol_app_escritura;
GRANT rol_app_escritura TO app_web;
```

> **`NOINHERIT`:** Los roles no heredan permisos automáticamente al ser miembros de otro rol.  
> Se usa `SET ROLE` explícito para activar permisos heredados, lo que fuerza intencionalidad.  
> Si se prefiere herencia automática, reemplazar por `INHERIT` y documentar la decisión.

---

## 3. GRANTs por Rol

### 3.1 `rol_app_lectura`

```sql
-- Dominio principal: lectura de catálogo y operaciones
GRANT SELECT ON TABLE public.categoria        TO rol_app_lectura;
GRANT SELECT ON TABLE public.producto         TO rol_app_lectura;
GRANT SELECT ON TABLE public.pedido           TO rol_app_lectura;
GRANT SELECT ON TABLE public.detalle_pedido   TO rol_app_lectura;
GRANT SELECT ON TABLE public.lote             TO rol_app_lectura;
GRANT SELECT ON TABLE public.deposito         TO rol_app_lectura;

-- cliente: solo columnas no sensibles (sin email, sin teléfono)
GRANT SELECT (id_cliente, nombre, apellido)   ON TABLE public.cliente TO rol_app_lectura;

-- Vistas públicas de solo lectura
GRANT SELECT ON public.vista_productos_mas_vendidos TO rol_app_lectura;
GRANT SELECT ON public.vista_stock_critico          TO rol_app_lectura;
```

---

### 3.2 `rol_app_escritura`

```sql
-- Hereda todo de rol_app_lectura (via GRANT rol_app_lectura TO rol_app_escritura)

-- Pedidos y detalle: ciclo de vida transaccional completo
GRANT INSERT, UPDATE ON TABLE public.pedido         TO rol_app_escritura;
GRANT INSERT, UPDATE ON TABLE public.detalle_pedido TO rol_app_escritura;

-- Secuencias necesarias para los INSERT
GRANT USAGE ON SEQUENCE public.pedido_id_pedido_seq TO rol_app_escritura;

-- cliente: alta y actualización (sin borrado)
GRANT INSERT, UPDATE ON TABLE public.cliente        TO rol_app_escritura;
GRANT USAGE ON SEQUENCE public.cliente_id_cliente_seq TO rol_app_escritura;

-- producto: solo columna stock (reposición tras venta)
-- No se concede UPDATE general sobre producto para proteger precio y activo
GRANT UPDATE (stock) ON TABLE public.producto       TO rol_app_escritura;
```

---

### 3.3 `rol_soporte`

```sql
-- Lectura completa del dominio principal
GRANT SELECT ON TABLE public.categoria        TO rol_soporte;
GRANT SELECT ON TABLE public.producto         TO rol_soporte;
GRANT SELECT ON TABLE public.pedido           TO rol_soporte;
GRANT SELECT ON TABLE public.detalle_pedido   TO rol_soporte;
GRANT SELECT ON TABLE public.cliente          TO rol_soporte;

-- Dominio de almacén: lectura completa
GRANT SELECT ON TABLE public.lote                     TO rol_soporte;
GRANT SELECT ON TABLE public.deposito                 TO rol_soporte;
GRANT SELECT ON TABLE public.control_lote_almacen     TO rol_soporte;
GRANT SELECT ON TABLE public.control_lote             TO rol_soporte;
GRANT SELECT ON TABLE public.responsable_deposito     TO rol_soporte;

-- usuario: solo columna id (correlación de registros sin exponer identidad)
GRANT SELECT (id) ON TABLE public.usuario             TO rol_soporte;
```

---

### 3.4 `rol_reportes`

```sql
-- Tablas de negocio agregables
GRANT SELECT ON TABLE public.categoria        TO rol_reportes;
GRANT SELECT ON TABLE public.producto         TO rol_reportes;
GRANT SELECT ON TABLE public.pedido           TO rol_reportes;
GRANT SELECT ON TABLE public.detalle_pedido   TO rol_reportes;

-- Vistas relacionales (ya filtran columnas sensibles de cliente)
GRANT SELECT ON public.vista_productos_mas_vendidos TO rol_reportes;
GRANT SELECT ON public.vista_ventas_usuario_mes     TO rol_reportes;
GRANT SELECT ON public.vista_stock_critico          TO rol_reportes;

-- Vista materializada (lectura de datos precalculados)
GRANT SELECT ON public.mv_facturacion_categoria_mes TO rol_reportes;

-- Sin acceso a: cliente (directo), usuario, lote, deposito,
-- control_lote, responsable_deposito, control_lote_almacen
```

---

### 3.5 `app_web`

```sql
-- Hereda rol_app_lectura y rol_app_escritura via cadena de membresías.
-- Solo se agregan permisos exclusivos de app_web que no corresponden
-- a los roles genéricos.

-- Uso de secuencias de producto si app_web crea productos (opcional)
-- GRANT USAGE ON SEQUENCE public.producto_id_producto_seq TO app_web;

-- Sin acceso adicional al dominio de almacén.
-- Sin acceso a usuario, control_lote, responsable_deposito.
```

---

### 3.6 `admin_datos`

```sql
-- Dominio principal: gestión completa del catálogo
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.categoria TO admin_datos;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.producto  TO admin_datos;
GRANT USAGE ON SEQUENCE public.categoria_id_categoria_seq     TO admin_datos;
GRANT USAGE ON SEQUENCE public.producto_id_producto_seq       TO admin_datos;

-- Pedidos y clientes: solo lectura (no puede borrar transacciones)
GRANT SELECT ON TABLE public.pedido           TO admin_datos;
GRANT SELECT ON TABLE public.detalle_pedido   TO admin_datos;
GRANT SELECT ON TABLE public.cliente          TO admin_datos;

-- Dominio de almacén: gestión completa
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lote                 TO admin_datos;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.deposito             TO admin_datos;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.control_lote_almacen TO admin_datos;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.control_lote         TO admin_datos;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.responsable_deposito TO admin_datos;

-- usuario: gestión completa (id + nombre)
GRANT SELECT, INSERT, UPDATE ON TABLE public.usuario TO admin_datos;

-- Vistas y vista materializada
GRANT SELECT ON public.vista_productos_mas_vendidos   TO admin_datos;
GRANT SELECT ON public.vista_ventas_usuario_mes       TO admin_datos;
GRANT SELECT ON public.vista_stock_critico            TO admin_datos;
GRANT SELECT ON public.mv_facturacion_categoria_mes   TO admin_datos;

-- Refresco de la vista materializada (requiere ser owner o tener privilegio)
-- El DBA debe ejecutar: GRANT TRIGGER ON mv_facturacion_categoria_mes TO admin_datos;
-- o bien ejecutar el REFRESH desde un procedimiento almacenado con SECURITY DEFINER.
```

---

## 4. Permisos a Nivel de Columna — Tabla `usuario`

La tabla `usuario(id BIGINT, nombre VARCHAR)` requiere control de acceso por columna porque `nombre` identifica a una persona física.

```sql
-- rol_soporte: solo puede ver el id para correlacionar registros
GRANT SELECT (id)        ON TABLE public.usuario TO rol_soporte;

-- admin_datos: acceso completo a ambas columnas
GRANT SELECT (id, nombre) ON TABLE public.usuario TO admin_datos;
GRANT INSERT, UPDATE      ON TABLE public.usuario TO admin_datos;

-- Todos los demás roles: sin ningún acceso a usuario
-- (no se emite ningún GRANT — sin acceso por defecto en PostgreSQL)
```

**Verificación de aislamiento:**

```sql
-- Conectado como rol_soporte, esta consulta debe fallar:
SELECT nombre FROM usuario;
-- ERROR: permission denied for table usuario

-- Esta debe funcionar:
SELECT id FROM usuario;
-- OK
```

---

## 5. Permisos sobre Secuencias

Los `INSERT` que usan columnas `GENERATED ALWAYS AS IDENTITY` requieren `USAGE` sobre la secuencia subyacente.

| Secuencia | Rol que necesita USAGE |
|---|---|
| `pedido_id_pedido_seq` | `rol_app_escritura`, `app_web` |
| `cliente_id_cliente_seq` | `rol_app_escritura`, `app_web` |
| `categoria_id_categoria_seq` | `admin_datos` |
| `producto_id_producto_seq` | `admin_datos` |

---

## 6. Restricciones Explícitas — Qué Nunca se Otorga

| Operación prohibida | Roles afectados | Motivo |
|---|---|---|
| `GRANT ALL` | Todos | Viola el principio de mínimo privilegio |
| `SUPERUSER` | Todos | Bypasea todo el sistema de permisos |
| `CREATEROLE` | Todos | Un rol de aplicación no debe crear otros roles |
| `CREATEDB` | Todos | Fuera del alcance de la aplicación |
| `DELETE` sobre `pedido`, `detalle_pedido`, `cliente` | `rol_app_escritura`, `app_web`, `admin_datos` | Las transacciones de negocio son inmutables; el borrado requiere proceso formal del DBA |
| `TRUNCATE` | Todos | Operación destructiva irreversible |
| DDL (`CREATE`, `ALTER`, `DROP`) | Todos | Reservado exclusivamente al DBA |
| `UPDATE (precio)` en `producto` | `rol_app_escritura`, `app_web` | El precio solo lo modifica `admin_datos` |
| Acceso a `usuario.nombre` | `rol_app_lectura`, `rol_app_escritura`, `app_web`, `rol_soporte`, `rol_reportes` | Dato de identidad sensible |

---

## 7. Política de Privilegios para Futuras Tablas

Procedimiento obligatorio ante cada nueva tabla:

```
1. Clasificar la tabla (pública / transaccional / sensible).
2. Redactar los GRANTs mínimos necesarios por rol.
3. Identificar columnas sensibles → usar GRANT SELECT (col) en lugar de GRANT SELECT.
4. Agregar los GRANTs al script de migración con comentario de justificación.
5. Nunca usar GRANT ALL.
6. Revisar si la nueva tabla requiere una secuencia y otorgar USAGE al rol correspondiente.
7. Documentar en u5_requirements.md la nueva tabla y su clasificación.
```

**Plantilla de migración para nueva tabla:**

```sql
-- Nueva tabla: <nombre_tabla>
-- Clasificación: <pública / transaccional / sensible>
-- Justificación: <motivo del acceso por rol>

GRANT SELECT ON TABLE public.<nombre_tabla> TO <rol>;          -- lectura
GRANT INSERT ON TABLE public.<nombre_tabla> TO <rol>;          -- alta
GRANT UPDATE ON TABLE public.<nombre_tabla> TO <rol>;          -- modificación
GRANT DELETE ON TABLE public.<nombre_tabla> TO <rol>;          -- baja (solo si aplica)
-- GRANT ALL: PROHIBIDO
```

---

## 8. Criterios de Aceptación del Diseño

| # | Criterio | Verificación |
|---|---|---|
| 1 | Ningún rol usa `GRANT ALL` ni `SUPERUSER` | Auditoría de scripts: `grep -i "grant all\|superuser"` |
| 2 | `rol_soporte` no puede leer `usuario.nombre` | `SET ROLE rol_soporte; SELECT nombre FROM usuario;` → debe fallar |
| 3 | `rol_app_escritura` no puede modificar `producto.precio` | `SET ROLE rol_app_escritura; UPDATE producto SET precio = 0 WHERE id_producto = 1;` → debe fallar |
| 4 | `app_web` no puede hacer `DELETE` sobre ninguna tabla | `SET ROLE app_web; DELETE FROM pedido WHERE id_pedido = 1;` → debe fallar |
| 5 | `rol_reportes` accede a `vista_ventas_usuario_mes` pero no a `cliente` directo | `SET ROLE rol_reportes; SELECT * FROM vista_ventas_usuario_mes;` → OK; `SELECT email FROM cliente;` → debe fallar |
| 6 | `admin_datos` no puede hacer `DELETE` sobre `pedido` | `SET ROLE admin_datos; DELETE FROM pedido;` → debe fallar |
| 7 | `admin_datos` puede ejecutar `REFRESH MATERIALIZED VIEW` | Verificar via procedimiento `SECURITY DEFINER` o grant explícito del DBA |
| 8 | Toda nueva tabla inicia sin permisos para roles de aplicación | `\dp nueva_tabla` en psql → sin entradas para roles de app |
