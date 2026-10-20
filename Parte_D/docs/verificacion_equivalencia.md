# Parte D — Verificación de equivalencia (resultados agrupados validados)

**Base:** `foodstorecopia` (PostgreSQL). **Tablas:** `public.usuario` y `public.usuario_anon`.

## Evidencia disponible

La captura `docs/evidencias/46_parte_D_conteos_reales_anonimos_coinciden.png` prueba que hay **2 filas en cada tabla** y que el conteo global coincide (`true`). La tabla anónima usa `ROW_NUMBER() OVER (ORDER BY usuario.id)` para generar identificadores secuenciales y nombres sintéticos; no comparte el nombre original ni el ID real.

## Propuesta de OpenCode y corrección

OpenCode propuso agrupar por paridad de la posición ordinal en ambas tablas y comparar mediante `FULL OUTER JOIN`. Es compatible con las columnas disponibles, porque no existen `rol` ni `fecha_alta` en `usuario`.

**Error detectado:** OpenCode añadió `SELECT EVERY(coinciden) FROM comparacion;` después de una sentencia que había definido `comparacion` con `WITH`. En PostgreSQL, la CTE ya no existe al terminar esa sentencia. Se corrigió fusionando el detalle por grupos y la comprobación global con `BOOL_AND(coinciden) OVER ()` dentro de la misma sentencia. El SQL corregido está en `sql/parte_d_consultas_equivalencia_corregidas.sql`.

## Resultados agrupados — confirmados con pgAdmin

El 20/10/2026, el estudiante ejecutó la consulta consolidada y aportó una captura del resultado, guardada como `docs/evidencias/47_parte_D_equivalencia_grupos_confirmada.png`. La imagen contiene tanto los conteos por grupo como la comprobación global en cada fila:

| Grupo | Cantidad en usuario | Cantidad en usuario_anon | ¿Coinciden? | ¿Todos coinciden? |
|---|---:|---:|---|---|
| impar | 1 | 1 | `true` | `true` |
| par | 1 | 1 | `true` | `true` |

**Conclusión verificable:** para estos dos grupos artificiales los conteos de ambas tablas coinciden, y la condición de equivalencia global es verdadera. La evidencia adjunta documenta específicamente el resultado de la consulta de comparación consolidada; las salidas independientes de las consultas 1 y 2 no se aportaron como capturas separadas.

**Consulta utilizada:** `sql/parte_d_consultas_equivalencia_corregidas.sql`. La corrección al alcance de CTE propuesto por OpenCode se ejecutó satisfactoriamente.

## Alcance de la anonimización y de la prueba

Al anonimizar, no deben compartirse con una IA nombres, contactos, correos, teléfonos, contraseñas, hashes de credenciales, direcciones y otros datos identificables de clientes o usuarios, así como logs sin depurar que puedan exponer información sensible. Deben prepararse datos sintéticos y limitarse los campos necesarios.

**Limitación:** la paridad de la posición ordinal es un grupo artificial definido únicamente por el número de filas, no por una variable de negocio. Con 2 registros, la igualdad de conteos y grupos no acredita preservación de distribuciones empresariales, ni prueba anonimización irreversible. La correspondencia con el orden de los registros originales puede facilitar vinculación si se conoce información externa. Para un caso real se requieren más datos y evaluación de riesgo de reidentificación.
