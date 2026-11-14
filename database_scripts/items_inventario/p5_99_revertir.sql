-- =============================================================================
-- PARTE 5 / 99 - REVERTIR
-- -----------------------------------------------------------------------------
-- Quita los movimientos agregados para las entregas, restaura sp_ajustar_stock
-- original, elimina los SPs nuevos y devuelve el ENUM a su lista original
-- (solo si ya no hay movimientos ENTREGA_PERSONAL).
-- Los movimientos hechos con el nuevo sp_ajustar_stock (ENT-000016...) NO se
-- borran: son operaciones reales del sistema.
-- =============================================================================

DELETE FROM `TblMovimientoInventario`
WHERE tipo_documento = 'ENTREGA_PERSONAL' AND codigo_movimiento LIKE 'SAL-ENT%';

SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_verificar_kardex`$$

DROP PROCEDURE IF EXISTS `sp_ajustar_stock`$$
CREATE PROCEDURE `sp_ajustar_stock`(
    IN p_id_inventario INT,
    IN p_tipo_movimiento VARCHAR(20),
    IN p_cantidad DECIMAL(10,2),
    IN p_motivo TEXT,
    IN p_documento_referencia VARCHAR(50),
    IN p_realizado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255),
    OUT p_nuevo_stock DECIMAL(10,2)
)
BEGIN
    DECLARE v_stock_actual DECIMAL(10,2);
    DECLARE v_id_almacen INT;
    DECLARE v_nombre_item VARCHAR(200);
    DECLARE v_nuevo_stock DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al procesar el movimiento';
        SET p_nuevo_stock = 0;
    END;
    START TRANSACTION;
    SELECT stock_actual, id_almacen, nombre
    INTO v_stock_actual, v_id_almacen, v_nombre_item
    FROM TblInventario
    WHERE id_inventario = p_id_inventario;
    IF v_nombre_item IS NULL THEN
        SET p_success = FALSE;
        SET p_message = 'Item no encontrado';
        SET p_nuevo_stock = 0;
        ROLLBACK;
    ELSE
        IF p_tipo_movimiento = 'ENTRADA' THEN
            SET v_nuevo_stock = v_stock_actual + p_cantidad;
        ELSEIF p_tipo_movimiento = 'SALIDA' THEN
            IF p_cantidad > v_stock_actual THEN
                SET p_success = FALSE;
                SET p_message = CONCAT('Stock insuficiente. Disponible: ', v_stock_actual);
                SET p_nuevo_stock = v_stock_actual;
                ROLLBACK;
            ELSE
                SET v_nuevo_stock = v_stock_actual - p_cantidad;
            END IF;
        ELSEIF p_tipo_movimiento = 'AJUSTE' THEN
            SET v_nuevo_stock = p_cantidad;
        ELSE
            SET p_success = FALSE;
            SET p_message = 'Tipo de movimiento inválido';
            SET p_nuevo_stock = v_stock_actual;
            ROLLBACK;
        END IF;
        IF p_success IS NULL THEN
            UPDATE TblInventario
            SET stock_actual = v_nuevo_stock, fecha_actualizacion = NOW()
            WHERE id_inventario = p_id_inventario;
            INSERT INTO TblMovimientoInventario (
                codigo_movimiento, id_inventario, id_almacen_origen, tipo_movimiento,
                cantidad, motivo, observaciones, id_documento_referencia,
                costo_unitario, costo_total, fecha_movimiento, realizado_por, aprobado_por
            ) VALUES (
                CONCAT(CASE p_tipo_movimiento WHEN 'ENTRADA' THEN 'ENT' WHEN 'SALIDA' THEN 'SAL' WHEN 'AJUSTE' THEN 'AJU' END,
                       '-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(p_id_inventario, 5, '0')),
                p_id_inventario, v_id_almacen, p_tipo_movimiento, p_cantidad, p_motivo, NULL, NULL,
                (SELECT precio_compra FROM TblInventario WHERE id_inventario = p_id_inventario),
                p_cantidad * (SELECT precio_compra FROM TblInventario WHERE id_inventario = p_id_inventario),
                NOW(), p_realizado_por, NULL
            );
            SET p_success = TRUE;
            SET p_message = CONCAT('Movimiento registrado correctamente. Nuevo stock: ', v_nuevo_stock);
            SET p_nuevo_stock = v_nuevo_stock;
            COMMIT;
        END IF;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_registrar_movimiento_stock`$$

DELIMITER ;

-- ENUM original (solo si no quedan movimientos ENTREGA_PERSONAL)
SET @hay := (SELECT COUNT(*) FROM `TblMovimientoInventario` WHERE tipo_documento = 'ENTREGA_PERSONAL');
SET @sql := IF(@hay = 0,
  'ALTER TABLE `TblMovimientoInventario` MODIFY COLUMN `tipo_documento` ENUM(''COMPRA'',''REQUERIMIENTO'',''ORDEN_TRABAJO'',''AJUSTE_INVENTARIO'',''TRANSFERENCIA'') DEFAULT NULL',
  'SELECT ''ENUM sin cambios: hay movimientos ENTREGA_PERSONAL'' AS info');
PREPARE st FROM @sql;
EXECUTE st;
DEALLOCATE PREPARE st;
