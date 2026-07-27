-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerCargosPorArea
-- ============================================================================
-- Descripción: Obtiene los cargos de un área específica
-- Parámetros: 
--   - p_id_area: ID del área
-- Retorna: Lista de cargos activos del área
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerCargosPorArea //

CREATE PROCEDURE sp_ObtenerCargosPorArea(
    IN p_id_area INT
)
BEGIN
    SELECT 
        c.id_cargo,
        c.nombre,
        c.descripcion,
        c.id_area,
        a.nombre AS area_nombre,
        c.activo,
        c.fecha_creacion
    FROM TblCargo c
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    WHERE c.id_area = p_id_area
    AND c.activo = 1
    ORDER BY c.nombre ASC;
END //

DELIMITER ;

-- Prueba rápida del SP (comentado)
-- CALL sp_ObtenerCargosPorArea(1);
