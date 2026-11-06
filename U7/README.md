# U7 - Food Store

**Integrantes:** Tomas Martin, Benjamin Lagos, Santiago Prandina, Emir Gris, Leandro Rea, Brian Rampone, Joel Herrera, Octa Medina.  
**Ensayo:** 06/11/2026. PostgreSQL 17.11 y MongoDB 8.0.10.

Esta entrega contiene el informe corregido en `tp_Unidad7.md`, su versión PDF de cuatro páginas, los scripts y las evidencias del mismo subconjunto de cinco pedidos.

## Integrar en GitHub

Usar esta carpeta `U7` en lugar de la versión anterior del repositorio. `tp_Unidad7.md` reemplaza el informe anterior. Las demás unidades se conservan.

## Repetir las consultas

1. En pgAdmin, conectado a `foodstorecopia`, ejecutar `consultas_postgresql.sql`. Para obtener solo la tabla de comparación, ejecutar `comparacion_postgresql.sql`.
2. Abrir `PEGAR_EN_CONSOLA_MONGODB.txt` o `consultas_mongodb.js` con un editor de texto y pegar su contenido completo en la consola de MongoDB conectada. El script selecciona expresamente `foodstorecopia_nosql.pedidos_u7` y comprueba la carga y las cuatro consultas.
3. Conservar la salida. El resultado puede recuperarse con `print(JSON.stringify(resultadoU7, null, 2))`; los documentos con `print(JSON.stringify(documentosU7, null, 2))`; el registro con `print(logU7.join("\n"))`.

La versión entregada es la que se ejecutó mediante pegado directo. Muestra las evidencias en pantalla y mantiene las variables de resultado. Repetirla reemplaza o incorpora los mismos cinco IDs en la colección del laboratorio.

## Resultados

| Consulta | PostgreSQL | MongoDB | IDs |
|---|---:|---:|---|
| Estado ACTIVO | 3 | 3 | 181019, 181036, 181045 |
| Producto 30998 | 1 | 1 | 180991 |

MongoDB también recuperó los cinco pedidos en la consulta general y cuatro con total mayor a 10000. Ambos controles de integridad devolvieron cero.

`estado` expresa la vigencia por baja lógica del campo existente `eliminado`. Los nombres públicos de cliente son alias; sus IDs originales se mantienen. Los precios son históricos y las fechas PostgreSQL completas se conservan además de su representación BSON Date.

La procedencia de los archivos y las transcripciones está en [evidencias/LEER_ORIGEN.md](evidencias/LEER_ORIGEN.md).
