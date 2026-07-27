-- ============================================================================
-- SETUP: Crear SPs para Áreas y Cargos
-- ============================================================================
-- Este script crea dos Stored Procedures necesarios para el módulo de 
-- Flujo de Aprobación:
-- 1. sp_ObtenerAreas - Obtiene todas las áreas activas
-- 2. sp_ObtenerCargosPorArea - Obtiene cargos filtrados por área
-- 
-- Ejecución: mysql -u usuario -p nombre_bd < SETUP_SPS_AREAS_CARGOS.sql
-- ============================================================================

USE kallpa_db;

-- ============================================================================
-- SP 1: sp_ObtenerAreas
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerAreas //

CREATE PROCEDURE sp_ObtenerAreas()
READS SQL DATA
BEGIN
    SELECT 
        a.id_area,
        a.nombre,
        a.descripcion,
        a.activo,
        a.fecha_creacion,
        COUNT(c.id_cargo) AS total_cargos
    FROM TblArea a
    LEFT JOIN TblCargo c ON a.id_area = c.id_area AND c.activo = 1
    WHERE a.activo = 1
    GROUP BY a.id_area, a.nombre, a.descripcion, a.activo, a.fecha_creacion
    ORDER BY a.nombre ASC;
END //

DELIMITER ;

-- ============================================================================
-- SP 2: sp_ObtenerCargosPorArea
-- ============================================================================

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

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerAreas creado correctamente' AS resultado UNION
SELECT 'SP sp_ObtenerCargosPorArea creado correctamente' AS resultado;

-- ============================================================================
-- VERIFICAR QUE LOS SPs EXISTEN
-- ============================================================================

SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME IN ('sp_ObtenerAreas', 'sp_ObtenerCargosPorArea')
AND ROUTINE_SCHEMA = DATABASE()
ORDER BY ROUTINE_NAME;

-- ============================================================================
-- PRUEBAS (DESCOMENTA PARA PROBAR)
-- ============================================================================

-- Obtener todas las áreas
-- CALL sp_ObtenerAreas();

-- Obtener cargos de área específica (reemplaza 1 con un id_area válido)
-- CALL sp_ObtenerCargosPorArea(1);
