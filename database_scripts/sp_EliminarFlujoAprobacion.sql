-- ============================================================================
-- STORED PROCEDURE: sp_EliminarFlujoAprobacion
-- PROPÓSITO: Eliminar un flujo de aprobación de forma segura y cascada
-- FECHA: 21 de Julio de 2026
-- DESCRIPCIÓN:
--   Elimina un flujo completo (todos los cargos de un paso)
--   Valida que no haya presupuestos/requerimientos en proceso
--   Elimina historial de aprobación relacionado
--   Usa transacción para garantizar consistencia
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
    DECLARE v_flujo_existe INT;
    DECLARE v_numero_paso INT;
    DECLARE v_presupuestos_pendientes INT;
    DECLARE v_requerimientos_pendientes INT;
    DECLARE v_registros_aprobacion_eliminados INT;
    DECLARE v_flujos_en_paso INT;
    DECLARE v_error_message VARCHAR(500);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_resultado = 'ERROR';
        SET p_mensaje = CONCAT('Error en SP: ', v_error_message);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- ========================================================================
    -- PASO 1: VALIDAR QUE EL FLUJO EXISTE
    -- ========================================================================
    
    SELECT COUNT(*) INTO v_flujo_existe
    FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    IF v_flujo_existe = 0 THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Flujo no encontrado';
        ROLLBACK;
        SELECT p_resultado, p_mensaje;
        LEAVE sp_EliminarFlujoAprobacion;
    END IF;
    
    -- ========================================================================
    -- PASO 2: OBTENER INFORMACIÓN DEL FLUJO
    -- ========================================================================
    
    SELECT numero_paso INTO v_numero_paso
    FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    -- ========================================================================
    -- PASO 3: VALIDAR QUE NO HAY DOCUMENTOS EN PROCESO
    -- ========================================================================
    
    -- Presupuestos pendientes (si es tipo_documento = 1)
    IF p_id_tipo_documento = 1 THEN
        SELECT COUNT(*) INTO v_presupuestos_pendientes
        FROM TblPresupuesto
        WHERE estado IN ('PENDIENTE', 'RECHAZADO')
        AND id_tipo_documento = p_id_tipo_documento;
        
        IF v_presupuestos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                'No se puede eliminar: Hay ',
                v_presupuestos_pendientes,
                ' presupuestos en proceso de aprobación'
            );
            ROLLBACK;
            SELECT p_resultado, p_mensaje;
            LEAVE sp_EliminarFlujoAprobacion;
        END IF;
    END IF;
    
    -- Requerimientos pendientes (si es tipo_documento = 2)
    IF p_id_tipo_documento = 2 THEN
        SELECT COUNT(*) INTO v_requerimientos_pendientes
        FROM TblRequerimiento
        WHERE estado IN ('PENDIENTE', 'RECHAZADO')
        AND id_tipo_documento = p_id_tipo_documento;
        
        IF v_requerimientos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                'No se puede eliminar: Hay ',
                v_requerimientos_pendientes,
                ' requerimientos en proceso de aprobación'
            );
            ROLLBACK;
            SELECT p_resultado, p_mensaje;
            LEAVE sp_EliminarFlujoAprobacion;
        END IF;
    END IF;
    
    -- ========================================================================
    -- PASO 4: ELIMINAR HISTORIAL DE APROBACIÓN
    -- ========================================================================
    
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_numero_paso;
    
    SET v_registros_aprobacion_eliminados = ROW_COUNT();
    
    -- ========================================================================
    -- PASO 5: ELIMINAR EL FLUJO DE APROBACIÓN
    -- ========================================================================
    
    DELETE FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    -- ========================================================================
    -- PASO 6: VALIDAR SI QUEDAN FLUJOS EN ESTE PASO
    -- ========================================================================
    
    SELECT COUNT(*) INTO v_flujos_en_paso
    FROM TblFlujoAprobacionCargos
    WHERE numero_paso = v_numero_paso
    AND id_tipo_documento = p_id_tipo_documento;
    
    -- ========================================================================
    -- PASO 7: CONFIRMAR TRANSACCIÓN
    -- ========================================================================
    
    COMMIT;
    
    -- ========================================================================
    -- PASO 8: PREPARAR RESPUESTA
    -- ========================================================================
    
    SET p_resultado = 'OK';
    SET p_mensaje = CONCAT(
        '✅ Flujo eliminado exitosamente. ',
        'Paso: ', v_numero_paso, '. ',
        'Registros de aprobación eliminados: ', v_registros_aprobacion_eliminados, '. ',
        'Cargos restantes en este paso: ', v_flujos_en_paso
    );
    
    SELECT p_resultado AS resultado, p_mensaje AS mensaje;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ Stored Procedure sp_EliminarFlujoAprobacion creado exitosamente' as estado;

-- ============================================================================
-- NOTAS DE USO:
-- ============================================================================

/*

EJEMPLO 1: Eliminar un flujo de aprobación

    CALL sp_EliminarFlujoAprobacion(5, 1, @resultado, @mensaje);
    
    Parámetros:
    - p_id_flujo_cargo: 5 (ID del flujo a eliminar)
    - p_id_tipo_documento: 1 (1=Presupuesto, 2=Requerimiento)
    - @resultado (OUT): 'OK' o 'ERROR' o 'ADVERTENCIA'
    - @mensaje (OUT): Mensaje de resultado

EJEMPLO 2: Verificar resultado

    SELECT @resultado AS resultado, @mensaje AS mensaje;

VALIDACIONES:
    ✓ El flujo debe existir
    ✓ No puede haber documentos en proceso (PENDIENTE o RECHAZADO)
    ✓ Elimina cascada: TblRegistroAprobacion + TblFlujoAprobacionCargos

RESULTADO POSIBLE:
    OK: Flujo eliminado correctamente
    ADVERTENCIA: Hay documentos en proceso (no se elimina)
    ERROR: Flujo no encontrado u otro error

RESPUESTA:
    {
        "resultado": "OK",
        "mensaje": "✅ Flujo eliminado. Registros de aprobación: 0. Cargos restantes: 2"
    }

*/

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

