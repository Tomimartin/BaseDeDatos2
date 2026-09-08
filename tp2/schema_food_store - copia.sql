CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

--TABLA: categoria

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL,
    activo       BOOLEAN NOT NULL DEFAULT TRUE
);

-- TABLA: cliente

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(80) NOT NULL,
    apellido   VARCHAR(80) NOT NULL,
    email      VARCHAR(150) NOT NULL,
    telefono   VARCHAR(30),
    CONSTRAINT uq_cliente_email UNIQUE (email)
);

-- TABLA: producto

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(120) NOT NULL,
    descripcion VARCHAR(500),
    precio      NUMERIC(12,2) NOT NULL,
    stock       INTEGER NOT NULL DEFAULT 0,
    activo      BOOLEAN NOT NULL DEFAULT TRUE,
    id_categoria BIGINT NOT NULL,

    CONSTRAINT ck_producto_precio_no_negativo
        CHECK (precio >= 0),

    CONSTRAINT ck_producto_stock_no_negativo
        CHECK (stock >= 0),

    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria(id_categoria)
        ON DELETE RESTRICT
);

-- TABLA: pedido

CREATE TABLE pedido (
    id_pedido  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    id_cliente BIGINT NOT NULL,
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
        ON DELETE RESTRICT
);

-- TABLA: detalle_pedido

CREATE TABLE detalle_pedido (
    id_pedido      BIGINT NOT NULL,
    id_producto    BIGINT NOT NULL,
    cantidad       INTEGER NOT NULL,
    precio_unitario NUMERIC(12,2) NOT NULL,

    subtotal NUMERIC(14,2)
        GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    CONSTRAINT pk_detalle_pedido
        PRIMARY KEY (id_pedido, id_producto),

    CONSTRAINT ck_detalle_cantidad_positiva
        CHECK (cantidad > 0),

    CONSTRAINT ck_detalle_precio_no_negativo
        CHECK (precio_unitario >= 0),

    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (id_pedido)
        REFERENCES pedido(id_pedido)
        ON DELETE CASCADE,

    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (id_producto)
        REFERENCES producto(id_producto)
        ON DELETE RESTRICT
);

-- ÍNDICES

CREATE INDEX idx_pedido_id_cliente
    ON pedido(id_cliente);

CREATE INDEX idx_producto_categoria_activo
    ON producto(id_categoria)
    WHERE activo = TRUE;
