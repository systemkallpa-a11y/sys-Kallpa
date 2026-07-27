-- ============================================================================
-- SCRIPT CONSOLIDADO: EJECUTAR AMBOS SPs PROGRESIVOS
-- FECHA: 20 de Julio, 2026
-- PROPÓSITO: Crear/Actualizar los 2 SPs necesarios para aprobación progresiva
-- VERSIÓN: 2.0
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- SP 1: APROBAR PRESUPUESTO (PROGRESIVO v2)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_AprobarPresupuesto_Progresivo;

DELIMITER //

CREATE PROCEDURE sp_AprobarPresupuesto_Progresivo(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT,
    IN p_id_tipo_documento INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_siguiente_paso INT;
    DECLARE v_es_final TINYINT;
    DECLARE v_pasos_totales INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    DECLARE v_id_cargo INT;
    
    -- PASO 1: VALIDACIONES BÁSICAS
    
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no encontrado';
    END IF;
    
    SELECT estado INTO v_estado_actual
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Presupuesto en estado ', v_estado_actual, '. No puede aprobarse.');
    END IF;
    
    -- PASO 2: OBTENER SIGUIENTE PASO PENDIENTE
    
    SELECT 
        COALESCE(MIN(fc.numero_paso), 1) INTO v_siguiente_paso
    FROM TblFlujoAprobacionCargos fc
    WHERE fc.id_tipo_documento = p_id_tipo_documento
    AND fc.numero_paso > COALESCE(
        (SELECT MAX(numero_paso) 
         FROM TblRegistroAprobacion 
         WHERE id_documento_referencia = p_id_presupuesto 
         AND id_tipo_documento = p_id_tipo_documento 
         AND estado_aprobacion = 'APROBADO'), 
        0
    )
    AND fc.es_requerido = 1
    AND fc.activo = 1;
    
    IF v_siguiente_paso IS NULL THEN
        SELECT MIN(numero_paso) INTO v_siguiente_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1
        AND activo = 1;
    END IF;
    
    IF v_siguiente_paso IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay pasos de aprobación configurados para este tipo de documento';
    END IF;
    
    -- PASO 3: OBTENER INFORMACIÓN DEL PASO ACTUAL
    
    SELECT 
        es_final,
        id_cargo INTO v_es_final, v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- PASO 4: REGISTRAR LA APROBACIÓN EN TblRegistroAprobacion
    
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso;
    
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento,
            id_documento_referencia,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion
        ) VALUES (
            p_id_tipo_documento,
            p_id_presupuesto,
            v_siguiente_paso,
            v_id_cargo,
            p_num_documento_aprobador,
            'APROBADO',
            NOW()
        );
    ELSE
        UPDATE TblRegistroAprobacion
        SET 
            num_documento_aprobador = p_num_documento_aprobador,
            estado_aprobacion = 'APROBADO',
            fecha_aprobacion = NOW()
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_siguiente_paso;
    END IF;
    
    -- PASO 5: VERIFICAR SI ES EL ÚLTIMO PASO
    
    IF v_es_final = 1 THEN
        
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1
        AND activo = 1;
        
        SELECT COUNT(*) INTO v_pasos_aprobados
        FROM TblRegistroAprobacion
        WHERE id_documento_referencia = p_id_presupuesto
        AND id_tipo_documento = p_id_tipo_documento
        AND estado_aprobacion = 'APROBADO';
        
        IF v_pasos_totales = v_pasos_aprobados AND v_pasos_totales > 0 THEN
            
            UPDATE TblPresupuesto
            SET 
                estado = 'APROBADO',
                fecha_actualizacion = NOW()
            WHERE id_presupuesto = p_id_presupuesto;
            
            SET v_mensaje = CONCAT(
                '✅ ¡PRESUPUESTO COMPLETAMENTE APROBADO! ',
                'Todos los ', v_pasos_totales, ' pasos fueron completados.'
            );
        ELSE
            SET v_mensaje = CONCAT(
                '⚠️ Paso ', v_siguiente_paso, ' aprobado. ',
                'Pasos aprobados: ', v_pasos_aprobados, '/', v_pasos_totales
            );
        END IF;
        
    ELSE
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1
        AND activo = 1;
        
        SELECT COUNT(*) INTO v_pasos_aprobados
        FROM TblRegistroAprobacion
        WHERE id_documento_referencia = p_id_presupuesto
        AND id_tipo_documento = p_id_tipo_documento
        AND estado_aprobacion = 'APROBADO';
        
        SET v_mensaje = CONCAT(
            '✅ Paso ', v_siguiente_paso, ' aprobado. ',
            'Esperando paso siguiente. ',
            'Progreso: ', v_pasos_aprobados, '/', v_pasos_totales
        );
    END IF;
    
    -- RESPUESTA
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_siguiente_paso AS paso_actual;

END //

DELIMITER ;

-- ============================================================================
-- SP 2: RECHAZAR PRESUPUESTO (PROGRESIVO v2)
-- ============================================================================

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
    
    -- PASO 1: VALIDACIONES BÁSICAS
    
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no encontrado';
    END IF;
    
    SELECT estado INTO v_estado_actual
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_estado_actual NOT IN ('PENDIENTE', 'APROBADO', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Presupuesto en estado ', v_estado_actual, '. No puede rechazarse.');
    END IF;
    
    -- PASO 2: OBTENER PASO ACTUAL
    
    SELECT MAX(numero_paso) INTO v_numero_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento;
    
    IF v_numero_paso_actual IS NULL THEN
        SET v_numero_paso_actual = 1;
    END IF;
    
    -- PASO 3: OBTENER CARGO DEL PASO ACTUAL
    
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_numero_paso_actual
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- PASO 4: ACTUALIZAR ESTADO DEL PRESUPUESTO A RECHAZADO
    
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 5: REGISTRAR EL RECHAZO EN TblRegistroAprobacion
    
    SELECT COUNT(*) INTO v_registro_rechazo_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_numero_paso_actual
    AND estado_aprobacion = 'RECHAZADO';
    
    IF v_registro_rechazo_existe = 0 THEN
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
    
    -- RESPUESTA
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_numero_paso_actual AS paso_rechazo;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN: Confirmar que SPs se crearon
-- ============================================================================

SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'kallgwkn_kallpa_bd'
AND ROUTINE_NAME LIKE 'sp_AprobarPresupuesto%'
OR ROUTINE_NAME LIKE 'sp_RechazarPresupuesto%'
ORDER BY ROUTINE_NAME;

-- ============================================================================
-- RESUMEN
-- ============================================================================

SELECT 
    '✅ ÉXITO: Ambos SPs progresivos han sido creados/actualizados' as estado,
    'sp_AprobarPresupuesto_Progresivo' as sp_1,
    'sp_RechazarPresupuesto_Progresivo' as sp_2,
    'Versión 2.0 - Simplificada' as version,
    '20 de Julio, 2026' as fecha;

-- ============================================================================
-- SCRIPT COMPLETADO
-- ============================================================================
