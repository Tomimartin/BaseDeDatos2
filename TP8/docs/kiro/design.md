# TP8 Food Store - Design - propuesta para registrar en Kiro

Arquitectura: PostgreSQL es fuente de verdad de precios, stock y ventas. `v_snapshot_movil` exporta catálogo y marcas de baja lógica. SQLite usa cuatro tablas STRICT (`producto_cache`, `pedido_borrador`, `item_borrador`, `cola_sync`) y una instantánea importada (`snapshot_servidor`). MongoDB de U7 es lectura documental, sin control de stock.

Datos: importes enteros en centavos; disponibilidad/eliminado en SQLite 0/1; claves foráneas activas; UUID para idempotencia. La baja lógica conserva la fila para no romper referencias. El semáforo clasifica por prioridad RECHAZADO > CONFLICTO > SIMULADO_APROBADO y solo actualiza solicitudes PENDIENTE.

Transacciones: guardar borrador, ítems y solicitud mediante BEGIN/COMMIT. Ante error hacer ROLLBACK. DB Browser permite SAVEPOINT para ensayos, pero la prueba explícita se realizó en Python sqlite3 sobre copia aislada.

Limitación deliberada del TP8: no existe un endpoint que confirme ventas. La deduplicación definitiva debe implementarse en PostgreSQL cuando se construya el servicio real.
