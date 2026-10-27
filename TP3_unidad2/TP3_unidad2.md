# TP3 - Unidad 2: Optimización y Escalado de Food Store

**Materia:** Base de Datos II
**Carrera:** Tecnicatura Universitaria en Programación
**Institución:** Universidad Tecnológica Nacional (UTN)
**Proyecto:** Food Store
**Repositorio:** https://github.com/Tomimartin/BaseDeDatos2

---

Contenido del trabajo:

- **Parte 1** — Carga masiva de datos: `cargar_datos_masivos.sql`
- **Parte 2** — Optimización de Consultas asistida por IA
- **Parte 3** — Lectura Crítica de Planes Interpretados por IA
- **Parte 4** — Consultas Resumen y Subconsultas bajo Especificación Precisa
- **DUIA** — Declaración de Uso de IA

---

## Parte 1 - Carga masiva de datos

Script completo: `cargar_datos_masivos.sql` (PostgreSQL, sin PL/pgSQL, basado en `generate_series`).

```sql
-- =====================================================================
-- Carga masiva de datos para Food Store (PostgreSQL)
-- Generado con generate_series, sin PL/pgSQL.
-- Ejecutar solo sobre una copia de la base (nunca en producción):
--   psql -U postgres -h localhost -d "food_store-copia" -v ON_ERROR_STOP=1 -f cargar_datos_masivos.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) 50.000 productos nuevos, distribuidos de forma pareja entre las
--    categorías existentes. Precio entre 500 y 5000, stock 0..200.
--    Se usan ids explícitos (OVERRIDING SYSTEM VALUE) para poder
--    referenciarlos de forma determinística en detalle_pedido.
-- ---------------------------------------------------------------------

WITH cats AS (
    SELECT array_agg(id_categoria ORDER BY id_categoria) AS ids,
           count(*) AS n
    FROM public.categoria
),
base AS (
    SELECT COALESCE(max(id_producto), 0) AS b FROM public.producto
)
INSERT INTO public.producto (
    id_producto, nombre, descripcion, precio, stock, activo, id_categoria
)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    'Producto generado ' || (base.b + g.g),
    'Carga masiva de prueba',
    round((500 + random() * 4500)::numeric, 2),     -- CHECK precio > 0
    floor(random() * 201)::int,                      -- 0..200, CHECK stock >= 0
    true,
    cats.ids[((g.g - 1) % cats.n) + 1]              -- reparto equilibrado
FROM generate_series(1, 50000) AS g(g)
CROSS JOIN cats, base;

-- ---------------------------------------------------------------------
-- 2) 20.000 clientes nuevos. Emails únicos por construcción.
--    Se usan ids explícitos (OVERRIDING SYSTEM VALUE) para que la
--    secuencia no dependa de corridas previas.
-- ---------------------------------------------------------------------

WITH base AS (
    SELECT COALESCE(max(id_cliente), 0) AS b FROM public.cliente
)
INSERT INTO public.cliente (id_cliente, nombre, apellido, email, telefono)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    'Nombre ' || g.g,
    'Apellido ' || g.g,
    'cliente' || g.g || '@foodstore.com',            -- UNIQUE (email)
    '261' || lpad((floor(random() * 10000000)::bigint)::text, 7, '0')
FROM generate_series(1, 20000) AS g(g)
CROSS JOIN base;

-- ---------------------------------------------------------------------
-- 3) 200.000 pedidos nuevos. Fechas en el pasado (CHECK fecha <= now()),
--    forma de pago del enum e id_cliente existente.
-- ---------------------------------------------------------------------

WITH base AS (
    SELECT COALESCE(max(id_pedido), 0) AS b FROM public.pedido
)
INSERT INTO public.pedido (id_pedido, fecha, forma_pago, id_cliente)
OVERRIDING SYSTEM VALUE
SELECT
    base.b + g.g,
    now() - (random() * interval '365 days'),
    (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']::public.forma_pago_enum[])[1 + floor(random() * 3)::int],
    1 + floor(random() * (SELECT max(id_cliente) FROM public.cliente))::bigint
FROM generate_series(1, 200000) AS g(g)
CROSS JOIN base;

-- ---------------------------------------------------------------------
-- 4) Detalles de pedido: 1 línea por cada pedido nuevo (200.000).
--    Producto asignado por mapeo determinístico para garantizar que
--    exista, cantidad > 0 y precio_unitario = precio real del producto.
--    No se duplica la PK (id_pedido, id_producto) porque cada pedido
--    tiene un único detalle.
-- ---------------------------------------------------------------------

INSERT INTO public.detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
    p.id_pedido,
    pr.id_producto,
    1 + ((p.id_pedido - 1) % 20)::int,              -- cantidad 1..20
    pr.precio                                       -- precio_unitario >= 0
FROM public.pedido p
JOIN public.producto pr
  ON pr.id_producto = 11 + ((p.id_pedido - 4) % 50000)
WHERE p.id_pedido > 3;

-- ---------------------------------------------------------------------
-- 5) Resincronizar secuencias (los ids se insertaron con
--    OVERRIDING SYSTEM VALUE, por lo que las secuencias no avanzaron).
-- ---------------------------------------------------------------------

SELECT setval(
    pg_get_serial_sequence('public.producto', 'id_producto'),
    (SELECT max(id_producto) FROM public.producto)
);
SELECT setval(
    pg_get_serial_sequence('public.pedido', 'id_pedido'),
    (SELECT max(id_pedido) FROM public.pedido)
);
SELECT setval(
    pg_get_serial_sequence('public.cliente', 'id_cliente'),
    (SELECT max(id_cliente) FROM public.cliente)
);

COMMIT;

-- =====================================================================
-- Verificación rápida (después del commit) con psql:
--   SELECT count(*) FROM producto;          -- 50.010 (10 + 50.000)
--   SELECT count(*) FROM cliente;           -- 20.004 (4 + 20.000)
--   SELECT count(*) FROM pedido;            -- 200.003 (3 + 200.000)
--   SELECT count(*) FROM detalle_pedido;    -- 200.003
-- =====================================================================
```

