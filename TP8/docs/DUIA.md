# Declaración de Uso de Inteligencia Artificial (DUIA) — TP8

**Materia:** Base de Datos II. **Trabajo:** Food Store, Unidad 8. **Fecha de actualización:** 09/11/2026.

## Herramientas utilizadas y tareas

**ChatGPT:** apoyo para interpretar la consigna, elaborar y corregir scripts SQL, comprender errores de integridad en DB Browser, preparar las pruebas del semáforo y redactar el informe. Las respuestas se contrastaron con consultas SQLite/PostgreSQL y no se trataron como pruebas por sí solas.

**OpenCode, agente Plan:** revisión de scripts de distintas unidades, sin ejecutar cambios. Se comprobaron tres hallazgos: ausencia de UNIQUE en la instantánea importada, incompatibilidad entre cargas y columnas obligatorias/generadas, y persistencia del paso Sort pese al índice de precio. Se aceptaron los dos primeros hallazgos para el análisis y se descartó la afirmación de que el índice elimina necesariamente el Sort. Las comprobaciones se describen en el informe y la bitácora.

**Kiro:** revisión de `requirements.md`, `design.md` y `tasks.md` para la especificación 4.a, cuatro requisitos EARS con casos C1–C7 y tareas de generación. Se aceptó reforzar la introducción, las restricciones y el flujo; las discrepancias entre nombres propuestos y el esquema ya implementado se corrigieron posteriormente para mantener compatibilidad.

**OpenCode, agente Build:** generación de versiones alternativas del esquema, pruebas y semáforo desde los documentos de Kiro; comparación con la implementación existente. Se rechazó eliminar el índice parcial y cambiar nombres/añadir `evaluado_en` porque implicaría migración. Se aceptó únicamente un parche para tratar como error o conflicto los valores `NULL` del snapshot, aplicándolo a `movil/semaforo.sql` y probándolo sobre copias temporales. Se verificaron C2–C7, controles N1–N7, `PRAGMA integrity_check=ok` y `foreign_key_check` sin errores. La base entregada no se modificó (SHA-256 `43ca12c19644f707ed30c86092736d5b598f178c89b35dd043b7d759377f90f1`).

## Criterios de seguridad y responsabilidad

Se utilizaron copias y datos de prueba. No se enviaron credenciales ni datos personales reales de clientes a la tablet ni a las consultas de IA. Ningún semáforo de SQLite confirma ventas ni actualiza el servidor; `SIMULADO_APROBADO` es solo una evaluación local. El estudiante revisó las sugerencias, decidió cuáles usar y contrastó los resultados. OpenCode Build no volvió a ejecutar verificaciones sobre PostgreSQL en la última pasada; las consultas PostgreSQL documentadas son de las pruebas del TP8 previas.

## Identificación y conformidad (completar por los integrantes)

**Integrantes responsables:**

- 1. **Benjamin Lagos** — Legajo: __________________
- 2. **Leandro Rea** — Legajo: __________________
- 3. **Tomas Martin** — Legajo: __________________
- 4. **Brian Rampone** — Legajo: __________________
- 5. **Santiago Prandina** — Legajo: __________________
- 6. **Emir Gris** — Legajo: __________________
- 7. **Joel Herrera** — Legajo: __________________
- 8. **Octavio Medina** — Legajo: __________________
- **Fecha de presentación:** __________________________
- **Firma(s):** __________________________
- **Formulario DUIA oficial de la cátedra:** completar/adjuntar cuando corresponda.

*Este documento declara el uso realizado y no reemplaza un formulario institucional separado, si la cátedra lo exige.*
