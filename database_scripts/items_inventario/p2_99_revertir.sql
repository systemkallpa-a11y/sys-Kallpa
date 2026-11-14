-- =============================================================================
-- PARTE 2 / 99 - REVERTIR
-- -----------------------------------------------------------------------------
-- Válido mientras NO se haya ejecutado la Parte 3 (que crea las fichas según
-- el tipo nuevo). Restaura desde las fotos de p2_01 y aux_p2_reapuntes.
-- =============================================================================

-- 1. Referencias: volver a apuntar al ítem original
UPDATE `TblPresupuestoDetalle` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblPresupuestoDetalle' AND r.id_fila = d.id_detalle
SET d.id_inventario = r.id_anterior;

UPDATE `TblRequerimientoDetalle` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblRequerimientoDetalle' AND r.id_fila = d.id_detalle
SET d.id_inventario = r.id_anterior;

UPDATE `TblMovimientoInventario` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblMovimientoInventario' AND r.id_fila = d.id_movimiento
SET d.id_inventario = r.id_anterior;

UPDATE `TblEntregaPersonalDetalle` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblEntregaPersonalDetalle' AND r.id_fila = d.id_entrega_detalle
SET d.id_inventario = r.id_anterior;

UPDATE `TblPresupuestoVersionDetalleHistorial` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblPresupuestoVersionDetalleHistorial' AND r.id_fila = d.id_detalle_version
SET d.id_inventario = r.id_anterior;

UPDATE `TblInventarioProveedor` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblInventarioProveedor' AND r.id_fila = d.id_inventario_proveedor
SET d.id_inventario = r.id_anterior;

UPDATE `TblInventarioAtributos` d JOIN `aux_p2_reapuntes` r
  ON r.tabla = 'TblInventarioAtributos' AND r.id_fila = d.id_atributo
SET d.id_inventario = r.id_anterior;

-- 2. Ítems: código, tipo, categoría, unidad, nombre, descripción, stock, estado
UPDATE `TblInventario` SET codigo = CONCAT('TMP-', id_inventario);

UPDATE `TblInventario` i JOIN `aux_p2_items_antes` a ON a.id_inventario = i.id_inventario
SET i.codigo = a.codigo,
    i.nombre = a.nombre,
    i.descripcion = a.descripcion,
    i.tipo_inventario = a.tipo_inventario,
    i.id_categoria = a.id_categoria,
    i.id_unidad = a.id_unidad,
    i.stock_actual = a.stock_actual,
    i.estado = a.estado;

-- 3. Generador de código original
DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_generar_material`$$

CREATE PROCEDURE `sp_generar_material`(
    IN p_tipo_inventario VARCHAR(50),
    OUT p_codigo VARCHAR(50)
)
BEGIN
    DECLARE v_prefijo VARCHAR(10);
    DECLARE v_siguiente_numero INT;
    DECLARE v_codigo_generado VARCHAR(50);
    SET v_prefijo = CASE p_tipo_inventario
        WHEN 'MATERIAL' THEN 'MAT'
        WHEN 'HERRAMIENTA' THEN 'HER'
        WHEN 'EQUIPO' THEN 'EQU'
        WHEN 'TECNOLOGIA' THEN 'TEC'
        WHEN 'ROPA' THEN 'ROP'
        WHEN 'CONSUMIBLE' THEN 'OFI'
        ELSE 'INV'
    END;
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(codigo, LENGTH(v_prefijo) + 2) AS UNSIGNED)
    ), 0) + 1
    INTO v_siguiente_numero
    FROM TblInventario
    WHERE codigo LIKE CONCAT(v_prefijo, '-%')
      AND LENGTH(codigo) >= LENGTH(v_prefijo) + 2
      AND SUBSTRING(codigo, LENGTH(v_prefijo) + 2) REGEXP '^[0-9]+$';
    SET v_codigo_generado = CONCAT(v_prefijo, '-', LPAD(v_siguiente_numero, 5, '0'));
    SET p_codigo = v_codigo_generado;
END$$

DELIMITER ;

-- 4. Tablas de la Parte 2
DROP TABLE IF EXISTS `TblInventarioCodigoAnterior`;
DROP TABLE IF EXISTS `TblInventarioUnificacion`;
DROP TABLE IF EXISTS `aux_p2_items_destino`;
DROP TABLE IF EXISTS `aux_p2_reapuntes`;
DROP TABLE IF EXISTS `aux_p2_totales_presupuesto`;
DROP TABLE IF EXISTS `aux_p2_totales_requerimiento`;
DROP TABLE IF EXISTS `aux_p2_items_antes`;
