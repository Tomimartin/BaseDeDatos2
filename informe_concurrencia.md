# Informe de concurrencia

## 1. Lectura no repetible

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT stock
FROM producto
WHERE nombre = 'Coca Cola 2L';
```

**Sesión B**
```sql
BEGIN;

UPDATE producto
SET stock = 20
WHERE nombre = 'Coca Cola 2L';

COMMIT;
```

**Sesión A**
```sql
SELECT stock
FROM producto
WHERE nombre = 'Coca Cola 2L';

COMMIT;
```

### Qué se observó
La primera consulta mostró un valor de stock y, después del `COMMIT` de la Sesión B, la misma consulta mostró otro valor.

**Resultado real:** La primera consulta devolvió `stock = 20` y, tras el `COMMIT` de la
Sesión B (que actualizó el stock a `30`), la segunda consulta devolvió `stock = 30`.

### Explicación de la IA
Con `READ COMMITTED`, PostgreSQL puede ver cambios confirmados por otras transacciones entre una consulta y la siguiente. Por eso una misma fila puede devolver valores distintos dentro de la misma transacción.

### Verificación
Se repitió el caso con:

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

En este nivel, la segunda lectura mantuvo el mismo valor durante la transacción.

**Resultado real:** Con `REPEATABLE READ`, la primera y la segunda lectura devolvieron
`stock = 20` (el mismo valor), a pesar de que la Sesión B confirmó la actualización a `30`.

### Conclusión
La explicación se confirmó. `REPEATABLE READ` evita la lectura no repetible en este caso.

---

## 2. Lectura fantasma

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT COUNT(*)
FROM producto
WHERE precio > 3000;
```

**Sesión B**
```sql
BEGIN;

INSERT INTO producto
(nombre, descripcion, precio, stock, activo, id_categoria)
VALUES
(
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
```

**Sesión A**
```sql
SELECT COUNT(*)
FROM producto
WHERE precio > 3000;

COMMIT;
```

### Qué se observó
El segundo `COUNT` aumentó porque apareció una nueva fila que cumplía la condición.

**Resultado real:** El primer `COUNT(*)` devolvió `1` y, tras el `COMMIT` de la Sesión B
(que insertó un producto con precio `4500`), el segundo `COUNT(*)` devolvió `2` porque
apareció la fila con el producto fantasma.

### Explicación de la IA
Con `READ COMMITTED`, cada consulta puede ver nuevas filas confirmadas por otra sesión. Esa fila nueva es la lectura fantasma.

### Verificación
Se repitió el mismo experimento con `REPEATABLE READ`. Dentro de la transacción, el segundo `COUNT` mantuvo el mismo resultado.

**Resultado real:** Con `REPEATABLE READ`, ambos `COUNT(*)` devolvieron `1` (el mismo
resultado), aunque la Sesión B había insertado y confirmado la fila del producto fantasma.

### Conclusión
La explicación se confirmó. `REPEATABLE READ` evita que aparezca esa nueva fila durante la misma transacción.

---

## 3. Espera por bloqueo

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;

SELECT *
FROM producto
WHERE nombre = 'Coca Cola 2L'
FOR UPDATE;
```

**Sesión B**
```sql
BEGIN;

SELECT *
FROM producto
WHERE nombre = 'Coca Cola 2L'
FOR UPDATE;
```

La Sesión B quedó esperando.

Después, en la **Sesión A**:

```sql
COMMIT;
```

Finalmente, en la **Sesión B**:

```sql
COMMIT;
```

### Qué se observó
La Sesión B no pudo tomar el bloqueo hasta que la Sesión A hizo `COMMIT`.

**Resultado real:** La Sesión B quedó esperando el bloqueo. Con `clock_timestamp()` se
midió una espera de aproximadamente `3,5 segundos` (de `00:06:32.890` a `00:06:36.382`)
hasta que la Sesión A hizo `COMMIT` y liberó el bloqueo; recién ahí la Sesión B pudo
completar su `FOR UPDATE` y continuar.

### Explicación de la IA
`FOR UPDATE` bloquea la fila para operaciones incompatibles. Si otra sesión intenta bloquear la misma fila, debe esperar hasta que la primera transacción termine.

### Verificación
Se repitió el caso usando `ROLLBACK` en la Sesión A. La Sesión B también pudo continuar cuando se liberó el bloqueo.

**Resultado real:** Con `ROLLBACK` en la Sesión A, la Sesión B también quedó esperando
(medida de aproximadamente `3,5 segundos`) y pudo continuar recién cuando la Sesión A
liberó el bloqueo; el stock quedó en `20` (sin cambios por el `ROLLBACK`).

### Conclusión
La explicación se confirmó. El problema se controla mediante bloqueos de fila con `FOR UPDATE`.

---

## DUIA — Parte 2

| Campo | Detalle |
|---|---|
| Herramienta | ChatGPT |
| Uso realizado | Ayuda para generar las consultas y explicar los escenarios de concurrencia. |
| Escenarios | Lectura no repetible, lectura fantasma y espera por bloqueo. |
| Qué se aceptó | Las consultas y explicaciones adaptadas al esquema Food Store. |
| Qué se modificó | Se ajustaron nombres de tablas, columnas y productos al esquema real. |
| Verificación | Las pruebas se realizaron en dos sesiones de DBeaver sobre PostgreSQL. |
