-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerDetalleDocumentoPorCargo
-- ============================================================================
-- Descripción: Obtiene detalles de UN documento específico para un cargo
--
-- Parámetros:
--   p_id_tipo_documento: Tipo de documento (1=Presupuesto, 2=Requerimiento, etc)
--   p_id_documento: ID del documento (presupuesto, requerimiento, etc)
--   p_id_cargo: ID del cargo (para validar permisos)
--
-- Retorna:
--   Columnas dinámicas según el tipo de documento
--
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerDetalleDocumentoPorCargo;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerDetalleDocumentoPorCargo(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT,
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    -- Validar que el cargo tiene acceso a este documento
    -- mediante TblRegistroAprobacion con estado PENDIENTE
    
    DECLARE v_tiene_acceso INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_tiene_acceso
    FROM TblRegistroAprobacion ra
    INNER JOIN TblFlujoAprobacionCargos fac
        ON fac.id_tipo_documento = ra.id_tipo_documento
        AND fac.numero_paso = ra.numero_paso
        AND fac.id_cargo = p_id_cargo
    WHERE ra.id_tipo_documento = p_id_tipo_documento
        AND ra.id_documento_referencia = p_id_documento
        AND ra.estado_aprobacion = 'PENDIENTE'
        AND fac.activo = 1
        AND fac.es_requerido = 1;
    
    IF v_tiene_acceso = 0 THEN
        SELECT 'ERROR' AS resultado, 'Acceso denegado' AS mensaje;
    ELSE
        -- Retornar información base del documento + paso actual
        SELECT 
            tda.id_tipo_documento,
            tda.nombre AS nombre_documento,
            ra.id_documento_referencia AS id_documento,
            ra.numero_paso,
            ra.fecha_asignacion,
            fac.nombre_paso,
            fac.descripcion AS descripcion_paso
        FROM TblRegistroAprobacion ra
        INNER JOIN TblTipoDocumentoAprobacion tda
            ON tda.id_tipo_documento = ra.id_tipo_documento
        INNER JOIN TblFlujoAprobacionCargos fac
            ON fac.id_tipo_documento = ra.id_tipo_documento
            AND fac.numero_paso = ra.numero_paso
        WHERE ra.id_tipo_documento = p_id_tipo_documento
            AND ra.id_documento_referencia = p_id_documento
            AND ra.estado_aprobacion = 'PENDIENTE'
        LIMIT 1;
    END IF;

END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerDetalleDocumentoPorCargo creado exitosamente' as estado;
