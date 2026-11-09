# Requirements — Migración de ControlLoteAlmacen a FNBC

## Contexto

La tabla `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` del esquema
`public` en la base `foodstorecopia` viola la Forma Normal de Boyce-Codd (FNBC). La
migración la reemplaza por dos tablas en FNBC, preservando todos los datos originales y
permitiendo revertir los cambios si algo falla.

El trabajo se realiza exclusivamente sobre una **base de prueba aislada** (nunca sobre
`foodstorecopia`). Esa base se prepara con tablas maestras mínimas creadas expresamente
para el ejercicio; no se utiliza `data.sql` del TP2 porque ese archivo no crea las tablas
`lote`, `deposito` ni `usuario` con los IDs requeridos. No se elimina ninguna tabla ni
dato durante las pruebas.

---

## Dependencias funcionales del dominio

Sea la relación `C(L, D, R)` donde:
- `L` = `lote_id`
- `D` = `deposito_id`
- `R` = `responsable_control_id`

El conjunto mínimo de dependencias funcionales `F` es:

| Dependencia | Origen en el dominio |
| :--- | :--- |
| `{L, D} → R` | Un par lote-depósito tiene un único responsable asignado |
| `R → D` | Cada responsable pertenece a un único depósito |

Estas reglas surgen de las reglas de negocio de Food Store y deben cumplirse en toda
instancia válida de la relación.

---

## Claves candidatas

Con `F = { LD → R, R → D }`:

| Conjunto | Clausura | Resultado |
| :--- | :--- | :--- |
| `{L}` | `{L}` | No es superclave |
| `{D}` | `{D}` | No es superclave |
| `{R}` | `{R, D}` | No es superclave |
| `{L, D}` | `{L, D, R}` | **Clave candidata** |
| `{L, R}` | `{L, R, D}` | **Clave candidata** |
| `{L, D, R}` | `{L, D, R}` | Superclave no mínima |

Los tres atributos son **primos** porque todos aparecen en alguna clave candidata.

---

## Violación de FNBC

FNBC requiere que, en toda dependencia funcional no trivial `X → Y`, el determinante `X`
sea superclave. La dependencia `R → D` la viola: `R⁺ = {R, D}` no contiene `L`, por lo
que `R` no es superclave. La relación no cumple FNBC aunque todos sus atributos sean primos.

---

## Anomalías que motivan la migración

**Inserción:** No se puede registrar que el responsable 803 pertenece al depósito 32 sin
asignarle un lote concreto, porque `lote_id` es parte de la PK y es obligatorio.

**Borrado:** Eliminar la última fila donde aparece el responsable 802 destruye también la
información de a qué depósito pertenece, aunque ese dato sea independiente del control de lote.

**Actualización:** Si el responsable 801 tiene múltiples filas y se cambia su depósito en
solo algunas de ellas, se viola `R → D`. Para mantener la consistencia hay que actualizar
todas sus filas simultáneamente.

---

## Requisitos funcionales

| ID | Requisito |
| :--- | :--- |
| RF-01 | Descomponer `control_lote_almacen` en dos relaciones que cumplan FNBC. |
| RF-02 | La descomposición debe ser **sin pérdida de información** (lossless join). |
| RF-03 | Todas las filas de `control_lote_almacen` deben ser recuperables mediante JOIN sobre las tablas descompuestas. |
| RF-04 | El script de migración debe ejecutarse en una única transacción con `BEGIN / COMMIT`. |
| RF-05 | Una vista de compatibilidad debe reconstruir la relación original para uso transitorio. |
| RF-06 | La verificación automática debe arrojar `filas_diferentes = 0` al finalizar la migración. |
| RF-07 | Debe existir un plan de reversión documentado que permita volver al estado anterior **antes** y **después** de un `COMMIT`. |
| RF-08 | La limitación de preservación de dependencias para futuras inserciones debe quedar documentada. |

---

## Requisitos no funcionales

| ID | Requisito |
| :--- | :--- |
| RNF-01 | El trabajo se ejecuta únicamente sobre una base de prueba aislada, preparada con tablas maestras mínimas propias. |
| RNF-02 | No se modifican ni eliminan datos en `foodstorecopia`. |
| RNF-03 | `control_lote_almacen` se conserva durante todo el proceso de prueba; no se elimina. |
| RNF-04 | La migración debe ser reversible mediante un script SQL documentado. |
| RNF-05 | No se utiliza `DROP … CASCADE`. Cada objeto se elimina por nombre explícito y en el orden que respeta las dependencias de FK. |

---

## Limitación de preservación de dependencias

La descomposición no preserva localmente la dependencia `{L, D} → R`. Las PK y FK de las
tablas resultantes permiten la existencia de dos filas en `control_lote` que asocien el
mismo `lote_id` con dos responsables distintos del mismo depósito, violando la regla
original. Para garantizar esa regla en nuevas inserciones se necesita un control
inter-tabla (trigger o restricción diferida) que no puede expresarse solo con restricciones
declarativas sobre cada tabla por separado. Esta limitación no afecta la prueba de reunión
sin pérdida sobre datos ya existentes.
