# TP8 Food Store - Requirements (EARS) - propuesta para ingresar en Kiro

> Especificación redactada durante la preparación del TP8. Aún no es evidencia de una ejecución en Kiro.

- **REQ-01.** WHEN la tablet pierde conexión con PostgreSQL, THE SYSTEM SHALL permitir consultar el catálogo local sin modificar stock ni confirmar ventas. **Caso:** C1.
- **REQ-02.** WHEN se guarda un borrador, THE SYSTEM SHALL conservar pedido, ítems y solicitud atómicamente, y rechazar cantidades inválidas o productos inexistentes. **Casos:** C7 y prueba de transacciones.
- **REQ-03.** WHEN se compara una solicitud PENDIENTE con la instantánea del servidor, THE SYSTEM SHALL marcar RECHAZADO ante baja, ausencia, no disponibilidad o falta de stock; CONFLICTO ante cambio de precio sin rechazo; o SIMULADO_APROBADO cuando todo coincida. **Casos:** C2, C3, C4, C5.
- **REQ-04.** WHEN una solicitud con el mismo UUID se reenvía, THE SYSTEM SHALL impedir el duplicado y conservar el estado ya evaluado. **Caso:** C6.
