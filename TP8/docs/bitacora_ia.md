# Bitácora de uso de IA - TP8 Food Store

> Se documentan interacciones efectivamente ocurridas. OpenCode Plan se utilizó para la revisión 3.c; Kiro se utilizó para revisar la especificación 4.a y OpenCode Build para generar, comparar y verificar scripts; sus intervenciones se registran abajo.

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

## Kiro — especificación de la consigna 4.a

**Interacción informada por el estudiante (09/11/2026):** se pidió a Kiro revisar `docs/kiro/requirements.md`, `design.md` y `tasks.md` para comprobar los cuatro requisitos EARS, los casos C1–C7 y las tareas de construcción sin alterar las bases ni los SQL originales. Kiro devolvió un diagnóstico: cuatro requisitos EARS correctos pero poco contextualizados; diseño en texto plano sin detalle de las cuatro tablas y restricciones; tareas de OpenCode Build poco específicas.

**Decisión humana:** se aceptaron mejoras documentales en los tres archivos. Se conservaron cuatro requisitos vinculados a los casos, se estructuró el diseño y se detallaron las tareas. Se indicó explícitamente no inventar pruebas ejecutadas ni marcar como terminadas tareas que aún no se habían realizado. Más tarde, OpenCode Build señaló discrepancias de nombres entre el diseño propuesto y el esquema real: se corrigió `design.md` para reflejar `id_local`, `precio_centavos_visto`, `creada_en`, `usuario_id_servidor`, `forma_pago`, `v_catalogo_disponible` y `ux_cola_una_pendiente`.

**Alcance:** las respuestas de Kiro fueron compartidas por el estudiante en la conversación; la verificación posterior de las implementaciones se atribuye a OpenCode Build y a las pruebas en SQLite, no a Kiro.

## OpenCode Build — generación y verificación de la consigna 4.a

**Fecha:** 09/11/2026. Se pidió a OpenCode Build generar en una carpeta temporal, a partir de los archivos de Kiro, versiones de `schema_sqlite.sql`, `pruebas_sqlite.sql` y `semaforo.sql`; compararlas con los scripts del TP8 y no modificar la base original. Se usó `C:\Users\ignac\AppData\Local\Temp\opencode\tp8_4a_generated`, y se documentaron diferencias en `comparacion.md`.

| Recomendación o resultado | Decisión y fundamento | Prueba documentada |
|---|---|---|
| Generar un esquema con columnas `borrador_id`, `precio_unitario_centavos` y `evaluado_en`. | **Descartado para la entrega:** implicaría migrar `foodstore_movil.db` y romper la compatibilidad con los SQL originales. | Comparación de nombres con las tablas y restricciones existentes. |
| Eliminar el índice `ux_cola_una_pendiente`. | **Descartado:** la PK evita repetir el UUID (1555), mientras el índice parcial evita dos solicitudes pendientes para un mismo borrador (2067); protegen reglas distintas. | Reproducción de ambos errores en SQLite `:memory:`. |
| Corregir el manejo de `NULL` en `semaforo.sql`. | **Aceptado:** un stock, precio, indicador de disponibilidad o baja desconocido no debe terminar en `SIMULADO_APROBADO`. Se aplicó un parche mínimo sin alterar el esquema. | N1 stock NULL → RECHAZADO; N2 precio NULL → CONFLICTO; N3 disponibilidad NULL y N4 baja NULL → RECHAZADO. N5–N7 mantuvieron sus resultados. |
| Mantener el esquema original y revisar en copia. | **Aceptado:** preservar las tablas `STRICT`, PK, FK, CHECK y columna de fecha `creada_en`. No se agregó `evaluado_en`. | C2 CONFLICTO; C3/C4 RECHAZADO; C5 SIMULADO_APROBADO; C6 1555; C7 275/787, todo en pruebas temporales. |

**Verificación de integridad informada por OpenCode Build:** `integrity_check=ok`, `foreign_key_check` vacío, 0 solicitudes pendientes luego de la evaluación. La base original no cambió: SHA-256 antes y después `43ca12c19644f707ed30c86092736d5b598f178c89b35dd043b7d759377f90f1`. Los ensayos se realizaron con bases temporales y Python `sqlite3`, sin modificar PostgreSQL ni el archivo SQLite original.

**Contraste con PostgreSQL:** durante el TP8, por separado, se verificaron los cambios deliberados de precio, stock y baja lógica y que ambas bases de PostgreSQL tenían 200.004 pedidos. OpenCode Build no ejecutó nuevamente consultas PostgreSQL en esta revisión final.

## Declaración y cierre

`docs/DUIA.md` describe las herramientas utilizadas y decisiones aceptadas/descartadas. **Pendiente personal del equipo:** completar responsables/legajo, fecha y firma, y usar el formulario DUIA oficial si la cátedra lo exige. El ensayo individual de 10 minutos se realiza en clase.
