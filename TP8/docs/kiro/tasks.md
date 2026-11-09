# TP8 Food Store — Tasks

Tareas de la especificación del módulo offline revisada en Kiro. Los estados reflejan únicamente acciones realizadas; los controles documentales pendientes se distinguen de las pruebas técnicas completadas.

## Bloque 1 — Esquema SQLite

- [x] **T1.1** Diseñar las cuatro tablas `STRICT` (`producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`) con `PRIMARY KEY`, `FOREIGN KEY`, `CHECK` y el índice parcial `UNIQUE`.
- [x] **T1.2** Crear `public.v_snapshot_movil` en PostgreSQL, convirtiendo precios a centavos y calculando disponibilidad y baja lógica.
- [x] **T1.3** Exportar el catálogo CSV de 50.010 productos.
- [x] **T1.4** Importar `snapshot_servidor` y poblar `producto_cache` en SQLite.
- [x] **T1.5** Verificar `PRAGMA integrity_check = ok` y `foreign_key_check` sin errores.

## Bloque 2 — Transacciones

- [x] **T2.1** Implementar `BEGIN` y `COMMIT` para guardar borrador, ítems y solicitud; usar `ROLLBACK` ante error.
- [x] **T2.2** Probar COMMIT en copia con Python `sqlite3`: conteos (1,1,1).
- [x] **T2.3** Probar ROLLBACK en copia con Python `sqlite3`: conteos (0,0,0).
- [x] **T2.4** Comprobar C7: CHECK por cantidad 0 (275).
- [x] **T2.5** Comprobar C7: FOREIGN KEY por producto inexistente (787).

## Bloque 3 — Semáforo

- [x] **T3.1** Implementar el semáforo para solicitudes `PENDIENTE`, sin escribir en PostgreSQL.
- [x] **T3.2** Verificar C2: cambio de precio → `CONFLICTO` y reintento corregido.
- [x] **T3.3** Verificar C3: stock insuficiente → `RECHAZADO`.
- [x] **T3.4** Verificar C4: baja lógica → `RECHAZADO`, conservando el producto en caché.
- [x] **T3.5** Verificar C5: sin cambios → `SIMULADO_APROBADO`.
- [x] **T3.6** Verificar C6: UUID duplicado → error 1555, preservando la solicitud original.

## Bloque 4 — Kiro y OpenCode Build (consigna 4.a)

- [x] **T4.1** Utilizar Kiro para revisar requirements.md, design.md y tasks.md; utilizar OpenCode Build para generar una versión alternativa del esquema SQLite y contrastarla con `schema_sqlite.sql`. Se conservó el esquema original compatible con la base entregada.
- [x] **T4.2** Utilizar OpenCode Build para generar/revisar las pruebas de transacciones y contrastarlas con `pruebas_sqlite.sql` y C1–C7 en bases temporales.
- [x] **T4.3** Utilizar OpenCode Build para generar/revisar el semáforo, preservar el índice `ux_cola_una_pendiente`, corregir el tratamiento de NULL y verificar en copias los casos normales y N1–N7.
- [x] **T4.4** Contrastar los resultados del TP8 con SQLite y con las consultas ya ejecutadas en PostgreSQL, registradas en el informe (precio, stock, baja lógica y conteo de pedidos). OpenCode Build no volvió a conectarse a PostgreSQL durante la revisión final.
- [x] **T4.5** Documentar las interacciones realmente realizadas y las decisiones en `docs/bitacora_ia.md` y preparar `docs/DUIA.md`.

**Antes de presentar:** completar datos institucionales, firma y formulario oficial de DUIA si la cátedra lo entrega. El ensayo de defensa de 10 minutos se realiza en clase.
