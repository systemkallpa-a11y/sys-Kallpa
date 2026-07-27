-- ============================================================================
-- SCRIPT: Actualizar SP_ActualizarRequerimiento a V2.0
-- DESCRIPCIÓN: Reemplaza la versión antigua (v1.0) con la nueva (v2.0)
--              que permite editar items
-- FECHA: 2026-07-16
-- ============================================================================

-- Paso 1: Verificar SP actual
SELECT 'VERIFICANDO SP ACTUAL...' as status;
SHOW PROCEDURE STATUS WHERE Name = 'sp_ActualizarRequerimiento';

-- Paso 2: Eliminar SP antiguo
DROP PROCEDURE IF EXISTS sp_ActualizarRequerimiento;

-- Paso 3: Crear SP nuevo v2.0
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
        
        -- Actualizar datos del requerimiento
        UPDATE TblRequerimiento
        SET
            descripcion = p_descripcion,
            observaciones = p_observaciones,
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        -- Actualizar detalles si se proporcionan
        IF p_detalles_json IS NOT NULL AND p_detalles_json != '[]' THEN
            -- Procesar cada detalle del JSON
            SET v_detalle_index = 0;
            SET v_total_detalles = JSON_LENGTH(p_detalles_json);
            
            WHILE v_detalle_index < v_total_detalles DO
                -- Extraer datos del detalle (desescapando strings)
                SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].id_detalle'));
                SET v_desc_detalle = JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].descripcion')));
                SET v_cantidad_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].cantidad'));
                
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
        END IF;
        
        COMMIT;
        SET p_resultado = 1;
    END IF;
    
END$$

DELIMITER ;

-- Paso 4: Verificar SP creado
SELECT 'SP ACTUALIZADO EXITOSAMENTE' as status;
SHOW PROCEDURE STATUS WHERE Name = 'sp_ActualizarRequerimiento';

-- Paso 5: Verificar parámetros del SP
SELECT 'PARÁMETROS DEL SP:' as info;
SELECT 
    PARAMETER_NAME,
    PARAMETER_MODE,
    ORDINAL_POSITION,
    DATA_TYPE
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE SPECIFIC_NAME = 'sp_ActualizarRequerimiento'
ORDER BY ORDINAL_POSITION;

-- Paso 6: Prueba rápida (opcional - comentado)
-- CALL sp_ActualizarRequerimiento(1, 'Test', 'Test', '[]', @resultado);
-- SELECT @resultado AS resultado_prueba;

SELECT '✅ ACTUALIZACIÓN COMPLETADA' as estado;
