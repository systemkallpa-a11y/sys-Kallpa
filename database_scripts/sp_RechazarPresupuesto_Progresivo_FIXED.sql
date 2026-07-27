-- ============================================================================
-- STORED PROCEDURE: sp_RechazarPresupuesto_Progresivo (VERSIÓN FIXED - SIN DELIMITER)
-- PROPÓSITO: Manejar rechazo en flujo de aprobación progresivo
-- LÓGICA: Rechaza un paso y vuelve presupuesto a PENDIENTE desde el inicio
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_RechazarPresupuesto_Progresivo;

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
    DECLARE v_paso_actual INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_rechazo_existe INT;
    DECLARE v_id_cargo INT;
    
    -- PASO 1: VALIDACIONES BÁSICAS
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
    
    -- Verificar que está en estado PENDIENTE o APROBADO (puede ser rechazado en cualquier momento)
    IF v_estado_actual = 'RECHAZADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto ya fue rechazado. No puede rechazarse nuevamente.';
    END IF;
    
    IF v_estado_actual = 'ELIMINADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto eliminado. No puede rechazarse.';
    END IF;
    
    -- PASO 2: OBTENER PASO ACTUAL (EL QUE ESTÁ PENDIENTE O ÚLTIMO APROBADO)
    -- Buscar el último paso aprobado
    SELECT MAX(numero_paso) INTO v_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND estado_aprobacion = 'APROBADO';
    
    -- Si no hay ningún paso aprobado, es el Paso 1
    IF v_paso_actual IS NULL THEN
        SET v_paso_actual = 1;
    ELSE
        -- Si hay pasos aprobados, el rechazo es en el siguiente paso
        SET v_paso_actual = v_paso_actual + 1;
        
        -- Verificar que ese siguiente paso existe
        IF NOT EXISTS (
            SELECT 1 FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_paso_actual
        ) THEN
            -- Si no existe siguiente paso, fue rechazado el último paso aprobado
            SET v_paso_actual = (SELECT MAX(numero_paso) 
                                 FROM TblRegistroAprobacion
                                 WHERE id_documento_referencia = p_id_presupuesto
                                 AND id_tipo_documento = p_id_tipo_documento
                                 AND estado_aprobacion = 'APROBADO');
        END IF;
    END IF;
    
    -- Obtener cargo de este paso para auditoría
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_paso_actual;
    
    -- PASO 3: REGISTRAR EL RECHAZO EN TblRegistroAprobacion
    -- Verificar si ya existe registro para este paso
    SELECT COUNT(*) INTO v_registro_rechazo_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_paso_actual;
    
    IF v_registro_rechazo_existe = 0 THEN
        -- Crear nuevo registro de rechazo
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento,
            id_documento_referencia,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            comentario,
            fecha_aprobacion
        ) VALUES (
            p_id_tipo_documento,
            p_id_presupuesto,
            v_paso_actual,
            v_id_cargo,
            p_num_documento_rechazador,
            'RECHAZADO',
            p_motivo_rechazo,
            NOW()
        );
    ELSE
        -- Actualizar registro existente
        UPDATE TblRegistroAprobacion
        SET 
            num_documento_aprobador = p_num_documento_rechazador,
            estado_aprobacion = 'RECHAZADO',
            comentario = p_motivo_rechazo,
            fecha_aprobacion = NOW()
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_paso_actual;
    END IF;
    
    -- PASO 4: CAMBIAR ESTADO DE PRESUPUESTO A RECHAZADO
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 5: ELIMINAR REGISTROS DE PASOS POSTERIORES (CLEANUP)
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso > v_paso_actual
    AND estado_aprobacion = 'PENDIENTE';
    
    -- RESPUESTA AL USUARIO
    SET v_mensaje = CONCAT(
        '❌ Presupuesto RECHAZADO en Paso ', v_paso_actual, '. ',
        'Motivo: ', COALESCE(p_motivo_rechazo, 'Sin especificar'), '. ',
        'El presupuesto vuelve a estado PENDIENTE para re-envío.'
    );
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_paso_actual AS paso_rechazado;

END;
