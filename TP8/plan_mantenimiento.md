# Plan de mantenimiento - Food Store TP8

## 1. Objetivo

Mantener la disponibilidad, integridad y seguridad
de la información almacenada en PostgreSQL,
MongoDB y SQLite.

PostgreSQL es la fuente de verdad del negocio.
SQLite permite operar sin conexión y MongoDB
se utiliza para consultas documentales.

## 2. PostgreSQL - Servidor principal

Responsable: Administrador de base de datos.

Tareas:
- Realizar respaldos diarios con pg_dump.
- Comprobar diariamente conexiones y errores.
- Revisar semanalmente las estadísticas y el
  funcionamiento de autovacuum.
- Ejecutar ANALYZE cuando esté justificado.
- Probar semanalmente una restauración en una
  base independiente.
- Verificar la integridad de pedidos y stock.
- Revisar permisos y roles periódicamente.

Herramientas:
pgAdmin, pg_dump, pg_restore y scripts de la U6.

Recuperación:
Restaurar el último respaldo válido y comprobar
las cantidades de registros y la integridad.

Objetivos de referencia de U6:
RTO = 300 segundos.
RPO = 24 horas.

Estos son objetivos del plan y no garantías
para cualquier incidente.

## 3. MongoDB - Base documental

Responsable: Administrador de base de datos.

Tareas:
- Realizar respaldos periódicos de las colecciones.
- Verificar índices únicos sobre los pedidos.
- Controlar la integridad de los documentos.
- Revisar espacio ocupado y registros de errores.
- Comprobar que los datos migrados coincidan
  con su origen PostgreSQL.

Recuperación:
Restaurar el respaldo documental o reconstruir
las copias desde PostgreSQL cuando corresponda.

MongoDB no modifica el stock oficial ni
confirma ventas.

## 4. SQLite - Tablet sin conexión

Responsable: Operador de la tablet y soporte.

Tareas:
- Actualizar el catálogo antes de cada jornada.
- Respaldar el archivo foodstore_movil.db.
- Proteger especialmente los borradores pendientes.
- Revisar las solicitudes de cola_sync.
- Comprobar las claves foráneas.
- Ejecutar PRAGMA integrity_check periódicamente.
- Verificar el espacio disponible en la tablet.

Recuperación:
Restaurar una copia del archivo SQLite.

Si se pierde el archivo sin respaldo, también
podrían perderse los pedidos todavía pendientes
de sincronización.

## 5. Plan de sincronización

Antes de vender:
- Obtener una instantánea desde PostgreSQL.
- Actualizar producto_cache en SQLite.

Durante la venta sin conexión:
- Consultar el catálogo local.
- Registrar pedidos borradores.
- Crear solicitudes PENDIENTE en cola_sync.

Al recuperar conectividad:
- Comparar los pedidos con los datos actualizados.
- Detectar falta de stock y bajas lógicas.
- Detectar diferencias de precios.
- Registrar el resultado del semáforo.
- Evitar duplicar solicitudes mediante UUID.

Los estados posibles son:
PENDIENTE, CONFLICTO, RECHAZADO y
SIMULADO_APROBADO.

Ninguno de estos estados confirma una venta
real en PostgreSQL.

## 6. Evidencias del TP8

Se comprobaron las siguientes situaciones:

- C1: catálogo disponible sin conexión.
- C2: diferencia de precios y aceptación.
- C3: rechazo por stock insuficiente.
- C4: rechazo por baja lógica.
- C5: aprobación simulada sin cambios.
- C6: rechazo de UUID duplicado.
- C7: rechazo de cantidades inválidas y
  referencias a productos inexistentes.

Las pruebas de COMMIT y ROLLBACK se ejecutaron
con Python sobre una copia de SQLite.

También se comprobó que la base PostgreSQL de
pruebas mantuvo 200004 pedidos, igual que la
base original.

## 7. Conclusión

El mantenimiento debe priorizar la integridad
de los datos y la recuperación ante fallos.

PostgreSQL conserva el control de las ventas y
del stock oficial, mientras que SQLite permite
registrar operaciones sin conexión.

MongoDB proporciona una representación
documental para consultas y análisis.

La sincronización debe detectar conflictos antes
de permitir cualquier confirmación definitiva.