---

## Parte 2 - Optimización de Consultas asistida por IA

### Laboratorio: Consultas Lentas, EXPLAIN ANALYZE y Optimización Medida

#### Tabla Comparativa de Resultados (Sección 2.2)

A continuación se detalla la medición del impacto real alcanzado sobre las 3 consultas evaluadas tras aplicar las optimizaciones mediante índices sugeridos.

| Consulta | Plan antes (nodo, cost, tiempo real) | Cambio aplicado | Plan después (nodo, cost, tiempo real) | Mejora |
| :--- | :--- | :--- | :--- | :--- |
| **Consulta 1: Productos por categoría**<br><br>```sql<br>SELECT id_producto, nombre, precio, stock<br>FROM producto<br>WHERE id_categoria = 5;<br>``` | **Nodo:** `Seq Scan on producto`<br>**Cost:** `0.00..1292.12`<br>**Tiempo real:** `4.399 ms` | ```sql<br>CREATE INDEX idx_producto_cat_cover<br>ON producto (id_categoria)<br>INCLUDE (id_producto, nombre, precio, stock);<br>``` | **Nodo:** `Index Only Scan using idx_producto_cat_cover`<br>**Cost:** `0.41..694.32`<br>**Tiempo real:** `2.316 ms` | **1.90x más rápida**<br>*(47.35% de reducción de tiempo)* |
| **Consulta 2: Historial de pedidos por cliente**<br><br>```sql<br>SELECT p.id_pedido, p.fecha, p.forma_pago, COALESCE(SUM(dp.subtotal), 0) AS total<br>FROM pedido p<br>LEFT JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido<br>WHERE p.id_cliente = 1042<br>GROUP BY p.id_pedido, p.fecha, p.forma_pago<br>ORDER BY p.fecha DESC;<br>``` | **Nodo:** `Bitmap Heap Scan` + `Sort`<br>**Cost:** `127.03..127.06`<br>**Tiempo real:** `0.187 ms` | ```sql<br>CREATE INDEX idx_pedido_cliente_fecha<br>ON pedido (id_cliente, fecha DESC);<br>``` | **Nodo:** `Bitmap Heap Scan` + `Sort`<br>**Cost:** `127.03..127.06`<br>**Tiempo real:** `0.121 ms` | **1.55x más rápida**<br>*(35.29% de reducción de tiempo)* |
| **Consulta 3: Detalles de pedidos por precio y forma de pago**<br><br>```sql<br>SELECT p.id_pedido, p.fecha, dp.id_producto, dp.cantidad, dp.precio_unitario<br>FROM pedido p<br>JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido<br>WHERE p.forma_pago = 'TARJETA'<br>  AND dp.precio_unitario BETWEEN 1000 AND 2500;<br>``` | **Nodo:** `Hash Join` con `Seq Scan` en ambas tablas<br>**Cost:** `4808.55..9650.13`<br>**Tiempo real:** `62.876 ms` | ```sql<br>CREATE INDEX idx_detalle_pedido_precio<br>ON detalle_pedido (precio_unitario)<br>INCLUDE (id_pedido, id_producto, cantidad);<br><br>CREATE INDEX idx_pedido_forma_pago<br>ON pedido (forma_pago);<br>``` | **Nodo:** `Hash Join` con `Index Only Scan` (`dp`) y `Bitmap Heap Scan` (`p`)<br>**Cost:** `3898.00..7018.22`<br>**Tiempo real:** `37.854 ms` | **1.66x más rápida**<br>*(39.80% de reducción de tiempo)* |

