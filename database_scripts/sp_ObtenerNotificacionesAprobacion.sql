-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerNotificacionesAprobacion
-- ============================================================================
-- Descripción: Obtiene todos los documentos pendientes de aprobación para 
--              un usuario según su cargo y el flujo de aprobación configurado
--
-- Parámetros:
--   p_id_cargo: ID del cargo del usuario
--
-- Retorna: Lista de documentos pendientes con información del tipo de documento
--          y cantidad de documentos pendientes
--
-- Lógica:
--   1. Obtener todos los tipos de documento que requieren aprobación
--   2. Para cada tipo, obtener el siguiente paso en el flujo que requiere 
--      aprobación del cargo del usuario
--   3. Contar documentos pendientes en ese paso
--   4. Retornar resumen de notificaciones
--
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesAprobacion //

CREATE PROCEDURE sp_ObtenerNotificacionesAprobacion(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    -- Variable para el resultado
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR' AS resultado;
    END;

    -- Obtener notificaciones: documentos pendientes por tipo de documento
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

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP (COMENTADA)
-- ============================================================================

-- Obtener notificaciones para un cargo específico (reemplaza 48 con id_cargo real)
-- CALL sp_ObtenerNotificacionesAprobacion(48);

-- ============================================================================
