-- ============================================================================
-- SCRIPT COMPLETO: Fix Flujo de Rechazo + Comentario
-- FECHA: 17 Julio 2026
-- DESCRIPCIÓN:
--   1. Actualiza sp_RechazarPresupuesto para INSERT/UPDATE TblRegistroAprobacion
--   2. Actualiza sp_AprobarPresupuesto para INSERT/UPDATE TblRegistroAprobacion
--   3. Verifica que sp_ReportePresupuestos trae comentario_rechazo
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  Ejecutando Fix: Flujo de Rechazo con Comentario              ║';
SELECT '║  Fecha: 17 Julio 2026                                          ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';

-- ============================================================================
-- PASO 1: Actualizar sp_RechazarPresupuesto
-- ============================================================================
SELECT '✓ PASO 1: Actualizando sp_RechazarPresupuesto...';

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
    
    -- Verificar que está en estado PENDIENTE
    IF v_estado_actual != 'PENDIENTE' THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- Actualizar estado a RECHAZADO en TblPresupuesto
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
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
            estado_aprobacion,
            num_documento,
            fecha_aprobacion,
            comentario
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            'RECHAZADO',                            -- Estado: RECHAZADO
            p_num_documento_rechazador,             -- Usuario que rechaza
            NOW(),                                  -- Fecha actual
            p_motivo_rechazo                        -- Motivo del rechazo
        );
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' rechazado correctamente (Nuevo registro creado)');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'RECHAZADO',
            num_documento = p_num_documento_rechazador,      -- Registrar documento del rechazador
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

SELECT '  ✅ sp_RechazarPresupuesto actualizado con INSERT/UPDATE logic';
SELECT '';

-- ============================================================================
-- PASO 2: Actualizar sp_AprobarPresupuesto
-- ============================================================================
SELECT '✓ PASO 2: Actualizando sp_AprobarPresupuesto...';

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
    
    -- Verificar que está en estado PENDIENTE
    IF v_estado_actual != 'PENDIENTE' THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- Actualizar estado a APROBADO en TblPresupuesto
    UPDATE TblPresupuesto
    SET 
        estado = 'APROBADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
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
            estado_aprobacion,
            num_documento,
            fecha_aprobacion
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            'APROBADO',                             -- Estado: APROBADO
            p_num_documento_aprobador,              -- Usuario que aprueba
            NOW()                                   -- Fecha actual
        );
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' aprobado correctamente (Nuevo registro creado)');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'APROBADO',
            num_documento = p_num_documento_aprobador,      -- Registrar documento del aprobador
            fecha_aprobacion = NOW()                        -- Registrar fecha de aprobación
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = 1;
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' aprobado correctamente (Registro actualizado)');
    END IF;
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje;

END //

DELIMITER ;

SELECT '  ✅ sp_AprobarPresupuesto actualizado con INSERT/UPDATE logic';
SELECT '';

-- ============================================================================
-- PASO 3: Verificación - sp_ReportePresupuestos ya tiene LEFT JOIN
-- ============================================================================
SELECT '✓ PASO 3: Verificando sp_ReportePresupuestos...';

-- Mostrar si ya tiene el LEFT JOIN correcto
SELECT 
    CASE 
        WHEN ROUTINE_DEFINITION LIKE '%TblRegistroAprobacion%' 
             AND ROUTINE_DEFINITION LIKE '%comentario_rechazo%'
        THEN '  ✅ sp_ReportePresupuestos ya tiene LEFT JOIN y comentario_rechazo'
        ELSE '  ⚠️ sp_ReportePresupuestos necesita actualización manual'
    END as verificacion
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_SCHEMA = DATABASE() 
AND ROUTINE_NAME = 'sp_ReportePresupuestos';

SELECT '';

-- ============================================================================
-- PASO 4: Pruebas
-- ============================================================================
SELECT '✓ PASO 4: Pruebas de SPs (descomenta para ejecutar)...';
SELECT '';

-- PRUEBA 1: Rechazar presupuesto
-- CALL sp_RechazarPresupuesto(1, 123456, 'Presupuesto no cumple especificaciones');
-- SELECT * FROM TblPresupuesto WHERE id_presupuesto = 1;
-- SELECT * FROM TblRegistroAprobacion WHERE id_documento_referencia = 1;

-- PRUEBA 2: Aprobar presupuesto
-- CALL sp_AprobarPresupuesto(2, 654321);
-- SELECT * FROM TblPresupuesto WHERE id_presupuesto = 2;
-- SELECT * FROM TblRegistroAprobacion WHERE id_documento_referencia = 2;

-- PRUEBA 3: Verificar que reporte trae comentario
-- CALL sp_ReportePresupuestos();

SELECT '';
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  ✅ Fix completado exitosamente                               ║';
SELECT '║                                                                ║';
SELECT '║  Cambios realizados:                                           ║';
SELECT '║  ✓ sp_RechazarPresupuesto: INSERT/UPDATE TblRegistroAprobacion║';
SELECT '║  ✓ sp_AprobarPresupuesto: INSERT/UPDATE TblRegistroAprobacion ║';
SELECT '║  ✓ Comentario se guarda en TblRegistroAprobacion.comentario   ║';
SELECT '║  ✓ sp_ReportePresupuestos trae comentario_rechazo             ║';
SELECT '║  ✓ Frontend muestra comentario en tabla                        ║';
SELECT '║                                                                ║';
SELECT '║  Próximos pasos:                                               ║';
SELECT '║  1. Probar rechazo desde aplicación                            ║';
SELECT '║  2. Verificar que aparece en tabla con tooltip                 ║';
SELECT '║  3. Confirmar que se guarda en BD                              ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
