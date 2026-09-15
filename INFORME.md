# Informe TP2 — Base de Datos 2

Repositorio: `https://github.com/Tomimartin/BaseDeDatos2`

Partes del trabajo:

- **Parte 0** — Protocolo de seguridad: `protocolo_seguridad.md`
- **Parte 1** — Restricciones de integridad: `base_food_store.sql` + informe
- **Parte 2** — Concurrencia: `informe_concurrencia.md`
- **Parte 3** — Lectura crítica: `ejercicio_lectura_critica.md`

---

## 1. Script de restricciones commiteado

El script commiteado es `base_food_store.sql` (PostgreSQL 17). Contiene el esquema
completo de la tienda (`forma_pago_enum`, `categoria`, `cliente`, `producto`,
`pedido`, `detalle_pedido`) con datos de ejemplo, más los índices.

### Restricciones de integridad del script

| Tabla | Constraint | Expresión | Spec que cumple |
|-------|------------|-----------|-----------------|
| `categoria` | `ck_categoria_nombre_no_blanco` | `CHECK (TRIM(nombre) <> '')` | Spec 1 |
| `producto` | `ck_producto_precio_positivo` | `CHECK (precio > 0)` | Spec 2 |
| `pedido` | `ck_pedido_fecha_no_futura` | `CHECK (fecha <= now())` | Spec 3 |

Otras restricciones preexistentes (sin cambios):

| Tabla | Constraint | Expresión |
|-------|-----------|-----------|
| `cliente` | `uq_cliente_email` | `UNIQUE (email)` |
| `producto` | `ck_producto_stock_no_negativo` | `CHECK (stock >= 0)` |
| `producto` | `fk_producto_categoria` | `FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria) ON DELETE RESTRICT` |
| `pedido` | `fk_pedido_cliente` | `FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT` |
| `detalle_pedido` | `pk_detalle_pedido` | `PRIMARY KEY (id_pedido, id_producto)` |
| `detalle_pedido` | `ck_detalle_cantidad_positiva` | `CHECK (cantidad > 0)` |
| `detalle_pedido` | `ck_detalle_precio_no_negativo` | `CHECK (precio_unitario >= 0)` |
| `detalle_pedido` | `fk_detalle_pedido` | `FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE CASCADE` |
| `detalle_pedido` | `fk_detalle_producto` | `FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT` |

### Evidencia de verificación

Las pruebas de existencia de las restricciones y los casos válidos e inválidos
con sus salidas completas están en `verificacion_restricciones.md`.

---

## 2. Historial de commits (`git log`)

```
d8cada8 Initial commit
5858cd8 Agrega esquema de la base de datos
c68b325 Agrega informe del TP2 con DUIA
e3f4c05 actualizo los archivos del TP2
6561f18 Completa resultados reales de los escenarios de concurrencia
```

Detalle del commit que incorpora las restricciones:

```
Commit: 5858cd8
Mensaje: Agrega esquema de la base de datos
Autor: Santiago Tomas Martin Montaner <santitomimartin14@gmail.com>
Fecha: 2026-09-08 15:42:55 -0300
Archivos: tp2/AGENTS.md, tp2/schema_food_store - copia.sql, tp2/schema_food_store.sql
```

Aclaración sobre la evolución del esquema:

- El commit `5858cd8` incorporó el esquema con las restricciones en
  `tp2/schema_food_store.sql`.
- El commit `e3f4c05` reorganizó el repositorio: el esquema quedó como
  `base_food_store.sql` (dump de PostgreSQL generado desde la base real sobre la
  que se aplicaron las restricciones).
- El commit `6561f18` volcó los resultados reales de los escenarios de concurrencia
  y `git push` subió todo a `origin/main` del repositorio remoto.

### Comando y salida real de la verificación

```
$ git log --oneline --all
6561f18 Completa resultados reales de los escenarios de concurrencia
e3f4c05 actualizo los archivos del TP2
c68b325 Agrega informe del TP2 con DUIA
5858cd8 Agrega esquema de la base de datos
d8cada8 Initial commit
```

---

## 3. DUIA — Documento Único de Informe de Actividad (Parte 1)

### 3.1 Herramienta

**OpenCode** — asistente de ingeniería de software por línea de comandos (CLI),
utilizado para interpretar los requirements, modificar el esquema SQL, configurar
el repositorio Git y verificar los cambios.

### 3.2 Specs (texto exacto dado por el usuario)

1. `en la tabla categoría, la columna "nombre" no puede contener una cadena vacía ni unicamente espacio`
2. `en la tabla producto, la columna "precio" debe ser mayor a 0`
3. `en la tabla "pedido", la columna "fecha" no puede representar una fecha y hora posterior al momento de registrar el pedido`

### 3.3 Resumen de lo propuesto

Frente a cada spec, se propuso la siguiente solución sobre `base_food_store.sql`:

- **Spec 1** — Agregar una restricción `CHECK (TRIM(nombre) <> '')` en la tabla
  `categoria` (nombre de constraint: `ck_categoria_nombre_no_blanco`). Se eligió
  `TRIM()` porque rechaza tanto la cadena vacía `''` como las cadenas de solo espacios.
  La columna ya era `NOT NULL`, por lo que no hacía falta reforzar nulidad.
- **Spec 2** — Modificar la constraint existente de `producto.precio`: cambiar
  `CHECK (precio >= 0)` por `CHECK (precio > 0)` y renombrarla de
  `ck_producto_precio_no_negativo` a `ck_producto_precio_positivo` para que el
  nombre refleje el nuevo requisito.
- **Spec 3** — Agregar en `pedido` la restricción `CHECK (fecha <= now())`
  (`ck_pedido_fecha_no_futura`). Aclaración: como `fecha` tiene `DEFAULT now()`,
  la restricción prohíbe insertar fechas futuras de forma explícita; los registros
  que no especifican fecha usan la hora actual por defecto y nunca fallan el check.

### 3.4 Lo aceptado y generado

| Spec | Cambio aceptado | Estado |
|------|-----------------|--------|
| Spec 1 | `CONSTRAINT ck_categoria_nombre_no_blanco CHECK (TRIM(nombre) <> '')` agregada en `categoria` | Generado y commiteado |
| Spec 2 | `precio >= 0` → `precio > 0` con rename a `ck_producto_precio_positivo` | Generado y commiteado |
| Spec 3 | `CONSTRAINT ck_pedido_fecha_no_futura CHECK (fecha <= now())` agregada en `pedido` | Generado y commiteado |

Las tres restricciones se aplicaron sobre la base `foodstorecopia` (copia de
trabajo) con `ALTER TABLE`, se verificaron con casos válidos e inválidos y el
esquema resultante se volcó a `base_food_store.sql`.

Trabajo adicional realizado y aceptado:

- Configuración de Git: el repositorio local estaba inicializado; se clonó
  `https://github.com/Tomimartin/BaseDeDatos2` reemplazando la carpeta (con
  backup previo del trabajo en `C:\Users\ignac\AppData\Local\Temp\opencode\BaseDeDatos2_backup`).
- Se resolvió un conflicto de autenticación: el Git Credential Manager guardaba
  la sesión de la cuenta `Nacho5901`, que no tiene permisos sobre el repo. Se
  deslogueó con `git credential-manager github logout Nacho5901` y se re-pusheó
  autenticando con la cuenta `Tomimartin`.

Las DUIA de la Parte 2 y de la Parte 3 se encuentran en
`informe_concurrencia.md` y `ejercicio_lectura_critica.md` respectivamente.