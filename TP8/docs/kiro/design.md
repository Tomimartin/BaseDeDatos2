# TP8 Food Store — Design

Documento de diseño del módulo móvil offline de Food Store para su registro en Kiro. Describe la base SQLite, sus restricciones, el catálogo sin conexión y la simulación de sincronización con PostgreSQL.

---

## 1. Arquitectura general

PostgreSQL es la **fuente de verdad** del sistema: administra precios, stock oficial y pedidos confirmados. SQLite representa una tablet que opera sin conexión, almacena una copia del catálogo y registra borradores de pedido. MongoDB (U7) es de lectura documental y no interviene en el control de stock ni en la sincronización.

```
PostgreSQL (fuente de verdad)
    │
    │  exporta v_snapshot_movil → CSV
    ▼
SQLite (tablet offline)
    ├── producto_cache       ← catálogo importado
    ├── pedido_borrador      ← cabeceras sin confirmar
    ├── item_borrador        ← líneas de borrador
    ├── cola_sync            ← solicitudes y estados del semáforo
    └── snapshot_servidor    ← instantánea temporal para comparación
```

---

## 2. Base de datos SQLite

### 2.1 Tablas STRICT

La base `foodstore_movil.db` usa cuatro tablas declaradas con `STRICT` para que SQLite aplique verificación de tipos en cada inserción:

| Tabla | Propósito |
|---|---|
| `producto_cache` | Copia local del catálogo: `producto_id` (PK), `nombre`, `precio_centavos` (INTEGER), `stock_visto`, `disponible_visto` (0/1), `eliminado` (0/1), `capturado_en` |
| `pedido_borrador` | Cabecera de pedido offline: `id_local` (PK), `usuario_id_servidor` (NOT NULL), `forma_pago` (NOT NULL), `creado_en` |
| `item_borrador` | Líneas del borrador: `id_local` (FK), `producto_id` (FK), `cantidad`, `precio_centavos_visto`; PK compuesta `(id_local, producto_id)` |
| `cola_sync` | Solicitudes de sincronización: `solicitud_uuid` (PK), `id_local` (FK), `estado`, `motivo`, `creada_en` |

La tabla `snapshot_servidor` se importa desde CSV en cada ciclo de sincronización y no forma parte del esquema permanente. En esa instantánea, `disponible` y `eliminado` llegan como texto (`'True'`/`'False'`). La base entregada también conserva `snapshot_c2`, `snapshot_c3` y `snapshot_c4` como evidencia de las pruebas; son tablas auxiliares, no parte del modelo permanente.

### 2.2 Restricciones aplicadas

| Restricción | Tabla | Columna / Condición | Propósito |
|---|---|---|---|
| `PRIMARY KEY` | `producto_cache`, `pedido_borrador`, `cola_sync` | `producto_id`, `id_local`, `solicitud_uuid` | Unicidad de fila; en `cola_sync` implementa la idempotencia (error 1555) |
| `PRIMARY KEY` compuesta | `item_borrador` | `(id_local, producto_id)` | Una línea por producto en cada borrador |
| `FOREIGN KEY` | `item_borrador` | `id_local → pedido_borrador(id_local)` | Integridad referencial |
| `FOREIGN KEY` | `item_borrador` | `producto_id → producto_cache(producto_id)` | Solo productos existentes (error 787) |
| `FOREIGN KEY` | `cola_sync` | `id_local → pedido_borrador(id_local)` | Solicitud ligada a borrador válido |
| `CHECK` | `item_borrador` | `cantidad > 0` | Impide cantidades inválidas (error 275) |
| `UNIQUE` parcial | `cola_sync` | `id_local` donde `estado = 'PENDIENTE'` (`ux_cola_una_pendiente`) | Evita dos solicitudes pendientes para el mismo borrador (error 2067) |
| `NOT NULL` | varias | columnas obligatorias de negocio (`usuario_id_servidor`, `forma_pago`, `cantidad`, etc.) | Integridad mínima de datos |

Las claves foráneas están activas mediante `PRAGMA foreign_keys = ON` en cada sesión (SQLite las desactiva por defecto).

### 2.3 Importes en centavos

Los precios se almacenan como enteros en centavos (`precio_centavos INTEGER` en SQLite; `BIGINT` al exportar desde PostgreSQL) para evitar errores de punto flotante. La conversión se aplica al exportar desde PostgreSQL: `(precio * 100)::BIGINT`.

### 2.4 Baja lógica

Los productos dados de baja en PostgreSQL se conservan en `producto_cache` con `eliminado = 1` y `disponible_visto = 0`. Esto preserva la integridad referencial de borradores ya creados sin eliminar la fila física.

