# Informe de concurrencia

Las pruebas se ejecutaron en dos sesiones de `psql` sobre PostgreSQL 17.11
(sistema Windows, cliente local). Cada escenario usa dos archivos de script
(`*_sesionA.sql` y `*_sesionB.sql`) ejecutados en paralelo; a continuación se
transcriben los comandos y sus salidas completas.

---

## 1. Lectura no repetible

### Cómo se reprodujo

**Sesión A** (`esc1_sesionA.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION A - LECTURA NO REPETIBLE (READ COMMITTED)
\echo ============================================
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
\echo ===== PRIMERA LECTURA (A) =====
SELECT stock AS stock_leido_1 FROM producto WHERE nombre = 'Coca Cola 2L';
\echo ===== Esperando 3 segundos para que B actualice... =====
SELECT pg_sleep(3);
\echo ===== SEGUNDA LECTURA (A) =====
SELECT stock AS stock_leido_2 FROM producto WHERE nombre = 'Coca Cola 2L';
COMMIT;
\echo ===== FIN SESION A =====
```

**Sesión B** (`esc1_sesionB.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION B - UPDATE COCA COLA (READ COMMITTED)
\echo ============================================
\echo ===== Esperando 1 segundo antes de actualizar =====
SELECT pg_sleep(1);
BEGIN;
UPDATE producto SET stock = 30 WHERE nombre = 'Coca Cola 2L';
COMMIT;
\echo ===== FIN SESION B =====
```

### Salida real — Sesión A

```
============================================
SESSION A - LECTURA NO REPETIBLE (READ COMMITTED)
============================================
BEGIN
SET
===== PRIMERA LECTURA (A) =====
 stock_leido_1
---------------
            20
(1 row)

===== Esperando 3 segundos para que B actualice... =====
 pg_sleep
----------
 
(1 row)

===== SEGUNDA LECTURA (A) =====
 stock_leido_2
---------------
            30
(1 row)

COMMIT
===== FIN SESION A =====
```

### Salida real — Sesión B

```
============================================
SESSION B - UPDATE COCA COLA (READ COMMITTED)
============================================
===== Esperando 1 segundo antes de actualizar =====
 pg_sleep
----------
 
(1 row)

BEGIN
UPDATE 1
COMMIT
===== FIN SESION B =====
```

### Explicación

Con `READ COMMITTED`, PostgreSQL puede ver cambios confirmados por otras
transacciones entre una consulta y la siguiente. Por eso una misma fila puede
devolver valores distintos dentro de la misma transacción: la primera lectura ve
`20` y, tras el `COMMIT` de B que actualiza a `30`, la segunda lectura ve `30`.

### Verificación con `REPEATABLE READ`

**Sesión A** (`esc1RR_sesionA.sql`): idéntica a la anterior pero con
`SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;`. La **Sesión B** vuelve a
hacer `UPDATE ... SET stock = 30 ... COMMIT` (misma salida que la sesión B de
arriba).

Salida real — Sesión A:

```
============================================
SESSION A - VERIFICACION REPEATABLE READ
============================================
BEGIN
SET
===== PRIMERA LECTURA (A) =====
 stock_leido_1
---------------
            20
(1 row)

===== Esperando 3 segundos para que B actualice... =====
 pg_sleep
----------
 
(1 row)

===== SEGUNDA LECTURA (A) =====
 stock_leido_2
---------------
            20
(1 row)

COMMIT
===== FIN SESION A =====
```

### Conclusión

La explicación se confirmó. `REPEATABLE READ` mantiene la misma instantánea de
datos durante toda la transacción, por lo que la segunda lectura sigue viendo
`20` a pesar del `COMMIT` de B.

---

## 2. Lectura fantasma

### Cómo se reprodujo

**Sesión A** (`esc2_sesionA.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION A - LECTURA FANTASMA (READ COMMITTED)
\echo ============================================
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
\echo ===== PRIMER COUNT (A) =====
SELECT COUNT(*) AS count_inicial FROM producto WHERE precio > 3000;
\echo ===== Esperando 3 segundos para que B inserte... =====
SELECT pg_sleep(3);
\echo ===== SEGUNDO COUNT (A) =====
SELECT COUNT(*) AS count_final FROM producto WHERE precio > 3000;
COMMIT;
\echo ===== FIN SESION A =====
```

**Sesión B** (`esc2_sesionB.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION B - INSERT PRODUCTO FANTASMA TP
\echo ============================================
\echo ===== Esperando 1 segundo antes de insertar =====
SELECT pg_sleep(1);
BEGIN;
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria)
VALUES (
    'Producto Fantasma TP',
    'Producto de prueba',
    4500,
    5,
    TRUE,
    (SELECT id_categoria
     FROM categoria
     WHERE nombre = 'Bebidas'
     LIMIT 1)
);
COMMIT;
\echo ===== FIN SESION B =====
```

### Salida real — Sesión A

```
============================================
SESSION A - LECTURA FANTASMA (READ COMMITTED)
============================================
BEGIN
SET
===== PRIMER COUNT (A) =====
 count_inicial
---------------
             1
(1 row)

===== Esperando 3 segundos para que B inserte... =====
 pg_sleep
----------
 
(1 row)

===== SEGUNDO COUNT (A) =====
 count_final
-------------
           2
(1 row)

COMMIT
===== FIN SESION A =====
```

### Salida real — Sesión B

```
============================================
SESSION B - INSERT PRODUCTO FANTASMA TP
============================================
===== Esperando 1 segundo antes de insertar =====
 pg_sleep
----------
 
(1 row)

BEGIN
INSERT 0 1
COMMIT
===== FIN SESION B =====
```

### Explicación

Con `READ COMMITTED`, cada consulta puede ver filas nuevas confirmadas por otra
sesión entre consultas. La fila insertada por B (`precio = 4500 > 3000`) aparece
en el segundo `COUNT`, que pasa de `1` a `2`: es la lectura fantasma.

### Verificación con `REPEATABLE READ`

**Sesión A** (`esc2RR_sesionA.sql`): idéntica con `REPEATABLE READ`. La **Sesión B**
inserta el mismo producto fantasma (misma salida de arriba).

Salida real — Sesión A:

```
============================================
SESSION A - VERIFICACION LECTURA FANTASMA (REPEATABLE READ)
============================================
BEGIN
SET
===== PRIMER COUNT (A) =====
 count_inicial
---------------
             1
(1 row)

===== Esperando 3 segundos para que B inserte... =====
 pg_sleep
----------
 
(1 row)

===== SEGUNDO COUNT (A) =====
 count_final
-------------
           1
(1 row)

COMMIT
===== FIN SESION A =====
```

### Conclusión

La explicación se confirmó. `REPEATABLE READ` mantiene la instantánea de la
transacción, por lo que la fila nueva del producto fantasma no aparece en el
segundo `COUNT`.

---

## 3. Espera por bloqueo

### Cómo se reprodujo (verificación con `COMMIT`)

**Sesión A** (`esc3_sesionA.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION A - BLOQUEO FOR UPDATE
\echo ============================================
BEGIN;
\echo ===== A toma el lock sobre Coca Cola 2L =====
SELECT id_producto, nombre, stock FROM producto WHERE nombre = 'Coca Cola 2L' FOR UPDATE;
\echo ===== A mantiene el lock 5 segundos... =====
SELECT pg_sleep(5) AS espera_A;
\echo ===== A COMMIT libera el lock =====
COMMIT;
\echo ===== FIN SESION A =====
```

**Sesión B** (`esc3_sesionB.sql`)

```sql
\set QUIET off
\echo ============================================
\echo SESSION B - ESPERA POR BLOQUEO (FOR UPDATE) - con clock_timestamp
\echo ============================================
\echo ===== Esperando 1 segundo para que A tome el lock =====
SELECT pg_sleep(1);
BEGIN;
SELECT clock_timestamp() AS hora_before_lock;
\echo ===== B intenta tomar el lock (deberia esperar) =====
SELECT id_producto, nombre, stock FROM producto WHERE nombre = 'Coca Cola 2L' FOR UPDATE;
SELECT clock_timestamp() AS hora_after_lock;
\echo ===== B obtuvo el lock tras el COMMIT de A =====
SELECT stock AS stock_visto_B FROM producto WHERE nombre = 'Coca Cola 2L';
COMMIT;
\echo ===== FIN SESION B =====
```

### Salida real — Sesión A

```
============================================
SESSION A - BLOQUEO FOR UPDATE
============================================
BEGIN
===== A toma el lock sobre Coca Cola 2L =====
 id_producto |    nombre    | stock
-------------+--------------+-------
           1 | Coca Cola 2L |    20
(1 row)

===== A mantiene el lock 5 segundos... =====
 espera_a
----------
 
(1 row)

===== A COMMIT libera el lock =====
COMMIT
===== FIN SESION A =====
```

### Salida real — Sesión B

```
============================================
SESSION B - ESPERA POR BLOQUEO (FOR UPDATE)
============================================
===== Esperando 1 segundo para que A tome el lock =====
 pg_sleep
----------
 
(1 row)

BEGIN
       hora_before_lock
-------------------------------
 2026-09-15 00:19:10.309466-03
(1 row)

===== B intenta tomar el lock (deberia esperar) =====
 id_producto |    nombre    | stock
-------------+--------------+-------
           1 | Coca Cola 2L |    20
(1 row)

        hora_after_lock
-------------------------------
 2026-09-15 00:19:14.319359-03
(1 row)

===== B obtuvo el lock tras el COMMIT de A =====
 stock_visto_b
---------------
            20
(1 row)

COMMIT
===== FIN SESION B =====
```

### Verificación con `ROLLBACK`

**Sesión A** (`esc3_rollback_sesionA.sql`): idéntica pero termina con `ROLLBACK;`
en lugar de `COMMIT;`. La **Sesión B** es la misma de arriba.

Salida real — Sesión B (con ROLLBACK en A):

```
============================================
SESSION B - ESPERA POR BLOQUEO (FOR UPDATE) - con clock_timestamp
============================================
===== Esperando 1 segundo para que A tome el lock =====
 pg_sleep
----------
 
(1 row)

BEGIN
       hora_before_lock
-------------------------------
 2026-09-15 00:19:18.004879-03
(1 row)

===== B intenta tomar el lock (deberia esperar) =====
 id_producto |    nombre    | stock
-------------+--------------+-------
           1 | Coca Cola 2L |    20
(1 row)

        hora_after_lock
-------------------------------
 2026-09-15 00:19:21.895109-03
(1 row)

===== B obtuvo el lock tras el COMMIT de A =====
 stock_visto_b
---------------
            20
(1 row)

COMMIT
===== FIN SESION B =====
```

### Explicación

`FOR UPDATE` bloquea la fila para operaciones incompatibles. La Sesión B no pudo
tomar el bloqueo hasta que la Sesión A terminó (con `COMMIT` o `ROLLBACK`), que
es cuando se libera el lock. Se midió con `clock_timestamp()`:

- Con `COMMIT` en A: espera de `00:19:10.309` a `00:19:14.319` (~4,0 segundos).
- Con `ROLLBACK` en A: espera de `00:19:18.004` a `00:19:21.895` (~3,9 segundos).

### Conclusión

La explicación se confirmó. El problema se controla mediante bloqueos de fila con
`FOR UPDATE`, y la liberación ocurre tanto al hacer `COMMIT` como `ROLLBACK`.

---

## Resumen de resultados

| Escenario | Nivel | 1ª lectura | 2ª lectura | Lectura no repetible / fantasma |
|-----------|-------|-----------|-----------|---------------------------------|
| Lectura no repetible | READ COMMITTED | 20 | 30 | Sí |
| Lectura no repetible | REPEATABLE READ | 20 | 20 | No |
| Lectura fantasma | READ COMMITTED | 1 | 2 | Sí |
| Lectura fantasma | REPEATABLE READ | 1 | 1 | No |
| Espera por bloqueo | Cualquiera | lock esperado | lock tras COMMIT/ROLLBACK | Controlada |

---

## DUIA — Parte 2

| Campo | Detalle |
|---|---|
| Herramienta | ChatGPT |
| Uso realizado | Ayuda para generar las consultas y explicar los escenarios de concurrencia. |
| Escenarios | Lectura no repetible, lectura fantasma y espera por bloqueo. |
| Qué se aceptó | Las consultas y explicaciones adaptadas al esquema Food Store. |
| Qué se modificó | Se ajustaron nombres de tablas, columnas y productos al esquema real. |
| Verificación | Las pruebas se realizaron en dos sesiones de psql sobre PostgreSQL 17.11, con las salidas completas transcriptas arriba. |