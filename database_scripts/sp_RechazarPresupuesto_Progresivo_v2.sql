-- ============================================================================
-- STORED PROCEDURE: sp_RechazarPresupuesto_Progresivo (VERSIÓN 2 - SIMPLIFICADA)
-- PROPÓSITO: Manejar rechazo en cualquier paso del flujo progresivo
-- LÓGICA: Un rechazo en cualquier paso revierte documento a estado RECHAZADO
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_RechazarPresupuesto_Progresivo;

DELIMITER //

CREATE PROCEDURE sp_RechazarPresupuesto_Progresivo(
    IN p_id_presupuesto INT,
    IN p_num_documento_rechazador INT,
    IN p_motivo_rechazo VARCHAR(500),
    IN p_id_tipo_documento INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_numero_paso_actual INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_rechazo_existe INT;
    DECLARE v_id_cargo INT;
    
    -- ========================================================================
    -- PASO 1: VALIDACIONES BÁSICAS
    -- ========================================================================
    
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
    
    -- Verificar que está en estado válido para rechazo
    IF v_estado_actual NOT IN ('PENDIENTE', 'APROBADO', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Presupuesto en estado ', v_estado_actual, '. No puede rechazarse.');
    END IF;
    
    -- ========================================================================
    -- PASO 2: OBTENER PASO ACTUAL
    -- ========================================================================
    
    SELECT MAX(numero_paso) INTO v_numero_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento;
    
    -- Si no hay pasos registrados, usar el primero
    IF v_numero_paso_actual IS NULL THEN
        SET v_numero_paso_actual = 1;
    END IF;
    
    -- ========================================================================
    -- PASO 3: OBTENER CARGO DEL PASO ACTUAL
    -- ========================================================================
    
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_numero_paso_actual
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- ========================================================================
    -- PASO 4: ACTUALIZAR ESTADO DEL PRESUPUESTO A RECHAZADO
    -- ========================================================================
    
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO 5: REGISTRAR EL RECHAZO EN TblRegistroAprobacion
    -- ========================================================================
    
    -- Verificar si ya existe un registro de rechazo para este paso
    SELECT COUNT(*) INTO v_registro_rechazo_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_numero_paso_actual
    AND estado_aprobacion = 'RECHAZADO';
    
    IF v_registro_rechazo_existe = 0 THEN
        -- Crear nuevo registro de rechazo
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento,
            id_documento_referencia,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion,
            comentario
        ) VALUES (
            p_id_tipo_documento,
            p_id_presupuesto,
            v_numero_paso_actual,
            v_id_cargo,
            p_num_documento_rechazador,
            'RECHAZADO',
            NOW(),
            p_motivo_rechazo
        );
        
        SET v_mensaje = CONCAT(
            '❌ Presupuesto rechazado en paso ', v_numero_paso_actual, 
            '. Motivo: ', COALESCE(p_motivo_rechazo, 'Sin especificar')
        );
    ELSE
        -- Actualizar registro existente
        UPDATE TblRegistroAprobacion
        SET 
            num_documento_aprobador = p_num_documento_rechazador,
            estado_aprobacion = 'RECHAZADO',
            fecha_aprobacion = NOW(),
            comentario = p_motivo_rechazo
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_numero_paso_actual;
        
        SET v_mensaje = CONCAT(
            '❌ Rechazo actualizado en paso ', v_numero_paso_actual, 
            '. Motivo: ', COALESCE(p_motivo_rechazo, 'Sin especificar')
        );
    END IF;
    
    -- ========================================================================
    -- RESPUESTA AL USUARIO
    -- ========================================================================
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_numero_paso_actual AS paso_rechazo;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ Stored Procedure sp_RechazarPresupuesto_Progresivo (v2) creado exitosamente' as estado;

-- ============================================================================
-- EJEMPLO DE USO
-- ============================================================================

/*

CALL sp_RechazarPresupuesto_Progresivo(5, 4, 'Presupuesto no cumple requisitos', 1);

PARÁMETROS:
  p_id_presupuesto:         5 (ID del presupuesto)
  p_num_documento_rechazador: 4 (Usuario que rechaza)
  p_motivo_rechazo:         'Presupuesto no cumple requisitos'
  p_id_tipo_documento:      1 (Presupuesto)

RESULTADO:
  resultado: OK
  mensaje: ❌ Presupuesto rechazado en paso 1. Motivo: Presupuesto no cumple requisitos
  paso_rechazo: 1

EFECTO EN BD:
  1. UPDATE TblPresupuesto SET estado = 'RECHAZADO'
  2. Inserta/Actualiza en TblRegistroAprobacion con estado 'RECHAZADO'
  3. Guarda el motivo en comentario

*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
