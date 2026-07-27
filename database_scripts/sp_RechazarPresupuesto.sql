-- ============================================================================
-- STORED PROCEDURE: sp_RechazarPresupuesto
-- PROPÓSITO: Cambiar estado de presupuesto a RECHAZADO y registrar rechazo
-- FECHA: 16 de Julio de 2026
-- ACTUALIZADO: 17 de Julio de 2026 - Agregar INSERT si no existe registro
-- PARÁMETROS: 
--   - p_id_presupuesto INT
--   - p_num_documento_rechazador INT (quien rechaza)
--   - p_motivo_rechazo VARCHAR(500) (motivo del rechazo - opcional)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_RechazarPresupuesto;

DELIMITER //

CREATE PROCEDURE sp_RechazarPresupuesto(
    IN p_id_presupuesto INT,
    IN p_num_documento_rechazador INT,
    IN p_motivo_rechazo VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    
    -- Verificar que el presupuesto existe
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no encontrado';
    END IF;
    
    -- Obtener estado actual
    SELECT estado INTO v_estado_actual
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Verificar que está en estado PENDIENTE o APROBADO (permite cambio)
    IF v_estado_actual NOT IN ('PENDIENTE', 'APROBADO') THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE o APROBADO. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- PASO 1: Actualizar estado del presupuesto a RECHAZADO
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO'
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 2: Registrar en TblRegistroAprobacion
    -- Verificar si existe registro en TblRegistroAprobacion
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Si NO existe registro, crear uno nuevo con estado RECHAZADO
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_documento_referencia,
            id_tipo_documento,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion,
            comentario
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            1,                                      -- Paso por defecto: 1
            NULL,                                   -- Cargo (no requerido para presupuesto simple)
            p_num_documento_rechazador,             -- Usuario que rechaza
            'RECHAZADO',                            -- Estado: RECHAZADO
            NOW(),                                  -- Fecha actual
            p_motivo_rechazo                        -- Motivo del rechazo
        );
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' rechazado correctamente (Nuevo registro creado)');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'RECHAZADO',
            num_documento_aprobador = p_num_documento_rechazador,      -- Registrar documento del rechazador
            fecha_aprobacion = NOW(),                        -- Registrar fecha de rechazo
            comentario = p_motivo_rechazo                    -- Registrar motivo del rechazo
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = 1;
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' rechazado correctamente (Registro actualizado)');
    END IF;
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP (COMENTAR DESPUÉS DE VERIFICAR)
-- ============================================================================
-- CALL sp_RechazarPresupuesto(5, 1, 'Presupuesto no cumple requisitos de calidad');
-- SELECT * FROM TblPresupuesto WHERE id_presupuesto = 5;
-- SELECT * FROM TblRegistroAprobacion WHERE id_documento_referencia = 5;

SELECT 'Stored Procedure sp_RechazarPresupuesto actualizado exitosamente ✓' as resultado;
