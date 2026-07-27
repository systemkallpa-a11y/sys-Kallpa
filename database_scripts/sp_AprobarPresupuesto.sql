-- ============================================================================
-- STORED PROCEDURE: sp_AprobarPresupuesto
-- PROPÓSITO: Cambiar estado de presupuesto a APROBADO y registrar aprobador
-- FECHA: 14 de Julio de 2026
-- ACTUALIZADO: 17 de Julio de 2026 - Agregar INSERT si no existe registro
-- PARÁMETROS: 
--   - p_id_presupuesto INT
--   - p_num_documento_aprobador INT (quien aprueba)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_AprobarPresupuesto;

DELIMITER //

CREATE PROCEDURE sp_AprobarPresupuesto(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT
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
    
    -- Verificar que está en estado PENDIENTE o RECHAZADO (permite re-envío)
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE o RECHAZADO. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- PASO 1: Actualizar estado del presupuesto a APROBADO
    UPDATE TblPresupuesto
    SET 
        estado = 'APROBADO'
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 2: Registrar en TblRegistroAprobacion
    -- Verificar si existe registro en TblRegistroAprobacion
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Si NO existe registro, crear uno nuevo con estado APROBADO
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_documento_referencia,
            id_tipo_documento,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            1,                                      -- Paso por defecto: 1
            NULL,                                   -- Cargo (no requerido para presupuesto simple)
            p_num_documento_aprobador,              -- Usuario que aprueba
            'APROBADO',                             -- Estado: APROBADO
            NOW()                                   -- Fecha actual
        );
        
        SET v_mensaje = CONCAT('✅ Presupuesto ', p_id_presupuesto, ' APROBADO. Estado actualizado en TblPresupuesto. Registro nuevo creado en TblRegistroAprobacion');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'APROBADO',
            num_documento_aprobador = p_num_documento_aprobador,      -- Registrar documento del aprobador
            fecha_aprobacion = NOW()                        -- Registrar fecha de aprobación
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = 1;
        
        SET v_mensaje = CONCAT('✅ Presupuesto ', p_id_presupuesto, ' APROBADO. Estado actualizado en TblPresupuesto. Registro actualizado en TblRegistroAprobacion');
    END IF;
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP
-- ============================================================================

-- CALL sp_AprobarPresupuesto(1, 1);
-- SELECT * FROM TblPresupuesto WHERE id_presupuesto = 1;
-- SELECT * FROM TblRegistroAprobacion WHERE id_documento_referencia = 1;

SELECT 'Stored Procedure sp_AprobarPresupuesto actualizado exitosamente ✓' as resultado;
