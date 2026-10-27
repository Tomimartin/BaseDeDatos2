# Verificación de permisos ajustados — Parte A

Fecha: 19/10/2026. Fuente: captura de pgAdmin `docs/evidencias/13_verificacion_permisos_ajustados.png` aportada por el estudiante.

| Comprobación (`app_web`) | Resultado observado | Interpretación |
|---|---|---|
| `UPDATE` sobre `pedido.eliminado` | `true` | Permite borrado lógico de pedidos. |
| `UPDATE` sobre `detalle_pedido.precio_unitario` | `false` | Restringe cambios de precio unitario. |
| `UPDATE` sobre `detalle_pedido.cantidad` | `true` | Permite actualizar cantidades. |
| `DELETE` sobre `pedido` | `false` | Impide borrado físico. |

Conclusión: estos cuatro permisos coinciden con la política de mínimo privilegio acordada. Queda pendiente comprobar el comportamiento funcional de una cancelación bajo sus triggers, otros privilegios por columna, permisos sobre secuencias IDENTITY y la política de privilegios por defecto.
