## Criterio de Seguridad Aplicado en Vistas
En la vista vista_ventas_usuario_mes, se aplicó el principio de seguridad de Mínimo Privilegio y Ocultamiento de Información Sensible:

## Justificación: La tabla base cliente almacena información confidencial y sensible (como credenciales de acceso, contraseñas hash, teléfonos o direcciones).

## Implementación: La vista únicamente selecciona e identifica al usuario mediante id_cliente y proyecta la concatenación de su nombre completo (c.nombre || ' ' || c.apellido), excluyendo deliberadamente cualquier columna con información sensible o contraseñas.

Control de Acceso (DBA): Esto permite conceder permisos de lectura (GRANT SELECT) únicamente sobre la vista vista_ventas_usuario_mes a roles comerciales, de analítica o reporte:

``` SQL

GRANT SELECT ON vista_ventas_usuario_mes TO rol_reportes;

De esta forma, se otorga acceso a los datos de facturación e historial de compras sin brindar acceso directo a la tabla base cliente, protegiendo la base de datos contra filtraciones de credenciales.

# Declaración de Uso de IA (DUIA) y Bitácora de Interacciones

Este documento registra de forma cronológica y detallada el proceso de trabajo asistido por Inteligencia Artificial (Kiro y OpenCode) para el desarrollo del proyecto de optimización en PostgreSQL, detallando el propósito de cada consulta, las propuestas generadas, los ajustes aplicados y los criterios de aceptación o descarte técnico.

---

## 1. Bitácora de Interacciones por Componente

### Interacción 1: Búsqueda de Pedidos por Rango de Fechas (Parte A)
- **Herramienta:** Kiro (Especificación) / OpenCode (Generación)
- **Propósito:** Especificar la necesidad de negocio para optimizar la consulta de pedidos por fecha y generar el índice B-Tree óptimo.
- **Prompt / Spec utilizado (`specs/spec_pedidos_fecha.md`):**
  > "Especificar requerimiento para acelerar búsquedas de pedidos en el rango de fechas '2024-05-01' y '2024-05-31'. Criterio de aceptación: Evitar el Seq Scan completo sobre la tabla pedido."
- **Propuesta de la IA:**
  Creación del índice `CREATE INDEX idx_pedido_fecha ON pedido(fecha);`.
- **Decisión Técnica:**
  - **Aceptado:** Se creó el índice tal cual lo sugirió la IA.
  - **Justificación / Resultado:** En `EXPLAIN ANALYZE`, la consulta redujo su tiempo de ejecución de `36.468 ms` (Seq Scan) a `0.021 ms` (Index Scan).

---

### Interacción 2: Filtrado y Ordenamiento de Productos por Precio (Parte A)
- **Herramienta:** OpenCode (Generación y Revisión)
- **Propósito:** Optimizar la consulta de productos con precio superior a 4970 ordenados de forma descendente.
- **Prompt enviado:**
  > "Analizá la consulta SELECT id_producto, nombre, precio FROM producto WHERE precio > 4970 ORDER BY precio DESC; y proponé el índice adecuado para evitar el Quicksort en memoria."
- **Propuesta de la IA:**
  Creación del índice `CREATE INDEX idx_producto_precio_desc ON producto(precio DESC);`.
- **Decisión Técnica:**
  - **Aceptado:** Se implementó el índice en orden descendente.
  - **Justificación / Resultado:** Se eliminó la etapa de ordenamiento explícito en RAM (`Quicksort 42kB`), pasando de `3.898 ms` a `0.346 ms` mediante un `Bitmap Index Scan`.

---

### Interacción 3: Historial de Detalle de Producto por Cantidad (Parte A)
- **Herramienta:** Kiro (Especificación) / OpenCode (Generación)
- **Propósito:** Optimizar el filtrado por producto y ordenamiento por cantidad vendida en la tabla `detalle_pedido`.
- **Prompt / Spec utilizado (`specs/spec_detalle_producto.md`):**
  > "Necesitamos consultar detalle_pedido filtrando por id_producto = 150 y ordenando por cantidad DESC. Generar índice que cubra filtro y orden."
- **Propuesta de la IA:**
  Creación del índice compuesto `CREATE INDEX idx_detalle_pedido_producto_cant ON detalle_pedido(id_producto, cantidad DESC);`.
- **Decisión Técnica:**
  - **Aceptado:** Se implementó el índice compuesto.
  - **Justificación / Resultado:** Se logró la mayor aceleración del proyecto (**588x**), bajando de `35.268 ms` (Parallel Seq Scan + Sort) a `0.060 ms` (Index Scan), evitando el escaneo paralelo en disco.

---

### Interacción 4: Caso de Sobreindexación y Descarte Técnico (Parte A - Registro Obligatorio)
- **Herramienta:** OpenCode (Revisión y Análisis)
- **Propósito:** Analizar la sugerencia automática de un índice sobre la columna booleana de estado de productos.
- **Prompt enviado:**
  > "La IA sugiere ejecutar: CREATE INDEX idx_producto_activo ON producto(activo); para filtrar productos activos. ¿Es conveniente aplicarlo?"
- **Propuesta de la IA:**
  Sugerencia de indexación sobre la columna booleana `activo`.
- **Decisión Técnica:**
  - **DESCARTADO:** Se rechazó la creación de este índice.
  - **Justificación Técnica:** La columna `activo` posee una **baja cardinalidad** (solo dos valores posibles: `TRUE`/`FALSE`). Un índice B-Tree sobre una columna de tan baja selectividad es ineficiente, ya que el optimizador de PostgreSQL elegirá un `Seq Scan` al tener que leer un porcentaje muy alto de la tabla. Además, crearlo generaría una penalización innecesaria en operaciones de escritura (`INSERT`/`UPDATE`) sin aportar beneficio en lecturas.

---

### Interacción 5: Evaluación del Costo de Mantenimiento en Escrituras (Parte A)
- **Herramienta:** OpenCode (Generación de Script de Prueba)
- **Propósito:** Medir la degradación del rendimiento en escrituras masivas provocada por la existencia de índices activos.
- **Prompt enviado:**
  > "Generá un script con generate_series() para insertar 1.000 filas de prueba dentro de una transacción con ROLLBACK, midiendo tiempos con y sin índices."
- **Propuesta de la IA:**
  Script de inserción masiva sobre la tabla `pedido`.
- **Modificación Humana:**
  Se modificó el destino de la inserción a la tabla `categoria` debido a restricciones de clave foránea (`FK`) y campos obligatorios (`NOT NULL`) que bloqueaban el test masivo sintético.
- **Resultado Obtenido:**
  - Inserción SIN índices: `3.337 ms`.
  - Inserción CON índices activos: `9.501 ms`.
  - **Conclusión:** Penalización del **~184%** en tiempo de escritura.

---

### Interacción 6: Vistas del Sistema y Verificación de Equivalencia (Parte B - Registro Obligatorio)
- **Herramienta:** Kiro (Especificación) / OpenCode (Generación)
- **Propósito:** Generar la vista de resumen mensual de ventas por cliente e implementar controles de seguridad.
- **Prompt / Spec utilizado (`specs/spec_vista_ventas_usuario_mes.md`):**
  > "Generar una vista que agrupe ventas por cliente y mes. Aplicar el criterio de seguridad de la teoría ocultando columnas sensibles como contraseñas o hashes."
- **Propuesta de la IA:**
  Código SQL con `JOIN` entre las tablas `usuario`, `pedido` y `detalle_pedido`.
- **Modificación Humana:**
  - **Ajuste de Esquema:** La IA utilizó el nombre de tabla `usuario`. Se modificó manualmente a `cliente` y `c.id_cliente` para adecuarlo al esquema real del entorno.
  - **Aceptado (Seguridad):** Se proyectó únicamente `id_cliente` y `c.nombre || ' ' || c.apellido AS nombre_usuario`, omitiendo credenciales para habilitar un `GRANT SELECT` seguro.
- **Verificación de Equivalencia de Resultados:**
  Se ejecutó la consulta sobre la vista y la consulta SQL directa equivalente:
  ```sql
  -- Consulta Vista:
  SELECT * FROM vista_ventas_usuario_mes LIMIT 5;
  -- Consulta Directa Equivalente:
  SELECT c.id_cliente AS id_usuario, c.nombre || ' ' || c.apellido AS nombre_usuario,
         DATE_TRUNC('month', p.fecha) AS mes_anio, COUNT(DISTINCT p.id_pedido) AS total_pedidos,
         SUM(dp.subtotal) AS total_gastado
  FROM cliente c JOIN pedido p ON c.id_cliente = p.id_cliente
  JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
  GROUP BY c.id_cliente, c.nombre, c.apellido, DATE_TRUNC('month', p.fecha)
  ORDER BY mes_anio DESC, total_gastado DESC LIMIT 5;

