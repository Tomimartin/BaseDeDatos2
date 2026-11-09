# TP8 - Food Store en la feria | Base de Datos II

**Unidad 8, ciclo 2026.** Proyecto integrador con PostgreSQL 17.11 y SQLite 3.37+.

## Alcance y estado de los archivos

Se completaron las pruebas SQL de la consigna 1 y los casos C1-C7 de la consigna 2. La carpeta contiene **solo los archivos que figuran en «Qué se entrega» de la consigna**.

**Archivo `movil/foodstore_movil.db` verificado:** se incluye ahora la **base SQLite original aportada por el estudiante**, en lugar de la reconstrucción previa. Se revisó en modo de solo lectura: `PRAGMA integrity_check = ok`, sin errores en `PRAGMA foreign_key_check`, con 50.010 productos en `producto_cache`, 50.010 filas en `snapshot_servidor`, 4 borradores, 5 ítems y 5 solicitudes. Los estados guardados son 2 `SIMULADO_APROBADO`, 1 `CONFLICTO` y 2 `RECHAZADO`. Se conservan en la base original las tablas auxiliares `snapshot_c2`, `snapshot_c3` y `snapshot_c4`, cada una con 50.010 filas, como evidencia de la evolución de la instantánea.

La instantánea `movil/servidor_snapshot.csv` **sí es el archivo real exportado desde PostgreSQL al inicio** (8/11/2026, aproximadamente 17:10 -03:00), **antes** de los cambios de C2-C4. Por eso conserva Coca Cola a $2.500, Sprite con stock 15 y Agua Mineral disponible. En la base SQLite original `snapshot_servidor` refleja el estado final de los casos: Coca Cola $2.800, Sprite stock 4 y Agua Mineral dada de baja. No confundir esa evolución con una discrepancia accidental.

**Verificación de los CSV históricos (08/11/2026):** se contrastaron los cuatro archivos originales aportados por el estudiante, cada uno con **50.010 productos e IDs únicos**. El CSV inicial coincide byte a byte con `movil/servidor_snapshot.csv`. Respecto del snapshot anterior, C2 modifica **solo el precio del producto 1** (250000 → 280000 centavos), C3 modifica **solo el stock del producto 2** (15 → 4) y C4 modifica **solo disponibilidad/baja lógica del producto 3** (`True/False` → `False/True`). `snapshot_c2`, `snapshot_c3` y `snapshot_c4` de la SQLite original coinciden exactamente con los archivos correspondientes, incluidas las fechas de captura. `snapshot_servidor` coincide con C4 en **todos los campos de negocio**; conserva fechas de captura anteriores para las filas no actualizadas porque los casos se aplicaron a los productos afectados, no se recargó toda la tabla. Los CSV históricos C2-C4 se usan como evidencia de verificación y **no se agregan al ZIP** porque la consigna de entrega pide un único CSV inicial.

**Revisión 3.c y 4.a:** OpenCode Plan permitió identificar tres hallazgos de U2, U3 y U8, contrastados con consultas reales; se descartó una afirmación con fundamento. Kiro se utilizó para revisar los requisitos EARS, el diseño y las tareas. OpenCode Build generó versiones alternativas, las comparó con los scripts existentes y verificó el parche NULL del semáforo sobre copias temporales. Las decisiones reales figuran en `docs/bitacora_ia.md`. **Pendiente personal:** completar identificación, fecha y firma y, si la cátedra lo requiere, el formulario DUIA oficial. El ensayo individual se realiza en clase.

## Estructura exacta de la entrega

```text
food-store/
├── README.md
├── movil/
│   ├── schema_sqlite.sql
│   ├── pruebas_sqlite.sql
│   ├── semaforo.sql
│   ├── servidor_snapshot.csv
│   └── foodstore_movil.db
└── docs/
    ├── informe.pdf
    ├── kiro/
    │   ├── requirements.md
    │   ├── design.md
    │   └── tasks.md
    ├── bitacora_ia.md
    └── DUIA.md
```

## Orden de reproducción desde cero

1. **PostgreSQL de PRUEBAS:** crear una copia independiente de `foodstorecopia` llamada `foodstore_tp8`. Nunca usar datos personales reales ni modificar la base original.
2. **Vista de exportación:** ejecutar en pgAdmin la vista siguiente (ajustada a las columnas `activo` de producto y categoría):

```sql
CREATE OR REPLACE VIEW public.v_snapshot_movil AS
SELECT p.id_producto AS producto_id,
       p.nombre,
       (p.precio * 100)::BIGINT AS precio_centavos,
       p.stock,
       (p.activo AND c.activo) AS disponible,
       NOT (p.activo AND c.activo) AS eliminado,
       NOW() AS capturado_en
FROM public.producto p
JOIN public.categoria c ON c.id_categoria = p.id_categoria;
```

