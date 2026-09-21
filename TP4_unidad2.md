# Parte 1: Laboratorio de Consultas Analíticas Lentas (Semana 4)

## Tabla de Resultados (Parte 1.2)

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
| :--- | :--- | :--- | :--- | :--- |
| **1. Facturación por Categoría y Mes**<br>*(Cruza `categoria`, `producto`, `detalle_pedido` y `pedido`)* | `Parallel Hash Join` (`dp` ⋈ `p`) y `Hash Join` encadenados (`dp` ⋈ `pr`, `pr` ⋈ `c`) | ```sql\nCREATE INDEX idx_pedido_fecha\nON pedido(fecha);\n\nCREATE INDEX idx_detalle_pedido_prod_cover\nON detalle_pedido(id_producto)\nINCLUDE (id_pedido, subtotal);\n``` | Se mantienen los `Hash Join` utilizando barridos eficientes de datos en memoria. | **1.27x más rápida**<br>*(De 300.63 ms a 237.58 ms)* |
| **2. Ranking de Clientes por Gasto**<br>*(Cruza `cliente`, `pedido` y `detalle_pedido`)* | `Parallel Hash Join` (`dp` ⋈ `p`) y `Hash Join` (`p` ⋈ `cl`) | ```sql\nCREATE INDEX idx_pedido_cliente_pedido\nON pedido(id_cliente, id_pedido);\n``` | Se mantuvieron los `Hash Join` en paralelo debido al volumen global de filas agrupadas (`GROUP BY`) sin filtro previo. | **1.02x más rápida**<br>*(De 307.51 ms a 301.62 ms)* |

---

# Parte 2: Lectura Crítica de Planes de Join Interpretados por IA

## Tabla de Evaluación Crítica

| Afirmación de la IA | ¿Correcta? | Corrección / Evidencia del plan real |
| :--- | :---: | :--- |
| *"El optimizador eligió un Nested Loop para unir la tabla cliente con los pedidos acumulados."* | **No** | El plan muestra explícitamente un nodo **`Hash Join`** (`Hash Cond: (p.id_cliente = cl.id_cliente)`). No usó `Nested Loop` porque procesó en masa las 20.000 filas de clientes. |
| *"En la unión paralela con detalle_pedido, la tabla interna (build phase) utilizada para armar la tabla Hash fue detalle_pedido."* | **No** | En el nodo `Parallel Hash Join`, la tabla bajo el nodo `Parallel Hash` es **`pedido`** (`Parallel Seq Scan on pedido p`), confirmando que `pedido` fue la tabla interna para la estructura Hash. |
| *"El tiempo de ejecución consumido por el nodo de Hash Join paralelo fue de 7270.43 milisegundos."* | **No** | Confunde el **costo estimado arbitrario** (`cost=4118.10..7270.43`) con milisegundos reales. El tiempo real registrado fue de **31.193 ms a 90.444 ms** (`actual time=31.193..90.444`). |
| *"El agrupamiento HashAggregate no cupo completamente en la memoria RAM y tuvo que utilizar disco."* | **Sí** | Correcto. La presencia explícita de **`Disk Usage: 720kB`** en los nodos `HashAggregate` confirma el desborde de *work_mem* hacia archivos temporales en disco. |