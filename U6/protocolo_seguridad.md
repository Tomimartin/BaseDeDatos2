# Protocolo de seguridad - Unidad 6

## Entorno y alcance

- Motor utilizado: PostgreSQL 17.11 sobre Windows.
- Herramientas utilizadas: pgAdmin, PowerShell, `psql`, `pg_dump`, `pg_restore`, `createdb` y `dropdb`.
- Base de trabajo y origen del respaldo: **`foodstorecopia`**.
- Base descartable para restauración: **`foodstore_restore_test`**.
- Repositorio: [Tomimartin/BaseDeDatos2](https://github.com/Tomimartin/BaseDeDatos2).

Se conserva el nombre real `foodstorecopia` utilizado por el equipo. La consigna denomina a la base de origen `foodstore`; esa diferencia de nombre queda documentada.

## 1. Identificar la base antes de operar

Antes de ejecutar consultas o mantenimiento en pgAdmin, comprobar la conexión:

```sql
SELECT current_database() AS base_actual;
```

Los controles de salud y el mantenimiento de este trabajo se ejecutan en `foodstorecopia`. Los controles posteriores a la restauración se ejecutan en `foodstore_restore_test`.

La eliminación y recreación del simulacro se limita a `foodstore_restore_test`. El script tiene ese destino fijo y requiere la opción explícita `-RecreateTestDatabase` para reemplazar una base de prueba existente.

## 2. Credenciales

- Ingresar la contraseña durante la ejecución, sin escribirla en el script ni en los comandos guardados.
- No incorporar contraseñas, `.pgpass`, `pgpass.conf`, archivos `.env` ni credenciales exportadas al repositorio.
- El restaurador solicita la contraseña de forma oculta y utiliza `PGPASSWORD` únicamente en su proceso, restableciendo su valor al finalizar mediante `finally`.
- Conservar logs y capturas sin mostrar contraseñas.

## 3. Respaldo antes del ensayo

Registrar los conteos exactos de las cinco tablas antes del respaldo y mantener los datos sin cambios mientras se obtiene esa línea base y se genera la copia. Ejecutar desde la carpeta `U6`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup_foodstore.ps1 -PgBin "C:\Program Files\PostgreSQL\17\bin"
```

El script respalda `foodstorecopia` en formato custom, incluye fecha y hora en el nombre, conserva el log y los metadatos y verifica que `pg_restore --list` pueda leer el archivo. Si la ejecución falla o el archivo está vacío, termina con error. Los archivos incompletos permanecen identificados como `.partial`.

La lectura del listado confirma que el archivo puede interpretarse; la recuperación se comprueba con la restauración y sus validaciones.

## 4. Restauración exclusivamente en la base de prueba

Para repetir el ensayo con el archivo utilizado en este trabajo, en la computadora donde se conserva el respaldo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore_test.ps1 -PgBin "C:\Program Files\PostgreSQL\17\bin" -BackupFile "C:\Users\ignac\backups\foodstorecopia_20261106_145119_926.dump" -RecreateTestDatabase
```

El script verifica las herramientas, el archivo y sus metadatos antes de preparar el destino. Si ya existe `foodstore_restore_test`, la elimina con la opción indicada y vuelve a crearla desde `template0`. `dropdb --force` puede cerrar las conexiones a esa base de prueba.

La restauración utiliza `--exit-on-error`, `--no-owner` y `--no-privileges`, con `foodstore_restore_test` como destino. Se conserva la base de trabajo `foodstorecopia`.

La ruta del archivo del comando anterior corresponde a la computadora del ensayo. Para otro equipo o respaldo, ajustar `-BackupFile`, `-PgBin` y los parámetros de conexión cuando corresponda. Los metadatos `respaldo_FECHA_HORA.json` deben encontrarse en la carpeta `logs` situada junto a `backups`.

## 5. Transacciones según el tipo de operación

Para probar modificaciones transaccionales compatibles, como `INSERT`, `UPDATE` o `DELETE`, se puede utilizar `BEGIN` y `ROLLBACK` antes de una ejecución definitiva autorizada. Este mecanismo no se aplica indiscriminadamente a todos los comandos.

`CREATE DATABASE`, `DROP DATABASE` y `VACUUM` se ejecutan fuera de bloques `BEGIN/COMMIT`. La creación y eliminación de la base de prueba se realizan con las herramientas de PostgreSQL desde PowerShell. El mantenimiento aplicado en este ensayo fue `ANALYZE VERBOSE` sobre las cinco tablas principales, con observación previa y verificación posterior; no se utilizó `VACUUM FULL`.

## 6. Validaciones y mediciones

Después de restaurar, el script verifica la base de conexión, compara los conteos de `categoria`, `cliente`, `producto`, `pedido` y `detalle_pedido` y exige cero productos y detalles inválidos.

La línea base contenida en `restore_test.ps1` corresponde a los conteos observados por el equipo el 06/11/2026. Para otro conjunto de datos, actualizarla con los valores registrados antes de ese respaldo.

- **RTO:** comienza inmediatamente antes de crear la base de prueba y finaliza al completar las validaciones. La eliminación previa de un destino existente forma parte de la preparación. Objetivo: 300 segundos.
- **RPO del laboratorio:** antigüedad del respaldo al iniciar el ensayo, tomando su hora de inicio. Objetivo: 24 horas. No representa una pérdida real medida de transacciones.

La tarea se acepta cuando la restauración y las validaciones terminan sin errores y quedan conservados el log, los resultados JSON, la comparación CSV y las evidencias. Si falla, revisar el log antes de repetir el procedimiento.

## 7. Evidencias conservadas

Los 10 archivos de `logs/` se incorporaron sin modificar desde el ZIP aportado por el equipo. `evidencias/` conserva las capturas completas, la transcripción de la salida de `ANALYZE` y los conteos previos. `INFORME_U6.md` e `informe_u6.pdf` presentan los resultados del ensayo.

El campo `full_restore_verified: false` de los metadatos del respaldo describe el momento anterior al simulacro. El resultado posterior de la restauración consta como `EXITO` en `resultado_restore_20261106_150423_239.json` y en su log. Se mantienen ambos registros originales para conservar su secuencia temporal.

## Referencias técnicas

- [PostgreSQL 17: CREATE DATABASE](https://www.postgresql.org/docs/17/sql-createdatabase.html).
- [PostgreSQL 17: DROP DATABASE](https://www.postgresql.org/docs/17/sql-dropdatabase.html).
- [PostgreSQL 17: VACUUM](https://www.postgresql.org/docs/17/sql-vacuum.html).
- [PostgreSQL 17: pg_restore](https://www.postgresql.org/docs/17/app-pgrestore.html).
