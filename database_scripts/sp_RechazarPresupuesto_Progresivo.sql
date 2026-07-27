-- ============================================================================
-- STORED PROCEDURE: sp_RechazarPresupuesto_Progresivo
-- PROPÓSITO: Manejar rechazo en flujo de aprobación progresivo
-- LÓGICA: Rechaza un paso y vuelve presupuesto a PENDIENTE desde el inicio
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
    DECLARE v_paso_actual INT;
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
    
    -- Verificar que está en estado PENDIENTE o APROBADO (puede ser rechazado en cualquier momento)
    IF v_estado_actual = 'RECHAZADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto ya fue rechazado. No puede rechazarse nuevamente.';
    END IF;
    
    IF v_estado_actual = 'ELIMINADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto eliminado. No puede rechazarse.';
    END IF;
    
    -- ========================================================================
    -- PASO 2: OBTENER PASO ACTUAL (EL QUE ESTÁ PENDIENTE O ÚLTIMO APROBADO)
    -- ========================================================================
    
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
    
    -- ========================================================================
    -- PASO 3: REGISTRAR EL RECHAZO EN TblRegistroAprobacion
    -- ========================================================================
    
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
    
    -- ========================================================================
    -- PASO 4: CAMBIAR ESTADO DE PRESUPUESTO A RECHAZADO
    -- ========================================================================
    
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO 5: ELIMINAR REGISTROS DE PASOS POSTERIORES (CLEANUP)
    -- ========================================================================
    -- Eliminar registros de pasos que vinieron después del rechazo
    -- para que en el re-envío se reinicie todo
    
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso > v_paso_actual
    AND estado_aprobacion = 'PENDIENTE';
    
    -- ========================================================================
    -- RESPUESTA AL USUARIO
    -- ========================================================================
    
    SET v_mensaje = CONCAT(
        '❌ Presupuesto RECHAZADO en Paso ', v_paso_actual, '. ',
        'Motivo: ', COALESCE(p_motivo_rechazo, 'Sin especificar'), '. ',
        'El presupuesto vuelve a estado PENDIENTE para re-envío.'
    );
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_paso_actual AS paso_rechazado;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN Y PRUEBA
-- ============================================================================

SELECT '✅ Stored Procedure sp_RechazarPresupuesto_Progresivo creado exitosamente' as estado;

-- ============================================================================
-- NOTAS DE USO:
-- ============================================================================
/*

EJEMPLO 1: Rechazar en Paso 1

    CALL sp_RechazarPresupuesto_Progresivo(5, 4, 'No cumple especificaciones técnicas', 1);
    
    Resultado:
    ├─ resultado: OK
    ├─ mensaje: ❌ Presupuesto RECHAZADO en Paso 1. Motivo: No cumple especificaciones técnicas. El presupuesto vuelve a estado PENDIENTE para re-envío.
    └─ paso_rechazado: 1
    
    Efecto: 
    ├─ TblPresupuesto.estado = 'RECHAZADO'
    ├─ TblRegistroAprobacion Paso 1: RECHAZADO
    └─ Pasos posteriores se limpian

EJEMPLO 2: Rechazar en Paso 2 (cuando ya Paso 1 fue aprobado)

    CALL sp_RechazarPresupuesto_Progresivo(5, 7, 'Presupuesto fuera de línea', 1);
    
    Resultado:
    ├─ resultado: OK
    ├─ mensaje: ❌ Presupuesto RECHAZADO en Paso 2. Motivo: Presupuesto fuera de línea. El presupuesto vuelve a estado PENDIENTE para re-envío.
    └─ paso_rechazado: 2
    
    Efecto:
    ├─ TblPresupuesto.estado = 'RECHAZADO'
    ├─ TblRegistroAprobacion Paso 1: APROBADO (se mantiene)
    ├─ TblRegistroAprobacion Paso 2: RECHAZADO (nuevo)
    ├─ TblRegistroAprobacion Paso 3: Se elimina si existe
    └─ Presupuesto queda para re-envío

PARÁMETROS:
    p_id_presupuesto:           ID del presupuesto a rechazar (INT)
    p_num_documento_rechazador: Documento de quién rechaza (INT)
    p_motivo_rechazo:          Motivo/comentario del rechazo (VARCHAR 500)
    p_id_tipo_documento:       Tipo de documento (INT, ej: 1=Presupuesto)

COMPORTAMIENTO:
    1. Valida que presupuesto existe y puede rechazarse
    2. Identifica en qué paso se está rechazando
    3. Registra rechazo en TblRegistroAprobacion con comentario
    4. Cambia estado presupuesto a RECHAZADO
    5. Limpia registros de pasos posteriores
    6. Presupuesto listo para re-envío desde el inicio

FLUJO POST-RECHAZO:
    Presupuesto RECHAZADO
    ├─ Usuario puede editar presupuesto
    ├─ Usuario hace click "RE-ENVIAR"
    ├─ Estado cambia a PENDIENTE
    └─ Vuelve a comenzar desde Paso 1

ERRORS:
    ❌ Presupuesto no encontrado
    ❌ Presupuesto ya rechazado
    ❌ Presupuesto eliminado

AUDITORÍA:
    Todos los rechazos quedan registrados en TblRegistroAprobacion:
    ├─ num_documento_rechazador: Quién rechazó
    ├─ comentario: Por qué rechazó
    ├─ fecha_aprobacion: Cuándo rechazó
    └─ Conserva historial completo

*/

-- ============================================================================
-- FIL DE SCRIPT
-- ============================================================================

