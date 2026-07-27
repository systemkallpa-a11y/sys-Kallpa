-- ============================================================================
-- ACTUALIZACIÓN: SP sp_EliminarFlujoAprobacion
-- PROBLEMA: Validaba documentos de forma confusa
-- SOLUCIÓN: Simplificar lógica para validar SOLO el tipo correcto
-- FECHA: 22 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Eliminar versión anterior
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
    DECLARE v_nombre_documento VARCHAR(50);
    
    -- ========================================================================
    -- PASO 1: VALIDAR QUE EL FLUJO EXISTE
    -- ========================================================================
    
    SELECT COUNT(*) INTO v_flujo_existe
    FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    IF v_flujo_existe = 0 THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Flujo no encontrado';
    ELSE
        -- ====================================================================
        -- PASO 2: OBTENER INFORMACIÓN DEL FLUJO
        -- ====================================================================
        
        SELECT numero_paso INTO v_numero_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        -- ====================================================================
        -- PASO 3: VALIDAR QUE NO HAY DOCUMENTOS EN PROCESO
        -- ====================================================================
        -- Validar SOLO el tipo de documento correcto
        
        IF p_id_tipo_documento = 1 THEN
            -- Validar PRESUPUESTOS
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblPresupuesto
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 1;
            
            SET v_nombre_documento = 'presupuestos';
            
        ELSEIF p_id_tipo_documento = 2 THEN
            -- Validar REQUERIMIENTOS
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblRequerimiento
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 2;
            
            SET v_nombre_documento = 'requerimientos';
        ELSE
            SET p_resultado = 'ERROR';
            SET p_mensaje = 'Tipo de documento inválido';
        END IF;
        
        -- ====================================================================
        -- PASO 4: VERIFICAR SI HAY DOCUMENTOS EN PROCESO
        -- ====================================================================
        
        IF v_documentos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                'No se puede eliminar: Hay ',
                v_documentos_pendientes,
                ' ',
                v_nombre_documento,
                ' en proceso de aprobación'
            );
        ELSE
            -- ================================================================
            -- PASO 5: ELIMINAR HISTORIAL DE APROBACIÓN
            -- ================================================================
            
            DELETE FROM TblRegistroAprobacion
            WHERE id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_numero_paso;
            
            SET v_registros_aprobacion_eliminados = ROW_COUNT();
            
            -- ================================================================
            -- PASO 6: ELIMINAR EL FLUJO DE APROBACIÓN
            -- ================================================================
            
            DELETE FROM TblFlujoAprobacionCargos
            WHERE id_flujo_cargo = p_id_flujo_cargo;
            
            -- ================================================================
            -- PASO 7: VALIDAR SI QUEDAN FLUJOS EN ESTE PASO
            -- ================================================================
            
            SELECT COUNT(*) INTO v_flujos_en_paso
            FROM TblFlujoAprobacionCargos
            WHERE numero_paso = v_numero_paso
            AND id_tipo_documento = p_id_tipo_documento;
            
            -- ================================================================
            -- PASO 8: PREPARAR RESPUESTA DE ÉXITO
            -- ================================================================
            
            SET p_resultado = 'OK';
            SET p_mensaje = CONCAT(
                '✅ Flujo eliminado exitosamente. ',
                'Paso: ', v_numero_paso, '. ',
                'Tipo: ', v_nombre_documento, '. ',
                'Registros de aprobación eliminados: ', v_registros_aprobacion_eliminados, '. ',
                'Cargos restantes en este paso: ', v_flujos_en_paso
            );
        END IF;
    END IF;
    
    -- ========================================================================
    -- PASO 9: RETORNAR RESULTADO
    -- ========================================================================
    
    SELECT p_resultado AS resultado, p_mensaje AS mensaje;

END //

DELIMITER ;

SELECT '✅ Stored Procedure sp_EliminarFlujoAprobacion ACTUALIZADO exitosamente' as estado;

-- ============================================================================
-- CAMBIOS REALIZADOS:
-- ============================================================================
-- 1. Simplificada lógica de validación
-- 2. SOLO valida el tipo_documento correcto
-- 3. Variable v_nombre_documento para mensaje claro
-- 4. Eliminada confusión entre presupuestos y requerimientos
-- 5. Mensaje ahora incluye qué tipo se intentó eliminar
-- ============================================================================

-- EJEMPLOS DE USO:

-- EJEMPLO 1: Eliminar flujo de PRESUPUESTO (id_tipo_documento=1)
-- CALL sp_EliminarFlujoAprobacion(1, 1, @resultado, @mensaje);
-- SELECT @resultado AS resultado, @mensaje AS mensaje;

-- EJEMPLO 2: Eliminar flujo de REQUERIMIENTO (id_tipo_documento=2)
-- CALL sp_EliminarFlujoAprobacion(4, 2, @resultado, @mensaje);
-- SELECT @resultado AS resultado, @mensaje AS mensaje;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
