# Design — Migración de ControlLoteAlmacen a FNBC

## Descomposición algorítmica

Se aplica el algoritmo de descomposición FNBC sobre la dependencia violatoria `R → D`,
con `X = {R}` e `Y = {D}`. Las relaciones resultantes son:

```
C₁ = X ∪ Y            →  ResponsableDeposito(R, D)
C₂ = C − (Y − X)      →  ControlLote(L, R)
```

### C₁ — `responsable_deposito(responsable_control_id, deposito_id)`

- **PK:** `responsable_control_id`  
- **FK:** `responsable_control_id → usuario(id)`  
- **FK:** `deposito_id → deposito(id)`  
- La dependencia `R → D` tiene aquí como determinante su propia PK: cumple FNBC.

### C₂ — `control_lote(lote_id, responsable_control_id)`

- **PK:** `(lote_id, responsable_control_id)`  
- **FK:** `lote_id → lote(id)`  
- **FK:** `responsable_control_id → responsable_deposito(responsable_control_id)`  
- No hay dependencias no triviales con determinante menor que `{L, R}`: cumple FNBC.

---

## Prueba de reunión sin pérdida

El atributo común a las dos tablas es `responsable_control_id`.

Para que la descomposición sea sin pérdida basta con que ese atributo común sea clave
de alguna de las dos relaciones. Se cumple: `responsable_control_id` es PK de
`responsable_deposito`.

Formalmente: `C₁ ∩ C₂ = {R}` y en `F⁺` se verifica `{R} → {R, D} = C₁`.

Consecuencia: la reunión natural de las proyecciones sobre cualquier instancia válida
original produce **exactamente** la instancia original, sin tuplas espurias.

**Instancia de ejemplo:**

| `responsable_deposito` | | `control_lote` | |
| :--- | :--- | :--- | :--- |
| responsable_control_id | deposito_id | lote_id | responsable_control_id |
| 801 | 30 | 501 | 801 |
| 802 | 31 | 502 | 801 |
| | | 503 | 802 |

Reunión natural → reconstruye las tres filas originales de `control_lote_almacen`.

---

## Vista de compatibilidad

```sql
CREATE OR REPLACE VIEW public.control_lote_almacen_compat AS
SELECT cl.lote_id, rd.deposito_id, rd.responsable_control_id
FROM public.control_lote AS cl
NATURAL JOIN public.responsable_deposito AS rd;
```

Permite que las consultas existentes que leen `control_lote_almacen` puedan apuntar
transitoriamente a esta vista sin modificar su SQL, facilitando la transición.

---

## Estructura del script de migración (`tp_fnbc_control_lote.sql`)

Todo el DDL y los INSERT corren dentro de una única transacción:

```
BEGIN
  ├─ CREATE TABLE IF NOT EXISTS control_lote_almacen   (tabla original + datos de ejemplo)
  ├─ CREATE TABLE IF NOT EXISTS responsable_deposito    (C₁)
  ├─ CREATE TABLE IF NOT EXISTS control_lote            (C₂)
  ├─ INSERT INTO responsable_deposito  SELECT DISTINCT ... FROM control_lote_almacen
  ├─ INSERT INTO control_lote          SELECT DISTINCT ... FROM control_lote_almacen
  └─ CREATE OR REPLACE VIEW control_lote_almacen_compat
COMMIT
```

`SELECT DISTINCT` elimina duplicados de la proyección (ej.: responsable 801 aparece en
dos filas de la tabla original pero debe insertarse una sola vez en `responsable_deposito`).
`ON CONFLICT … DO NOTHING` permite re-ejecutar el script sin error si las tablas ya tienen datos.

---

## Verificación automática

```sql
WITH diferencias AS (
    (SELECT … FROM control_lote_almacen
     EXCEPT
     SELECT … FROM control_lote_almacen_compat)
    UNION ALL
    (SELECT … FROM control_lote_almacen_compat
     EXCEPT
     SELECT … FROM control_lote_almacen)
)
SELECT COUNT(*) AS filas_diferentes FROM diferencias;
```

Resultado esperado: `filas_diferentes = 0`. La comprobación en ambos sentidos con
`EXCEPT` detecta tanto filas presentes en el original pero ausentes en la vista, como
filas espurias que pudieran aparecer en la vista pero no en el original.

---

## Plan de reversión

### Caso 1 — Reversión con ROLLBACK explícito (transacción aún abierta)

Si el script falla dentro del bloque `BEGIN … COMMIT` se usa `ROLLBACK` explícito para
cancelar la transacción. PostgreSQL también revierte automáticamente ante un error fatal,
pero el ROLLBACK explícito hace el intento intencional inequívoco y permite verificar el
estado resultante en la misma sesión.

El procedimiento es:

```sql
-- 1. Dentro de la sesión donde se abrió BEGIN, emitir:
ROLLBACK;

-- 2. Verificar que ningún objeto de la migración fue creado.
SELECT to_regclass('public.responsable_deposito') AS c1,
       to_regclass('public.control_lote')          AS c2,
       to_regclass('public.control_lote_almacen_compat') AS vista;
-- Resultado esperado: las tres columnas devuelven NULL.

-- 3. Verificar que control_lote_almacen conserva sus datos.
SELECT COUNT(*) AS total_filas FROM public.control_lote_almacen;
-- Resultado esperado: 3.
```

Si el error fue irrecuperable y la sesión se cortó, reconectarse a la base de prueba y
ejecutar solo los pasos 2 y 3: PostgreSQL ya habrá revertido la transacción incompleta.

