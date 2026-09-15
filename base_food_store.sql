--
-- PostgreSQL database dump
--

\restrict V5CPfMx0vTVQmCPCoK3gUeo6hyeetLLYyyv0qQib8kL6yzHC5bXdRUw0hVHlFDT

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: forma_pago_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categoria (
    id_categoria bigint NOT NULL,
    nombre character varying(80) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_categoria_nombre_no_blanco CHECK ((TRIM(BOTH FROM nombre) <> ''::text))
);


--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categoria ALTER COLUMN id_categoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categoria_id_categoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cliente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cliente (
    id_cliente bigint NOT NULL,
    nombre character varying(80) NOT NULL,
    apellido character varying(80) NOT NULL,
    email character varying(150) NOT NULL,
    telefono character varying(30)
);


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cliente ALTER COLUMN id_cliente ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cliente_id_cliente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: detalle_pedido; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detalle_pedido (
    id_pedido bigint NOT NULL,
    id_producto bigint NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(12,2) NOT NULL,
    subtotal numeric(14,2) GENERATED ALWAYS AS (((cantidad)::numeric * precio_unitario)) STORED,
    CONSTRAINT ck_detalle_cantidad_positiva CHECK ((cantidad > 0)),
    CONSTRAINT ck_detalle_precio_no_negativo CHECK ((precio_unitario >= (0)::numeric))
);


--
-- Name: pedido; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pedido (
    id_pedido bigint NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    forma_pago public.forma_pago_enum NOT NULL,
    id_cliente bigint NOT NULL,
    CONSTRAINT ck_pedido_fecha_no_futura CHECK ((fecha <= now()))
);


--
-- Name: pedido_id_pedido_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.pedido ALTER COLUMN id_pedido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pedido_id_pedido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.producto (
    id_producto bigint NOT NULL,
    nombre character varying(120) NOT NULL,
    descripcion character varying(500),
    precio numeric(12,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    id_categoria bigint NOT NULL,
    CONSTRAINT ck_producto_precio_positivo CHECK ((precio > (0)::numeric)),
    CONSTRAINT ck_producto_stock_no_negativo CHECK ((stock >= 0))
);


--
-- Name: producto_id_producto_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.producto ALTER COLUMN id_producto ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.producto_id_producto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categoria (id_categoria, nombre, activo) FROM stdin;
1	Bebidas	t
2	Almacen	t
3	Limpieza	t
4	Golosinas	t
\.


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cliente (id_cliente, nombre, apellido, email, telefono) FROM stdin;
1	Juan	Perez	juan.perez@gmail.com	2611111111
2	Maria	Gomez	maria.gomez@gmail.com	2612222222
3	Pedro	Lopez	pedro.lopez@gmail.com	2613333333
4	Lucia	Fernandez	lucia.fernandez@gmail.com	2614444444
\.


--
-- Data for Name: detalle_pedido; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) FROM stdin;
1	1	2	2500.00
1	5	3	1300.00
2	7	1	2100.00
3	6	2	3200.00
\.


--
-- Data for Name: pedido; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pedido (id_pedido, fecha, forma_pago, id_cliente) FROM stdin;
1	2026-09-08 19:03:25.552633-03	EFECTIVO	1
2	2026-09-08 19:03:25.552633-03	TARJETA	2
3	2026-09-08 19:03:25.552633-03	TRANSFERENCIA	3
\.


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.producto (id_producto, nombre, descripcion, precio, stock, activo, id_categoria) FROM stdin;
2	Sprite 2L	Gaseosa Sprite de 2 litros	2300.00	15	t	1
3	Agua Mineral 1.5L	Agua mineral sin gas	1200.00	25	t	1
4	Arroz 1kg	Paquete de arroz de 1 kilogramo	1800.00	20	t	2
5	Fideos 500g	Paquete de fideos de 500 gramos	1300.00	30	t	2
6	Aceite 900ml	Aceite de girasol	3200.00	12	t	2
7	Detergente	Detergente para platos	2100.00	18	t	3
8	Lavandina 1L	Lavandina de un litro	1500.00	8	t	3
9	Chocolate	Chocolate con leche	1100.00	35	t	4
10	Caramelos	Paquete de caramelos surtidos	800.00	50	t	4
1	Coca Cola 2L	Gaseosa Coca Cola de 2 litros	2500.00	20	t	1
\.


--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categoria_id_categoria_seq', 4, true);


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cliente_id_cliente_seq', 4, true);


--
-- Name: pedido_id_pedido_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.pedido_id_pedido_seq', 3, true);


--
-- Name: producto_id_producto_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.producto_id_producto_seq', 10, true);


--
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id_categoria);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente);


--
-- Name: pedido pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_pkey PRIMARY KEY (id_pedido);


--
-- Name: detalle_pedido pk_detalle_pedido; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto);


--
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id_producto);


--
-- Name: cliente uq_cliente_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT uq_cliente_email UNIQUE (email);


--
-- Name: idx_pedido_id_cliente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pedido_id_cliente ON public.pedido USING btree (id_cliente);


--
-- Name: idx_producto_categoria_activo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_producto_categoria_activo ON public.producto USING btree (id_categoria) WHERE (activo = true);


--
-- Name: detalle_pedido fk_detalle_pedido; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido) REFERENCES public.pedido(id_pedido) ON DELETE CASCADE;


--
-- Name: detalle_pedido fk_detalle_producto; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto) ON DELETE RESTRICT;


--
-- Name: pedido fk_pedido_cliente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente) ON DELETE RESTRICT;


--
-- Name: producto fk_producto_categoria; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES public.categoria(id_categoria) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict V5CPfMx0vTVQmCPCoK3gUeo6hyeetLLYyyv0qQib8kL6yzHC5bXdRUw0hVHlFDT

