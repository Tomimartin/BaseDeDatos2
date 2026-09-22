# Spec: Vista Materializada de Facturación por Categoría y Mes

## Objetivo
Optimizar la consulta analítica de facturación agrupada por categoría y mes, evitando el costo de procesamiento de múltiples JOINs y agregaciones sobre tablas de gran volumen.

## Estructura de la Vista Materializada (`mv_facturacion_categoria_mes`)
- `id_categoria`: Identificador de la categoría.
- `categoria`: Nombre de la categoría (`categoria.nombre`).
- `mes_anio`: Fecha truncada al primer día del mes (`DATE_TRUNC('month', pedido.fecha)`).
- `total_pedidos`: Conteo único de pedidos (`COUNT(DISTINCT pedido.id_pedido)`).
- `total_unidades`: Suma de unidades vendidas (`SUM(detalle_pedido.cantidad)`).
- `facturacion_total`: Suma acumulada de facturación (`SUM(detalle_pedido.subtotal)`).

## Requisitos de Infraestructura
1. Crear con cláusula `WITH DATA`.
2. Incluir un índice único sobre `(id_categoria, mes_anio)` para habilitar el refresco concurrente (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).