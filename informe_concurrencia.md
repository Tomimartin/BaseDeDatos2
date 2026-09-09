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

**Resultado real:** `[COMPLETAR]`

### Explicación de la IA
Con `READ COMMITTED`, PostgreSQL puede ver cambios confirmados por otras transacciones entre una consulta y la siguiente. Por eso una misma fila puede devolver valores distintos dentro de la misma transacción.

### Verificación
Se repitió el caso con:

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

En este nivel, la segunda lectura mantuvo el mismo valor durante la transacción.

**Resultado real:** `[COMPLETAR]`

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

**Resultado real:** `[COMPLETAR]`

### Explicación de la IA
Con `READ COMMITTED`, cada consulta puede ver nuevas filas confirmadas por otra sesión. Esa fila nueva es la lectura fantasma.

### Verificación
Se repitió el mismo experimento con `REPEATABLE READ`. Dentro de la transacción, el segundo `COUNT` mantuvo el mismo resultado.

**Resultado real:** `[COMPLETAR]`

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

**Resultado real:** `[COMPLETAR]`

### Explicación de la IA
`FOR UPDATE` bloquea la fila para operaciones incompatibles. Si otra sesión intenta bloquear la misma fila, debe esperar hasta que la primera transacción termine.

### Verificación
Se repitió el caso usando `ROLLBACK` en la Sesión A. La Sesión B también pudo continuar cuando se liberó el bloqueo.

**Resultado real:** `[COMPLETAR]`

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
