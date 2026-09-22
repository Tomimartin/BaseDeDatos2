# Food Store — Proyecto de Optimización en PostgreSQL

Trabajo práctico de optimización de bases de datos relacionales sobre el esquema **Food Store** (PostgreSQL 17). Cubre tres partes: índices B-Tree, vistas relacionales con criterios de seguridad y vistas materializadas para reportes analíticos.

---

## Requisitos Previos

| Herramienta | Versión mínima | Notas |
|---|---|---|
| PostgreSQL | 17.x | Puede funcionar en 14+ con mínimos ajustes |
| psql | Incluido con PostgreSQL | O cualquier cliente SQL (DBeaver, pgAdmin) |

---

## Estructura del Proyecto

```
BaseDeDatos2/
│
├── base_food_store.sql          # DDL completo + datos base (esquema inicial)
├── indices.sql                  # Índices B-Tree optimizados (Parte A)
├── views.sql                    # Vistas relacionales (Parte B)
├── materializadas.md            # Vista materializada y mediciones (Parte C)
│
├── informe_mediciones.md        # Informe antes/después de cada optimización
├── DUIA.md                      # Declaración de Uso de IA y bitácora
│
└── specs/
    ├── spec_pedidos_fecha.md              # Spec: índice sobre pedido.fecha
    ├── spec_producto_precio.md            # Spec: índice sobre producto.precio DESC
    ├── spec_detalle_producto.md           # Spec: índice compuesto detalle_pedido
    ├── spec_vista_stock_critico.md        # Spec: vista stock crítico
    ├── spec_vista_ventas_usuario_mes.md   # Spec: vista ventas por cliente y mes
    ├── spec_vista_producots_mas_vendidos  # Spec: vista productos más vendidos
    └── spec_vista_materializada_facturacion.md  # Spec: vista materializada
```

---

## Paso 1 — Crear la Base de Datos

```sql
-- Desde psql como superusuario:
CREATE DATABASE food_store;
\c food_store
```

---

## Paso 2 — Cargar el Esquema Base

Ejecutar el dump completo que crea todas las tablas, secuencias, restricciones y datos iniciales:

```bash
psql -U <usuario> -d food_store -f base_food_store.sql
```

Tablas creadas: `categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`.

Verificar que la carga fue exitosa:

```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

Resultado esperado: 5 tablas (`categoria`, `cliente`, `detalle_pedido`, `pedido`, `producto`).

---

## Paso 3 — Verificar el Plan ANTES de los Índices (Baseline)

Antes de aplicar ninguna optimización, capturar el plan de ejecución original con `EXPLAIN ANALYZE` para cada consulta. Estos son los valores de referencia del informe.

**Consulta 1 — Pedidos por rango de fechas:**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha
FROM pedido
WHERE fecha BETWEEN '2020-01-01' AND '2026-12-31';
```

Resultado esperado sin índice: `Seq Scan on pedido` — tiempo ~36 ms con datos masivos.

**Consulta 2 — Productos por precio:**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio
FROM producto
WHERE precio > 4970
ORDER BY precio DESC;
```

Resultado esperado sin índice: `Seq Scan on producto` + nodo `Sort (Quicksort)` — tiempo ~3.9 ms.

**Consulta 3 — Historial de detalle por producto:**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, cantidad, subtotal
FROM detalle_pedido
WHERE id_producto = 150
ORDER BY cantidad DESC;
```

Resultado esperado sin índice: `Parallel Seq Scan on detalle_pedido` + `Sort` — tiempo ~35 ms con tabla masiva.

---

## Paso 4 — Aplicar los Índices (Parte A)

```bash
psql -U <usuario> -d food_store -f indices.sql
```

O ejecutar cada sentencia individualmente:

```sql
-- Índice 1: rango de fechas en pedidos
CREATE INDEX idx_pedido_fecha
    ON public.pedido USING btree (fecha);

-- Índice 2: filtro y orden descendente por precio
CREATE INDEX idx_producto_precio_desc
    ON public.producto (precio DESC);

-- Índice 3: historial de ventas por producto (índice compuesto)
CREATE INDEX idx_detalle_pedido_producto_cant
    ON public.detalle_pedido (id_producto, cantidad DESC);
```

Actualizar estadísticas del planificador:

```sql
ANALYZE public.pedido;
ANALYZE public.producto;
ANALYZE public.detalle_pedido;
```

---

## Paso 5 — Verificar el Plan DESPUÉS de los Índices

Repetir exactamente las mismas consultas del Paso 3 con `EXPLAIN (ANALYZE, BUFFERS)`.

**Resultados esperados:**

