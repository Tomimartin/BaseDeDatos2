# Spec: Vista de Productos Más Vendidos

## Objetivo
Permitir a la administración consultar el ranking de productos según su volumen de ventas.

## Estructura de la Vista (`vista_productos_mas_vendidos`)
- `id_producto`: Identificador del producto.
- `nombre_producto`: Nombre del producto (`producto.nombre`).
- `categoria`: Nombre de la categoría (`categoria.nombre`).
- `total_unidades_vendidas`: Suma de las cantidades vendidas (`SUM(detalle_pedido.cantidad)`).
- `monto_total_recaudado`: Suma de los subtotales (`SUM(detalle_pedido.subtotal)`).

## Criterio de Aceptación
1. Utilizar `INNER JOIN` entre `producto`, `categoria` y `detalle_pedido`.
2. Agrupar por `id_producto`, `producto.nombre` y `categoria.nombre`.
3. Ordenar los resultados por `total_unidades_vendidas` de forma descendente.