-- ============================================================================
-- STORED PROCEDURE: sp_ActualizarRequerimiento
-- DESCRIPCIÓN: Actualiza datos de un requerimiento y sus detalles
--              Calcula cantidad total como suma de items
-- PARÁMETROS:
--   p_id_requerimiento: ID del requerimiento a actualizar
--   p_descripcion: Nueva descripción del requerimiento
--   p_observaciones: Nuevas observaciones del requerimiento
--   p_detalles_json: JSON con detalles actualizados [{id_detalle, descripcion, cantidad}, ...]
-- RETORNA: 
--   @p_resultado: 1 si fue exitoso, 0 si falló
-- AUTOR: Sistema Kallpa
-- FECHA: 2026-07-16
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_ActualizarRequerimiento(
    IN p_id_requerimiento INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_resultado INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_detalle_index INT DEFAULT 0;
    DECLARE v_total_detalles INT DEFAULT 0;
    DECLARE v_id_detalle INT;
    DECLARE v_desc_detalle VARCHAR(255);
    DECLARE v_cantidad_detalle INT;
    DECLARE v_cantidad_total INT DEFAULT 0;
    
    -- Verificar que el requerimiento existe
    SELECT COUNT(*)
    INTO v_existe
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no existe';
        SET p_resultado = 0;
    ELSE
        -- INICIO TRANSACCIÓN
        START TRANSACTION;
        
        -- Actualizar detalles si se proporcionan
        IF p_detalles_json IS NOT NULL AND p_detalles_json != '[]' THEN
            -- Procesar cada detalle del JSON
            SET v_detalle_index = 0;
            SET v_total_detalles = JSON_LENGTH(p_detalles_json);
            
            WHILE v_detalle_index < v_total_detalles DO
                -- Extraer datos del detalle (desescapando si es necesario)
                SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].id_detalle'));
                SET v_desc_detalle = JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].descripcion')));
                SET v_cantidad_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].cantidad'));
                
                -- Acumular cantidad total
                SET v_cantidad_total = v_cantidad_total + COALESCE(v_cantidad_detalle, 0);
                
                -- Actualizar el detalle
                UPDATE TblRequerimientoDetalle
                SET
                    descripcion = v_desc_detalle,
                    cantidad = v_cantidad_detalle,
                    fecha_actualizacion = NOW()
                WHERE id_detalle = v_id_detalle
                  AND id_requerimiento = p_id_requerimiento;
                
                SET v_detalle_index = v_detalle_index + 1;
            END WHILE;
        ELSE
            -- Si no hay JSON, calcular suma de cantidades actuales
            SELECT COALESCE(SUM(cantidad), 0)
            INTO v_cantidad_total
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
        END IF;
        
        -- Actualizar datos del requerimiento (incluyendo cantidad total)
        UPDATE TblRequerimiento
        SET
            descripcion = p_descripcion,
            observaciones = p_observaciones,
            cantidad = v_cantidad_total,
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        COMMIT;
        SET p_resultado = 1;
    END IF;
    
END$$

DELIMITER ;
