-- ============================================================================
-- FIX: Corregir SP de Notificaciones
-- ============================================================================
-- El SP anterior tenía filtros por 'activo' que no existen en las tablas
-- Este script recrea el SP sin esos filtros
-- ============================================================================

USE kallpa_db;

-- Eliminar el SP que causa error
DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesPendientes;

-- Crear versión corregida
DELIMITER //

CREATE PROCEDURE sp_ObtenerNotificacionesPendientes(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        COALESCE(tda.icono, 'fa-file') AS icono,
        COALESCE(tda.color, 'blue') AS color,
        COALESCE(tda.descripcion, '') AS descripcion_documento,
        COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
        fa.numero_paso,
        COALESCE(fa.nombre_paso, '') AS descripcion_paso,
        COALESCE(fa.descripcion, '') AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        TblFlujoAprobacion fa ON tda.id_tipo_documento = fa.id_tipo_documento
    INNER JOIN 
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fa.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        fa.id_cargo = p_id_cargo
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        fa.numero_paso,
        fa.nombre_paso
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerNotificacionesPendientes corregido' AS resultado;

-- Probar el SP
-- CALL sp_ObtenerNotificacionesPendientes(48);
