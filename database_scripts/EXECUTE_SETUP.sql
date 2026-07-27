-- ============================================================================
-- SCRIPT: Ejecutar Setup Completo del Sistema de Requerimientos
-- DESCRIPCIÓN: Preparar BD para trabajar con requerimientos
-- FECHA: 2026-07-16
-- ============================================================================

-- SECCIÓN 1: Verificar que las tablas existen
-- ============================================================================
SELECT '========== SECCIÓN 1: VERIFICACIÓN INICIAL ==========' as seccion;

-- Verificar TblRequerimiento existe
SELECT COUNT(*) as tbl_requerimiento_existe FROM information_schema.tables 
WHERE table_schema = DATABASE() AND table_name = 'TblRequerimiento';

-- Verificar TblRequerimientoDetalle existe
SELECT COUNT(*) as tbl_requerimiento_detalle_existe FROM information_schema.tables 
WHERE table_schema = DATABASE() AND table_name = 'TblRequerimientoDetalle';

-- Verificar estructura actual de TblRequerimientoDetalle
SELECT 'ESTRUCTURA ACTUAL DE TblRequerimientoDetalle:' as info;
SHOW COLUMNS FROM TblRequerimientoDetalle;

-- Verificar constraints actuales
SELECT 'CONSTRAINTS ACTUALES:' as info;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle'
ORDER BY CONSTRAINT_NAME;

-- SECCIÓN 2: Asegurar que NO hay FK en id_material
-- ============================================================================
SELECT '========== SECCIÓN 2: REMOVER FK EN id_material ==========' as seccion;

SET SQL_SAFE_UPDATES = 0;

-- Si existe FK en id_material, removerla
ALTER TABLE TblRequerimientoDetalle DROP FOREIGN KEY IF EXISTS fk_requerimiento_material;

-- Asegurar que id_material es NULLABLE
ALTER TABLE TblRequerimientoDetalle MODIFY COLUMN id_material INT NULL COMMENT 'FK a TblMateriales (opcional para servicios)';

-- Crear índice para búsquedas (sin FK constraint)
ALTER TABLE TblRequerimientoDetalle DROP INDEX IF EXISTS idx_id_material;
ALTER TABLE TblRequerimientoDetalle ADD INDEX idx_id_material (id_material);

SET SQL_SAFE_UPDATES = 1;

-- SECCIÓN 3: Verificar SP existe
-- ============================================================================
SELECT '========== SECCIÓN 3: VERIFICAR SP ==========' as seccion;

-- Verificar que el SP existe
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    ROUTINE_SCHEMA
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE() 
AND ROUTINE_NAME = 'sp_CrearRequerimientoCompleto';

-- SECCIÓN 4: Verificación Final
-- ============================================================================
SELECT '========== SECCIÓN 4: VERIFICACIÓN FINAL ==========' as seccion;

-- Mostrar estructura final de TblRequerimientoDetalle
SELECT 'ESTRUCTURA FINAL:' as info;
SHOW COLUMNS FROM TblRequerimientoDetalle;

-- Mostrar constraints finales
SELECT 'CONSTRAINTS FINALES:' as info;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle'
ORDER BY CONSTRAINT_NAME;

SELECT '✓ Setup completado - Sistema listo para requerimientos' as resultado;
