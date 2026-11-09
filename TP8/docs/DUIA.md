# Declaración de Uso de Inteligencia Artificial (DUIA) - TP8

**Asignatura:** Base de Datos II. **Trabajo:** TP8 Food Store. **Fecha del borrador:** 08/11/2026. **Última actualización:** 09/11/2026.

## Herramientas utilizadas y alcance

Durante el desarrollo de este TP se empleó **ChatGPT** como asistencia conversacional para interpretar consignas, redactar propuestas de scripts SQL, depurar su ejecución en DB Browser for SQLite, explicar transacciones y preparar documentación. Las decisiones fueron contrastadas con consultas reales y capturas aportadas por el equipo: exportación de 50.010 productos, estados de sincronización, errores de integridad y prueba de COMMIT/ROLLBACK sobre copia SQLite. La validación del comportamiento no se basó únicamente en una respuesta de IA.

También se utilizó **OpenCode en el agente Plan** para revisar scripts de distintas unidades sin modificarlos. Su respuesta fue contrastada con consultas reales en SQLite y PostgreSQL: unicidad de la instantánea, definición de columnas generadas/obligatorias y EXPLAIN del índice por precio. Se aceptaron dos observaciones y se descartó la afirmación de que el índice eliminaba necesariamente el Sort. Los detalles figuran en `bitacora_ia.md`.

El 09/11/2026 se utilizó **OpenCode Build** para revisar `movil/semaforo.sql` contra el esquema real, aplicar un parche acotado de manejo de NULL, verificar los casos C2-C7 y los casos NULL sobre una copia temporal de `foodstore_movil.db`, y actualizar `docs/kiro/design.md`, `docs/bitacora_ia.md` y este documento. El parche conserva las tablas, columnas y el índice `ux_cola_una_pendiente`; no agrega `evaluado_en` ni modifica PostgreSQL. La verificación se ejecutó con Python sqlite3 sobre una copia temporal: el hash de la base original no cambió (`43ca12c19644f707ed30c86092736d5b598f178c89b35dd043b7d759377f90f1`), `integrity_check` devolvió `ok` y `foreign_key_check` no reportó filas. Los resultados completos están en `bitacora_ia.md`. No se agregaron archivos extra a la entrega.

**Kiro no se ejecutó** en este TP; no se le atribuyen acciones.

## Datos y privacidad

Se utilizaron datos de prueba y la base provista para el trabajo. No se incorporaron contraseñas ni datos personales de clientes en las pruebas. `SIMULADO_APROBADO` fue interpretado exclusivamente como verificación local, no como venta confirmada.

## Validación humana y responsabilidad

Las respuestas de IA fueron revisadas y aceptadas por el estudiante antes de incorporarlas. La verificación técnica de la consigna 4.a se realizó sobre una copia temporal; la base original y PostgreSQL no se modificaron. La responsabilidad final sobre el contenido, las decisiones y la presentación del TP es humana. No se incluyen interacciones ficticias ni datos personales inventados.

## Datos institucionales pendientes

- **Integrantes responsables:** [completar con nombre y apellido/legajo]
- **Fecha final de presentación:** [completar]
- **Firma:** [completar]
- **Formulario oficial de la cátedra:** adjuntar si la cátedra proporciona una plantilla específica.
