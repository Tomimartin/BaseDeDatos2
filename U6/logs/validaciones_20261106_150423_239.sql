SELECT json_build_object(
  'base', current_database(),
  'conteos', json_build_object(
    'categoria', (SELECT count(*) FROM public.categoria),
    'cliente', (SELECT count(*) FROM public.cliente),
    'producto', (SELECT count(*) FROM public.producto),
    'pedido', (SELECT count(*) FROM public.pedido),
    'detalle_pedido', (SELECT count(*) FROM public.detalle_pedido)
  ),
  'productos_invalidos', (SELECT count(*) FROM public.producto WHERE precio < 0 OR stock < 0),
  'detalles_invalidos', (SELECT count(*) FROM public.detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0)
)::text;
