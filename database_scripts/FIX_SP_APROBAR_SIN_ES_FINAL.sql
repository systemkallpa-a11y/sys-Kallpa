-- ============================================================================
-- FIX: sp_AprobarPresupuesto_Progresivo
-- ============================================================================
-- Problema: Usa campo es_final que está en 0, por eso no cambia a APROBADO
-- Solución: Calcular dinámicamente si es el último paso
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_AprobarPresupuesto_Progresivo;

DELIMITER $$

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
    DECLARE v_max_paso INT;
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
        SET MESSAGE_TEXT = 'Presupuesto no puede aprobarse. Estado incorrecto.';
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
        SET MESSAGE_TEXT = 'No hay pasos de aprobación configurados';
    END IF;
    
    -- PASO 3: OBTENER id_cargo del paso actual
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- PASO 4: REGISTRAR LA APROBACIÓN
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
    
    -- PASO 5: CALCULAR SI ES EL ÚLTIMO PASO (DINÁMICAMENTE)
    -- Obtener el máximo número de paso del flujo
    SELECT MAX(numero_paso) INTO v_max_paso
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND es_requerido = 1
    AND activo = 1;
    
    -- Contar pasos totales y aprobados
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
    
    -- ⭐ CAMBIO CLAVE: Comparar v_siguiente_paso con v_max_paso (NO usar es_final)
    IF v_siguiente_paso = v_max_paso THEN
        -- Es el último paso, verificar si TODOS los pasos están aprobados
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
        -- No es el último paso, presupuesto sigue PENDIENTE
        SET v_mensaje = CONCAT(
            '✅ Paso ', v_siguiente_paso, ' aprobado. ',
            'Esperando paso siguiente. ',
            'Progreso: ', v_pasos_aprobados, '/', v_pasos_totales
        );
    END IF;
    
    -- RESPUESTA
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_siguiente_paso AS paso_actual;

END$$

DELIMITER ;

SELECT '✅ SP sp_AprobarPresupuesto_Progresivo corregido - SIN usar campo es_final' AS estado;

-- ============================================================================
-- PRUEBA CON PRES-013
-- ============================================================================

/*
-- Obtener el id_presupuesto de PRES-013
SET @id_pres013 = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013');

-- Aprobar con tu usuario (documento 8)
CALL sp_AprobarPresupuesto_Progresivo(@id_pres013, 8, 1);

-- Verificar estado
SELECT numero_presupuesto, estado 
FROM TblPresupuesto 
WHERE numero_presupuesto = 'PRES-013';
*/
