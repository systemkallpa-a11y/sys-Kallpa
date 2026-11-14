-- =============================================================================
-- PARTE 5 / 03 - COMPLETAR EL KARDEX CON LAS ENTREGAS AL PERSONAL EXISTENTES
-- -----------------------------------------------------------------------------
-- /api/entregas-personal/guardar descontó stock_actual sin registrar
-- movimiento. Aquí se agrega el movimiento SALIDA que faltaba por cada línea
-- de entrega, con su fecha original.
-- NO modifica stock_actual (ya fue descontado en su momento).
-- Código: SAL-ENT<entrega>-<ítem>, mismo estilo que SAL-RQA... de requerimientos.
-- Idempotente: no duplica si se ejecuta otra vez.
-- Las entregas NUEVAS registrarán su movimiento desde la Parte 6 (Python usará
-- sp_registrar_movimiento_stock).
-- =============================================================================

INSERT INTO `TblMovimientoInventario` (
    codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
    id_almacen_origen, id_almacen_destino, tipo_documento, id_documento_referencia,
    costo_unitario, costo_total, motivo, observaciones, fecha_movimiento, realizado_por
)
SELECT
    CONCAT('SAL-ENT', LPAD(e.id_entrega, 6, '0'), '-', LPAD(d.id_inventario, 5, '0')),
    d.id_inventario,
    'SALIDA',
    SUM(d.cantidad),
    i.id_almacen,
    NULL,
    'ENTREGA_PERSONAL',
    e.id_entrega,
    COALESCE(i.precio_compra, 0),
    SUM(d.cantidad) * COALESCE(i.precio_compra, 0),
    CONCAT('Entrega al personal ', e.codigo_entrega),
    'Registrado en la Parte 5: la entrega descontó stock sin movimiento',
    e.fecha_entrega,
    CAST(NULLIF(e.creado_por, '') AS UNSIGNED)
FROM `TblEntregaPersonal` e
JOIN `TblEntregaPersonalDetalle` d ON d.id_entrega = e.id_entrega
JOIN `TblInventario` i ON i.id_inventario = d.id_inventario
WHERE NOT EXISTS (
    SELECT 1 FROM `TblMovimientoInventario` m
    WHERE m.tipo_documento = 'ENTREGA_PERSONAL'
      AND m.id_documento_referencia = e.id_entrega
      AND m.id_inventario = d.id_inventario
)
GROUP BY e.id_entrega, e.codigo_entrega, e.fecha_entrega, e.creado_por,
         d.id_inventario, i.id_almacen, i.precio_compra;
