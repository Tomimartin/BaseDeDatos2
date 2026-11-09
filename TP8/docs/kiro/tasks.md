# TP8 Food Store — Tasks

Tareas del módulo móvil offline de Food Store para su registro en Kiro. Las tareas completadas reflejan el trabajo ejecutado; las pendientes corresponden al uso de OpenCode Build según la consigna 4.a.

---

## Bloque 1 — Esquema SQLite (completado)

- [x] **T1.1** Diseñar las cuatro tablas STRICT de SQLite (`producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`) con sus restricciones `PRIMARY KEY`, `FOREIGN KEY`, `CHECK` y `UNIQUE`.
- [x] **T1.2** Crear la vista `public.v_snapshot_movil` en PostgreSQL con conversión de precios a centavos y cálculo de `disponible`/`eliminado` desde `producto.activo` y `categoria.activo`.
- [x] **T1.3** Exportar el catálogo desde PostgreSQL a `movil/servidor_snapshot.csv` (50.010 productos, UTF-8, con encabezados).
- [x] **T1.4** Importar el CSV en DB Browser como tabla `snapshot_servidor` y poblar `producto_cache` mediante `INSERT ... SELECT` con casteos explícitos de tipo.
- [x] **T1.5** Verificar integridad del esquema: `PRAGMA integrity_check = ok` y `PRAGMA foreign_key_check` sin errores sobre `movil/foodstore_movil.db`.

---

## Bloque 2 — Transacciones (completado)

- [x] **T2.1** Implementar el guardado atómico de borrador: `BEGIN` → insertar en `pedido_borrador` → insertar en `item_borrador` → insertar en `cola_sync` → `COMMIT`. Ante cualquier error, ejecutar `ROLLBACK`.
- [x] **T2.2** Probar `COMMIT` exitoso con Python `sqlite3` sobre copia aislada: verificar que las tres tablas contienen `(1, 1, 1)` filas tras el commit.
- [x] **T2.3** Probar `ROLLBACK` con Python `sqlite3`: verificar que las tres tablas contienen `(0, 0, 0)` filas tras el rollback.
- [x] **T2.4** Probar restricción `CHECK (cantidad > 0)` en `item_borrador`: verificar error SQLite 275 al intentar `cantidad = 0` (caso C7).
- [x] **T2.5** Probar restricción `FOREIGN KEY` en `item_borrador`: verificar error SQLite 787 al referenciar un `producto_id` inexistente en `producto_cache` (caso C7).

---

## Bloque 3 — Semáforo (completado)

- [x] **T3.1** Implementar `movil/semaforo.sql`: evaluar todas las solicitudes en estado `PENDIENTE` cruzando `cola_sync` + `item_borrador` + `snapshot_servidor`.
- [x] **T3.2** Probar C2 (CONFLICTO): modificar precio del producto 1 en PostgreSQL, actualizar `snapshot_servidor` y verificar que la solicitud pasa a `CONFLICTO`.
- [x] **T3.3** Probar C3 (RECHAZADO por stock): reducir stock de producto 2 a 4 y solicitar 10 unidades; verificar `RECHAZADO` con motivo de stock insuficiente.
- [x] **T3.4** Probar C4 (RECHAZADO por baja lógica): dar de baja el producto 3 en PostgreSQL; verificar `RECHAZADO` y que el producto permanece en `producto_cache` con `eliminado = 1`.
- [x] **T3.5** Probar C5 (SIMULADO_APROBADO): enviar borrador sin cambios respecto al snapshot; verificar aprobación simulada.
- [x] **T3.6** Probar C6 (idempotencia por UUID): reintentar inserción con el mismo `solicitud_uuid`; verificar error 1555 y que `cola_sync` conserva una sola fila con el estado original.

---

## Bloque 4 — Uso de OpenCode Build (pendiente — consigna 4.a)

- [ ] **T4.1** Usar **OpenCode Build** para revisar `movil/schema_sqlite.sql`: verificar que todas las tablas tienen `STRICT`, que las restricciones `CHECK` y `FOREIGN KEY` están presentes y que los tipos de columna son correctos. Registrar la salida en `docs/bitacora_ia.md`.
- [ ] **T4.2** Usar **OpenCode Build** para revisar `movil/pruebas_sqlite.sql`: confirmar que los bloques `BEGIN/COMMIT` y `BEGIN/ROLLBACK` cubren los tres escenarios (commit exitoso, rollback por CHECK, rollback por FK). Registrar hallazgos en `docs/bitacora_ia.md`.
- [ ] **T4.3** Usar **OpenCode Build** para revisar `movil/semaforo.sql`: verificar que el `UPDATE` de `cola_sync` solo afecta filas con `estado = 'PENDIENTE'`, que los tres estados (`RECHAZADO`, `CONFLICTO`, `SIMULADO_APROBADO`) están cubiertos y que el orden de prioridad es correcto. Registrar hallazgos en `docs/bitacora_ia.md`.
- [ ] **T4.4** Contrastar en PostgreSQL y SQLite los hallazgos reportados por OpenCode Build: ejecutar las consultas de verificación indicadas y documentar los resultados reales en `docs/bitacora_ia.md`.
- [ ] **T4.5** Completar `docs/DUIA.md` con la declaración oficial de uso de IA, incluyendo las interacciones de OpenCode Build de T4.1–T4.4.
