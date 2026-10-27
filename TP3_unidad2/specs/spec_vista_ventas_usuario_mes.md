# Spec: Vista de Resumen Mensual de Ventas por Usuario

## Objetivo
Consolidar la actividad de compra de cada usuario mes a mes para análisis comercial y de fidelización.

## Estructura de la Vista (`vista_ventas_usuario_mes`)
- `id_usuario`: Identificador único del cliente.
- `nombre_usuario`: Nombre y apellido concatenados (`usuario.nombre || ' ' || usuario.apellido`).
- `mes_anio`: Primer día del mes correspondiente a las compras (`DATE_TRUNC('month', pedido.fecha)`).
- `total_pedidos`: Cantidad de pedidos distintos realizados en el mes (`COUNT(DISTINCT pedido.id_pedido)`).
- `total_gastado`: Suma acumulada del subtotal de los detalles de pedido (`SUM(detalle_pedido.subtotal)`).

## Criterio de Aceptación
1. Realizar `INNER JOIN` entre `usuario`, `pedido` y `detalle_pedido`.
2. Agrupar por `usuario.id_usuario`, `usuario.nombre`, `usuario.apellido` y el mes truncado de la fecha.
3. Ordenar por `mes_anio` descendente y luego por `total_gastado` descendente.