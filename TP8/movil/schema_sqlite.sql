PRAGMA foreign_keys = ON;
-- TP8 Food Store | SQLite >= 3.37 | Solo la tablet, sin ventas reales.
-- Ejecutar sobre una base nueva. Tablas STRICT y restricciones de integridad.

CREATE TABLE IF NOT EXISTS producto_cache (
    producto_id INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible_visto INTEGER NOT NULL CHECK (disponible_visto IN (0, 1)),
    eliminado INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    capturado_en TEXT NOT NULL
) STRICT;

CREATE TABLE IF NOT EXISTS pedido_borrador (
    id_local TEXT PRIMARY KEY,
    usuario_id_servidor INTEGER NOT NULL, -- identificador de prueba; sin datos personales
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    creado_en TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

CREATE TABLE IF NOT EXISTS item_borrador (
    id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id INTEGER NOT NULL REFERENCES producto_cache(producto_id),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE TABLE IF NOT EXISTS cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado TEXT NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE','CONFLICTO','RECHAZADO','SIMULADO_APROBADO')),
    motivo TEXT,
    creada_en TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

-- Se permiten reintentos tras CONFLICTO, pero no dos solicitudes PENDIENTE simultáneas.
CREATE UNIQUE INDEX IF NOT EXISTS ux_cola_una_pendiente
    ON cola_sync(id_local) WHERE estado = 'PENDIENTE';

CREATE VIEW IF NOT EXISTS v_catalogo_disponible AS
SELECT producto_id, nombre, precio_centavos / 100.0 AS precio, stock_visto
FROM producto_cache
WHERE disponible_visto = 1 AND eliminado = 0;

-- snapshot_servidor se crea al importar servidor_snapshot.csv en DB Browser
-- (File > Import > Table from CSV). No duplicar su creacion aqui.