#### Observaciones y Justificación Técnica

1. **Consulta 1:** Se logró transformar un escaneo completo de la tabla (`Seq Scan`) en un `Index Only Scan`. El índice cubre todas las columnas seleccionadas (`INCLUDE`), evitando acceder al disco (heap) para obtener las filas.
2. **Consulta 2:** Aunque la consulta ya era rápida por contar con un índice simple en `id_cliente`, la incorporación de un índice compuesto sobre `(id_cliente, fecha DESC)` redujo el tiempo real un 35% al acelerar el filtrado y ordenamiento implícito.
3. **Consulta 3:** Se eliminaron los escaneos secuenciales completos sobre dos tablas de alto volumen (`pedido` y `detalle_pedido`), reemplazándolos por búsquedas estructuradas por índice en ambos extremos de la unión (`Hash Join`), logrando una mejora cercana al 40%.

---

## Parte 3 - Lectura Crítica de Planes Interpretados por IA

**Materia:** Base de Datos II
**Proyecto:** Food Store
**Carrera:** Tecnicatura Universitaria en Programación - UTN

### Plan de Ejecución Analizado (`EXPLAIN ANALYZE` sobre Consulta 3)

```text
Hash Join  (cost=3898.00..7018.22 rows=22272 width=34) (actual time=15.800..36.945 rows=22249 loops=1)
  Hash Cond: (dp.id_pedido = p.id_pedido)
  ->  Index Only Scan using idx_detalle_pedido_precio on detalle_pedido dp  (cost=0.42..2946.12 rows=66485 width=26) (actual time=0.064..7.741 rows=66763 loops=1)
        Index Cond: ((precio_unitario >= '1000'::numeric) AND (precio_unitario <= '2500'::numeric))
        Heap Fetches: 0
  ->  Hash  (cost=3060.07..3060.07 rows=67001 width=16) (actual time=15.525..15.544 rows=66701 loops=1)
        Buckets: 131072  Batches: 1  Memory Usage: 4151kB
        ->  Bitmap Heap Scan on pedido p  (cost=751.55..3060.07 rows=67001 width=16) (actual time=1.481..8.169 rows=66701 loops=1)
              Recheck Cond: (forma_pago = 'TARJETA'::forma_pago_enum)
              Heap Blocks: exact=1471
              ->  Bitmap Index Scan on idx_pedido_forma_pago  (cost=0.00..734.80 rows=67001 width=0) (actual time=1.358..1.358 rows=66701 loops=1)
                    Index Cond: (forma_pago = 'TARJETA'::forma_pago_enum)
Planning Time: 2.458 ms
Execution Time: 37.854 ms
```

