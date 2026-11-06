# Unidad 6 - Food Store

Entrega del ensayo realizado el **06/11/2026**, con PostgreSQL **17.11** sobre Windows. La base de origen utilizada es **`foodstorecopia`** y el destino de restauración es **`foodstore_restore_test`**.

## Archivos de entrega

| Archivo o carpeta | Contenido |
|---|---|
| `INFORME_U6.md` | Versión Markdown del informe presentado en PDF. |
| `informe_u6.pdf` | Informe de una página con las métricas y las validaciones. |
| `SPEC_U6.md` | Plan, frecuencias, criterios de éxito y reglas del ensayo. |
| `protocolo_seguridad.md` | Protocolo actualizado para el procedimiento realmente ejecutado. |
| `scripts/backup_foodstore.ps1` | Respaldo custom, log, metadatos y verificación de lectura. |
| `scripts/restore_test.ps1` | Restauración en el destino fijo, comparación y medición de RTO/RPO. |
| `health_check.sql` | Tamaño, conexiones, estado de tablas y otras consultas activas. |
| `maintenance.sql` | Revisión, justificación de ANALYZE y verificación posterior. |
| `logs/` | Los 10 archivos originales recibidos del equipo. |
| `evidencias/` | Capturas, salida de ANALYZE y conteos previos. |

## Resultados comprobados

- Respaldo custom: **7.053.279 bytes**, código de salida 0.
- Restauración: **EXITO** en `foodstore_restore_test`.
- Cinco conteos coincidentes; cero productos y detalles inválidos.
- RTO observado: **4,673 segundos**, objetivo de 300 segundos.
- RPO del laboratorio: **13,309 minutos de antigüedad**, objetivo de 24 horas.
- Mantenimiento: `ANALYZE VERBOSE` en las cinco tablas principales y verificación de `last_analyze` y `analyze_count = 1`.
- Monitoreo: 215 MB, 2 conexiones y 0 deadlocks; la consulta de actividad no devolvió otras sesiones fuera de `idle`.

## Incorporación al repositorio

Usar esta carpeta `U6` en lugar de la versión anterior, conservando las demás unidades. El protocolo corregido reemplaza `U6/protocolo_seguridad.md`. El respaldo de esta entrega utiliza el `.ps1` probado en Windows; retirar del repositorio la versión anterior `U6/scripts/backup_foodstore.sh` para que no queden dos procedimientos diferentes.

Después de revisar los cambios, desde la raíz del repositorio:

```powershell
git add -A -- U6
git commit -m "Corrige U6: protocolo, restauracion, metricas y evidencias"
git push
```

## Repetir el laboratorio

Desde `U6`, ejecutar el respaldo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_foodstore.ps1 -PgBin "C:\Program Files\PostgreSQL\17\bin"
```

El script crea `backups/` y `logs/` junto a `scripts/`. Para restaurar, seguir el comando y las condiciones indicados en [el protocolo de seguridad](protocolo_seguridad.md). La opción `-RecreateTestDatabase` elimina y recrea exclusivamente `foodstore_restore_test`. Para otro respaldo, actualizar la línea base de conteos correspondiente a ese archivo.

Ejecutar `health_check.sql` y `maintenance.sql` en pgAdmin conectado a `foodstorecopia`, conservando las salidas de cada consulta.

## Trazabilidad y alcance

- Los logs se conservaron tal como fueron recibidos; las capturas también se preservan completas. Los archivos de transcripción están identificados como tales.
- El `.dump` permanece en `C:\Users\ignac\backups\foodstorecopia_20261106_145119_926.dump`. Se adjuntan evidencias de su generación, tamaño y restauración; el archivo binario no se incluye en el repositorio.
- Los 7 rollbacks registrados son un contador acumulado y no se presentan como fallos del simulacro.
- `full_restore_verified: false` en `respaldo_20261106_145119_926.json` pertenece a la etapa anterior al ensayo. La restauración posterior está registrada como `EXITO` en su resultado y log.
- La asistencia de estas correcciones fue de Codex; el equipo ejecutó los scripts y SQL y aportó los resultados. No se atribuyen pruebas nuevas a otra herramienta.
- Se mantiene el nombre real `foodstorecopia`, según la decisión del equipo. La diferencia con el nombre `foodstore` de la consigna queda documentada.

Este paquete corresponde a **U6**. La corrección de U7 se realiza por separado.
