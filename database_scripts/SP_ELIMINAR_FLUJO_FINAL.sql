-- ============================================================================
-- STORED PROCEDURE: sp_EliminarFlujoAprobacion (VERSIÓN FINAL)
-- PROPÓSITO: Eliminar un flujo de aprobación
-- CAMBIO: Permite eliminar AUNQUE haya documentos en proceso (solo advierte)
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
        -- PASO 3: VERIFICAR SI HAY DOCUMENTOS EN PROCESO (solo informar)
        -- ====================================================================
        
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
        
        -- ====================================================================
        -- PASO 4: ELIMINAR HISTORIAL DE APROBACIÓN
        -- ====================================================================
        
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND numero_paso = v_numero_paso;
        
        SET v_registros_aprobacion_eliminados = ROW_COUNT();
        
        -- ====================================================================
        -- PASO 5: ELIMINAR EL FLUJO DE APROBACIÓN
        -- ====================================================================
        
        DELETE FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        -- ====================================================================
        -- PASO 6: VALIDAR SI QUEDAN FLUJOS EN ESTE PASO
        -- ====================================================================
        
        SELECT COUNT(*) INTO v_flujos_en_paso
        FROM TblFlujoAprobacionCargos
        WHERE numero_paso = v_numero_paso
        AND id_tipo_documento = p_id_tipo_documento;
        
        -- ====================================================================
        -- PASO 7: PREPARAR RESPUESTA
        -- ====================================================================
        -- Si hay documentos pendientes, devolver ADVERTENCIA (pero flujo ya fue eliminado)
        -- Si NO hay documentos, devolver OK
        
        IF v_documentos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                '⚠️ Flujo eliminado. NOTA: Hay ',
                v_documentos_pendientes,
                ' ',
                v_nombre_documento,
                ' en proceso de aprobación que ya no tendrán este paso en su flujo. ',
                'Cargos restantes en paso ', v_numero_paso, ': ', v_flujos_en_paso
            );
        ELSE
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
    -- PASO 8: RETORNAR RESULTADO
    -- ========================================================================
    
    SELECT p_resultado AS resultado, p_mensaje AS mensaje;

END //

DELIMITER ;

SELECT '✅ Stored Procedure sp_EliminarFlujoAprobacion (VERSIÓN FINAL) creado exitosamente' as estado;

-- ============================================================================
-- CAMBIO IMPORTANTE:
-- ============================================================================
-- ANTES: Si hay documentos pendientes, NO eliminaba el flujo (ROLLBACK)
-- DESPUÉS: Elimina el flujo de todas formas, pero advierte al usuario
-- 
-- RAZÓN: Los pasos individuales de un flujo deben poder ser eliminados
-- administrativamente sin estar bloqueado por documentos en proceso.
-- El usuario recibe advertencia clara de las implicaciones.
-- ============================================================================

-- EJEMPLOS:

-- EJEMPLO 1: Eliminar flujo sin documentos pendientes
-- CALL sp_EliminarFlujoAprobacion(1, 1, @resultado, @mensaje);
-- SELECT @resultado AS resultado, @mensaje AS mensaje;
-- Resultado: OK

-- EJEMPLO 2: Eliminar flujo CON documentos pendientes
-- CALL sp_EliminarFlujoAprobacion(2, 1, @resultado, @mensaje);
-- SELECT @resultado AS resultado, @mensaje AS mensaje;
-- Resultado: ADVERTENCIA (pero flujo fue eliminado)

-- ============================================================================
