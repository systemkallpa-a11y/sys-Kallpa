-- ============================================================================
-- STORED PROCEDURE: sp_AprobarPresupuesto_Progresivo
-- PROPÓSITO: Manejar aprobación en múltiples pasos
-- LÓGICA: Solo cambia a APROBADO cuando TODOS los pasos estén aprobados
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

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
    
    -- Verificar que está en estado PENDIENTE o RECHAZADO (permite re-aprobación)
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Presupuesto en estado ', v_estado_actual, '. No puede aprobarse.');
    END IF;
    
    -- ========================================================================
    -- PASO 2: OBTENER SIGUIENTE PASO PENDIENTE
    -- ========================================================================
    
    -- Buscar el siguiente paso que aún no tiene aprobación registrada
    SELECT 
        COALESCE(MIN(f.numero_paso), 1) INTO v_siguiente_paso
    FROM TblFlujoAprobacionCargos f
    WHERE f.id_tipo_documento = p_id_tipo_documento
    AND f.numero_paso > COALESCE(
        (SELECT MAX(numero_paso) 
         FROM TblRegistroAprobacion 
         WHERE id_documento_referencia = p_id_presupuesto 
         AND id_tipo_documento = p_id_tipo_documento 
         AND estado_aprobacion = 'APROBADO'), 
        0
    )
    AND f.es_requerido = 1;
    
    -- Si no hay siguiente paso, buscar el primero
    IF v_siguiente_paso IS NULL THEN
        SELECT MIN(numero_paso) INTO v_siguiente_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1;
    END IF;
    
    IF v_siguiente_paso IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay pasos de aprobación configurados para este tipo de documento';
    END IF;
    
    -- ========================================================================
    -- PASO 3: OBTENER INFORMACIÓN DEL PASO ACTUAL
    -- ========================================================================
    
    SELECT 
        es_requerido,
        id_cargo INTO v_es_final, v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso;
    
    -- ========================================================================
    -- PASO 4: REGISTRAR LA APROBACIÓN EN TblRegistroAprobacion
    -- ========================================================================
    
    -- Verificar si ya existe registro para este paso
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso;
    
    IF v_registro_aprobacion_existe = 0 THEN
        -- Crear nuevo registro
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
        -- Actualizar registro existente
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
    
    -- ========================================================================
    -- PASO 5: VERIFICAR SI ES EL ÚLTIMO PASO
    -- ========================================================================
    
    -- Obtener el máximo número de paso para este tipo de documento
    SELECT MAX(numero_paso) INTO v_es_final
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND es_requerido = 1;
    
    IF v_siguiente_paso = v_es_final THEN
        -- Es el último paso, verificar si TODOS los pasos están aprobados
        
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1;
        
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_aprobados
        FROM TblRegistroAprobacion
        WHERE id_documento_referencia = p_id_presupuesto
        AND id_tipo_documento = p_id_tipo_documento
        AND estado_aprobacion = 'APROBADO';
        
        -- Si todos los pasos están aprobados, cambiar estado de presupuesto
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
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1;
        
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_aprobados
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
    
    -- ========================================================================
    -- RESPUESTA AL USUARIO
    -- ========================================================================
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_siguiente_paso AS paso_actual;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN Y PRUEBA
-- ============================================================================

SELECT '✅ Stored Procedure sp_AprobarPresupuesto_Progresivo creado exitosamente' as estado;

-- ============================================================================
-- NOTAS DE USO:
-- ============================================================================
/*

EJEMPLO 1: Aprobar presupuesto en sistema con 3 pasos

    CALL sp_AprobarPresupuesto_Progresivo(5, 4, 1);
    
    Resultado:
    ├─ resultado: OK
    ├─ mensaje: ✅ Paso 1 aprobado. Esperando paso siguiente. Progreso: 1/3
    └─ paso_actual: 1

EJEMPLO 2: Cuando se completa el último paso

    CALL sp_AprobarPresupuesto_Progresivo(5, 1, 1);
    
    Resultado:
    ├─ resultado: OK
    ├─ mensaje: ✅ ¡PRESUPUESTO COMPLETAMENTE APROBADO! Todos los 3 pasos fueron completados.
    └─ paso_actual: 3
    
    Efecto: TblPresupuesto.estado = 'APROBADO'

PARÁMETROS:
    p_id_presupuesto:         ID del presupuesto a aprobar (INT)
    p_num_documento_aprobador: Documento de quién aprueba (INT)
    p_id_tipo_documento:      Tipo de documento (INT, ej: 1=Presupuesto)

COMPORTAMIENTO:
    1. Encuentra el siguiente paso que aún no se ha aprobado
    2. Registra la aprobación en TblRegistroAprobacion
    3. Si es último paso, verifica que TODOS estén aprobados
    4. Si todos aprobados: UPDATE TblPresupuesto estado='APROBADO'
    5. Si faltan pasos: Presupuesto sigue PENDIENTE

ERRORS:
    ❌ Presupuesto no encontrado
    ❌ Presupuesto en estado APROBADO/RECHAZADO
    ❌ No hay pasos configurados

*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================

