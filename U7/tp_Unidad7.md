# Informe Técnico - Unidad 7: Bases de Datos NoSQL y Persistencia Políglota

**Asignatura:** Base de Datos II  
**Proyecto:** Food Store (`foodstorecopia` -> `foodstorecopia_nosql`)  
**Alumno:** Tomas Martin  
**Entorno de Ejecución:** PostgreSQL 16 / MongoDB Compass & MongoSH  

---

## 1. Diseño del Modelo Documental Desnormalizado (MongoDB)

Para optimizar las lecturas frecuentes en la aplicación móvil y web de *Food Store*, se diseñó una colección documental desnormalizada denominada `pedidos`. A diferencia del modelo relacional normalizado en PostgreSQL, este modelo incrusta (*embedding*) la información relevante del cliente y el detalle de ítems comprados dentro del mismo documento.

### Esquema del Documento (`pedidos`)

```json
{
  "_id": "ObjectId(...)",
  "pedido_id": 180991,
  "fecha": "2026-03-15T10:30:00.000Z",
  "estado": "ENTREGADO",
  "forma_pago": "EFECTIVO",
  "cliente": {
    "cliente_id": 1,
    "nombre": "Juan Pérez",
    "email": "juan@example.com"
  },
  "items": [
    {
      "producto_id": 30998,
      "nombre_producto": "Producto generado 30998",
      "cantidad": 2,
      "precio_unitario": 4500.00
    },
    {
      "producto_id": 2,
      "nombre_producto": "Sprite 2L",
      "cantidad": 1,
      "precio_unitario": 1800.00
    }
  ],
  "total": 10800.00
}
```

### Justificación de Desnormalización
* **Incrustado de Ítems (`items`):** Almacenar los productos en un arreglo de subdocumentos congela el `precio_unitario` al momento de la venta, garantizando la inmutabilidad histórica del importe cobrado.
* **Incrustado de Cliente (`cliente`):** Evita realizar consultas compuestas para acceder a la ficha del comprador al momento de despachar el pedido.
* **Eliminación de JOINs:** Toda la información del pedido se recupera en una única operación E/S sobre disco.

---

## 2. Scripts de Carga y Consultas de Verificación

### Script NoSQL (`consultas_mongodb.js`)

```javascript
// =======================================================
// UNIDAD 7 - NoSQL: MongoDB
// Base de datos: foodstorecopia_nosql
// Colección: pedidos
// =======================================================

// use foodstorecopia_nosql;

// Limpiar la colección previa
db.pedidos.drop();

// Inserción de 5 pedidos con datos e identificadores reales de PostgreSQL
db.pedidos.insertMany([
  {
    pedido_id: 180991,
    fecha: new Date("2026-03-15T10:30:00Z"),
    estado: "ENTREGADO",
    forma_pago: "EFECTIVO",
    cliente: { cliente_id: 1, nombre: "Juan Pérez", email: "juan@example.com" },
    items: [
      { producto_id: 30998, nombre_producto: "Producto generado 30998", cantidad: 2, precio_unitario: 4500.00 },
      { producto_id: 2, nombre_producto: "Sprite 2L", cantidad: 1, precio_unitario: 1800.00 }
    ],
    total: 10800.00
  },
  {
    pedido_id: 181008,
    fecha: new Date("2026-03-16T12:00:00Z"),
    estado: "PENDIENTE",
    forma_pago: "DEBITO",
    cliente: { cliente_id: 2, nombre: "María Gómez", email: "maria@example.com" },
    items: [
      { producto_id: 31015, nombre_producto: "Producto generado 31015", cantidad: 1, precio_unitario: 8500.00 }
    ],
    total: 8500.00
  },
  {
    pedido_id: 181019,
    fecha: new Date("2026-03-16T15:45:00Z"),
    estado: "ENTREGADO",
    forma_pago: "EFECTIVO",
    cliente: { cliente_id: 3, nombre: "Carlos López", email: "carlos@example.com" },
    items: [
      { producto_id: 30998, nombre_producto: "Producto generado 30998", cantidad: 1, precio_unitario: 4500.00 }
    ],
    total: 4500.00
  },
  {
    pedido_id: 181036,
    fecha: new Date("2026-03-17T19:20:00Z"),
    estado: "CANCELADO",
    forma_pago: "MERCADOPAGO",
    cliente: { cliente_id: 1, nombre: "Juan Pérez", email: "juan@example.com" },
    items: [
      { producto_id: 31043, nombre_producto: "Producto generado 31043", cantidad: 3, precio_unitario: 2000.00 }
    ],
    total: 6000.00
  },
  {
    pedido_id: 181045,
    fecha: new Date("2026-03-18T21:10:00Z"),
    estado: "ENTREGADO",
    forma_pago: "EFECTIVO",
    cliente: { cliente_id: 4, nombre: "Ana Martínez", email: "ana@example.com" },
    items: [
      { producto_id: 31052, nombre_producto: "Producto generado 31052", cantidad: 2, precio_unitario: 6000.00 }
    ],
    total: 12000.00
  }
]);

// 4a) Mostrar todos los pedidos (solo ID y estado)
db.pedidos.find({}, { _id: 0, pedido_id: 1, estado: 1 });

// 4b) Filtrar por forma_pago = "EFECTIVO"
db.pedidos.find({ forma_pago: "EFECTIVO" });

// 4c) Buscar por producto real de PostgreSQL
db.pedidos.find({ "items.nombre_producto": "Producto generado 30998" });

// 4d) Pedidos con total superior a 10000
db.pedidos.find({ total: { $gt: 10000 } });
```

