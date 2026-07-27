-- ============================================================================
-- VERIFICACIÓN COMPLETA: Flujo de Aprobación
-- ============================================================================
-- Este script verifica que todo esté correctamente configurado para el
-- módulo de Flujo de Aprobación con filtro de cargos por área
--
-- Ejecución: mysql -u usuario -p nombre_bd < VERIFICACION_COMPLETA_FLUJO_APROBACION.sql
-- ============================================================================

USE kallpa_db;

-- ============================================================================
-- SECCIÓN 1: VERIFICAR TABLAS
-- ============================================================================

SELECT '========== SECCIÓN 1: VERIFICAR TABLAS ==========' AS verificacion;

-- 1.1 Verificar que TblArea existe
SELECT '1.1 Estructura de TblArea:' AS paso;
DESCRIBE TblArea;

-- 1.2 Verificar que TblCargo existe
SELECT '1.2 Estructura de TblCargo:' AS paso;
DESCRIBE TblCargo;

-- ============================================================================
-- SECCIÓN 2: VERIFICAR SPs
-- ============================================================================

SELECT '========== SECCIÓN 2: VERIFICAR SPs ==========' AS verificacion;

-- 2.1 Verificar que los SPs existen
SELECT '2.1 Verificando existencia de SPs:' AS paso;
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    ROUTINE_SCHEMA,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME IN ('sp_ObtenerAreas', 'sp_ObtenerCargosPorArea')
AND ROUTINE_SCHEMA = DATABASE()
ORDER BY ROUTINE_NAME;

-- ============================================================================
-- SECCIÓN 3: VERIFICAR DATOS
-- ============================================================================

SELECT '========== SECCIÓN 3: VERIFICAR DATOS ==========' AS verificacion;

-- 3.1 Contar áreas activas
SELECT '3.1 Áreas activas:' AS paso;
SELECT 
    COUNT(*) AS total_areas
FROM TblArea
WHERE activo = 1;

-- 3.2 Listar áreas
SELECT '3.2 Detalle de áreas:' AS paso;
SELECT 
    id_area,
    nombre,
    descripcion,
    activo,
    fecha_creacion
FROM TblArea
WHERE activo = 1
ORDER BY nombre;

-- 3.3 Contar cargos por área
SELECT '3.3 Cargos por área:' AS paso;
SELECT 
    a.id_area,
    a.nombre AS area_nombre,
    COUNT(c.id_cargo) AS total_cargos
FROM TblArea a
LEFT JOIN TblCargo c ON a.id_area = c.id_area AND c.activo = 1
WHERE a.activo = 1
GROUP BY a.id_area, a.nombre
ORDER BY a.nombre;

-- 3.4 Listar todos los cargos con su área
SELECT '3.4 Detalle de cargos por área:' AS paso;
SELECT 
    a.nombre AS area,
    c.id_cargo,
    c.nombre AS cargo,
    c.descripcion,
    c.activo
FROM TblArea a
LEFT JOIN TblCargo c ON a.id_area = c.id_area
WHERE a.activo = 1
ORDER BY a.nombre, c.nombre;

-- ============================================================================
-- SECCIÓN 4: PROBAR SPs
-- ============================================================================

SELECT '========== SECCIÓN 4: PROBAR SPs ==========' AS verificacion;

-- 4.1 Probar sp_ObtenerAreas
SELECT '4.1 Resultado de sp_ObtenerAreas:' AS paso;
CALL sp_ObtenerAreas();

-- 4.2 Probar sp_ObtenerCargosPorArea con primer área disponible
SELECT '4.2 Resultado de sp_ObtenerCargosPorArea (primera área):' AS paso;
-- Obtener el primer id_area
SET @first_area = (SELECT id_area FROM TblArea WHERE activo = 1 LIMIT 1);

-- Si existe al menos una área
IF @first_area IS NOT NULL THEN
    -- Mostrar qué área se está probando
    SELECT CONCAT('Probando con área ID: ', @first_area) AS info;
    
    -- Llamar al SP
    CALL sp_ObtenerCargosPorArea(@first_area);
ELSE
    SELECT 'NO HAY ÁREAS ACTIVAS' AS error;
END IF;

-- ============================================================================
-- SECCIÓN 5: RESUMEN DE VERIFICACIÓN
-- ============================================================================

SELECT '========== SECCIÓN 5: RESUMEN ==========' AS verificacion;

SELECT 
    'Tablas existentes' AS verificacion,
    'TblArea' AS tabla,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_NAME = 'TblArea' 
     AND TABLE_SCHEMA = DATABASE()) AS existe
UNION ALL
SELECT 
    'Tablas existentes',
    'TblCargo',
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
     WHERE TABLE_NAME = 'TblCargo' 
     AND TABLE_SCHEMA = DATABASE())
UNION ALL
SELECT 
    'SPs existentes',
    'sp_ObtenerAreas',
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
     WHERE ROUTINE_NAME = 'sp_ObtenerAreas' 
     AND ROUTINE_SCHEMA = DATABASE())
UNION ALL
SELECT 
    'SPs existentes',
    'sp_ObtenerCargosPorArea',
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
     WHERE ROUTINE_NAME = 'sp_ObtenerCargosPorArea' 
     AND ROUTINE_SCHEMA = DATABASE());

-- ============================================================================
-- SECCIÓN 6: CHECKLIST FINAL
-- ============================================================================

SELECT '========== SECCIÓN 6: CHECKLIST FINAL ==========' AS verificacion;

SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
              WHERE TABLE_NAME = 'TblArea' AND TABLE_SCHEMA = DATABASE()) = 1
        THEN '✅ TblArea existe'
        ELSE '❌ TblArea NO existe'
    END AS estado_1,
    CASE 
        WHEN (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
              WHERE TABLE_NAME = 'TblCargo' AND TABLE_SCHEMA = DATABASE()) = 1
        THEN '✅ TblCargo existe'
        ELSE '❌ TblCargo NO existe'
    END AS estado_2,
    CASE 
        WHEN (SELECT COUNT(*) FROM TblArea WHERE activo = 1) > 0
        THEN CONCAT('✅ Hay ', (SELECT COUNT(*) FROM TblArea WHERE activo = 1), ' áreas activas')
        ELSE '❌ No hay áreas activas'
    END AS estado_3,
    CASE 
        WHEN (SELECT COUNT(*) FROM TblCargo WHERE activo = 1) > 0
        THEN CONCAT('✅ Hay ', (SELECT COUNT(*) FROM TblCargo WHERE activo = 1), ' cargos activos')
        ELSE '❌ No hay cargos activos'
    END AS estado_4,
    CASE 
        WHEN (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
              WHERE ROUTINE_NAME = 'sp_ObtenerAreas' AND ROUTINE_SCHEMA = DATABASE()) = 1
        THEN '✅ sp_ObtenerAreas existe'
        ELSE '❌ sp_ObtenerAreas NO existe'
    END AS estado_5,
    CASE 
        WHEN (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
              WHERE ROUTINE_NAME = 'sp_ObtenerCargosPorArea' AND ROUTINE_SCHEMA = DATABASE()) = 1
        THEN '✅ sp_ObtenerCargosPorArea existe'
        ELSE '❌ sp_ObtenerCargosPorArea NO existe'
    END AS estado_6;

-- ============================================================================
-- FIN DE VERIFICACIÓN
-- ============================================================================

SELECT '✅ VERIFICACIÓN COMPLETADA' AS resultado;
