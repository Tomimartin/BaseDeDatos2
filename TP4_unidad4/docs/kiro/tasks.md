# Tasks — Migración de ControlLoteAlmacen a FNBC

## Estado general

| Fase | Estado |
| :--- | :--- |
| 1. Preparación del entorno de prueba | ✅ Completada |
| 2. Ejecución del script de migración | ✅ Completada |
| 3. Verificación de la migración | ✅ Completada |
| 4. Prueba del plan de reversión | ✅ Completada |
| 5. Documentación de evidencias | 🔲 Pendiente (capturas por incorporar) |

---

## Nota sobre el entorno de prueba utilizado

Las pruebas no se realizaron sobre una base creada desde cero con tablas maestras
mínimas, sino sobre la base restaurada `food_store_copia`, usando un **esquema aislado**
`tpi_u4_rollback_lab` creado expresamente para el laboratorio. Las tablas maestras
`lote`, `deposito` y `usuario` ya existían en esa base con los IDs requeridos (lotes
501–503, depósitos 30–31, usuarios 801–802). Este enfoque es equivalente en términos
de aislamiento: todos los objetos del ejercicio viven dentro del esquema de laboratorio
y no afectan el esquema `public` ni ningún dato de producción.

La preparación alternativa con tablas maestras mínimas documentada en T-01 queda como
referencia para reproducir el ejercicio en una base completamente vacía.

---

## Fase 1 — Preparación del entorno de prueba

### T-01 Preparar el entorno de prueba — ✅ Completada

**Entorno real utilizado:** base restaurada `food_store_copia`, esquema aislado
`tpi_u4_rollback_lab`. Las tablas maestras necesarias (`lote`, `deposito`, `usuario`)
ya estaban presentes con los registros requeridos.

**Resultado verificado:** la tabla original `control_lote_almacen` contenía 3 filas
antes de iniciar la migración.

---

**Referencia — preparación alternativa desde cero**

Si se parte de una base vacía (sin `food_store_copia`), crear las tablas maestras
mínimas con el siguiente script antes de ejecutar `tp_fnbc_control_lote.sql`:

```sql
-- Tablas maestras mínimas (solo las columnas requeridas por las FK del ejercicio).
CREATE TABLE IF NOT EXISTS public.usuario  (id BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS public.deposito (id BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS public.lote     (id BIGINT PRIMARY KEY);

-- Registros requeridos por la instancia de ejemplo.
INSERT INTO public.usuario  (id) VALUES (801), (802) ON CONFLICT DO NOTHING;
INSERT INTO public.deposito (id) VALUES (30),  (31)  ON CONFLICT DO NOTHING;
INSERT INTO public.lote     (id) VALUES (501), (502), (503) ON CONFLICT DO NOTHING;
```

Criterio de aceptación:

```sql
SELECT COUNT(*) FROM public.lote     WHERE id IN (501, 502, 503);  -- 3
SELECT COUNT(*) FROM public.deposito WHERE id IN (30, 31);         -- 2
SELECT COUNT(*) FROM public.usuario  WHERE id IN (801, 802);       -- 2
```

---

### T-02 Verificar que los objetos de la migración no existen aún — ✅ Completada

**Resultado verificado:** antes de ejecutar el script, `responsable_deposito`,
`control_lote` y la vista `control_lote_almacen_compat` no existían en el esquema
de laboratorio.

---

## Fase 2 — Ejecución del script de migración

### T-03 Ejecutar `tp_fnbc_control_lote.sql` — ✅ Completada

El script se ejecutó completo (BEGIN … COMMIT) en Query Tool conectado a
`food_store_copia`, esquema `tpi_u4_rollback_lab`. No se registraron errores.

**Objetos creados:**

| Objeto | Tipo |
| :--- | :--- |
| `control_lote_almacen` | Tabla (ya existía; `IF NOT EXISTS` no la recreó) |
| `responsable_deposito` | Tabla |
| `control_lote` | Tabla |
| `control_lote_almacen_compat` | Vista |

---

### T-04 Confirmar existencia de objetos creados — ✅ Completada