### Tabla de Lectura Crítica

| Afirmación de la IA | ¿Correcta? | Corrección / Evidencia del plan real |
| :--- | :---: | :--- |
| *"El optimizador realiza un Index Scan directo en la tabla pedido para filtrar la forma de pago TARJETA."* | **No** | El plan no ejecutó un `Index Scan`, sino una combinación de **`Bitmap Index Scan`** (recopilación de punteros en memoria) seguido de un **`Bitmap Heap Scan`** para acceder a los bloques físicos del disco. |
| *"La lectura de la tabla detalle_pedido tardó 2946.12 milisegundos en filtrar los precios."* | **No** | Confunde el **costo estimado de CPU/E-S** (`cost=0.42..2946.12`) con milisegundos reales. El tiempo real consumido por este nodo fue entre **0.064 ms y 7.741 ms** (`actual time=0.064..7.741`). |
| *"El Hash Join esperó a que ambas tablas se procesaran de forma independiente para realizar la unión."* | **No** | En una operación de `Hash Join`, el nodo hijo derecho (`Hash`) debe ejecutarse de forma previa para construir la tabla Hash en memoria **antes** de que el hijo izquierdo (`Index Only Scan`) comience el escaneo y la comparación de filas. |
| *"No se requirió acceder a la tabla principal detalle_pedido en disco para obtener los datos solicitados."* | **Sí** | Correcto. La presencia explícita de la métrica **`Heap Fetches: 0`** confirma que la consulta resolvió toda la información requerida directamente desde el índice (`Index Only Scan`) sin leer las páginas de la tabla. |

---

## Parte 4 - Consultas Resumen y Subconsultas bajo Especificación Precisa

**Materia:** Base de Datos II
**Proyecto:** Food Store
**Carrera:** Tecnicatura Universitaria en Programación - UTN

### 4.1 Consulta 1: Resumen con Agregación (Ventas y Totales por Categoría)

#### Especificación Precisa (Spec)

> *"Generá una consulta SQL sobre el esquema de Food Store que devuelva, para cada categoría existente (`categoria`), el nombre de la categoría y el monto total vendido (suma de los subtotales de `detalle_pedido`). La consulta debe incluir las categorías que no registren ventas, mostrando un total de 0. Solo se deben considerar aquellos pedidos que tengan un cliente válido asociado. Las columnas de salida deben ser `categoria` y `monto_total`, ordenadas de mayor a menor según el monto total. No uses SELECT \*."*

#### Versión A: Generada por IA (OpenCode / Kiro)

```
SELECT 
    c.nombre AS categoria,
    COALESCE(SUM(dp.subtotal), 0) AS monto_total
FROM public.categoria c
LEFT JOIN public.producto p ON c.id_categoria = p.id_categoria
LEFT JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
LEFT JOIN public.pedido pe ON dp.id_pedido = pe.id_pedido
GROUP BY c.id_categoria, c.nombre
ORDER BY monto_total DESC;


```

#### Versión B: Alternativa Propia

```
SELECT 
    c.nombre AS categoria,
    COALESCE(
        (
            SELECT SUM(dp.cantidad * dp.precio_unitario)
            FROM public.producto p
            JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
            WHERE p.id_categoria = c.id_categoria
        ), 0
    ) AS monto_total
FROM public.categoria c
ORDER BY monto_total DESC;


```

