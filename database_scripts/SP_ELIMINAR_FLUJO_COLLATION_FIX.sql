-- ============================================================================
-- STORED PROCEDURE: sp_EliminarFlujoAprobacion (FIX COLLATION)
-- PROBLEMA: Illegal mix of collations for operation 'concat'
-- SOLUCIÓN: Usar CAST explícito para todas las variables en CONCAT
-- FECHA: 22 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_EliminarFlujoAprobacion;

DELIMITER //

CREATE PROCEDURE sp_EliminarFlujoAprobacion(
    IN p_id_flujo_cargo INT,
    IN p_id_tipo_documento INT,
    OUT p_resultado VARCHAR(50),
    OUT p_mensaje VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_flujo_existe INT DEFAULT 0;
    DECLARE v_numero_paso INT DEFAULT 0;
    DECLARE v_documentos_pendientes INT DEFAULT 0;
    DECLARE v_registros_aprobacion_eliminados INT DEFAULT 0;
    DECLARE v_flujos_en_paso INT DEFAULT 0;
    DECLARE v_nombre_documento VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    
    SELECT COUNT(*) INTO v_flujo_existe
    FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    IF v_flujo_existe = 0 THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Flujo no encontrado';
    ELSE
        SELECT numero_paso INTO v_numero_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        IF p_id_tipo_documento = 1 THEN
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblPresupuesto
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 1;
            
            SET v_nombre_documento = 'presupuestos';
            
        ELSEIF p_id_tipo_documento = 2 THEN
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblRequerimiento
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 2;
            
            SET v_nombre_documento = 'requerimientos';
        END IF;
        
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND numero_paso = v_numero_paso;
        
        SET v_registros_aprobacion_eliminados = ROW_COUNT();
        
        DELETE FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        SELECT COUNT(*) INTO v_flujos_en_paso
        FROM TblFlujoAprobacionCargos
        WHERE numero_paso = v_numero_paso
        AND id_tipo_documento = p_id_tipo_documento;
        
        IF v_documentos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                CAST('⚠️ Flujo eliminado. NOTA: Hay ' AS CHAR),
                CAST(v_documentos_pendientes AS CHAR),
                CAST(' ' AS CHAR),
                CAST(v_nombre_documento AS CHAR),
                CAST(' en proceso de aprobación que ya no tendrán este paso en su flujo. Cargos restantes en paso ' AS CHAR),
                CAST(v_numero_paso AS CHAR),
                CAST(': ' AS CHAR),
                CAST(v_flujos_en_paso AS CHAR)
            );
        ELSE
            SET p_resultado = 'OK';
            SET p_mensaje = CONCAT(
                CAST('✅ Flujo eliminado exitosamente. Paso: ' AS CHAR),
                CAST(v_numero_paso AS CHAR),
                CAST('. Tipo: ' AS CHAR),
                CAST(v_nombre_documento AS CHAR),
                CAST('. Registros de aprobación eliminados: ' AS CHAR),
                CAST(v_registros_aprobacion_eliminados AS CHAR),
                CAST('. Cargos restantes en este paso: ' AS CHAR),
                CAST(v_flujos_en_paso AS CHAR)
            );
        END IF;
    END IF;
    
    SELECT p_resultado AS resultado, p_mensaje AS mensaje;

END //

DELIMITER ;

SELECT '✅ Stored Procedure sp_EliminarFlujoAprobacion (COLLATION FIX) creado exitosamente' as estado;

-- ============================================================================
