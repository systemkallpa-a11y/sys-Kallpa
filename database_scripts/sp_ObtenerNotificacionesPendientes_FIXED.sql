-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerNotificacionesPendientes (VERSIÓN FIXED - SIN DELIMITER)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesPendientes;

CREATE PROCEDURE sp_ObtenerNotificacionesPendientes(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        tda.icono,
        tda.color,
        tda.descripcion AS descripcion_documento,
        COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
        fc.numero_paso,
        fc.nombre_paso AS descripcion_paso,
        fc.descripcion AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        TblFlujoAprobacionCargos fc ON tda.id_tipo_documento = fc.id_tipo_documento
    INNER JOIN 
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fc.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        tda.activo = 1
        AND tda.requiere_aprobacion = 1
        AND fc.activo = 1
        AND fc.id_cargo = p_id_cargo
        AND fc.es_requerido = 1
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        fc.numero_paso,
        fc.nombre_paso
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END;
