# INFORME_U6.md

## 1. Datos de la prueba

- **Fecha y hora del respaldo utilizado:** [27/10/2026 2:17]
- **Base origen:** foodstorecopia
- **Base de restauración:** foodstore_restore_test

## 2. Métricas RTO y RPO

| Métrica | Previsto | Observado | Diferencia |
|---|---|---|---|
| **RTO** | [Especificar RTO previsto] | 2 min 56 seg | [Diferencia] |
| **RPO** | 24 horas por respaldo diario | [Antigüedad del respaldo en minutos] | [Diferencia] |

## 3. Resultados de Validación

### Conteo de filas de las 5 tablas principales

| Tabla | Cantidad de filas |
|---|---|
| categoria | 2006 |
| cliente | 20004 |
| producto | 50010 |
| pedido | 20004 |
| detalle_pedido | 200014 |

### Integridad

- **Producto:** 0 registros inválidos
- **Detalle_pedido:** 0 registros inválidos

## 4. Problema/Incidente real encontrado

Se identificó un problema relacionado con el ajuste inicial de la variable de entorno de nombre de la base de datos `DB_NAME`, el cual fue corregido para permitir la correcta restauración y conexión a la base de datos de destino.

## 5. Mejora propuesta

**Automatización mediante script `restore_test.sh` con alerta ante fallos de integridad.**

La implementación de este script permitirá estandarizar el proceso de restauración, ejecutar validaciones de integridad automáticamente y notificar al equipo en caso de detectar inconsistencias.

## 6. Uso de OpenCode

- **Scripts estructurados por la IA:** [Especificar nombres de scripts generados por OpenCode]
- **Pruebas y validación manual:** Los scripts generados fueron probados en un entorno controlado, revisados línea por línea para verificar su lógica, validados contra los datos esperados y ejecutados manualmente antes de su aceptación definitiva. 
