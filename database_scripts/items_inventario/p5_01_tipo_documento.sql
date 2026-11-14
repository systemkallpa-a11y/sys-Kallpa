-- =============================================================================
-- PARTE 5 / 01 - TIPO DE DOCUMENTO "ENTREGA_PERSONAL" EN EL KARDEX
-- -----------------------------------------------------------------------------
-- Las entregas al personal (vales de EPP / herramientas) descuentan stock pero
-- hoy no dejan movimiento. Para registrarlas se agrega su tipo de documento.
-- Agregar un valor AL FINAL de un ENUM no modifica los datos existentes.
-- Misma definición que la actual (NULL, DEFAULT NULL, sin comentario).
-- =============================================================================

ALTER TABLE `TblMovimientoInventario`
  MODIFY COLUMN `tipo_documento`
  ENUM('COMPRA','REQUERIMIENTO','ORDEN_TRABAJO','AJUSTE_INVENTARIO','TRANSFERENCIA','ENTREGA_PERSONAL')
  DEFAULT NULL;
