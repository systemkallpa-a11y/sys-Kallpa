-- ============================================================================
-- STORED PROCEDURE: sp_EliminarFlujoAprobacion (VERSIÓN CORREGIDA)
-- PROPÓSITO: Eliminar un flujo de aprobación de forma segura
-- FECHA: 21 de Julio de 2026
-- NOTA: Versión sin LEAVE (compatible con MySQL)
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- IMPORTANTE: ACTUALIZACIÓN - Versión mejorada con lógica de validación clara
-- ============================================================================

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
    DECLARE v_presupuestos_pendientes INT DEFAULT 0;
    DECLARE v_requerimientos_pendientes INT DEFAULT 0;
    DECLARE v_registros_aprobacion_eliminados INT DEFAULT 0;
    DECLARE v_flujos_en_paso INT DEFAULT 0;
    
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
        
        -- Validación según el tipo de documento
        IF p_id_tipo_documento = 1 THEN
            -- Es un flujo de PRESUPUESTO: validar TblPresupuesto
            SELECT COUNT(*) INTO v_presupuestos_pendientes
            FROM TblPresupuesto
            WHERE id_tipo_documento = 1
            AND estado IN ('PENDIENTE', 'RECHAZADO');
            
            IF v_presupuestos_pendientes > 0 THEN
                SET p_resultado = 'ADVERTENCIA';
                SET p_mensaje = CONCAT(
                    'No se puede eliminar: Hay ',
                    v_presupuestos_pendientes,
                    ' presupuestos en proceso de aprobación'
                );
            END IF;
            
        ELSEIF p_id_tipo_documento = 2 THEN
            -- Es un flujo de REQUERIMIENTO: validar TblRequerimiento
            SELECT COUNT(*) INTO v_requerimientos_pendientes
            FROM TblRequerimiento
            WHERE id_tipo_documento = 2
            AND estado IN ('PENDIENTE', 'RECHAZADO');
            
            IF v_requerimientos_pendientes > 0 THEN
                SET p_resultado = 'ADVERTENCIA';
                SET p_mensaje = CONCAT(
                    'No se puede eliminar: Hay ',
                    v_requerimientos_pendientes,
                    ' requerimientos en proceso de aprobación'
                );
            END IF;
        END IF;
        -- Proceder con eliminación solo si NO hay ADVERTENCIA
        IF p_resultado IS NULL OR p_resultado NOT IN ('ADVERTENCIA', 'ERROR') THEN
            -- ================================================================
            -- PASO 4: ELIMINAR HISTORIAL DE APROBACIÓN
            -- ================================================================
            
            DELETE FROM TblRegistroAprobacion
            WHERE id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_numero_paso;
            
            SET v_registros_aprobacion_eliminados = ROW_COUNT();
            
            -- ================================================================
            -- PASO 5: ELIMINAR EL FLUJO DE APROBACIÓN
            -- ================================================================
            
            DELETE FROM TblFlujoAprobacionCargos
            WHERE id_flujo_cargo = p_id_flujo_cargo;
            
            -- ================================================================
            -- PASO 6: VALIDAR SI QUEDAN FLUJOS EN ESTE PASO
            -- ================================================================
            
            SELECT COUNT(*) INTO v_flujos_en_paso
            FROM TblFlujoAprobacionCargos
            WHERE numero_paso = v_numero_paso
            AND id_tipo_documento = p_id_tipo_documento;
            
            -- ================================================================
            -- PASO 7: PREPARAR RESPUESTA DE ÉXITO
            -- ================================================================
            
            SET p_resultado = 'OK';
            SET p_mensaje = CONCAT(
                '✅ Flujo eliminado exitosamente. ',
                'Paso: ', v_numero_paso, '. ',
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

SELECT '✅ Stored Procedure sp_EliminarFlujoAprobacion (CORREGIDO) creado exitosamente' as estado;

-- ============================================================================
-- EJEMPLOS DE USO
-- ============================================================================

/*

EJEMPLO 1: Eliminar flujo de presupuesto

    CALL sp_EliminarFlujoAprobacion(1, 1, @resultado, @mensaje);
    SELECT @resultado AS resultado, @mensaje AS mensaje;

EJEMPLO 2: Eliminar flujo de requerimiento

    CALL sp_EliminarFlujoAprobacion(4, 2, @resultado, @mensaje);
    SELECT @resultado AS resultado, @mensaje AS mensaje;

RESULTADOS POSIBLES:

✅ OK:
    resultado: 'OK'
    mensaje: '✅ Flujo eliminado exitosamente. Paso: 1. Registros eliminados: 0. Cargos restantes: 2'

⚠️ ADVERTENCIA:
    resultado: 'ADVERTENCIA'
    mensaje: 'No se puede eliminar: Hay 3 presupuestos en proceso de aprobación'

❌ ERROR:
    resultado: 'ERROR'
    mensaje: 'Flujo no encontrado'

*/

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