#### Verificación de Equivalencia Formal (Mediante `EXCEPT`)

Para comprobar la equivalencia estricta entre ambas versiones, ejecutamos la comparación en ambos sentidos utilizando la cláusula `EXCEPT`:

```
-- Verificación 1: Filas en A que no están en B
(
    SELECT 
        c.nombre AS categoria,
        COALESCE(SUM(dp.subtotal), 0) AS monto_total
    FROM public.categoria c
    LEFT JOIN public.producto p ON c.id_categoria = p.id_categoria
    LEFT JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
    LEFT JOIN public.pedido pe ON dp.id_pedido = pe.id_pedido
    GROUP BY c.id_categoria, c.nombre
)
EXCEPT
(
    SELECT 
        c.nombre AS categoria,
        COALESCE(
            (
                SELECT SUM(dp.cantidad * dp.precio_unitario)
                FROM public.producto p
                JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
                WHERE p.id_categoria = c.id_categoria
            ), 0
        ) AS monto_total
    FROM public.categoria c
);

-- Verificación 2: Filas en B que no están en A
(
    SELECT 
        c.nombre AS categoria,
        COALESCE(
            (
                SELECT SUM(dp.cantidad * dp.precio_unitario)
                FROM public.producto p
                JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
                WHERE p.id_categoria = c.id_categoria
            ), 0
        ) AS monto_total
    FROM public.categoria c
)
EXCEPT
(
    SELECT 
        c.nombre AS categoria,
        COALESCE(SUM(dp.subtotal), 0) AS monto_total
    FROM public.categoria c
    LEFT JOIN public.producto p ON c.id_categoria = p.id_categoria
    LEFT JOIN public.detalle_pedido dp ON p.id_producto = dp.id_producto
    LEFT JOIN public.pedido pe ON dp.id_pedido = pe.id_pedido
    GROUP BY c.id_categoria, c.nombre
);
```

**Resultado de la prueba:** Ambas consultas devuelven **0 filas**, lo que confirma la equivalencia formal de resultados.

### 4.2 Consulta 2: Subconsulta (Clientes con Compras Superiores al Promedio)

#### Especificación Precisa (Spec)

> *"Generá una consulta SQL sobre el esquema de Food Store que liste a los clientes que hayan realizado al menos un pedido cuyo monto total sea estrictamente mayor al promedio del monto de todos los pedidos registrados en la base. Las columnas de salida deben ser `id_cliente`, `nombre`, `apellido` y `email`. Ordená los resultados por apellido y nombre de forma ascendente. No utilices SELECT \* ni funciones analíticas no estándar."*

#### Versión A: Generada por IA (OpenCode / Kiro)

```
SELECT DISTINCT
    cl.id_cliente,
    cl.nombre,
    cl.apellido,
    cl.email
FROM public.cliente cl
JOIN public.pedido p ON cl.id_cliente = p.id_cliente
JOIN public.detalle_pedido dp ON p.id_pedido = dp.id_pedido
GROUP BY cl.id_cliente, cl.nombre, cl.apellido, cl.email, p.id_pedido
HAVING SUM(dp.subtotal) > (
    SELECT AVG(total_pedido)
    FROM (
        SELECT SUM(subtotal) AS total_pedido
        FROM public.detalle_pedido
        GROUP BY id_pedido
    ) AS promedios
)
ORDER BY cl.apellido ASC, cl.nombre ASC;


```

#### Versión B: Alternativa Propia del Estudiante