**Resultado verificado:** las tres tablas y la vista aparecieron correctamente en el
catálogo del esquema de laboratorio tras el COMMIT.

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'tpi_u4_rollback_lab'
  AND table_name IN (
    'control_lote_almacen',
    'responsable_deposito',
    'control_lote'
  )
ORDER BY table_name;

SELECT viewname
FROM pg_views
WHERE schemaname = 'tpi_u4_rollback_lab'
  AND viewname = 'control_lote_almacen_compat';
```

---

## Fase 3 — Verificación de la migración

### T-05 Verificar contenido de las tablas descompuestas — ✅ Completada

**Resultados verificados:**

- `responsable_deposito`: 2 filas → (801, 30) y (802, 31).
- `control_lote`: 3 filas → (501, 801), (502, 801), (503, 802).

Los valores coinciden con la proyección esperada de la instancia original.

---

### T-06 Verificar la vista de compatibilidad (reunión sin pérdida) — ✅ Completada

**Resultado verificado:** la vista `control_lote_almacen_compat` reconstruyó
exactamente las 3 filas originales:

| lote_id | deposito_id | responsable_control_id |
| :--- | :--- | :--- |
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Evidencia: `TP4_unidad4/imagenes/tp4_u4_01_evidencia_verificacion.jpg`

---

### T-07 Verificar `filas_diferentes = 0` y ausencia de duplicados — ✅ Completada

**Resultados verificados:**

- Comparación con `EXCEPT` en ambos sentidos: `filas_diferentes = 0`.
- Control de duplicados: `0` filas duplicadas detectadas.

La migración es completa, sin pérdida y sin tuplas espurias.

Evidencia: `TP4_unidad4/imagenes/tp4_u4_01_evidencia_verificacion.jpg` (misma captura
que T-06, incluye ambas comprobaciones).

---

## Fase 4 — Prueba del plan de reversión

### T-08 Reversión con ROLLBACK explícito (Caso 1) — ✅ Completada

**Procedimiento ejecutado:** se abrió una transacción `BEGIN`, se ejecutaron las
sentencias de creación e inserción del script de migración y, antes del `COMMIT`,
se emitió `ROLLBACK` explícito.

**Resultados verificados:**

- La tabla original `control_lote_almacen` conservó sus **3 filas** intactas.
- `responsable_deposito`: `to_regclass` devolvió **NULL** (no existe).
- `control_lote`: `to_regclass` devolvió **NULL** (no existe).
- Vista `control_lote_almacen_compat`: `to_regclass` devolvió **NULL** (no existe).

El ROLLBACK dejó el esquema de laboratorio en el estado previo sin ningún objeto
residual de la migración.

Evidencia: `TP4_unidad4/imagenes/tp4_u4_07_reversion_en_transaccion.png`

---

### T-09 Reversión post-COMMIT (Caso 2) — ✅ Completada

**Procedimiento ejecutado en tres pasos:**

**Paso A — Verificación previa antes de los DROP:**

- `current_database()` confirmó la base `food_store_copia` (no `foodstorecopia`).
- `responsable_deposito` contenía exactamente 2 filas del ejercicio: (801, 30) y (802, 31).
- `control_lote` contenía exactamente 3 filas del ejercicio: (501, 801), (502, 801),
  (503, 802).
- No se detectaron FK externas adicionales apuntando a los objetos a eliminar; la única
  dependencia existente era la FK interna de `control_lote` hacia `responsable_deposito`.

**Paso B — Eliminación en orden correcto (DROP RESTRICT, sin CASCADE):**

```sql
BEGIN;
DROP VIEW  IF EXISTS tpi_u4_rollback_lab.control_lote_almacen_compat;
DROP TABLE IF EXISTS tpi_u4_rollback_lab.control_lote;          -- C₂ antes que C₁
DROP TABLE IF EXISTS tpi_u4_rollback_lab.responsable_deposito;  -- C₁ ya sin dependientes
COMMIT;
```

Los tres `DROP` ejecutaron sin errores. Se utilizó `RESTRICT` (comportamiento por
defecto) en todos los casos; no se empleó `CASCADE` en ningún momento.

**Resultados verificados:**

- `responsable_deposito`: `to_regclass` devolvió **NULL**.
- `control_lote`: `to_regclass` devolvió **NULL**.
- Vista `control_lote_almacen_compat`: `to_regclass` devolvió **NULL**.

Evidencia: `TP4_unidad4/imagenes/tp4_u4_08_reversion_post_commit.png`

---

### T-10 Verificar integridad de `control_lote_almacen` tras la reversión — ✅ Completada

**Resultados verificados:**

- `SELECT COUNT(*) FROM control_lote_almacen` → **3 filas**. Los datos originales
  permanecen intactos.
- Los tres objetos revertidos devuelven **NULL** en `to_regclass`.

La verificación final confirmó que la reversión post-COMMIT eliminó únicamente los
objetos creados por el laboratorio y no afectó ningún dato preexistente.

Evidencia incluida en la misma captura de T-09:
`TP4_unidad4/imagenes/tp4_u4_08_reversion_post_commit.png`

---

## Fase 5 — Documentación de evidencias

### T-11 Capturar y registrar evidencias — 🔲 Pendiente

Las capturas existen en disco; resta incorporarlas al informe.

| Tarea | Archivo | Estado |
| :--- | :--- | :--- |
| T-06 + T-07 (vista compat + 0 diferencias) | `tp4_u4_01_evidencia_verificacion.jpg` | Captura tomada |
| T-08 (ROLLBACK explícito) | `tp4_u4_07_reversion_en_transaccion.png` | Captura tomada |
| T-09 + T-10 (reversión post-COMMIT + verificación final) | `tp4_u4_08_reversion_post_commit.png` | Captura tomada |

Acción pendiente: agregar las referencias a las tres capturas en las secciones
correspondientes de `TP4_unidad4.md`.

---

### T-12 Registrar la limitación de preservación de dependencias — 🔲 Pendiente

Confirmar que `TP4_unidad4.md` menciona:

- Que `{L,D} → R` no se preserva localmente en las tablas descompuestas.
- Que las restricciones declarativas actuales no impiden inserciones que la violen.
- Que para futuras inserciones se requiere un control adicional (trigger o vista
  materializada).
- Que esta limitación no invalida la prueba de reunión sin pérdida sobre datos
  históricos.

---

## Resumen de resultados para el informe integrador

| Verificación | Resultado |
| :--- | :--- |
| Filas en `control_lote_almacen` antes de migrar | 3 |
| Filas reconstruidas por la vista de compatibilidad | 3 (coinciden exactamente) |
| `filas_diferentes` (comparación con EXCEPT) | 0 |
| Duplicados detectados | 0 |
| Estado de `responsable_deposito` tras ROLLBACK | NULL (no existe) |
| Estado de `control_lote` tras ROLLBACK | NULL (no existe) |
| Estado de la vista tras ROLLBACK | NULL (no existe) |
| Filas en `control_lote_almacen` tras ROLLBACK | 3 (intactas) |
| Estado de `responsable_deposito` tras reversión post-COMMIT | NULL (eliminada con RESTRICT) |
| Estado de `control_lote` tras reversión post-COMMIT | NULL (eliminada con RESTRICT) |
| Estado de la vista tras reversión post-COMMIT | NULL (eliminada con RESTRICT) |
| Filas en `control_lote_almacen` tras reversión post-COMMIT | 3 (intactas) |

---

## Dependencias entre tareas

```
T-01 → T-02 → T-03 → T-04
                        ↓
               T-05 → T-06 → T-07
                                ↓
               T-08 (ejecutada antes de T-03 definitivo, sobre sesión aislada)
               T-09 → T-10
                        ↓
                      T-11 → T-12
```

- T-08 se ejecutó en una sesión separada con ROLLBACK antes del COMMIT de T-03.
- T-09 requería T-03 con COMMIT confirmado; se ejecutó después.
- T-11 y T-12 permanecen pendientes hasta que las capturas se incorporen a `TP4_unidad4.md`.
