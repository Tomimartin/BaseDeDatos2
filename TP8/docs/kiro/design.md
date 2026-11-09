# TP8 Food Store — Design

Diseño del módulo móvil offline del TP8, elaborado y revisado con Kiro. Se conserva la estructura que efectivamente está implementada en `movil/foodstore_movil.db`.

## 1. Arquitectura

PostgreSQL es la fuente de verdad de productos, precios, stock y ventas. La tablet SQLite solo mantiene catálogo y borradores sin conexión. MongoDB, trabajado en la Unidad 7, conserva documentos para consultas, pero no participa en el control de stock.

```text
PostgreSQL (productos y ventas oficiales)
    | v_snapshot_movil → CSV
    v
SQLite (tablet sin conexión)
    producto_cache  ← catálogo local
    pedido_borrador ← pedido sin confirmar
    item_borrador   ← líneas y precios vistos
    cola_sync       ← UUID, estado y motivo
    snapshot_servidor ← importación de CSV para comparar
```

## 2. Esquema SQLite y restricciones

Las cuatro tablas permanentes se crean con `STRICT` y se activan las claves foráneas mediante `PRAGMA foreign_keys = ON` en cada conexión.

| Tabla | Campos importantes | Función |
|---|---|---|
| `producto_cache` | `producto_id` PK, `nombre`, `precio_centavos`, `stock_visto`, `disponible_visto`, `eliminado`, `capturado_en` | Catálogo de productos |
| `pedido_borrador` | `id_local` PK, `usuario_id_servidor`, `forma_pago`, `creado_en` | Cabecera local sin venta confirmada |
| `item_borrador` | `(id_local, producto_id)` PK compuesta, `cantidad`, `precio_centavos_visto` | Ítems del borrador |
| `cola_sync` | `solicitud_uuid` PK, `id_local`, `estado`, `motivo`, `creada_en` | Cola de solicitudes y resultado |

`item_borrador.id_local` y `cola_sync.id_local` tienen FK hacia `pedido_borrador`; `item_borrador.producto_id` tiene FK hacia `producto_cache`. `cantidad > 0` es un `CHECK` (error SQLite 275), y referenciar un producto inexistente incumple una FK (787). La PK de `solicitud_uuid` impide repetir el UUID (1555). El índice parcial `ux_cola_una_pendiente` impide más de una solicitud pendiente del mismo borrador con diferentes UUID (2067). Los estados aceptados por el CHECK son `PENDIENTE`, `RECHAZADO`, `CONFLICTO` y `SIMULADO_APROBADO`.

El campo `forma_pago` se limita a `EFECTIVO`, `TARJETA` o `TRANSFERENCIA`; `usuario_id_servidor` es un identificador de prueba, no un dato personal. Se utilizan importes enteros en centavos para evitar comparaciones decimales inexactas. Los productos dados de baja se conservan con `eliminado = 1` y `disponible_visto = 0`, para preservar los borradores.

Además de las cuatro tablas `STRICT`, la tabla auxiliar `snapshot_servidor` se crea importando el CSV en DB Browser. La base de las pruebas incluye también `snapshot_c2`, `snapshot_c3` y `snapshot_c4` como registros históricos de la prueba; no son tablas permanentes del diseño.

## 3. Catálogo sin conexión

La vista `public.v_snapshot_movil` de PostgreSQL genera las columnas `producto_id`, `nombre`, `precio_centavos`, `stock`, `disponible`, `eliminado` y `capturado_en`, usando los datos oficiales de `producto` y `categoria` y `(precio * 100)::BIGINT`.

Flujo de actualización:

1. Exportar `SELECT * FROM public.v_snapshot_movil ORDER BY producto_id` a CSV.
2. Importar el CSV en SQLite como `snapshot_servidor`, con encabezados.
3. Poblar `producto_cache` mediante `INSERT ... SELECT`, convirtiendo tipos y booleanos a enteros.
4. Consultar productos sin conexión desde la vista local `v_catalogo_disponible`.

Prueba C1:

```sql
SELECT producto_id, nombre, precio, stock_visto
FROM v_catalogo_disponible ORDER BY producto_id LIMIT 10;
```

`v_catalogo_disponible` selecciona `disponible_visto = 1 AND eliminado = 0` y muestra el precio decimal derivado de `precio_centavos / 100.0`; solo lee datos locales.

## 4. Simulación de sincronización

Cuando el dispositivo vuelve a recibir una instantánea reciente, `semaforo.sql` evalúa únicamente filas de `cola_sync` en estado `PENDIENTE`. Cruza cada borrador con sus ítems y los datos importados de `snapshot_servidor`, y registra `estado` y `motivo`.

| Prioridad | Estado | Regla |
|---|---|---|
| 1 | `RECHAZADO` | Producto ausente, eliminado, no disponible, sin stock o dato de rechazo desconocido/NULL |
| 2 | `CONFLICTO` | Cambio de precio o precio NULL, si no hay rechazo |
| 3 | `SIMULADO_APROBADO` | Coinciden todos los datos necesarios |

El semáforo trata `NULL` de `eliminado`, `disponible` o `stock` como rechazo; `NULL` de `precio_centavos` como conflicto. Una condición de rechazo prevalece sobre un conflicto de precio. El `UPDATE` lleva `WHERE estado = 'PENDIENTE'` y por lo tanto un segundo pase no modifica solicitudes ya evaluadas. C6 comprueba la idempotencia de la PK del UUID y se conserva el índice parcial adicional.

No existe un campo `evaluado_en` separado ni se cambian nombres (`id_local`, `precio_centavos_visto`, `creada_en`) para mantener compatibilidad con la base real. `SIMULADO_APROBADO` nunca confirma ventas ni escribe en PostgreSQL; la confirmación final requiere un servicio del servidor fuera del alcance del TP8.
