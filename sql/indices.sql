--
-- Índices para Food Store (PostgreSQL)
--

-- Optimiza consultas de rango sobre pedido.fecha (BETWEEN, <, >, <=, >=).
-- Permite pasar de Seq Scan a Index Scan / Bitmap Index Scan.
CREATE INDEX idx_pedido_fecha
    ON public.pedido USING btree (fecha);

-- Optimiza consultas de filtro de rango y ordenamiento por precio en el catálogo
-- de productos (WHERE precio > X ORDER BY precio DESC).
-- Elimina el Seq Scan y el nodo Sort explícito: el B-Tree descendente devuelve
-- las filas ya ordenadas sin un paso de ordenamiento adicional.
CREATE INDEX idx_producto_precio_desc
    ON public.producto (precio DESC);

-- Optimiza búsquedas del historial de ventas de un producto específico
-- (WHERE id_producto = X ORDER BY cantidad DESC).
-- La primera columna (id_producto) permite un index seek exacto evitando el
-- Seq Scan en la tabla masiva detalle_pedido; la segunda columna (cantidad DESC)
-- entrega las filas ya ordenadas eliminando el nodo Sort.
CREATE INDEX idx_detalle_pedido_producto_cant
    ON public.detalle_pedido (id_producto, cantidad DESC);
