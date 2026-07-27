-- ============================================================================
-- STORED PROCEDURE: sp_ReiniciarFlujoAprobacion
-- ============================================================================
-- Descripción: Reinicia el flujo de aprobación de un documento
--              - Cambia estado a PENDIENTE
--              - Limpia registros anteriores
--              - Crea registros PENDIENTE para TODOS los pasos del flujo
--              - SIN num_documento_aprobador (NULL) para que sea registrado en APROBADO
--
-- Parámetros:
--   p_id_tipo_documento: Tipo de documento (1=Presupuesto, 2=Requerimiento, etc)
--   p_id_documento: ID del documento a reiniciar
--
-- Retorna:
--   - 'OK' si éxito
--   - 'ERROR' si hay problema
--
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ReiniciarFlujoAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_ReiniciarFlujoAprobacion(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_documento_existe INT DEFAULT 0;
    DECLARE v_pasos_creados INT DEFAULT 0;
    DECLARE v_paso INT;
    DECLARE v_id_cargo INT;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE cursor_pasos CURSOR FOR
        SELECT numero_paso, id_cargo
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND activo = 1
        AND es_requerido = 1
        ORDER BY numero_paso ASC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- PASO 1: Validar que el documento existe
    IF p_id_tipo_documento = 1 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblPresupuesto WHERE id_presupuesto = p_id_documento;
    ELSEIF p_id_tipo_documento = 2 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblRequerimiento WHERE id_requerimiento = p_id_documento;
    END IF;
    
    IF v_documento_existe = 0 THEN
        SELECT 'ERROR' AS resultado, 'Documento no encontrado' AS mensaje;
    ELSE
        -- PASO 2: Cambiar estado a PENDIENTE
        IF p_id_tipo_documento = 1 THEN
            UPDATE TblPresupuesto
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_presupuesto = p_id_documento;
        ELSEIF p_id_tipo_documento = 2 THEN
            UPDATE TblRequerimiento
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_requerimiento = p_id_documento;
        END IF;
        
        -- PASO 3: Limpiar registros anteriores de aprobación
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND id_documento_referencia = p_id_documento;
        
        -- PASO 4: Crear registros PENDIENTE para TODOS los pasos del flujo
        -- SIN num_documento_aprobador (NULL) para que pueda ser registrado después
        OPEN cursor_pasos;
        
        loop_pasos: LOOP
            FETCH cursor_pasos INTO v_paso, v_id_cargo;
            IF done THEN
                LEAVE loop_pasos;
            END IF;
            
            INSERT INTO TblRegistroAprobacion (
                id_tipo_documento,
                id_documento_referencia,
                numero_paso,
                id_cargo_aprobador,
                num_documento_aprobador,
                estado_aprobacion,
                fecha_asignacion
            ) VALUES (
                p_id_tipo_documento,
                p_id_documento,
                v_paso,
                v_id_cargo,
                NULL,
                'PENDIENTE',
                NOW()
            );
            
            SET v_pasos_creados = v_pasos_creados + 1;
        END LOOP loop_pasos;
        
        CLOSE cursor_pasos;
        
        SELECT 'OK' AS resultado, 
               CONCAT('Flujo reiniciado: ', v_pasos_creados, ' pasos creados') AS mensaje,
               v_pasos_creados AS pasos_creados;
    END IF;

END$$

DELIMITER ;

-- ============================================================================
-- PRUEBAS DEL SP
-- ============================================================================

-- Reiniciar presupuesto (id=14)
-- CALL sp_ReiniciarFlujoAprobacion(1, 14);

-- Reiniciar requerimiento (id=5)
-- CALL sp_ReiniciarFlujoAprobacion(2, 5);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ReiniciarFlujoAprobacion creado exitosamente' as estado;
