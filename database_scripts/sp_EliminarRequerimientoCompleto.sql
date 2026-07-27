-- =============================================================================
-- SP: Eliminar Requerimiento Completo (Hard Delete)
-- =============================================================================
-- Propósito: Eliminar por completo un requerimiento y todos sus rastros
-- 
-- Eliminará:
-- 1. TblRequerimientoDetalle (todos los items del requerimiento)
-- 2. TblRegistroAprobacion (registros de flujo de aprobación)
-- 3. TblRequerimiento (el requerimiento principal)
--
-- Nota: También reversa los cambios en cantidad_consumida y cantidad_saldo 
--       del presupuesto vinculado (si existe)
-- =============================================================================

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarRequerimientoCompleto`(
    IN p_id_requerimiento INT,
    OUT p_resultado VARCHAR(20),
    OUT p_mensaje VARCHAR(255),
    OUT p_detalles_eliminados INT,
    OUT p_aprobaciones_eliminadas INT
)
sp_main: BEGIN
    DECLARE v_id_presupuesto INT;
    DECLARE v_cantidad_total_requerimiento DECIMAL(12,2);
    
    -- VARIABLES PARA AUDITORÍA
    DECLARE v_timestamp DATETIME DEFAULT NOW();
    
    -- HANDLERS
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Error ejecutando procedimiento';
        ROLLBACK;
    END;
    
    -- ==========================================================================
    -- PASO 1: VALIDACIÓN
    -- ==========================================================================
    
    SET p_detalles_eliminados = 0;
    SET p_aprobaciones_eliminadas = 0;
    
    -- Verificar que el requerimiento existe
    IF NOT EXISTS (SELECT 1 FROM TblRequerimiento WHERE id_requerimiento = p_id_requerimiento) THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Requerimiento no encontrado';
        LEAVE sp_main;
    END IF;
    
    -- Obtener datos del requerimiento para reversar cambios en presupuesto
    SELECT 
        id_presupuesto,
        COALESCE((SELECT COALESCE(SUM(cantidad), 0) FROM TblRequerimientoDetalle WHERE id_requerimiento = p_id_requerimiento), 0)
    INTO v_id_presupuesto, v_cantidad_total_requerimiento
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- ==========================================================================
    -- PASO 2: ELIMINAR DETALLES DEL REQUERIMIENTO
    -- ==========================================================================
    
    SELECT COUNT(*) INTO p_detalles_eliminados
    FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
    DELETE FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- ==========================================================================
    -- PASO 3: ELIMINAR REGISTROS DE APROBACIÓN
    -- ==========================================================================
    
    SELECT COUNT(*) INTO p_aprobaciones_eliminadas
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_requerimiento
      AND id_tipo_documento = 2;  -- 2 = Requerimiento
    
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_requerimiento
      AND id_tipo_documento = 2;
    
    -- ==========================================================================
    -- PASO 4: ELIMINAR REQUERIMIENTO PRINCIPAL
    -- ==========================================================================
    
    DELETE FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- ==========================================================================
    -- PASO 5: REVERSAR CAMBIOS EN PRESUPUESTO (si existe)
    -- ==========================================================================
    
    IF v_id_presupuesto IS NOT NULL AND v_id_presupuesto > 0 THEN
        -- Restar cantidad_consumida (reversar)
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total_requerimiento),
            cantidad_saldo = cantidad_saldo + v_cantidad_total_requerimiento,
            monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total_requerimiento),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = v_id_presupuesto;
        
        -- Reversar detalles del presupuesto también
        UPDATE TblPresupuestoDetalle pd
        SET 
            pd.cantidad_consumida = 0,
            pd.cantidad_saldo = pd.cantidad
        WHERE pd.id_presupuesto = v_id_presupuesto;
    END IF;
    
    -- ==========================================================================
    -- RESULTADO EXITOSO
    -- ==========================================================================
    
    SET p_resultado = 'OK';
    SET p_mensaje = 'Requerimiento eliminado completamente';
    
END sp_main$$

DELIMITER ;

-- =============================================================================
-- TEST DEL SP
-- =============================================================================
-- CALL sp_EliminarRequerimientoCompleto(36, @res, @msg, @det, @apr);
-- SELECT @res AS resultado, @msg AS mensaje, @det AS detalles_eliminados, @apr AS aprobaciones_eliminadas;