### Caso 2 — Reversión después de un COMMIT exitoso

Una vez confirmado el `COMMIT`, los cambios son permanentes y no existe un `ROLLBACK`
automático. Antes de eliminar ningún objeto se verifica que pertenecen a la base de prueba
y que sus contenidos coinciden exactamente con los proyectados por el script de migración.
Solo entonces se procede con los DROP.

**Paso A — Verificación previa (ejecutar antes de cualquier DROP):**

```sql
-- Confirmar base de prueba activa (debe ser distinta de foodstorecopia).
SELECT current_database() AS base_activa;

-- Confirmar que responsable_deposito solo contiene las filas proyectadas.
SELECT responsable_control_id, deposito_id
FROM public.responsable_deposito
ORDER BY responsable_control_id;
-- Resultado esperado: 2 filas → (801,30) y (802,31).

-- Confirmar que control_lote solo contiene las filas proyectadas.
SELECT lote_id, responsable_control_id
FROM public.control_lote
ORDER BY lote_id;
-- Resultado esperado: 3 filas → (501,801), (502,801), (503,802).

-- Confirmar que no existen FK externas apuntando a los objetos a eliminar.
SELECT tc.table_name, tc.constraint_name
FROM information_schema.referential_constraints rc
JOIN information_schema.table_constraints tc
    ON tc.constraint_name = rc.constraint_name
WHERE rc.unique_constraint_name IN (
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name IN ('responsable_deposito', 'control_lote')
      AND constraint_type = 'PRIMARY KEY'
);
-- Resultado esperado: solo aparece control_lote (su propia FK interna).
-- Si aparece otra tabla, detener y resolver la dependencia antes de continuar.
```

Solo si los tres controles anteriores son satisfactorios, continuar con el Paso B.

**Paso B — Eliminación en orden de dependencias (sin CASCADE):**

```sql
-- revert_fnbc_control_lote.sql
-- Revierte la migración a FNBC después de un COMMIT exitoso.
-- Requiere que control_lote_almacen exista y conserve sus datos originales.
-- No usa DROP CASCADE. No modifica foodstorecopia.

BEGIN;

-- 1. Eliminar la vista de compatibilidad.
DROP VIEW IF EXISTS public.control_lote_almacen_compat;

-- 2. Eliminar C₂ antes que C₁ para respetar la FK de control_lote
--    hacia responsable_deposito.
DROP TABLE IF EXISTS public.control_lote;

-- 3. Eliminar C₁ (ya sin dependientes).
DROP TABLE IF EXISTS public.responsable_deposito;

COMMIT;
```

**Paso C — Verificación post-reversión:**

```sql
-- Las tablas descompuestas y la vista no deben existir.
SELECT to_regclass('public.responsable_deposito') AS c1,
       to_regclass('public.control_lote')          AS c2,
       to_regclass('public.control_lote_almacen_compat') AS vista;
-- Resultado esperado: las tres columnas devuelven NULL.

-- control_lote_almacen debe conservar sus tres filas intactas.
SELECT lote_id, deposito_id, responsable_control_id
FROM public.control_lote_almacen
ORDER BY lote_id, deposito_id;
-- Resultado esperado: (501,30,801), (502,30,801), (503,31,802).
```

**Precondiciones para la reversión post-COMMIT:**

1. `current_database()` debe devolver la base de prueba, no `foodstorecopia`.
2. El Paso A no debe mostrar tablas externas con FK hacia los objetos a eliminar. Si las
   hubiera, deben eliminarse primero de forma explícita; no se usa CASCADE.
3. `control_lote_almacen` debe existir con sus datos originales. El script de migración
   la crea con `IF NOT EXISTS` y nunca la elimina.

**Orden de eliminación:** `control_lote` se elimina antes que `responsable_deposito`
porque tiene una FK hacia ella. Invertir el orden produce un error de dependencia de FK.

### Qué se conserva en ambos casos

| Objeto | ¿Se conserva? |
| :--- | :--- |
| `control_lote_almacen` (tabla original) | Sí, siempre |
| Datos de ejemplo (filas 501-503) | Sí, siempre |
| `responsable_deposito` | Se elimina en la reversión post-COMMIT |
| `control_lote` | Se elimina en la reversión post-COMMIT |
| `control_lote_almacen_compat` (vista) | Se elimina en la reversión post-COMMIT |

---

## Limitación de preservación de dependencias

La descomposición no preserva la dependencia `{L, D} → R` de forma local. Las restricciones
de las tablas descompuestas no impiden insertar:

```sql
INSERT INTO control_lote VALUES (501, 803);   -- lote 501 con responsable 803
-- si responsable 803 está en deposito 30 (igual que 801),
-- habrá dos responsables del depósito 30 para el lote 501,
-- violando {L,D}→R de la relación original.
```

Para detectar o prevenir esto en nuevas inserciones se necesita una de las siguientes
estrategias adicionales (fuera del alcance del presente TP):

- Un trigger `BEFORE INSERT ON control_lote` que consulte si ya existe otro responsable
  del mismo depósito para ese lote.
- Una restricción `UNIQUE(lote_id, deposito_id)` sobre una vista materializada que
  represente la reunión, mantenida por triggers.

Esta limitación no afecta la prueba de reunión sin pérdida sobre datos históricos ya
existentes, que sigue siendo válida por el argumento formal documentado en el apartado
de diseño.
