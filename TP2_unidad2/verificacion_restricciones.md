# Verificación de restricciones — evidencias de ejecución

Base: `foodstorecopia` (copia de trabajo local, PostgreSQL 17.11).
Servidor local `localhost:5432`, usuario `postgres`.

Comandos ejecutados con `psql` desde PowerShell:

```powershell
psql -U postgres -h localhost -d foodstorecopia
```

---

## 1. Aplicación de las restricciones

```sql
ALTER TABLE public.categoria
    ADD CONSTRAINT ck_categoria_nombre_no_blanco CHECK (TRIM(nombre) <> '');

ALTER TABLE public.producto
    DROP CONSTRAINT ck_producto_precio_no_negativo;

ALTER TABLE public.producto
    ADD CONSTRAINT ck_producto_precio_positivo CHECK (precio > 0);

ALTER TABLE public.pedido
    ADD CONSTRAINT ck_pedido_fecha_no_futura CHECK (fecha <= now());
```

### Salida real

```
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
```

---

## 2. Verificación de existencia de las restricciones

```sql
SELECT
    conrelid::regclass AS tabla,
    conname,
    pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid IN ('public.categoria'::regclass, 'public.producto'::regclass, 'public.pedido'::regclass)
  AND contype = 'c'
ORDER BY conrelid::regclass::text, conname;
```

### Salida real

```
   tabla   |            conname            |                  definicion
-----------+-------------------------------+----------------------------------------------
 categoria | ck_categoria_nombre_no_blanco | CHECK ((TRIM(BOTH FROM nombre) <> ''::text))
 pedido    | ck_pedido_fecha_no_futura     | CHECK ((fecha <= now()))
 producto  | ck_producto_precio_positivo   | CHECK ((precio > (0)::numeric))
 producto  | ck_producto_stock_no_negativo | CHECK ((stock >= 0))
(4 rows)
```

---

## 3. Casos válidos e inválidos

Cada caso se ejecuta dentro de `BEGIN` ... `ROLLBACK` para no alterar los datos
reales de la base.

### Spec 1 — `categoria.nombre` no vacío ni solo espacios

#### Caso válido (debe insertar)

```sql
BEGIN;
INSERT INTO public.categoria (nombre, activo) VALUES ('Cafe', true);
ROLLBACK;
```

```
BEGIN
INSERT 0 1
ROLLBACK
```

#### Caso inválido — nombre de solo espacios (debe fallar)

```sql
BEGIN;
INSERT INTO public.categoria (nombre, activo) VALUES ('   ', true);
ROLLBACK;
```

```
BEGIN
ERROR:  el nuevo registro para la relación «categoria» viola la restricción «check» «ck_categoria_nombre_no_blanco»
DETAIL:  La fila que falla contiene (6,    , t).
ROLLBACK
```

#### Caso inválido — cadena vacía (debe fallar)

```sql
BEGIN;
INSERT INTO public.categoria (nombre, activo) VALUES ('', true);
ROLLBACK;
```

```
BEGIN
ERROR:  el nuevo registro para la relación «categoria» viola la restricción «check» «ck_categoria_nombre_no_blanco»
DETAIL:  La fila que falla contiene (7, , t).
ROLLBACK
```

---

### Spec 2 — `producto.precio` mayor a 0

#### Caso válido (debe insertar)

```sql
BEGIN;
INSERT INTO public.producto (nombre, precio, stock, activo, id_categoria)
VALUES ('Cafe molido 250g', 1500.00, 10, true, 1);
ROLLBACK;
```

```
BEGIN
INSERT 0 1
ROLLBACK
```

#### Caso inválido — precio 0 (debe fallar)

```sql
BEGIN;
INSERT INTO public.producto (nombre, precio, stock, activo, id_categoria)
VALUES ('Cafe molido 250g', 0.00, 10, true, 1);
ROLLBACK;
```

```
BEGIN
ERROR:  el nuevo registro para la relación «producto» viola la restricción «check» «ck_producto_precio_positivo»
DETAIL:  La fila que falla contiene (12, Cafe molido 250g, null, 0.00, 10, t, 1).
ROLLBACK
```

#### Caso inválido — precio negativo (debe fallar)

```sql
BEGIN;
INSERT INTO public.producto (nombre, precio, stock, activo, id_categoria)
VALUES ('Cafe molido 250g', -50.00, 10, true, 1);
ROLLBACK;
```

```
BEGIN
ERROR:  el nuevo registro para la relación «producto» viola la restricción «check» «ck_producto_precio_positivo»
DETAIL:  La fila que falla contiene (13, Cafe molido 250g, null, -50.00, 10, t, 1).
ROLLBACK
```

---

### Spec 3 — `pedido.fecha` no posterior al momento de registro

#### Caso válido — fecha actual (debe insertar)

```sql
BEGIN;
INSERT INTO public.pedido (fecha, forma_pago, id_cliente)
VALUES (now(), 'EFECTIVO', 1);
ROLLBACK;
```

```
BEGIN
INSERT 0 1
ROLLBACK
```

#### Caso inválido — fecha futura (debe fallar)

```sql
BEGIN;
INSERT INTO public.pedido (fecha, forma_pago, id_cliente)
VALUES (now() + interval '1 day', 'EFECTIVO', 1);
ROLLBACK;
```

```
BEGIN
ERROR:  el nuevo registro para la relación «pedido» viola la restricción «check» «ck_pedido_fecha_no_futura»
DETAIL:  La fila que falla contiene (5, 2026-09-16 00:16:01.821565-03, EFECTIVO, 1).
ROLLBACK
```

---

## Conclusión

- Las tres restricciones existen en la base (`Verificación de existencia`).
- Todos los casos válidos fueron aceptados (`INSERT 0 1`).
- Todos los casos inválidos fueron rechazados con el mensaje de error correspondiente
  a la constraint esperada.
- Las pruebas no modificaron los datos: cada caso se revirtió con `ROLLBACK`.