| Consulta | Plan esperado | Nodos eliminados |
|---|---|---|
| Pedidos por fecha | `Index Scan using idx_pedido_fecha` | `Seq Scan` |
| Productos por precio | `Bitmap Index Scan` o `Index Scan` | `Seq Scan` + `Sort` |
| Detalle por producto | `Index Scan using idx_detalle_pedido_producto_cant` | `Seq Scan` + `Sort` |

Ver resultados completos en [`informe_mediciones.md`](informe_mediciones.md).

---

## Paso 6 — Crear las Vistas (Parte B)

```bash
psql -U <usuario> -d food_store -f views.sql
```

Tres vistas creadas:

| Vista | Descripción |
|---|---|
| `vista_productos_mas_vendidos` | Ranking de productos por unidades vendidas y monto recaudado |
| `vista_ventas_usuario_mes` | Resumen mensual de compras por cliente (sin datos sensibles) |
| `vista_stock_critico` | Productos activos con stock ≤ 10 unidades |

Verificar cada vista:

```sql
SELECT * FROM vista_productos_mas_vendidos LIMIT 10;
SELECT * FROM vista_ventas_usuario_mes LIMIT 10;
SELECT * FROM vista_stock_critico;
```

**Control de acceso (seguridad):** la vista `vista_ventas_usuario_mes` oculta columnas sensibles de la tabla `cliente`. Para conceder acceso de solo lectura a un rol de reportes:

```sql
GRANT SELECT ON vista_ventas_usuario_mes TO rol_reportes;
```

---

## Paso 7 — Crear la Vista Materializada (Parte C)

```sql
-- 1. Crear la vista materializada con datos precalculados
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT
    c.id_categoria,
    c.nombre AS categoria,
    DATE_TRUNC('month', p.fecha) AS mes_anio,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos,
    SUM(dp.cantidad)   AS total_unidades,
    SUM(dp.subtotal)   AS facturacion_total
FROM categoria c
JOIN producto      pr ON c.id_categoria  = pr.id_categoria
JOIN detalle_pedido dp ON pr.id_producto = dp.id_producto
JOIN pedido         p ON dp.id_pedido    = p.id_pedido
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

-- 2. Índice único (obligatorio para REFRESH CONCURRENTLY)
CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes_pk
    ON mv_facturacion_categoria_mes (id_categoria, mes_anio);
```

Consultar la vista materializada:

```sql
SELECT * FROM mv_facturacion_categoria_mes
ORDER BY mes_anio DESC, facturacion_total DESC;
```

Resultado esperado: respuesta en ~0.057 ms frente a ~537 ms de la consulta directa (~9400x más rápida).

Refrescar los datos cuando cambien los pedidos:

```sql
-- Sin bloqueo (requiere el índice único creado arriba):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

---

## Paso 8 — Prueba del Costo de Mantenimiento en Escrituras

Para reproducir la medición de penalización por índices activos, ejecutar el siguiente bloque dentro de una transacción con `ROLLBACK` (no modifica datos reales):

```sql
-- CON índices activos (estado normal luego del Paso 4):
BEGIN;
\timing on
INSERT INTO categoria (nombre)
SELECT 'Categoria_' || i
FROM generate_series(100000, 101000) AS i;
ROLLBACK;

-- SIN índices: primero hacer DROP de los índices, luego repetir el bloque,
-- y finalmente recrearlos con indices.sql
```

Resultado esperado:
- Sin índices: ~3.3 ms
- Con índices activos: ~9.5 ms (~184 % de penalización)

---

## Resumen de Mejoras Obtenidas

| Optimización | Antes | Después | Mejora |
|---|---|---|---|
| Índice `idx_pedido_fecha` | 36.468 ms (Seq Scan) | 0.021 ms (Index Scan) | ~1736x |
| Índice `idx_producto_precio_desc` | 3.898 ms (Seq Scan + Sort) | 0.346 ms (Bitmap Index Scan) | ~11x |
| Índice `idx_detalle_pedido_producto_cant` | 35.268 ms (Parallel Seq Scan + Sort) | 0.060 ms (Index Scan) | ~588x |
| Vista materializada `mv_facturacion_categoria_mes` | 537.597 ms (Hash Join + external merge) | 0.057 ms (Seq Scan en memoria) | ~9400x |
| Inserción masiva (costo de escritura) | 3.337 ms | 9.501 ms | −184 % |

---

## Referencias

- Especificaciones técnicas de cada optimización: `specs/`
- Informe completo antes/después: [`informe_mediciones.md`](informe_mediciones.md)
- Declaración de Uso de IA y bitácora de decisiones: [`DUIA.md`](DUIA.md)
