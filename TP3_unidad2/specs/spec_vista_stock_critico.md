# Spec: Vista de Stock Crítico

## Objetivo
Monitorear los productos con bajo nivel de inventario para generar alertas de reabastecimiento en el sector de compras.

## Estructura de la Vista (`vista_stock_critico`)
- `id_producto`: Identificador del producto.
- `nombre_producto`: Nombre del producto (`producto.nombre`).
- `categoria`: Nombre de la categoría (`categoria.nombre`).
- `stock`: Cantidad disponible en inventario (`producto.stock`).
- `precio`: Precio unitario del producto (`producto.precio`).

## Criterio de Aceptación
1. Realizar `INNER JOIN` entre `producto` y `categoria`.
2. Filtrar únicamente los productos donde `stock <= 10` y `activo = TRUE`.
3. Ordenar los resultados por `stock` de forma ascendente.