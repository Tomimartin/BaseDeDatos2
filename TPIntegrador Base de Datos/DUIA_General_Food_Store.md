# DUIA — Segunda entrega del TPI Food Store

**Asignatura:** Base de Datos II · Tecnicatura Universitaria en Programación · UTN FRM  
**Trabajo:** TPI Food Store, segunda entrega (unidades 4 a 8)  
**Fecha del documento:** 10/11/2026

## 1. Herramientas utilizadas y para qué

| Herramienta | Uso documentado | Cómo verificamos las propuestas |
|---|---|---|
| **Kiro** | Especificaciones `requirements.md`, `design.md` y `tasks.md` para la migración FNBC de U4 y el módulo móvil de U8; diseño inicial de roles en U5. | Revisión de reglas, compatibilidad de tablas y pruebas sobre bases o esquemas aislados. |
| **OpenCode** | Auditoría de permisos de U5 y análisis del simulacro; modo **Plan** para revisión transversal de scripts; modo **Build** para comparar alternativas de esquema, pruebas y semáforo de U8. | Contraste de permisos en PostgreSQL, capturas, consultas EXPLAIN y errores/controles de SQLite. |
| **Codex** | Apoyo en preparación y ajuste de los scripts de respaldo y restauración de la Unidad 6. | Ejecución real con logs, restauración independiente, cinco conteos e integridad en cero. |
| **Asistencia conversacional (ChatGPT)** | Apoyo para interpretar consignas, revisar prompts y especificaciones, aclarar errores y revisar/redactar documentación; también se contrastaron propuestas de consultas o pruebas en algunas etapas. | El equipo comprobó el SQL y los resultados en pgAdmin, MongoDB y SQLite. La asistencia no se presenta como prueba por sí misma. |

La mención de asistencia conversacional responde a las bitácoras existentes. No se atribuyen a una sola herramienta todas las etapas del proyecto.

## 2. Prompts y especificaciones empleados

Se conservan los pedidos completos cuando existen y, en otros casos, resúmenes de su contenido. **No se inventan transcripciones literales de prompts que no se hayan guardado**.

| Unidad | Pedido o especificación registrada | Archivo de referencia |
|---|---|---|
| U4 | Especificar la migración de ControlLoteAlmacen a FNBC, demostrar reunión sin pérdida y documentar reversión antes y después del COMMIT, sin tocar la base original. | `TP4_unidad4/docs/kiro/{requirements,design,tasks}.md` |
| U5 | Revisar roles y privilegios bajo mínimo privilegio, analizar logs anonimizados del incidente simulado y proponer medidas proporcionadas sin ejecutarlas. | `TP5_unidad5/Parte_A/docs/auditoria_opencode_parte_A.md`; `Parte_C/docs/prompt_opencode_parte_C.txt` y respuesta |
| U6 | Preparar scripts con manejo de errores para respaldo custom y restauración controlada; comprobar integridad y medir recuperación en base separada. | `U6/SPEC_U6.md`, `U6/INFORME_U6.md`, `U6/scripts/` |
| U7 | Comparar representación relacional y documental de pedidos, identificando beneficios, costos de duplicación e integridad. | `U7/tp_Unidad7.md` |
| U8 | Revisar requisitos EARS y escenarios C1–C7; analizar scripts con OpenCode Plan; generar alternativas en Build y conservar las que respeten el esquema real. | `TP8/docs/kiro/`, `TP8/docs/bitacora_ia.md` |

## 3. Propuestas aceptadas, corregidas o descartadas

- **U4:** se aceptó especificar en Kiro la reversión con `ROLLBACK` explícito y una secuencia compensatoria con `DROP ... RESTRICT`, limitada a objetos del laboratorio. Se comprobaron tres filas originales intactas.
- **U5:** se aceptaron permisos más precisos y verificaciones por columna. Se corrigieron inferencias de OpenCode sobre la cuarta llamada a la función de autenticación y sobre un presunto ataque real: los logs por sí solos no demostraban esos resultados.
- **U6:** se revisaron los scripts y se comprobaron respaldo, restauración, conteos y tiempos. Las frecuencias periódicas documentadas en la especificación no se declaran como tareas automáticas ejecutadas.
- **U7:** se mantuvo PostgreSQL como fuente transaccional principal. Se descartó afirmar que MongoDB es necesariamente más rápido sin una medición comparable.
- **U8:** se rechazó eliminar el índice parcial `ux_cola_una_pendiente` y cambiar nombres de columnas compatibles con la base real. Se aceptó corregir el tratamiento de `NULL` en el semáforo. Se contrastaron tres hallazgos de OpenCode Plan sobre scripts de diferentes unidades.

Las observaciones adicionales de `Revision_Consolidada_Codigo.md` fueron elaboradas en una revisión estática posterior y **no se atribuyen falsamente a OpenCode**. Sus propuestas nuevas requieren una decisión expresa del equipo si se van a aplicar.

## 4. Protección de datos y responsabilidad

Las pruebas documentadas se realizaron sobre bases de ensayo, esquemas aislados o archivos de copia cuando correspondía. Se utilizaron datos sintéticos o anonimizados para la revisión con IA, evitando enviar credenciales y datos personales reales. Ningún script generado o sugerido por IA se considera validado solo por su texto: la aceptación se apoya en los resultados efectivamente registrados.
