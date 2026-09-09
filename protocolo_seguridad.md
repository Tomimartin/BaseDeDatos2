# Parte 0 — Protocolo de seguridad

## Entorno utilizado

- Motor: PostgreSQL
- Cliente SQL: DBeaver
- Sistema operativo: Windows
- Proyecto: Food Store
- Repositorio: `H:\Mi unidad\Facultad\2do\Base de Datos 2`

## 1. Copia de trabajo

Las pruebas del TP se realizan sobre una copia local de la base y no sobre datos importantes.

Ejemplo desde PowerShell:

```powershell
createdb -U postgres -T <base_original> <copia_trabajo>
```

Antes de ejecutar cambios se verifica la base actual:

```sql
SELECT current_database();
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

Antes de cambios estructurales como `ALTER`, `DROP` o migraciones, se genera un respaldo con `pg_dump`.

```powershell
pg_dump -U postgres -F c -f ".\backups\food_store.backup" <copia_trabajo>
```

Si fuera necesario restaurarlo:

```powershell
createdb -U postgres <base_restaurada>

pg_restore -U postgres -d <base_restaurada> ".\backups\food_store.backup"
```

## Orden de trabajo

1. Verificar que se está trabajando sobre la copia.
2. Crear respaldo si el cambio es estructural.
3. Leer el script antes de ejecutarlo.
4. Probar con `BEGIN` y `ROLLBACK`.
5. Si funciona correctamente, volver a ejecutar y hacer `COMMIT`.
6. Guardar los cambios en Git.

## Conclusión

El objetivo del protocolo es evitar aplicar directamente cambios peligrosos sobre una base importante. Por eso se trabaja siempre con copia, transacción y respaldo antes de confirmar cambios.