3. **Exportar CSV:** `SELECT * FROM public.v_snapshot_movil ORDER BY producto_id;` y usar el botón de descarga de **Data Output**, formato CSV UTF-8 con encabezados, para generar `servidor_snapshot.csv`.
4. **SQLite:** abrir DB Browser, crear una base vacía `foodstore_movil.db`; ejecutar `movil/schema_sqlite.sql` en **Execute SQL** y guardar con **Write Changes**.
5. **Importar snapshot:** DB Browser > File > Import > Table from CSV file. Elegir `movil/servidor_snapshot.csv`; nombre de tabla `snapshot_servidor`; encabezados activados; separador coma; confirmar que `COUNT(*) = 50010`. Las columnas son `producto_id`, `nombre`, `precio_centavos`, `stock`, `disponible`, `eliminado`, `capturado_en`.
6. **Poblar `producto_cache`:** ejecutar en Execute SQL la siguiente consulta, una vez importada la tabla:

```sql
INSERT INTO producto_cache
(producto_id,nombre,precio_centavos,stock_visto,disponible_visto,eliminado,capturado_en)
SELECT CAST(producto_id AS INTEGER), nombre, CAST(precio_centavos AS INTEGER),
       CAST(stock AS INTEGER),
       CASE WHEN LOWER(TRIM(CAST(disponible AS TEXT))) IN ('true','t','1') THEN 1 ELSE 0 END,
       CASE WHEN LOWER(TRIM(CAST(eliminado AS TEXT))) IN ('true','t','1') THEN 1 ELSE 0 END,
       capturado_en
FROM snapshot_servidor;
```

7. **Transacciones y C1, C7:** usar `pruebas_sqlite.sql` sobre una **copia descartable**. En DB Browser, `BEGIN` puede chocar con transacciones internas; se ejecutó la prueba explícita `BEGIN/COMMIT/ROLLBACK` con Python `sqlite3` sobre una copia del archivo. Se comprobó COMMIT `(1,1,1)` y ROLLBACK `(0,0,0)`. Los intentos inválidos de C7 se ejecutan por separado para capturar errores `275` (CHECK) y `787` (FOREIGN KEY).
8. **Semáforo:** `movil/semaforo.sql` evalúa exclusivamente `PENDIENTE` y registra resultado y motivo en `cola_sync`. No confirma ventas.
9. **Casos C2-C6:** crear borradores, generar solicitudes, modificar solo `foodstore_tp8` y volver a exportar/importar los cambios. C2: `UPDATE public.producto SET precio=2800 WHERE id_producto=1;` C3: `UPDATE public.producto SET stock=4 WHERE id_producto=2;` C4: `UPDATE public.producto SET activo=FALSE WHERE id_producto=3;`. Para actualizar el snapshot importado, importar cada CSV como tabla nueva y volcar los cambios a `snapshot_servidor` (como se documenta en `docs/informe.pdf`). En C2 el cliente acepta el nuevo precio de $2.800 creando una solicitud nueva con otro UUID.
10. **Comprobar:** `SELECT solicitud_uuid, estado, motivo FROM cola_sync;` y en PostgreSQL comparar `SELECT COUNT(*) FROM public.pedido;` en la base de pruebas y la original. Ambas devolvieron 200.004 pedidos; stock comprobado en pruebas: Coca Cola 20, Sprite 4 (cambio intencional), Agua Mineral 25 (baja lógica).

## Resultados reales observados y corroborados en la base SQLite original

| Caso | Comportamiento | Resultado observado |
|---|---|---|
| C1 | Catálogo sin servidor | 10 primeros productos consultados en SQLite |
| C2 | Precio $2.500 vs $2.800 | CONFLICTO; después nuevo intento SIMULADO_APROBADO |
| C3 | Sprite: 10 pedidas, 4 disponibles | RECHAZADO |
| C4 | Agua Mineral inactiva | RECHAZADO; no aparece en catálogo; se conserva con `eliminado=1` |
| C5 | Borrador sin cambios | SIMULADO_APROBADO |
| C6 | UUID repetido | Error SQLite 1555; la solicitud sigue siendo una sola |
| C7 | Cantidad cero y producto inexistente | Errores SQLite 275 y 787; 5 ítems válidos conservados |

**Interpretación correcta:** `SIMULADO_APROBADO` es solo un resultado de comparación. La tablet no modificó el stock de PostgreSQL y no confirmó ventas.

## Documentación y defensa

`docs/informe.pdf` tiene tres páginas y resume 1.a, 2.c, 3.a, 3.b, 3.c y la revisión 4.a. `docs/kiro/` contiene cuatro requisitos EARS y el diseño y las tareas revisados con Kiro y alineados con las columnas reales de SQLite. `docs/bitacora_ia.md` registra las interacciones efectivas de ChatGPT, Kiro, OpenCode Plan y OpenCode Build, las pruebas y los descartes. `docs/DUIA.md` declara el uso de IA; completar identificación, fecha y firma y entregar el formulario oficial si la cátedra lo provee.

Ensayo de 10 minutos: explicar fuente de verdad, mostrar C2 (primer `CONFLICTO` y reintento), demostrar una restricción en Error Log y justificar un hallazgo del code review. El análisis con OpenCode Plan se realizó; el equipo contrastó tres hallazgos con las consultas indicadas en el informe.
