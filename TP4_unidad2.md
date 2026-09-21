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

---

# Parte 3: Consultas Resumen, Rankings y Subconsultas bajo Especificación Precisa (Semana 4)

---

## 1. Consulta A: Ranking con Función de Ventana (`DENSE_RANK`)

### Especificación Precisa (Spec)
> Generar una consulta SQL sobre el esquema de Food Store que devuelva, para cada cliente, su ID de cliente, su nombre completo (concatenando `nombre` y `apellido`), el total acumulado gastado en sus compras (`SUM(dp.subtotal)`) y su puesto en un ranking de mayor a menor gasto usando la función de ventana `DENSE_RANK()`. En caso de empate en el total gastado, deben compartir la misma posición sin saltar números. Evitar el uso de `SELECT *`.

### Versión 1 (Generada por IA - Uso de CTE)
```sql
WITH gasto_cliente AS (
    SELECT 
        cl.id_cliente,
        cl.nombre || ' ' || cl.apellido AS nombre_completo,
        COALESCE(SUM(dp.subtotal), 0) AS total_gastado
    FROM cliente cl
    JOIN pedido p ON cl.id_cliente = p.id_cliente
    JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
    GROUP BY cl.id_cliente, cl.nombre, cl.apellido
)
SELECT 
    id_cliente,
    nombre_completo,
    total_gastado,
    DENSE_RANK() OVER (ORDER BY total_gastado DESC) AS puesto_ranking
FROM gasto_cliente
ORDER BY puesto_ranking ASC;
```

### Versión 2 (Alternativa / Propia - Subconsulta Derivada)
```sql
SELECT 
    sub.id_cliente,
    sub.nombre_completo,
    sub.total_gastado,
    DENSE_RANK() OVER (ORDER BY sub.total_gastado DESC) AS puesto_ranking
FROM (
    SELECT 
        cl.id_cliente,
        CONCAT(cl.nombre, ' ', cl.apellido) AS nombre_completo,
        SUM(dp.subtotal) AS total_gastado
    FROM cliente cl
    INNER JOIN pedido p ON cl.id_cliente = p.id_cliente
    INNER JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
    GROUP BY cl.id_cliente, cl.nombre, cl.apellido
) sub
ORDER BY puesto_ranking ASC;
```

### Verificación de Equivalencia (`EXCEPT`)
```sql
-- Evaluación V1 EXCEPT V2 (Debe devolver 0 filas)
(
    WITH gasto_cliente AS (
        SELECT 
            cl.id_cliente,
            cl.nombre || ' ' || cl.apellido AS nombre_completo,
            COALESCE(SUM(dp.subtotal), 0) AS total_gastado
        FROM cliente cl
        JOIN pedido p ON cl.id_cliente = p.id_cliente
        JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido
    )
    SELECT id_cliente, nombre_completo, total_gastado, DENSE_RANK() OVER (ORDER BY total_gastado DESC) AS puesto_ranking 
    FROM gasto_cliente
)
EXCEPT
(
    SELECT sub.id_cliente, sub.nombre_completo, sub.total_gastado, DENSE_RANK() OVER (ORDER BY sub.total_gastado DESC) AS puesto_ranking
    FROM (
        SELECT cl.id_cliente, CONCAT(cl.nombre, ' ', cl.apellido) AS nombre_completo, SUM(dp.subtotal) AS total_gastado
        FROM cliente cl INNER JOIN pedido p ON cl.id_cliente = p.id_cliente INNER JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido
    ) sub
);

-- Evaluación V2 EXCEPT V1 (Debe devolver 0 filas)
(
    SELECT sub.id_cliente, sub.nombre_completo, sub.total_gastado, DENSE_RANK() OVER (ORDER BY sub.total_gastado DESC) AS puesto_ranking
    FROM (
        SELECT cl.id_cliente, CONCAT(cl.nombre, ' ', cl.apellido) AS nombre_completo, SUM(dp.subtotal) AS total_gastado
        FROM cliente cl INNER JOIN pedido p ON cl.id_cliente = p.id_cliente INNER JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido
    ) sub
)
EXCEPT
(
    WITH gasto_cliente AS (
        SELECT cl.id_cliente, cl.nombre || ' ' || cl.apellido AS nombre_completo, COALESCE(SUM(dp.subtotal), 0) AS total_gastado
        FROM cliente cl JOIN pedido p ON cl.id_cliente = p.id_cliente JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY cl.id_cliente, cl.nombre, cl.apellido
    )
    SELECT id_cliente, nombre_completo, total_gastado, DENSE_RANK() OVER (ORDER BY total_gastado DESC) AS puesto_ranking 
    FROM gasto_cliente
);
```

---

## 2. Consulta B: Subconsulta Correlacionada con `EXISTS`

### Especificación Precisa (Spec)
> Generar una consulta SQL sobre Food Store que obtenga las categorías activas (`activo = TRUE`) devolviendo su ID y nombre, únicamente si cuentan con al menos un producto con precio unitario superior al precio promedio global de todos los productos del sistema. La condición de existencia debe evaluarse mediante una subconsulta correlacionada con `EXISTS`. Evitar el uso de `SELECT *`.

### Versión 1 (Generada por IA - Subconsulta Correlacionada con `EXISTS`)
```sql
SELECT 
    c.id_categoria,
    c.nombre
FROM categoria c
WHERE c.activo = TRUE
  AND EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.id_categoria = c.id_categoria
      AND p.precio > (SELECT AVG(precio) FROM producto)
)
ORDER BY c.id_categoria ASC;
```

