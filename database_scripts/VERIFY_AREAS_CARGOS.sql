-- ============================================================================
-- VERIFICACIÓN: Tablas TblArea y TblCargo
-- ============================================================================

-- 1. Verificar estructura de TblArea
SELECT 'TblArea - Estructura:' AS verificacion;
DESC TblArea;

-- 2. Verificar estructura de TblCargo
SELECT 'TblCargo - Estructura:' AS verificacion;
DESC TblCargo;

-- 3. Contar áreas activas
SELECT 
    'Áreas activas' AS info,
    COUNT(*) AS total
FROM TblArea
WHERE activo = 1;

-- 4. Listar áreas con sus cargos
SELECT 
    a.id_area,
    a.nombre AS area_nombre,
    COUNT(c.id_cargo) AS total_cargos
FROM TblArea a
LEFT JOIN TblCargo c ON a.id_area = c.id_area AND c.activo = 1
WHERE a.activo = 1
GROUP BY a.id_area, a.nombre
ORDER BY a.nombre;

-- 5. Listar todos los cargos por área
SELECT 
    a.nombre AS area,
    c.id_cargo,
    c.nombre AS cargo
FROM TblArea a
JOIN TblCargo c ON a.id_area = c.id_area
WHERE a.activo = 1 AND c.activo = 1
ORDER BY a.nombre, c.nombre;

-- 6. Verificar que el SP existe
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'sp_ObtenerCargosPorArea'
AND ROUTINE_SCHEMA = DATABASE();

-- 7. Probar el SP (si existe)
-- CALL sp_ObtenerCargosPorArea(1);
