-- ============================================================================
-- STORED PROCEDURE: sp_AprobarRequerimiento
-- ============================================================================
-- Propósito: Aprobar un requerimiento de forma progresiva
--            - Verifica que el usuario tenga un registro PENDIENTE
--            - Actualiza el registro a APROBADO
--            - Si todos los pasos están aprobados, cambia estado a APROBADO
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_AprobarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_AprobarRequerimiento(
    IN p_id_requerimiento INT,
    IN p_num_documento_aprobador INT,
    IN p_comentario TEXT,
    OUT p_aprobacion_completa BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_cargo INT;
    DECLARE v_id_registro INT;
    DECLARE v_total_pasos INT;
    DECLARE v_pasos_aprobados INT;
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
    -- PASO 1: OBTENER CARGO DEL USUARIO
    -- ========================================================================
    SELECT id_cargo INTO v_id_cargo
    FROM TblUsuario
    WHERE num_documento = p_num_documento_aprobador 
    AND estado = 'Activo'
    LIMIT 1;
    
    IF v_id_cargo IS NULL THEN
        SET p_mensaje = '❌ Usuario no tiene cargo asignado o no está activo';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuario no tiene cargo asignado';
    END IF;
    
    -- ========================================================================
    -- PASO 2: VERIFICAR QUE TIENE REGISTRO PENDIENTE
    -- ========================================================================
    SELECT ra.id_registro INTO v_id_registro
    FROM TblRegistroAprobacion ra
    WHERE ra.id_tipo_documento = 2  -- 2 = Requerimiento
      AND ra.id_documento_referencia = p_id_requerimiento
      AND ra.id_cargo_aprobador = v_id_cargo
      AND ra.estado_aprobacion = 'PENDIENTE'
    LIMIT 1;
    
    IF v_id_registro IS NULL THEN
        SET p_mensaje = '❌ No tienes permiso para aprobar este requerimiento';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No tienes permiso para aprobar este requerimiento';
    END IF;
    
    -- ========================================================================
    -- PASO 3: ACTUALIZAR REGISTRO A APROBADO
    -- ========================================================================
    UPDATE TblRegistroAprobacion 
    SET 
        estado_aprobacion = 'APROBADO',
        num_documento_aprobador = p_num_documento_aprobador,
        comentario = p_comentario,
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;
    
    -- ========================================================================
    -- PASO 4: VERIFICAR SI TODOS LOS PASOS ESTÁN APROBADOS
    -- ========================================================================
    SELECT 
        COUNT(*) as total_pasos,
        SUM(CASE WHEN estado_aprobacion = 'APROBADO' THEN 1 ELSE 0 END) as aprobados
    INTO v_total_pasos, v_pasos_aprobados
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2 
    AND id_documento_referencia = p_id_requerimiento;
    
    -- ========================================================================
    -- PASO 5: SI TODOS APROBADOS, CAMBIAR ESTADO DEL REQUERIMIENTO
    -- ========================================================================
    IF v_total_pasos = v_pasos_aprobados THEN
        UPDATE TblRequerimiento 
        SET 
            estado = 'APROBADO',
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        SET p_aprobacion_completa = TRUE;
        SET p_mensaje = CONCAT(
            '✅ Requerimiento COMPLETAMENTE APROBADO. ',
            'Todos los ', v_total_pasos, ' pasos fueron aprobados.'
        );
    ELSE
        SET p_aprobacion_completa = FALSE;
        SET p_mensaje = CONCAT(
            '✅ Paso aprobado. ',
            'Progreso: ', v_pasos_aprobados, '/', v_total_pasos, ' pasos aprobados.'
        );
    END IF;
    
    COMMIT;

END$$

DELIMITER ;

SELECT '✅ SP sp_AprobarRequerimiento creado correctamente' AS estado;

-- ============================================================================
-- PRUEBA
-- ============================================================================
/*
-- Aprobar requerimiento
CALL sp_AprobarRequerimiento(
    56,                     -- id_requerimiento
    12345678,               -- num_documento_aprobador
    'Aprobado por prueba',  -- comentario
    @aprobacion_completa,
    @mensaje
);

SELECT 
    @aprobacion_completa AS aprobacion_completa,
    @mensaje AS mensaje;
*/