Resultado: Coincidencia exacta en filas, ordenamiento y montos calculados.

Interacción 7: Vista Materializada para Reporte Analítico (Parte C)
Herramienta: OpenCode (Generación y Revisión)

Propósito: Crear una vista materializada de facturación por categoría y mes, permitiendo refresco no bloqueante.

Prompt enviado:

"Generá la sentencia CREATE MATERIALIZED VIEW para la facturación mensual por categoría, con datos iniciales (WITH DATA) y un UNIQUE INDEX que habilite el comando REFRESH MATERIALIZED VIEW CONCURRENTLY."

Propuesta de la IA:
```sql 
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS ... WITH DATA;
CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes_pk ON mv_facturacion_categoria_mes (id_categoria, mes_anio);

Decisión Técnica:

Aceptado: Se ejecutó el DDL completo y su índice único.

Justificación / Resultado: La consulta directa tomaba 537.597 ms (con external merge en disco de 11 MB). La vista materializada respondió en 0.057 ms (~9400x más rápida).

2. Síntesis de Decisiones y Criterio Humano
El uso de Inteligencia Artificial como asistente de desarrollo (Kiro para especificación y OpenCode para codificación) permitió acelerar la creación de scripts SQL y la documentación técnica. Sin embargo, el criterio humano y la supervisión del estudiante resultaron indispensables para:

Evitar la sobreindexación: Filtrando sugerencias de bajo valor como índices en columnas booleanas (activo).

Adaptar el código al entorno real: Corregir inconsistencias de nombres de tablas entre los modelos teóricos propuestos por la IA y la base de datos real (usuario vs. cliente).

Validar la precisión de los datos: Comprobar línea por línea mediante comparaciones de datasets que las vistas no introdujeran sesgos o diferencias frente a las consultas directas.