---

## 3. Catálogo sin conexión

### 3.1 Vista de exportación en PostgreSQL

```sql
CREATE OR REPLACE VIEW public.v_snapshot_movil AS
SELECT p.id_producto           AS producto_id,
       p.nombre,
       (p.precio * 100)::BIGINT AS precio_centavos,
       p.stock,
       (p.activo AND c.activo)  AS disponible,
       NOT (p.activo AND c.activo) AS eliminado,
       NOW()                   AS capturado_en
FROM public.producto p
JOIN public.categoria c ON c.id_categoria = p.id_categoria;
```

### 3.2 Flujo de importación

1. Exportar `SELECT * FROM v_snapshot_movil ORDER BY producto_id` a CSV UTF-8.
2. Importar el CSV en DB Browser como tabla `snapshot_servidor`.
3. Poblar `producto_cache` mediante `INSERT INTO producto_cache ... SELECT ... FROM snapshot_servidor` con casteos explícitos de tipo.
4. La tabla `producto_cache` queda disponible para consultas offline sin ninguna conexión activa a PostgreSQL.

### 3.3 Consulta offline (C1)

```sql
SELECT producto_id, nombre, precio, stock_visto
FROM v_catalogo_disponible
ORDER BY producto_id
LIMIT 10;
```

La vista `v_catalogo_disponible` filtra `disponible_visto = 1 AND eliminado = 0` y expone `precio` como `precio_centavos / 100.0`. Esta consulta no modifica stock ni genera solicitudes. Es de solo lectura sobre datos locales.

---

## 4. Simulación de sincronización con PostgreSQL

### 4.1 Principio

La tablet no se conecta directamente a PostgreSQL para confirmar ventas. El semáforo local **simula** la comparación evaluando el estado del borrador contra la última instantánea importada. El resultado es orientativo; la confirmación real es responsabilidad de PostgreSQL cuando se construya el endpoint de sincronización.

### 4.2 Estados del semáforo

| Estado | Condición de asignación | Prioridad |
|---|---|---|
| `RECHAZADO` | Producto dado de baja, no existe, no disponible o stock insuficiente | Alta (1) |
| `CONFLICTO` | Precio cambió respecto al borrador, sin condición de rechazo | Media (2) |
| `SIMULADO_APROBADO` | Todos los campos del borrador coinciden con la instantánea | Baja (3) |

El semáforo aplica los estados en orden de prioridad: si una solicitud tiene al menos un motivo de rechazo, el estado final es `RECHAZADO` aunque también haya conflicto de precio.

### 4.3 Proceso de evaluación (`semaforo.sql`)

```
Para cada solicitud con estado = 'PENDIENTE' en cola_sync:
  1. Obtener los ítems de item_borrador asociados al id_local.
  2. Cruzar con snapshot_servidor para cada producto_id.
  3. Evaluar en orden:
     a. Si eliminado = 'True' o disponible ≠ 'True' (o NULL) → RECHAZADO (baja/no disponible)
     b. Si stock < cantidad solicitada (o stock NULL)          → RECHAZADO (stock insuficiente)
     c. Si precio_centavos ≠ precio_centavos_visto (o precio NULL) → CONFLICTO
     d. Si ninguna condición anterior                          → SIMULADO_APROBADO
  4. UPDATE cola_sync SET estado = <resultado>, motivo = <texto>
     WHERE solicitud_uuid = <uuid> AND estado = 'PENDIENTE';
```

Solo se actualizan solicitudes en estado `PENDIENTE`. Las que ya fueron evaluadas (`RECHAZADO`, `CONFLICTO`, `SIMULADO_APROBADO`) no se tocan. La implementación no guarda un `evaluado_en` separado; `creada_en` conserva la fecha de creación de la solicitud. Los valores NULL en `eliminado`, `disponible`, `stock` o `precio_centavos` de la instantánea se tratan como condición de rechazo o conflicto (fail-safe), no como coincidencia.

### 4.4 Idempotencia por UUID

Cada solicitud en `cola_sync` tiene `solicitud_uuid` como `PRIMARY KEY`, que implementa la unicidad y rechaza duplicados con error 1555 antes de que el semáforo la procese (C6). Además, `ux_cola_una_pendiente` impide dos solicitudes `PENDIENTE` para el mismo `id_local` con UUID distinto (error 2067).

### 4.5 Limitación deliberada

El TP8 no implementa un endpoint real. `SIMULADO_APROBADO` no modifica el stock de PostgreSQL ni registra el pedido en `public.pedido`. La sincronización definitiva requiere un servicio backend fuera del alcance de este trabajo.
