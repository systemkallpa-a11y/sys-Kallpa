-- ============================================================================
-- STORED PROCEDURE: sp_EliminarRequerimiento
-- ============================================================================
-- Propósito: Eliminar un requerimiento completamente (Hard Delete)
--            - Elimina detalles del requerimiento
--            - Elimina registros de aprobación
--            - Elimina el requerimiento principal
--            - Reversa cambios en presupuesto si está vinculado
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_EliminarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_EliminarRequerimiento(
    IN p_id_requerimiento INT,
    OUT p_codigo VARCHAR(50),
    OUT p_detalles_eliminados INT,
    OUT p_aprobaciones_eliminadas INT,
    OUT p_presupuesto_reversado BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_requerimiento INT;
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_id_presupuesto INT;
    DECLARE v_cantidad_total DECIMAL(10,2);
    DECLARE v_detalles_count INT;
    DECLARE v_aprobaciones_count INT;
    DECLARE v_error_msg VARCHAR(500);
    
    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('❌ ERROR: ', v_error_msg);
    END;
    
    START TRANSACTION;
    
    -- ========================================================================
    -- PASO 0: VALIDAR QUE EL REQUERIMIENTO EXISTE
    -- ========================================================================
    SELECT 
        id_requerimiento,
        codigo,
        id_presupuesto
    INTO 
        v_id_requerimiento,
        v_codigo,
        v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_id_requerimiento IS NULL THEN
        SET p_mensaje = '❌ Requerimiento no encontrado';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    
    -- Inicializar variables de salida
    SET p_codigo = v_codigo;
    SET p_presupuesto_reversado = FALSE;
    
    -- ========================================================================
    -- PASO 1: CALCULAR CANTIDAD TOTAL (si hay presupuesto vinculado)
    -- ========================================================================
    IF v_id_presupuesto IS NOT NULL THEN
        SELECT COALESCE(SUM(cantidad), 0)
        INTO v_cantidad_total
        FROM TblRequerimientoDetalle
        WHERE id_requerimiento = p_id_requerimiento;
    ELSE
        SET v_cantidad_total = 0;
    END IF;
    
    -- ========================================================================
    -- PASO 2: REVERSAR PRESUPUESTO (si está vinculado)
    -- ========================================================================
    IF v_id_presupuesto IS NOT NULL AND v_cantidad_total > 0 THEN
        
        -- 2A: Actualizar TblPresupuesto (totales)
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total),
            cantidad_saldo = cantidad_saldo + v_cantidad_total,
            monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = v_id_presupuesto;
        
        -- 2B: Actualizar TblPresupuestoDetalle (por descripción)
        UPDATE TblPresupuestoDetalle pd
        INNER JOIN (
            SELECT 
                LOWER(TRIM(descripcion)) as descripcion_key,
                SUM(cantidad) as total_cantidad
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento
            GROUP BY LOWER(TRIM(descripcion))
        ) rd ON LOWER(TRIM(pd.descripcion)) = rd.descripcion_key
        SET 
            pd.cantidad_consumida = GREATEST(0, pd.cantidad_consumida - rd.total_cantidad),
            pd.cantidad_saldo = pd.cantidad - GREATEST(0, pd.cantidad_consumida - rd.total_cantidad),
            pd.fecha_actualizacion = NOW()
        WHERE pd.id_presupuesto = v_id_presupuesto;
        
        SET p_presupuesto_reversado = TRUE;
    END IF;
    
    -- ========================================================================
    -- PASO 3: ELIMINAR DETALLES DEL REQUERIMIENTO
    -- ========================================================================
    DELETE FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
    SET p_detalles_eliminados = ROW_COUNT();
    
    -- ========================================================================
    -- PASO 4: ELIMINAR REGISTROS DE APROBACIÓN
    -- ========================================================================
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_requerimiento
    AND id_tipo_documento = 2;  -- 2 = Requerimiento
    
    SET p_aprobaciones_eliminadas = ROW_COUNT();
    
    -- ========================================================================
    -- PASO 5: ELIMINAR REQUERIMIENTO PRINCIPAL
    -- ========================================================================
    DELETE FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- ========================================================================
    -- COMMIT Y MENSAJE FINAL
    -- ========================================================================
    COMMIT;
    
    SET p_mensaje = CONCAT(
        '✅ Requerimiento ', v_codigo, ' eliminado completamente. ',
        'Detalles: ', p_detalles_eliminados, ', ',
        'Aprobaciones: ', p_aprobaciones_eliminadas, ', ',
        'Presupuesto reversado: ', IF(p_presupuesto_reversado, 'Sí', 'No')
    );

END$$

DELIMITER ;

SELECT '✅ SP sp_EliminarRequerimiento creado correctamente' AS estado;

-- ============================================================================
-- PRUEBA
-- ============================================================================
/*
-- Eliminar requerimiento de prueba
CALL sp_EliminarRequerimiento(
    999,  -- id_requerimiento
    @codigo,
    @detalles_eliminados,
    @aprobaciones_eliminadas,
    @presupuesto_reversado,
    @mensaje
);

SELECT 
    @codigo AS codigo,
    @detalles_eliminados AS detalles_eliminados,
    @aprobaciones_eliminadas AS aprobaciones_eliminadas,
    @presupuesto_reversado AS presupuesto_reversado,
    @mensaje AS mensaje;
*/