### Versión 2 (Alternativa / Propia - JOIN Explícito con `DISTINCT`)
```sql
SELECT DISTINCT
    c.id_categoria,
    c.nombre
FROM categoria c
JOIN producto p ON c.id_categoria = p.id_categoria
WHERE c.activo = TRUE
  AND p.precio > (SELECT AVG(precio) FROM producto)
ORDER BY c.id_categoria ASC;
```

### Verificación de Equivalencia (`EXCEPT`)
```sql
-- Evaluación V1 EXCEPT V2 (Debe devolver 0 filas)
(
    SELECT c.id_categoria, c.nombre
    FROM categoria c
    WHERE c.activo = TRUE AND EXISTS (
        SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria AND p.precio > (SELECT AVG(precio) FROM producto)
    )
)
EXCEPT
(
    SELECT DISTINCT c.id_categoria, c.nombre
    FROM categoria c JOIN producto p ON c.id_categoria = p.id_categoria
    WHERE c.activo = TRUE AND p.precio > (SELECT AVG(precio) FROM producto)
);

-- Evaluación V2 EXCEPT V1 (Debe devolver 0 filas)
(
    SELECT DISTINCT c.id_categoria, c.nombre
    FROM categoria c JOIN producto p ON c.id_categoria = p.id_categoria
    WHERE c.activo = TRUE AND p.precio > (SELECT AVG(precio) FROM producto)
)
EXCEPT
(
    SELECT c.id_categoria, c.nombre
    FROM categoria c
    WHERE c.activo = TRUE AND EXISTS (
        SELECT 1 FROM producto p WHERE p.id_categoria = c.id_categoria AND p.precio > (SELECT AVG(precio) FROM producto)
    )
);
```

---

# Declaración de Uso de IA (DUIA) - Trabajo Práctico Semana 4

**Asignatura:** Base de Datos II  
**Tema:** Reportes analíticos asistidos por IA sobre Food Store (joins, subconsultas, agregación y ventana)

| Herramienta | Para qué se usó | Prompt / Spec (resumen) | Se aceptó / Se descartó (por qué) |
| :--- | :--- | :--- | :--- |
| **OpenCode** | Propuesta de índices para optimizar consultas analíticas con múltiples JOINs (Parte 1). | *"Analizá los planes de EXPLAIN ANALYZE iniciales para dos consultas de reporte (Facturación mensual por categoría y Ranking histórico de clientes) que cruzan múltiples tablas, e indicá qué índices crear para bajar el tiempo de ejecución."* | **Se aceptó:** Se implementaron los índices propuestos (`idx_pedido_fecha`, `idx_detalle_pedido_prod_cover`, `idx_pedido_cliente_pedido`). En la Consulta 1 la mejora fue de 1.27x. En la Consulta 2, la mejora fue leve (1.02x) porque el optimizador prefirió mantener los escaneos secuenciales paralelos y `Hash Join` dado el gran volumen de datos a agrupar. |
| **OpenCode** | Explicación en lenguaje natural de un plan con múltiples JOINs (Parte 2). | *"Explicá nodo por nodo en lenguaje natural el plan de ejecución obtenido para la consulta del ranking histórico de clientes."* | **Se descartó (la explicación):** Se detectaron múltiples errores conceptuales. La IA afirmó que se usó un `Nested Loop` cuando el plan indicaba `Hash Join`; invirtió el orden de las tablas en la fase de construcción (build) y exploración (probe); y confundió el costo estimado con el tiempo en milisegundos. Solo acertó en que el nodo `HashAggregate` debió usar disco por falta de memoria. |
| **OpenCode** | Generación de la **Consulta A** (Ranking con función de ventana) bajo especificación precisa (Parte 3). | **Spec:** *"Generar una consulta SQL sobre Food Store que devuelva, para cada cliente, su ID, nombre completo, total gastado y su puesto en un ranking usando DENSE_RANK(). En caso de empate, deben compartir posición. Evitar SELECT \*."* | **Se aceptó con ajustes:** La IA generó correctamente la lógica usando una CTE (Common Table Expression). Sin embargo, se debió eliminar el filtro propuesto `cl.activo = TRUE` ya que, al validar contra el esquema real, la columna no existía. Tras el ajuste, se comprobó su equivalencia absoluta contra una versión con subconsulta derivada usando `EXCEPT` (0 filas de diferencia). |
| **OpenCode** | Generación de la **Consulta B** (Subconsulta correlacionada) bajo especificación precisa (Parte 3). | **Spec:** *"Generar una consulta SQL sobre Food Store que obtenga las categorías activas devolviendo su ID y nombre, únicamente si cuentan con al menos un producto con precio unitario superior al precio promedio global. Usar EXISTS. Evitar SELECT \*."* | **Se aceptó:** La IA estructuró de manera correcta la subconsulta correlacionada. Se verificó formalmente la equivalencia estricta contra una versión alternativa desarrollada manualmente (utilizando `JOIN` y `DISTINCT`) mediante la cláusula `EXCEPT` en ambos sentidos, resultando en 0 diferencias. |
| **Kiro** | *(No utilizado)* | N/A | **No aplica:** Todas las interacciones de este trabajo práctico se centralizaron exclusivamente en OpenCode. |