-- ============================================================================
-- STORED PROCEDURE: sp_EliminarRequerimiento
-- ============================================================================
-- Propósito: Eliminar un requerimiento completamente (Hard Delete)
--            - Elimina detalles del requerimiento
--            - Elimina registros de aprobación
--            - Elimina el requerimiento principal
--            - Reversa cambios en presupuesto si está vinculado
--
-- IMPORTANTE: cantidad_saldo es columna GENERATED, se recalcula automáticamente
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
    DECLARE v_codigo VARCHAR(50) DEFAULT '';
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    DECLARE v_cantidad_total DECIMAL(10,2) DEFAULT 0;
    
    -- Inicializar OUT
    SET p_codigo = '';
    SET p_detalles_eliminados = 0;
    SET p_aprobaciones_eliminadas = 0;
    SET p_presupuesto_reversado = 0;
    SET p_mensaje = '';
    
    -- Obtener datos del requerimiento
    SELECT codigo, id_presupuesto
    INTO v_codigo, v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- Si no existe
    IF v_codigo IS NULL OR v_codigo = '' THEN
        SET p_mensaje = CONCAT('ERROR: Requerimiento ', p_id_requerimiento, ' no encontrado');
    ELSE
        -- Requerimiento existe, proceder
        SET p_codigo = v_codigo;
        
        -- Calcular cantidad si hay presupuesto
        IF v_id_presupuesto IS NOT NULL THEN
            SELECT COALESCE(SUM(cantidad), 0)
            INTO v_cantidad_total
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Reversar presupuesto
            IF v_cantidad_total > 0 THEN
                -- Actualizar totales en TblPresupuesto
                UPDATE TblPresupuesto
                SET 
                    cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total),
                    cantidad_saldo = cantidad_saldo + v_cantidad_total,
                    monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total),
                    fecha_actualizacion = NOW()
                WHERE id_presupuesto = v_id_presupuesto;
                
                -- Actualizar detalles (NO tocar cantidad_saldo - es GENERATED)
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
                    pd.fecha_actualizacion = NOW()
                WHERE pd.id_presupuesto = v_id_presupuesto;
                
                SET p_presupuesto_reversado = 1;
            END IF;
        END IF;
        
        -- Eliminar detalles
        DELETE FROM TblRequerimientoDetalle
        WHERE id_requerimiento = p_id_requerimiento;
        SET p_detalles_eliminados = ROW_COUNT();
        
        -- Eliminar aprobaciones
        DELETE FROM TblRegistroAprobacion
        WHERE id_documento_referencia = p_id_requerimiento
        AND id_tipo_documento = 2;
        SET p_aprobaciones_eliminadas = ROW_COUNT();
        
        -- Eliminar requerimiento
        DELETE FROM TblRequerimiento
        WHERE id_requerimiento = p_id_requerimiento;
        
        -- COMMIT para persistir cambios
        COMMIT;
        
        -- Mensaje de éxito
        SET p_mensaje = CONCAT(
            'OK: Requerimiento ', v_codigo, ' eliminado. ',
            'Detalles: ', p_detalles_eliminados, ', ',
            'Aprobaciones: ', p_aprobaciones_eliminadas, ', ',
            'Presupuesto reversado: ', IF(p_presupuesto_reversado = 1, 'Si', 'No')
        );
    END IF;

END$$

DELIMITER ;

SELECT '✅ SP sp_EliminarRequerimiento creado correctamente' AS estado;

-- ============================================================================
-- PRUEBA
-- ============================================================================
/*
CALL sp_EliminarRequerimiento(
    56,
    @p_codigo,
    @p_detalles_eliminados,
    @p_aprobaciones_eliminadas,
    @p_presupuesto_reversado,
    @p_mensaje
);

SELECT 
    @p_codigo as codigo,
    @p_detalles_eliminados as detalles_eliminados,
    @p_aprobaciones_eliminadas as aprobaciones_eliminadas,
    @p_presupuesto_reversado as presupuesto_reversado,
    @p_mensaje as mensaje;
*/