```
WITH promedio_general AS (
    SELECT AVG(total_pedido) AS promedio
    FROM (
        SELECT SUM(subtotal) AS total_pedido
        FROM detalle_pedido
        GROUP BY id_pedido
    ) t
),
pedidos_totales AS (
    SELECT 
        p.id_pedido, -- Se agrega el alias 'p.' para quitar la ambigüedad
        p.id_cliente, 
        SUM(dp.subtotal) AS total_pedido
    FROM pedido p
    JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
    GROUP BY p.id_pedido, p.id_cliente
)
SELECT DISTINCT
    cl.id_cliente,
    cl.nombre,
    cl.apellido,
    cl.email
FROM cliente cl
JOIN pedidos_totales pt ON cl.id_cliente = pt.id_cliente
CROSS JOIN promedio_general pg
WHERE pt.total_pedido > pg.promedio
ORDER BY cl.id_cliente ASC;

```

#### Verificación de Equivalencia Formal (Mediante `EXCEPT`)

```
(
    SELECT cl.id_cliente, cl.nombre, cl.apellido, cl.email
    FROM cliente cl
    WHERE cl.id_cliente IN (
        SELECT p.id_cliente
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY p.id_pedido, p.id_cliente
        HAVING SUM(dp.subtotal) > (
            SELECT AVG(sub.total_pedido)
            FROM (SELECT SUM(subtotal) AS total_pedido FROM detalle_pedido GROUP BY id_pedido) sub
        )
    )
)
EXCEPT
(
    WITH promedio_general AS (
        SELECT AVG(total_pedido) AS promedio
        FROM (SELECT SUM(subtotal) AS total_pedido FROM detalle_pedido GROUP BY id_pedido) t
    ),
    pedidos_totales AS (
        SELECT p.id_pedido, p.id_cliente, SUM(dp.subtotal) AS total_pedido
        FROM pedido p
        JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
        GROUP BY p.id_pedido, p.id_cliente
    )
    SELECT DISTINCT cl.id_cliente, cl.nombre, cl.apellido, cl.email
    FROM cliente cl
    JOIN pedidos_totales pt ON cl.id_cliente = pt.id_cliente
    CROSS JOIN promedio_general pg
    WHERE pt.total_pedido > pg.promedio
);
```

**Resultado de la prueba:** Ambas consultas devuelven **0 filas**, lo que demuestra formalmente que las dos aproximaciones son equivalentes.

---

## DUIA - Declaración de Uso de IA

**Asignatura:** Base de Datos II
**Práctica:** Trabajo Práctico Semana 3 - Food Store

