# TP8 Food Store — Requirements (notación EARS)

Especificación de requisitos del módulo móvil offline de Food Store, redactada en notación **EARS** (Easy Approach to Requirements Syntax), revisada con Kiro.

Cada requisito sigue la forma: `WHEN <condición de activación>, THE SYSTEM SHALL <comportamiento esperado>`.

Los casos de prueba referenciados (C1–C7) corresponden a los escenarios ejecutados sobre `movil/foodstore_movil.db` y documentados en `docs/informe.pdf`.

---

- **REQ-01.** WHEN la tablet pierde conexión con PostgreSQL, THE SYSTEM SHALL permitir consultar el catálogo local almacenado en `producto_cache` sin modificar stock ni confirmar ventas en PostgreSQL.
  **Caso de prueba:** C1 — consulta de los 10 primeros productos desde SQLite sin servidor activo.

- **REQ-02.** WHEN el usuario guarda un borrador de pedido, THE SYSTEM SHALL insertar el encabezado en `pedido_borrador`, los ítems en `item_borrador` y la solicitud en `cola_sync` de forma atómica mediante una transacción `BEGIN/COMMIT`, rechazando con `ROLLBACK` cualquier cantidad inválida (≤ 0) o producto inexistente en `producto_cache`.
  **Casos de prueba:** C7 (errores SQLite 275 por CHECK y 787 por FOREIGN KEY) y prueba explícita de `COMMIT`/`ROLLBACK` con Python `sqlite3`.

- **REQ-03.** WHEN el sistema compara una solicitud en estado `PENDIENTE` con la instantánea actualizada del servidor (`snapshot_servidor`), THE SYSTEM SHALL clasificarla como `RECHAZADO` si el producto fue dado de baja, no existe, no está disponible o el stock es insuficiente; como `CONFLICTO` si el precio cambió sin que se den condiciones de rechazo; o como `SIMULADO_APROBADO` si todos los campos coinciden con el borrador. Un valor desconocido o NULL no se considera una coincidencia válida. El resultado y el motivo deben quedar registrados en `cola_sync`.
  **Casos de prueba:** C2 (CONFLICTO por cambio de precio), C3 (RECHAZADO por stock insuficiente), C4 (RECHAZADO por baja lógica), C5 (SIMULADO_APROBADO sin cambios). Pruebas adicionales N1–N7 sobre NULL y controles.

- **REQ-04.** WHEN una solicitud con un UUID ya registrado en `cola_sync` se intenta insertar nuevamente, THE SYSTEM SHALL impedir el duplicado mediante la `PRIMARY KEY` sobre `solicitud_uuid` y conservar el estado ya evaluado sin modificación.
  **Caso de prueba:** C6 — reenvío del mismo UUID; SQLite devuelve error 1555 y la tabla conserva una sola fila con el estado original.
