-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerDocumentosPendientesPorCargo
-- ============================================================================
-- Descripción: Obtiene lista de CUALQUIER tipo de documento PENDIENTE que un 
--              cargo específico necesita aprobar, basándose en TblRegistroAprobacion
--
-- IMPORTANTE: Solo retorna documentos que:
--   1. Están PENDIENTE en el paso actual del cargo
--   2. Han sido APROBADOS en todos los pasos anteriores (si los hay)
--
-- Parámetros:
--   p_id_cargo: ID del cargo del usuario
--   p_id_tipo_documento: ID del tipo de documento (ej: 1=Presupuesto, 2=Requerimiento)
--                        Si es NULL, retorna todos los tipos
--
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerDocumentosPendientesPorCargo;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerDocumentosPendientesPorCargo(
    IN p_id_cargo INT,
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
    -- Obtener documentos PENDIENTE para el cargo especificado
    -- Solo incluir documentos donde TODOS los pasos anteriores estén APROBADOS
    
    SELECT
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        ra.id_documento_referencia AS id_documento,
        ra.numero_paso,
        ra.fecha_asignacion,
        ra.estado_aprobacion,
        tda.icono,
        tda.color
    FROM 
        TblRegistroAprobacion ra
    INNER JOIN 
        TblTipoDocumentoAprobacion tda 
        ON ra.id_tipo_documento = tda.id_tipo_documento
    WHERE 
        ra.estado_aprobacion = 'PENDIENTE'
        AND ra.id_cargo_aprobador = p_id_cargo
        AND (p_id_tipo_documento IS NULL OR ra.id_tipo_documento = p_id_tipo_documento)
        AND tda.activo = 1
        AND tda.requiere_aprobacion = 1
        -- CRÍTICO: Verificar que TODOS los pasos anteriores estén APROBADOS
        -- Si hay algún paso anterior que NO esté APROBADO, excluir este documento
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    ORDER BY 
        ra.fecha_asignacion DESC,
        ra.id_tipo_documento ASC;

END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerDocumentosPendientesPorCargo actualizado - CON VALIDACIÓN DE PASOS ANTERIORES' as estado;
||