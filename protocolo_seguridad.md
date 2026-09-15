# Parte 0 — Protocolo de seguridad

## Entorno utilizado

- Motor: PostgreSQL 17.11
- Cliente SQL: DBeaver y psql
- Sistema operativo: Windows
- Proyecto: Food Store
- Base original: `food_store`
- Base de copia de trabajo: `foodstorecopia`
- Repositorio: `https://github.com/Tomimartin/BaseDeDatos2`

## 1. Copia de trabajo

Las pruebas del TP se realizan sobre una copia local de la base y no sobre datos
importantes. La copia de trabajo real utilizada es `foodstorecopia`.

Creación de la copia de trabajo desde la base original:

```powershell
createdb -U postgres -T food_store foodstorecopia
```

Antes de ejecutar cambios se verifica la base actual:

```sql
SELECT current_database();
```

Salida real verificada:

```
 current_database
------------------
 foodstorecopia
(1 row)
```

## 2. Transacción

Todo cambio se prueba primero dentro de una transacción.

```sql
BEGIN;

-- script a probar

ROLLBACK;
```

Si el resultado es correcto, se vuelve a ejecutar y se confirma:

```sql
BEGIN;

-- script validado

COMMIT;
```

## 3. Respaldo

Antes de cambios estructurales como `ALTER`, `DROP` o migraciones, se genera un
respaldo con `pg_dump`. Respaldo real ejecutado sobre `foodstorecopia`:

```powershell
pg_dump -U postgres -h localhost -F c -f ".\backups\foodstorecopia.backup" foodstorecopia
```

Salida real:

```
(comando ejecutado sin errores; se generó el archivo foodstorecopia.backup con los datos y el esquema)
```

Restauración si fuera necesaria:

```powershell
createdb -U postgres foodstorecopia

pg_restore -U postgres -d foodstorecopia ".\backups\foodstorecopia.backup"
```

## Orden de trabajo

1. Verificar que se está trabajando sobre la copia (`SELECT current_database();`).
2. Crear respaldo si el cambio es estructural.
3. Leer el script antes de ejecutarlo.
4. Probar con `BEGIN` y `ROLLBACK`.
5. Si funciona correctamente, volver a ejecutar y hacer `COMMIT`.
6. Guardar los cambios en Git.

## Conclusión

El objetivo del protocolo es evitar aplicar directamente cambios peligrosos sobre
una base importante. Por eso se trabaja siempre con copia, transacción y respaldo
antes de confirmar cambios.