-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerNotificacionesAprobacion (VERSIÓN FIXED - SIN DELIMITER)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesAprobacion;

CREATE PROCEDURE sp_ObtenerNotificacionesAprobacion(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR' AS resultado;
    END;

    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS tipo_documento,
        tda.icono,
        tda.color,
        COUNT(DISTINCT CONCAT(ra.id_tipo_documento, '_', ra.id_documento_referencia)) AS cantidad_pendientes,
        fa.numero_paso AS proximo_paso,
        fa.nombre_paso,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo
    FROM TblTipoDocumentoAprobacion tda
    LEFT JOIN TblFlujoAprobacionCargos fa ON tda.id_tipo_documento = fa.id_tipo_documento 
        AND fa.id_cargo = p_id_cargo 
        AND fa.activo = 1
    LEFT JOIN TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
        AND ra.estado_aprobacion = 'PENDIENTE'
        AND ra.numero_paso = fa.numero_paso
    WHERE tda.activo = 1
    AND tda.requiere_aprobacion = 1
    AND fa.id_flujo_cargo IS NOT NULL
    GROUP BY tda.id_tipo_documento, tda.nombre, tda.icono, tda.color, 
             fa.numero_paso, fa.nombre_paso
    HAVING cantidad_pendientes > 0
    ORDER BY cantidad_pendientes DESC, tda.nombre ASC;

END;
