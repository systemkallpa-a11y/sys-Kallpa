-- ============================================================================
-- SCRIPT: Actualizar TblRequerimientoDetalle - id_material NULLABLE sin FK
-- DESCRIPCIÓN: 
--   1. Eliminar FK a TblMateriales si existe
--   2. Convertir id_material a NULLABLE
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Deshabilitar safe mode
SET SQL_SAFE_UPDATES = 0;

-- PASO 2: Eliminar FK a TblMateriales si existe
ALTER TABLE TblRequerimientoDetalle DROP FOREIGN KEY IF EXISTS fk_requerimiento_material;

-- PASO 3: Modificar columna id_material para que sea NULLABLE
ALTER TABLE TblRequerimientoDetalle MODIFY COLUMN id_material INT NULL;

-- PASO 4: Reactivar safe mode
SET SQL_SAFE_UPDATES = 1;

-- VERIFICACIÓN
DESCRIBE TblRequerimientoDetalle;
SHOW KEYS FROM TblRequerimientoDetalle;

SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle';

