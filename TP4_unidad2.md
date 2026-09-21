# Parte 1: Laboratorio de Consultas Analíticas Lentas (Semana 4)

## Tabla de Resultados (Parte 1.2)

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
| :--- | :--- | :--- | :--- | :--- |
| **1. Facturación por Categoría y Mes**<br>*(Cruza `categoria`, `producto`, `detalle_pedido` y `pedido`)* | `Parallel Hash Join` (`dp` ⋈ `p`) y `Hash Join` encadenados (`dp` ⋈ `pr`, `pr` ⋈ `c`) | ```sql\nCREATE INDEX idx_pedido_fecha\nON pedido(fecha);\n\nCREATE INDEX idx_detalle_pedido_prod_cover\nON detalle_pedido(id_producto)\nINCLUDE (id_pedido, subtotal);\n``` | Se mantienen los `Hash Join` utilizando barridos eficientes de datos en memoria. | **1.27x más rápida**<br>*(De 300.63 ms a 237.58 ms)* |
| **2. Ranking de Clientes por Gasto**<br>*(Cruza `cliente`, `pedido` y `detalle_pedido`)* | `Parallel Hash Join` (`dp` ⋈ `p`) y `Hash Join` (`p` ⋈ `cl`) | ```sql\nCREATE INDEX idx_pedido_cliente_pedido\nON pedido(id_cliente, id_pedido);\n``` | Se mantuvieron los `Hash Join` en paralelo debido al volumen global de filas agrupadas (`GROUP BY`) sin filtro previo. | **1.02x más rápida**<br>*(De 307.51 ms a 301.62 ms)* |