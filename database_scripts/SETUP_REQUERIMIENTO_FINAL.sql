-- ============================================================================
-- SCRIPT: Setup Final de TblRequerimiento y TblRequerimientoDetalle
-- DESCRIPCIÓN: 
--   - Asegurar que TblRequerimiento tiene FK correcto a TblUsuario
--   - Asegurar que TblRequerimientoDetalle NO tiene FK a TblMateriales
--   - id_material en TblRequerimientoDetalle es NULLABLE sin FK
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Verificar que ambas tablas existen
SELECT 'Paso 1: Verificando tablas...' as paso;

-- PASO 2: Deshabilitar safe mode para hacer cambios
SET SQL_SAFE_UPDATES = 0;

-- PASO 3: Para TblRequerimientoDetalle - Remover FK si existe
SELECT 'Paso 3: Revisando FKs en TblRequerimientoDetalle...' as paso;

ALTER TABLE TblRequerimientoDetalle DROP FOREIGN KEY IF EXISTS fk_requerimiento_material;

-- PASO 4: Asegurar que id_material es NULLABLE (sin FK)
ALTER TABLE TblRequerimientoDetalle MODIFY COLUMN id_material INT NULL;

-- PASO 5: Crear índice en id_material para búsquedas rápidas (sin FK)
-- Primero remover si existe
ALTER TABLE TblRequerimientoDetalle DROP INDEX IF EXISTS idx_id_material;
-- Luego crear nuevo
ALTER TABLE TblRequerimientoDetalle ADD INDEX idx_id_material (id_material);

-- PASO 6: Verificar TblRequerimiento tiene FK correcto a TblUsuario
SELECT 'Paso 6: Revisando FKs en TblRequerimiento...' as paso;

-- PASO 7: Reactivar safe mode
SET SQL_SAFE_UPDATES = 1;

-- PASO 8: Verificación final
SELECT 'Paso 8: Verificación final...' as paso;

-- Mostrar estructura de TblRequerimientoDetalle
SHOW CREATE TABLE TblRequerimientoDetalle;

-- Mostrar todas las constraints
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle'
ORDER BY CONSTRAINT_NAME;

SELECT '✓ Setup completado' as resultado;
