-- ============================================================================
-- SCRIPT: CREATE_SP_FLUJO_APROBACION.sql
-- PROPÓSITO: Crear SPs para el sistema de flujo de aprobación
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- SP 1: sp_ObtenerFlujoAprobacion
-- PROPÓSITO: Obtener todos los pasos de aprobación para un tipo de documento
-- PARÁMETROS:
--   @p_id_tipo_documento INT - ID del tipo de documento
-- RETORNA: Lista de pasos con cargos asignados
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerFlujoAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerFlujoAprobacion(
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
    SELECT 
        fa.id_flujo_aprobacion,
        fa.id_tipo_documento,
        fa.numero_paso,
        fa.id_cargo,
        c.nombre AS nombre_cargo,
        fa.nombre_paso,
        fa.descripcion,
        fa.es_final,
        fa.es_requerido,
        fa.permite_rechazo,
        fa.activo
    FROM TblFlujoAprobacion fa
    JOIN TblCargo c ON fa.id_cargo = c.id_cargo
    WHERE fa.id_tipo_documento = p_id_tipo_documento
      AND fa.activo = 1
    ORDER BY fa.numero_paso ASC;
END$$

DELIMITER ;

-- ============================================================================
-- SP 2: sp_RegistrarAprobacion
-- PROPÓSITO: Registrar una aprobación o rechazo de un documento
-- PARÁMETROS:
--   @p_id_tipo_documento INT - ID del tipo de documento
--   @p_id_documento_referencia INT - ID del documento (presupuesto, etc)
--   @p_numero_paso INT - Número del paso completado
--   @p_id_cargo_aprobador INT - ID del cargo del aprobador
--   @p_num_documento_aprobador INT - Número de documento de la persona
--   @p_estado_aprobacion ENUM - APROBADO o RECHAZADO
--   @p_comentario TEXT - Comentarios del aprobador
-- RETORNA: ID del registro creado
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_RegistrarAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_RegistrarAprobacion(
    IN p_id_tipo_documento INT,
    IN p_id_documento_referencia INT,
    IN p_numero_paso INT,
    IN p_id_cargo_aprobador INT,
    IN p_num_documento_aprobador INT,
    IN p_estado_aprobacion VARCHAR(20),
    IN p_comentario TEXT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_registro INT;
    
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
        p_id_documento_referencia,
        p_numero_paso,
        p_id_cargo_aprobador,
        p_num_documento_aprobador,
        p_estado_aprobacion,
        p_comentario,
        CURRENT_TIMESTAMP
    );
    
    SET v_id_registro = LAST_INSERT_ID();
    
    SELECT v_id_registro AS id_registro;
END$$

DELIMITER ;

-- ============================================================================
-- SP 3: sp_ObtenerHistorialAprobacion
-- PROPÓSITO: Obtener el historial de aprobaciones de un documento
-- PARÁMETROS:
--   @p_id_tipo_documento INT - ID del tipo de documento
--   @p_id_documento_referencia INT - ID del documento
-- RETORNA: Lista de aprobaciones realizadas
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerHistorialAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerHistorialAprobacion(
    IN p_id_tipo_documento INT,
    IN p_id_documento_referencia INT
)
READS SQL DATA
BEGIN
    SELECT 
        ra.id_registro,
        ra.id_tipo_documento,
        ra.id_documento_referencia,
        ra.numero_paso,
        c.nombre AS cargo_aprobador,
        p.nombre AS nombre_aprobador,
        p.apellidos AS apellidos_aprobador,
        ra.estado_aprobacion,
        ra.comentario,
        ra.fecha_asignacion,
        ra.fecha_aprobacion,
        CASE 
            WHEN ra.estado_aprobacion = 'APROBADO' THEN 'Aprobado'
            WHEN ra.estado_aprobacion = 'RECHAZADO' THEN 'Rechazado'
            ELSE 'Pendiente'
        END AS estado_texto
    FROM TblRegistroAprobacion ra
    LEFT JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
    LEFT JOIN TblPersona p ON ra.num_documento_aprobador = p.num_documento
    WHERE ra.id_tipo_documento = p_id_tipo_documento
      AND ra.id_documento_referencia = p_id_documento_referencia
    ORDER BY ra.numero_paso ASC, ra.fecha_aprobacion ASC;
END$$

DELIMITER ;

-- ============================================================================
-- SP 4: sp_VerificarDocumentoAprobado
-- PROPÓSITO: Verificar si un documento ha completado todas las aprobaciones
-- PARÁMETROS:
--   @p_id_tipo_documento INT - ID del tipo de documento
--   @p_id_documento_referencia INT - ID del documento
-- RETORNA: 
--   1 si está completamente aprobado
--   0 si aún tiene pasos pendientes
--   -1 si fue rechazado
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_VerificarDocumentoAprobado;

DELIMITER $$

CREATE PROCEDURE sp_VerificarDocumentoAprobado(
    IN p_id_tipo_documento INT,
    IN p_id_documento_referencia INT
)
READS SQL DATA
BEGIN
    DECLARE v_total_pasos INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_rechazado INT;
    
    -- Contar total de pasos requeridos
    SELECT COUNT(*) INTO v_total_pasos
    FROM TblFlujoAprobacion
    WHERE id_tipo_documento = p_id_tipo_documento
      AND es_requerido = 1
      AND activo = 1;
    
    -- Verificar si fue rechazado
    SELECT COUNT(*) INTO v_rechazado
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = p_id_tipo_documento
      AND id_documento_referencia = p_id_documento_referencia
      AND estado_aprobacion = 'RECHAZADO';
    
    IF v_rechazado > 0 THEN
        SELECT -1 AS estado; -- Rechazado
    ELSE
        -- Contar pasos aprobados
        SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_aprobados
        FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
          AND id_documento_referencia = p_id_documento_referencia
          AND estado_aprobacion = 'APROBADO';
        
        IF v_pasos_aprobados >= v_total_pasos THEN
            SELECT 1 AS estado; -- Aprobado
        ELSE
            SELECT 0 AS estado; -- Pendiente
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- SP 5: sp_ObtenerProximoPasoAprobacion
-- PROPÓSITO: Obtener el siguiente paso de aprobación pendiente de un documento
-- PARÁMETROS:
--   @p_id_tipo_documento INT - ID del tipo de documento
--   @p_id_documento_referencia INT - ID del documento
-- RETORNA: Información del próximo paso
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerProximoPasoAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerProximoPasoAprobacion(
    IN p_id_tipo_documento INT,
    IN p_id_documento_referencia INT
)
READS SQL DATA
BEGIN
    SELECT 
        fa.id_flujo_aprobacion,
        fa.numero_paso,
        fa.id_cargo,
        c.nombre AS nombre_cargo,
        fa.nombre_paso,
        fa.descripcion,
        fa.es_final,
        fa.es_requerido,
        fa.permite_rechazo
    FROM TblFlujoAprobacion fa
    JOIN TblCargo c ON fa.id_cargo = c.id_cargo
    WHERE fa.id_tipo_documento = p_id_tipo_documento
      AND fa.activo = 1
      AND fa.numero_paso > (
          SELECT COALESCE(MAX(numero_paso), 0)
          FROM TblRegistroAprobacion
          WHERE id_tipo_documento = p_id_tipo_documento
            AND id_documento_referencia = p_id_documento_referencia
            AND estado_aprobacion = 'APROBADO'
      )
    ORDER BY fa.numero_paso ASC
    LIMIT 1;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SPs creados exitosamente' AS Mensaje;

SHOW PROCEDURE STATUS WHERE DB = 'kallgwkn_kallpa_bd' AND Name LIKE 'sp_%Aprobacion%';

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
