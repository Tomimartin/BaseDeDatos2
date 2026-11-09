# Bitácora de uso de IA - TP8 Food Store

> Se documentan interacciones efectivamente ocurridas. No se atribuye actividad a Kiro ni a OpenCode que todavía no se realizó.

| Solicitud hecha a ChatGPT | Qué se aceptó | Qué se corrigió/descartó y por qué | Validación humana |
|---|---|---|---|
| Diseñar la base SQLite de la tablet de Food Store (4 tablas STRICT y catálogo). | Esquema con CHECK, FK, precios en centavos y borradores. | Se separó PostgreSQL de SQLite: la tablet no puede confirmar ventas. | Creación real en DB Browser; consulta `v_catalogo_disponible` con 10 productos; importación de 50.010 productos. |
| Implementar la comparación de borradores con el servidor y los casos C2-C5. | Semáforo de tres resultados con prioridad RECHAZADO > CONFLICTO > SIMULADO_APROBADO. | Se evitó reevaluar estados terminales; el reintento tras cambio de precio usa otro UUID. | C2 mostró precio $2.500/$2.800 y luego CONFLICTO + SIMULADO_APROBADO; C3 y C4 terminaron RECHAZADO. |
| Probar restricciones C6-C7 y determinar por qué no se veían errores en DB Browser. | Revisión en SQL Log > Error Log y controles de COUNT. | Se descartó la idea de que un `SELECT` vacío, por sí solo, demostraba el CHECK o la FK. | Capturas con códigos SQLite 1555 (PK), 275 (CHECK), 787 (FK); 5 ítems conservados. |
| Probar BEGIN/COMMIT/ROLLBACK cuando DB Browser administraba SAVEPOINT internos. | Uso de Python sqlite3 sobre copia del archivo; no modificar la base original. | Se descartó insistir con BEGIN dentro de la transacción interna de DB Browser. | Captura PowerShell: COMMIT (1,1,1), ROLLBACK (0,0,0), `foreign_keys=1`. |
| Revisar antecedentes de MongoDB, mantenimiento y SQL en GitHub para el TP8. | Se tomaron los scripts de U5-U7 como antecedentes, no se copiaron TPs anteriores en esta entrega. | Se separó análisis asistido por ChatGPT de la revisión obligatoria con OpenCode Plan. | Inspección de archivos de repositorio; ver propuestas sujetas a validación en informe. |

## Actividades de IA pendientes y su registro

- Abrir requirements.md, design.md y tasks.md en **Kiro** y registrar la interacción real.
- Ejecutar **OpenCode** sobre tareas del TP8 y guardar comandos/salidas reales.
- Pedir a **OpenCode agente Plan** revisión de todos los scripts previos, documentar al menos tres hallazgos de dos unidades con decisión fundamentada y comprobación en la base.
- Adjuntar la **DUIA oficial** según formato de cátedra, si existe una plantilla o formulario específico.
