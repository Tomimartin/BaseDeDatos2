var resultadoU7 = null;
var documentosU7 = null;
var logU7 = [];

(() => {
  const databaseName = "foodstorecopia_nosql";
  const collectionName = "pedidos_u7";
  const source = [
  {
    "pedido_id": "180991",
    "fecha_utc_milisegundos": "2026-01-31T04:19:57.926Z",
    "fecha_origen_pg": "2026-01-31 01:19:57.926064-03",
    "estado": "ELIMINADO",
    "eliminado": true,
    "forma_pago": "TARJETA",
    "cliente_id": "18492",
    "nombre_publico_cliente": "Cliente 18492",
    "items": [
      {
        "producto_id": "30998",
        "nombre_producto": "Producto generado 30998",
        "cantidad": 11,
        "precio_unitario": "1350.33",
        "subtotal": "14853.63"
      }
    ],
    "total": "14853.63"
  },
  {
    "pedido_id": "181008",
    "fecha_utc_milisegundos": "2026-03-02T13:48:33.429Z",
    "fecha_origen_pg": "2026-03-02 10:48:33.429559-03",
    "estado": "ELIMINADO",
    "eliminado": true,
    "forma_pago": "TRANSFERENCIA",
    "cliente_id": "2412",
    "nombre_publico_cliente": "Cliente 2412",
    "items": [
      {
        "producto_id": "31015",
        "nombre_producto": "Producto generado 31015",
        "cantidad": 8,
        "precio_unitario": "4384.97",
        "subtotal": "35079.76"
      }
    ],
    "total": "35079.76"
  },
  {
    "pedido_id": "181019",
    "fecha_utc_milisegundos": "2025-09-24T22:05:10.616Z",
    "fecha_origen_pg": "2025-09-24 19:05:10.616643-03",
    "estado": "ACTIVO",
    "eliminado": false,
    "forma_pago": "TARJETA",
    "cliente_id": "4790",
    "nombre_publico_cliente": "Cliente 4790",
    "items": [
      {
        "producto_id": "31026",
        "nombre_producto": "Producto generado 31026",
        "cantidad": 19,
        "precio_unitario": "3544.59",
        "subtotal": "67347.21"
      }
    ],
    "total": "67347.21"
  },
  {
    "pedido_id": "181036",
    "fecha_utc_milisegundos": "2026-02-06T05:07:24.511Z",
    "fecha_origen_pg": "2026-02-06 02:07:24.511773-03",
    "estado": "ACTIVO",
    "eliminado": false,
    "forma_pago": "EFECTIVO",
    "cliente_id": "13628",
    "nombre_publico_cliente": "Cliente 13628",
    "items": [
      {
        "producto_id": "31043",
        "nombre_producto": "Producto generado 31043",
        "cantidad": 16,
        "precio_unitario": "3324.05",
        "subtotal": "53184.80"
      }
    ],
    "total": "53184.80"
  },
  {
    "pedido_id": "181045",
    "fecha_utc_milisegundos": "2026-05-04T03:41:41.731Z",
    "fecha_origen_pg": "2026-05-04 00:41:41.731898-03",
    "estado": "ACTIVO",
    "eliminado": false,
    "forma_pago": "TRANSFERENCIA",
    "cliente_id": "4026",
    "nombre_publico_cliente": "Cliente 4026",
    "items": [
      {
        "producto_id": "31052",
        "nombre_producto": "Producto generado 31052",
        "cantidad": 5,
        "precio_unitario": "1424.03",
        "subtotal": "7120.15"
      }
    ],
    "total": "7120.15"
  }
];
  const expected = {
  "procedencia": "Calculado del CSV; pendiente de ejecucion y comprobacion en MongoDB y de las consultas equivalentes en PostgreSQL.",
  "csv_sha256": "cb3a7f6ab08d26da3ecaef9fc9c6ca60338db2394f381455aa2b06adb7fa1ff1",
  "todos": [
    180991,
    181008,
    181019,
    181036,
    181045
  ],
  "estado_activo": [
    181019,
    181036,
    181045
  ],
  "estado_eliminado": [
    180991,
    181008
  ],
  "producto_30998": [
    180991
  ],
  "total_mayor_10000": [
    180991,
    181008,
    181019,
    181036
  ]
};

  function log(message) {
    const line = "[" + new Date().toISOString() + "] " + message;
    print(line);
    logU7.push(line);
  }
  function check(condition, message) {
    if (!condition) throw new Error(message);
  }
  function checkIds(label, found, wanted) {
    const ids = found.map(doc => doc.pedido_id.toString()).sort((a, b) => Number(a) - Number(b));
    const target = wanted.map(String).sort((a, b) => Number(a) - Number(b));
    log(label + ": cantidad=" + ids.length + "; IDs=" + ids.join(", "));
    check(JSON.stringify(ids) === JSON.stringify(target), label + ": los IDs no coinciden con el CSV de origen");
    return { cantidad: ids.length, ids };
  }
  function comparable(doc) {
    return {
      pedido_id: doc.pedido_id.toString(), fecha: doc.fecha.toISOString(),
      fecha_origen_pg: doc.fecha_origen_pg, estado: doc.estado,
      eliminado: doc.eliminado, forma_pago: doc.forma_pago,
      cliente: { cliente_id: doc.cliente.cliente_id.toString(), nombre_publico: doc.cliente.nombre_publico, anonimizado: doc.cliente.anonimizado },
      items: doc.items.map(item => ({
        producto_id: item.producto_id.toString(), nombre_producto: item.nombre_producto,
        cantidad: Number(item.cantidad), precio_unitario: item.precio_unitario.toString(), subtotal: item.subtotal.toString()
      })).sort((a, b) => Number(a.producto_id) - Number(b.producto_id)),
      total: doc.total.toString()
    };
  }

  try {
    const laboratorio = db.getSiblingDB(databaseName);
    check(laboratorio.runCommand({ ping: 1 }).ok === 1, "No se pudo verificar la conexion");
    log("INICIO base=" + laboratorio.getName() + " coleccion=" + collectionName);

    const documents = source.map(order => ({
      pedido_id: NumberLong(order.pedido_id),
      fecha: ISODate(order.fecha_utc_milisegundos),
      fecha_origen_pg: order.fecha_origen_pg,
      estado: order.estado,
      eliminado: order.eliminado,
      forma_pago: order.forma_pago,
      cliente: { cliente_id: NumberLong(order.cliente_id), nombre_publico: order.nombre_publico_cliente, anonimizado: true },
      items: order.items.map(item => ({
        producto_id: NumberLong(item.producto_id), nombre_producto: item.nombre_producto,
        cantidad: NumberInt(item.cantidad), precio_unitario: NumberDecimal(item.precio_unitario), subtotal: NumberDecimal(item.subtotal)
      })),
      total: NumberDecimal(order.total)
    }));
    const ids = documents.map(doc => doc.pedido_id);
    const scope = { pedido_id: { $in: ids } };
    const totalExpression = { $sum: { $map: { input: "$items", as: "item", in: { $multiply: ["$$item.cantidad", "$$item.precio_unitario"] } } } };
    const schema = {
      bsonType: "object",
      required: ["pedido_id", "fecha", "fecha_origen_pg", "estado", "eliminado", "forma_pago", "cliente", "items", "total"],
      properties: {
        pedido_id: { bsonType: "long" }, fecha: { bsonType: "date" }, fecha_origen_pg: { bsonType: "string" },
        estado: { enum: ["ACTIVO", "ELIMINADO"] }, eliminado: { bsonType: "bool" },
        forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
        cliente: { bsonType: "object", required: ["cliente_id", "nombre_publico", "anonimizado"], properties: {
          cliente_id: { bsonType: "long" }, nombre_publico: { bsonType: "string" }, anonimizado: { bsonType: "bool" }
        } },
        items: { bsonType: "array", minItems: 1, items: { bsonType: "object",
          required: ["producto_id", "nombre_producto", "cantidad", "precio_unitario", "subtotal"], properties: {
            producto_id: { bsonType: "long" }, nombre_producto: { bsonType: "string" },
            cantidad: { bsonType: "int", minimum: 1 },
            precio_unitario: { bsonType: "decimal", minimum: 0 }, subtotal: { bsonType: "decimal", minimum: 0 }
          }
        } },
        total: { bsonType: "decimal", minimum: 0 }
      }
    };
    if (laboratorio.getCollectionInfos({ name: collectionName }).length === 0) {
      laboratorio.createCollection(collectionName, {
        validator: { $and: [
          { $jsonSchema: schema },
          { $expr: { $and: [
            { $eq: ["$total", totalExpression] },
            { $eq: ["$estado", { $cond: ["$eliminado", "ELIMINADO", "ACTIVO"] }] }
          ] } }
        ] },
        validationLevel: "strict", validationAction: "error"
      });
      log("Coleccion creada con validacion de tipos, cantidades, precios, estado y total");
    }
    const pedidos = laboratorio.getCollection(collectionName);
    pedidos.createIndex({ pedido_id: 1 }, { unique: true, name: "uq_pedido_id_u7" });
    const write = pedidos.bulkWrite(documents.map(document => ({ replaceOne: {
      filter: { pedido_id: document.pedido_id }, replacement: document, upsert: true
    } })), { ordered: true });
    log("MIGRACION: cinco pedidos procesados; comienza la verificacion");

    const actual = pedidos.find(scope).sort({ pedido_id: 1 }).toArray();
    check(actual.length === documents.length, "No se recuperaron los cinco pedidos de origen");
    for (const document of documents) {
      const restored = actual.find(row => row.pedido_id.toString() === document.pedido_id.toString());
      check(Boolean(restored), "Falta un pedido migrado");
      check(JSON.stringify(comparable(restored)) === JSON.stringify(comparable(document)), "Diferencia en los datos migrados del pedido " + document.pedido_id);
    }
    documentosU7 = actual.map(comparable);
    log("Verificacion de datos originales: cinco pedidos coincidentes, con fechas, clientes, cantidades y precios");

    const all = pedidos.find(scope, { _id: 0, pedido_id: 1, estado: 1 }).sort({ pedido_id: 1 }).toArray();
    const queryA = checkIds("4a todos", all, expected.todos);
    for (const row of all) log("pedido_id=" + row.pedido_id + " estado=" + row.estado);

    const byState = pedidos.find({ ...scope, estado: "ACTIVO" }, { _id: 0, pedido_id: 1, estado: 1 }).sort({ pedido_id: 1 }).toArray();
    const queryB = checkIds("4b estado ACTIVO", byState, expected.estado_activo);

    const byProduct = pedidos.find({ ...scope, "items.producto_id": NumberLong("30998") }, { _id: 0, pedido_id: 1 }).sort({ pedido_id: 1 }).toArray();
    const queryC = checkIds("4c producto 30998", byProduct, expected.producto_30998);

    const byTotal = pedidos.find({ ...scope, total: { $gt: NumberDecimal("10000.00") } }, { _id: 0, pedido_id: 1, total: 1 }).sort({ pedido_id: 1 }).toArray();
    const queryD = checkIds("4d total mayor a 10000", byTotal, expected.total_mayor_10000);

    const invalidItems = pedidos.countDocuments({ ...scope, items: { $elemMatch: { $or: [
      { cantidad: { $lte: 0 } }, { precio_unitario: { $lt: NumberDecimal("0.00") } }
    ] } } });
    const invalidTotals = pedidos.countDocuments({ ...scope, $expr: { $ne: ["$total", totalExpression] } });
    check(invalidItems === 0 && invalidTotals === 0, "Se detectaron cantidades, precios o totales invalidos");
    const result = {
      resultado: "EXITO", fecha_ejecucion: new Date().toISOString(),
      base: databaseName, coleccion: collectionName, version_servidor: laboratorio.version(),
      csv_sha256: expected.csv_sha256,
      significado_estado: "Vigencia por baja logica: eliminado=true -> ELIMINADO; eliminado=false -> ACTIVO",
      documentos_verificados: actual.length,
      consultas: { todos: queryA, estado_activo: queryB, producto_30998: queryC, total_mayor_10000: queryD },
      integridad: { pedidos_con_items_invalidos: invalidItems, pedidos_con_total_inconsistente: invalidTotals },
      evidencia: "Salida de consola y variables resultadoU7, documentosU7 y logU7"
    };
    resultadoU7 = result;
    log("EXITO: migracion y cuatro consultas verificadas contra el CSV de PostgreSQL");
    print("RESULTADO_U7_JSON");
    print(JSON.stringify(resultadoU7, null, 2));
    print("Para recuperar el resultado: print(JSON.stringify(resultadoU7, null, 2))");
    print("Para recuperar los documentos: print(JSON.stringify(documentosU7, null, 2))");
  } catch (error) {
    resultadoU7 = { resultado: "FALLA", fecha_ejecucion: new Date().toISOString(), base: databaseName, coleccion: collectionName, error: String(error) };
    log("FALLA " + String(error));
    print(JSON.stringify(resultadoU7, null, 2));
    throw error;
  }
})();
