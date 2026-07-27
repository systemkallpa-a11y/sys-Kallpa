-- ==================================================================
-- STORED PROCEDURE: sp_ObtenerDocumentosPendientesPorCargo (CORREGIDO)
-- ==================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerDocumentosPendientesPorCargo;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerDocumentosPendientesPorCargo(
    IN p_id_cargo INT,
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
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

-- Verificación
SELECT '✅ SP sp_ObtenerDocumentosPendientesPorCargo actualizado' AS estado;
