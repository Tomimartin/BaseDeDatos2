# Bitácora de uso de IA - TP8 Food Store

> Se documentan interacciones efectivamente ocurridas. OpenCode Plan se utilizó para la revisión 3.c; Kiro y OpenCode Build todavía no se ejecutaron en este TP.

| Solicitud hecha a ChatGPT | Qué se aceptó | Qué se corrigió/descartó y por qué | Validación humana |
|---|---|---|---|
| Diseñar la base SQLite de la tablet de Food Store (4 tablas STRICT y catálogo). | Esquema con CHECK, FK, precios en centavos y borradores. | Se separó PostgreSQL de SQLite: la tablet no puede confirmar ventas. | Creación real en DB Browser; consulta `v_catalogo_disponible` con 10 productos; importación de 50.010 productos. |
| Implementar la comparación de borradores con el servidor y los casos C2-C5. | Semáforo de tres resultados con prioridad RECHAZADO > CONFLICTO > SIMULADO_APROBADO. | Se evitó reevaluar estados terminales; el reintento tras cambio de precio usa otro UUID. | C2 mostró precio $2.500/$2.800 y luego CONFLICTO + SIMULADO_APROBADO; C3 y C4 terminaron RECHAZADO. |
| Probar restricciones C6-C7 y determinar por qué no se veían errores en DB Browser. | Revisión en SQL Log > Error Log y controles de COUNT. | Se descartó la idea de que un `SELECT` vacío, por sí solo, demostraba el CHECK o la FK. | Capturas con códigos SQLite 1555 (PK), 275 (CHECK), 787 (FK); 5 ítems conservados. |
| Probar BEGIN/COMMIT/ROLLBACK cuando DB Browser administraba SAVEPOINT internos. | Uso de Python sqlite3 sobre copia del archivo; no modificar la base original. | Se descartó insistir con BEGIN dentro de la transacción interna de DB Browser. | Captura PowerShell: COMMIT (1,1,1), ROLLBACK (0,0,0), `foreign_keys=1`. |
| Revisar antecedentes de MongoDB, mantenimiento y SQL en GitHub para el TP8. | Se tomaron los scripts de U5-U7 como antecedentes, no se copiaron TPs anteriores en esta entrega. | Se separó análisis asistido por ChatGPT de la revisión obligatoria con OpenCode Plan. | Inspección de archivos de repositorio; ver propuestas sujetas a validación en informe. |


## OpenCode Plan - Revisión de scripts (consigna 3.c)

**Solicitud del estudiante:** revisar los scripts de TP2, TP3, TP4, TP5, U6, U7 y TP8, en modo Plan, sin modificar ni ejecutar consultas. Se pidió identificar hallazgos, proponer controles, tomar decisiones y justificar al menos un descarte. El usuario copió en la conversación la respuesta de OpenCode. **La comprobación fue realizada después por el estudiante**, no por OpenCode.

| Hallazgo de OpenCode | Comprobación del estudiante | Decisión y motivo |
|---|---|---|
| U8: `snapshot_servidor.producto_id` carece de `UNIQUE` y una importación posterior podría duplicar productos. | En SQLite, `PRAGMA index_list('snapshot_servidor')` no reportó índices. `COUNT(*)=50010`, `COUNT(DISTINCT producto_id)=50010`; la consulta `GROUP BY... HAVING COUNT(*)>1` devolvió cero filas. | **Aceptado como mejora preventiva.** No hay duplicados actuales; se propone exigir unicidad antes de futuras importaciones. No se ejecutó ALTER/CREATE INDEX sobre la base original. |
| U2: `TP2_unidad2/data.sql` no coincide con `base_food_store.sql` al cargar pedido/detalle. | En PostgreSQL `information_schema.columns`: `detalle_pedido.subtotal` `is_generated=ALWAYS`; `detalle_pedido.precio_unitario` `is_nullable=NO` sin default; `pedido.forma_pago` `is_nullable=NO` sin default. | **Aceptado.** El script descrito por OpenCode es incompatible con estas columnas. No se ejecutaron inserciones inválidas, la verificación fue de esquema. |
| U3: el comentario de `indices.sql` supone que `idx_producto_precio_desc` siempre elimina `Sort`. | `EXPLAIN (ANALYZE, BUFFERS)` de `WHERE precio>4970 ORDER BY precio DESC` mostró `Bitmap Index Scan on idx_producto_precio_desc` y `Sort Key: precio DESC`, con 329 filas y `Execution Time: 0.844 ms`. | **Descartado:** no se acepta afirmar que el índice elimina `Sort` en esta consulta. Sí se conserva el índice, porque puede ayudar en el filtro de precio. |

**Alcance y pendientes:** Son tres hallazgos verificados de tres unidades distintas. No se cambió el código de los TPs anteriores ni se realizaron escrituras como parte de esta revisión. Las capturas/salidas originales las conserva el estudiante; el informe documenta los resultados observados.

## Actividades de IA pendientes y su registro

- Abrir requirements.md, design.md y tasks.md en **Kiro** y registrar la interacción real.
- Ejecutar **OpenCode** sobre tareas del TP8 y guardar comandos/salidas reales.
- **Realizado:** revisión de scripts con **OpenCode agente Plan**; tres hallazgos seleccionados y contrastados con SQLite/PostgreSQL, con un descarte fundamentado.
- Adjuntar la **DUIA oficial** según formato de cátedra, si existe una plantilla o formulario específico.
