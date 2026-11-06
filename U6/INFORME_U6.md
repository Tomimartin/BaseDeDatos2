# Food Store: respaldo y recuperación

**Bases de Datos II / Unidad 6**

**Ensayo:** 06/11/2026 (-03:00). Windows. PostgreSQL 17.11.  
**Origen real:** `foodstorecopia`. **Destino:** `foodstore_restore_test`.  
**Repositorio:** [github.com/Tomimartin/BaseDeDatos2](https://github.com/Tomimartin/BaseDeDatos2).

## Respaldo y medición

Respaldo custom iniciado a las **14:51:20**: **`foodstorecopia_20261106_145119_926.dump`**, de **7.053.279 bytes**. Finalizó con código 0; el listado fue legible y se comprobó su restauración efectiva.

| Métrica | Objetivo previsto | Valor observado | Resultado |
|---|---|---|---|
| RTO | 300 segundos | **4,673 segundos** | Cumplido |
| RPO del laboratorio | 24 horas | **13,309 minutos** | Cumplido |

**RTO:** desde antes de crear el destino hasta completar las validaciones (franja 15:04:38-15:04:43). **RPO:** antigüedad del respaldo al iniciar el ensayo, tomando su hora de inicio; no es pérdida real medida de transacciones.

## Validación de la restauración

| Tabla | Antes del respaldo | Después de restaurar | Coinciden |
|---|---:|---:|---|
| categoria | 2.006 | 2.006 | Sí |
| cliente | 20.004 | 20.004 | Sí |
| producto | 50.010 | 50.010 | Sí |
| pedido | 200.004 | 200.004 | Sí |
| detalle_pedido | 200.014 | 200.014 | Sí |

**Integridad:** 0 productos con precio/stock negativos y 0 detalles con cantidad no positiva o precio negativo.

## Monitoreo y mantenimiento justificado

Se observaron **215 MB**, **2 conexiones**, 7.559 commits, 7 rollbacks y 0 deadlocks acumulados. La consulta de actividad no mostró otras sesiones fuera de `idle`. Ante estimaciones iniciales en cero y fechas de análisis `NULL`, pese a conteos positivos, se ejecutó **`ANALYZE VERBOSE`** sobre las cinco tablas. Se verificaron estimaciones actualizadas, **`last_analyze`** y **`analyze_count = 1`**; `track_counts` y `autovacuum` estaban en **`on`**. La acción actualizó estadísticas del planificador; no se utilizó `VACUUM FULL`.

## Incidente y mejora

**Incidente:** el script buscaba PostgreSQL 18 en una PC con clientes de PostgreSQL 17. Se corrigió con **`-PgBin`** y se repitió con éxito.

**Mejora propuesta:** guardar automáticamente los conteos previos junto a cada nuevo respaldo.

## Asistencia y verificación

Codex preparó/ajustó los scripts de PowerShell y la documentación. Se revisaron sintaxis y manejo de errores; el equipo ejecutó scripts y SQL y verificó salida, conteos, integridad y estadísticas.

## Evidencia de ejecución

Transcripción del extracto de la ejecución del restaurador incluido en el PDF:

```text
EXITO restauracion y validaciones completas en foodstore_restore_test
RTO observado: 4,673 segundos; objetivo: 300 segundos
RPO observado: 13,309 minutos de antiguedad; objetivo: 1440 minutos
Productos invalidos=0; detalles invalidos=0
```

Capturas completas 01-11 y salidas transcritas en `evidencias/`. Los logs originales se adjuntan en `logs/`.
