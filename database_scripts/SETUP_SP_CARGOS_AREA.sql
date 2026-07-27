-- ============================================================================
-- SETUP: Crear SP para obtener cargos por área
-- ============================================================================
-- Este script crea el Stored Procedure sp_ObtenerCargosPorArea
-- que se utiliza en el módulo de Flujo de Aprobación

USE kallpa_db;

-- 1. Crear el Stored Procedure
DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerCargosPorArea //

CREATE PROCEDURE sp_ObtenerCargosPorArea(
    IN p_id_area INT
)
READS SQL DATA
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

-- 2. Verificar que el SP fue creado correctamente
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'sp_ObtenerCargosPorArea'
AND ROUTINE_SCHEMA = DATABASE()
LIMIT 1;

-- 3. Mensaje de éxito
SELECT 'SP sp_ObtenerCargosPorArea creado correctamente' AS resultado;