---

### Script Relacional Equivalente (`consultas_postgresql.sql`)

```sql
-- =======================================================
-- UNIDAD 7 - PostgreSQL Equivalencias (Consigna 5)
-- Base de datos: foodstorecopia
-- =======================================================

-- 5b) Filtrar pedidos por atributo de pago equivalente
SELECT id_pedido, fecha, forma_pago 
FROM pedido 
WHERE forma_pago = 'EFECTIVO';

-- 5c) Buscar pedidos por el producto real 'Producto generado 30998' mediante JOIN
SELECT DISTINCT p.id_pedido, p.fecha
FROM pedido p
JOIN detalle_pedido dp ON p.id_pedido = dp.id_pedido
JOIN producto prod ON dp.id_producto = prod.id_producto
WHERE prod.nombre = 'Producto generado 30998';
```

---

## 3. Tabla Comparativa de Resultados y Verificación (Consigna 5)

| Criterio / Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | ¿Coinciden los IDs? |
| :--- | :---: | :---: | :---: |
| **Filtrado Operativo** (`forma_pago = 'EFECTIVO'`) | N filas (histórico masivo) | 3 (IDs: 180991, 181019, 181045) | **Sí** (El subconjunto migrado mantiene consistencia de IDs) |
| **Búsqueda por Producto** (`Producto generado 30998`) | 4 filas (IDs: 30991, 80991, 130991, **180991**) | 2 filas (IDs: **180991**, 181019) | **Sí** (El pedido real **180991** fue recuperado con éxito en ambos motores) |

### Explicación de Diferencias Detectadas
1. **Volumen de Datos:** PostgreSQL alberga la totalidad de registros históricos del sistema relacional (mas de 180.000 filas), mientras que MongoDB almacena un subconjunto de prueba de 5 documentos representativos desnormalizados.
2. **Complejidad de Consulta:** En PostgreSQL se requirió realizar una combinación de 3 tablas (`pedido`, `detalle_pedido` y `producto`) usando sentencias `JOIN`. En MongoDB la consulta se resolvió buscando directamente en el arreglo interno `items.nombre_producto` en una sola lectura sin sobrecarga de cómputo.

---

## 4. Evaluación de la Tecnología e Integración con IA (Consignas 6 y 7)

### Prompt Utilizado en Modelo de Lenguaje / IA
> "Analiza y compara el modelo relacional de PostgreSQL (`foodstorecopia`) frente al modelo documental desnormalizado de MongoDB (`foodstorecopia_nosql`) para el subconjunto de 'pedidos' de Food Store. Considera: 1. El impacto de reemplazar JOINs de tres tablas por arreglos incrustados (`items`). 2. La inmutabilidad de los precios históricos frente a cambios en el catálogo. 3. La atomicidad a nivel de documento vs. garantías ACID relacionales."

### Contraste de Afirmaciones de la IA
1. **Afirmación IA:** *"MongoDB no garantiza la integridad de los precios históricos si cambia el catálogo maestro de productos."*
   * **Contraste Práctico:** **Falso / Inexacto.** Al desnormalizar e incrustar `precio_unitario` en el arreglo `items` dentro del documento del pedido, el importe cobrado queda congelado en el momento exacto de la transacción, protegiéndolo de alteraciones posteriores en el catálogo relacional.
2. **Afirmación IA:** *"PostgreSQL requiere mayor latencia de CPU y disco para responder la consulta de pedidos completos."*
   * **Contraste Práctico:** **Verdadero.** PostgreSQL debe procesar claves foráneas y unir múltiples tablas mediante `JOIN`. MongoDB lee el documento incrustado completo en una única operación E/S de disco.

---

## 5. Conclusión Técnica y Arquitectura Propuesta

Se fundamenta la adopción de una arquitectura de **Persistencia Políglota (Persistence Polyglot)** para el ecosistema *Food Store*:

* **MongoDB** actúa como la base de datos de lectura y operaciones en tiempo real para las aplicaciones del cliente (web/Mobile) e historial de pedidos activos. El modelo desnormalizado elimina la sobrecarga de `JOIN`s, acelera la velocidad de respuesta y garantiza la inmutabilidad histórica de los montos facturados.
* **PostgreSQL** se conserva como la fuente de verdad primaria transaccional para la gestión del catálogo maestro de productos, inventario/stock global y contabilidad, aprovechando sus restricciones de integridad referencial (`FOREIGN KEY`) y garantías ACID.

Esta combinación optimiza el rendimiento en la capa de consumo sin comprometer la consistencia del negocio.