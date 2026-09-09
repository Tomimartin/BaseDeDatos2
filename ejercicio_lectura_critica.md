# Ejercicio de lectura crítica

## Script 1

### Script original

```sql
UPDATE funcion
SET activa = FALSE;
```

### Qué haría realmente

El script pondría `activa = FALSE` en **todas las filas** de la tabla `funcion`, porque no tiene cláusula `WHERE`.

### Por qué está mal

La consigna dice que solamente deben darse de baja las funciones correspondientes a películas retiradas de cartel. Sin una condición, se desactivan todas las funciones.

### Versión corregida

```sql
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id
    FROM pelicula
    WHERE retirada = TRUE
);
```

---

## Script 2

### Script original

```sql
DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id
    FROM producto
);
```

### Qué haría realmente

Busca borrar las categorías que no aparecen asociadas a ningún producto.

El problema es que, si la subconsulta devuelve algún `categoria_id` con valor `NULL`, el uso de `NOT IN` puede hacer que la condición no resulte verdadera para ninguna fila y no se borre lo esperado.

### Por qué está mal

La consulta depende de que la subconsulta no contenga valores `NULL`. Para comprobar de forma segura que una categoría no tiene productos asociados, conviene usar `NOT EXISTS`.

### Versión corregida

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

---

## Conclusión

Los dos ejemplos muestran por qué un script debe leerse antes de ejecutarse. El primero puede modificar muchas más filas de las necesarias por no tener `WHERE`, y el segundo puede dar un resultado incorrecto por el comportamiento de `NOT IN` frente a valores `NULL`.
