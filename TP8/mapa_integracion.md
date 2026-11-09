# Mapa de integración - Food Store TP8

## PostgreSQL
Es la fuente de verdad del sistema.
Administra productos, precios, stock oficial y pedidos.
Es el único motor autorizado para confirmar ventas.

## SQLite
Representa una tablet que funciona sin conexión.
Guarda una copia del catálogo en producto_cache.
Almacena pedidos en pedido_borrador e item_borrador.
Registra los intentos de sincronización en cola_sync.

El semáforo compara los borradores con una
instantánea actualizada del servidor y devuelve:
RECHAZADO, CONFLICTO o SIMULADO_APROBADO.

## MongoDB
Se utiliza para representar pedidos mediante
documentos, con sus datos y productos asociados.
Permite realizar consultas de lectura y análisis.
No administra el stock oficial ni confirma ventas.

## Flujo de información
1. PostgreSQL exporta una instantánea del catálogo.
2. SQLite importa la instantánea desde un CSV.
3. La tablet registra borradores sin conexión.
4. Al recuperar conectividad, se simula la
   comparación con datos actualizados del servidor.
5. El semáforo registra el resultado en cola_sync.
6. PostgreSQL conserva la autoridad para confirmar
   ventas y modificar el stock.

## Regla principal
Una solicitud SIMULADO_APROBADO no representa
una venta confirmada. La sincronización del TP8
es una simulación y no registra pedidos reales
en PostgreSQL.