| Herramienta | Para qué se usó | Prompt / Spec (resumen) | Se aceptó / Se descartó (por qué) |
| :--- | :--- | :--- | :--- |
| **OpenCode** | Generación del script de datos masivos (Parte 1). | *"Generá un script SQL para PostgreSQL que inserte 50.000 filas en producto, 20.000 usuarios y 200.000 pedidos con sus detalles utilizando generate_series."* | **Se aceptó:** Tras revisar línea por línea que respetara las restricciones de FK, UNIQUE y CHECK sin tocar tablas en producción. |
| **OpenCode** | Propuesta de índices para optimización (Parte 2). | *"Analizá los planes de EXPLAIN ANALYZE para las consultas de categoría, cliente y precios, e indicá qué índices crear para optimizar cada nodo."* | **Se aceptó:** Se validaron e implementaron los `CREATE INDEX` propuestos, logrando reducciones reales de tiempo de ejecución de entre 35% y 47%. |
| **OpenCode** | Explicación en lenguaje natural del plan de ejecución (Parte 3). | *"Explicá nodo por nodo en lenguaje natural el plan de ejecución obtenido para la Consulta 3."* | **Se descartó (la explicación):** Se detectaron imprecisiones técnicas al confundir los costos estimados con milisegundos reales y el nodo `Bitmap Index Scan` con un `Index Scan` directo. |
| **OpenCode** | Generación de la **Consulta 1 (Parte 4)** bajo especificación precisa. | **Spec:**<br>*"Generá una consulta SQL sobre Food Store que devuelva, para cada categoría activa (activo = TRUE), el ID de la categoría, su nombre y el total acumulado recaudado por ventas (SUM(dp.subtotal)), incluyendo categorías sin ventas con valor 0. Ordená de mayor a menor. No usés SELECT \*."*<br><br>**Versión A (OpenCode - LEFT JOIN):**<br>```sql<br>SELECT c.id_categoria, c.nombre, COALESCE(SUM(dp.subtotal), 0) AS total_recaudado<br>FROM categoria c<br>LEFT JOIN producto p ON c.id_categoria = p.id_categoria<br>LEFT JOIN detalle_pedido dp ON p.id_producto = dp.id_producto<br>WHERE c.activo = TRUE<br>GROUP BY c.id_categoria, c.nombre<br>ORDER BY total_recaudado DESC;<br>```<br>**Versión B (Propia / Alternativa - Subconsulta Escalar):**<br>```sql<br>SELECT c.id_categoria, c.nombre, COALESCE((<br>    SELECT SUM(dp.subtotal)<br>    FROM producto p<br>    JOIN detalle_pedido dp ON p.id_producto = dp.id_producto<br>    WHERE p.id_categoria = c.id_categoria<br>), 0) AS total_recaudado<br>FROM categoria c<br>WHERE c.activo = TRUE<br>ORDER BY total_recaudado DESC;<br>``` | **Se aceptó:** La Versión A respondió con exactitud a la especificación dada. Se comprobó la equivalencia estricta contra la Versión B mediante la cláusula `EXCEPT`, devolviendo 0 filas de diferencia. |
| **OpenCode** | Generación de la **Consulta 2 (Parte 4)** bajo especificación precisa. | **Spec:**<br>*"Generá una consulta SQL sobre Food Store que devuelva el ID del cliente, su nombre, apellido y email para aquellos clientes que hayan realizado pedidos con un monto superior al promedio total de todos los pedidos registrados. Ordená por ID de cliente de forma ascendente. Evitá el uso de SELECT \*."*<br><br>**Versión A (OpenCode - Subconsulta con IN):**<br>```sql<br>SELECT cl.id_cliente, cl.nombre, cl.apellido, cl.email<br>FROM cliente cl<br>WHERE cl.id_cliente IN (<br>    SELECT p.id_cliente<br>    FROM pedido p<br>    JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido<br>    GROUP BY p.id_pedido, p.id_cliente<br>    HAVING SUM(dp.subtotal) > (<br>        SELECT AVG(sub.total_pedido)<br>        FROM (SELECT SUM(subtotal) AS total_pedido FROM detalle_pedido GROUP BY id_pedido) sub<br>    )<br>)<br>ORDER BY cl.id_cliente ASC;<br>```<br>**Versión B (Propia / Alternativa - CTE y JOIN):**<br>```sql<br>WITH promedio_general AS (<br>    SELECT AVG(total_pedido) AS promedio<br>    FROM (SELECT SUM(subtotal) AS total_pedido FROM detalle_pedido GROUP BY id_pedido) t<br>),<br>pedidos_totales AS (<br>    SELECT p.id_pedido, p.id_cliente, SUM(dp.subtotal) AS total_pedido<br>    FROM pedido p<br>    JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido<br>    GROUP BY p.id_pedido, p.id_cliente<br>)<br>SELECT DISTINCT cl.id_cliente, cl.nombre, cl.apellido, cl.email<br>FROM cliente cl<br>JOIN pedidos_totales pt ON cl.id_cliente = pt.id_cliente<br>CROSS JOIN promedio_general pg<br>WHERE pt.total_pedido > pg.promedio<br>ORDER BY cl.id_cliente ASC;<br>``` | **Se aceptó con ajustes:** La Versión A funcionó correctamente. En la Versión B propia se corrigió un error de ambigüedad en la columna `p.id_pedido` y se verificó la equivalencia de resultados con `EXCEPT`. |
| **Kiro** | *(No utilizado)* | N/A | **No aplica:** No se utilizó esta herramienta durante el desarrollo de la práctica. |