-- ==============================================================================
-- VER ESTRUCTURA COMPLETA DE TblMateriales
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- Ver todas las columnas y sus tipos
SHOW COLUMNS FROM TblMateriales;

-- Ver las llaves foráneas (Foreign Keys)
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND TABLE_NAME = 'TblMateriales'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Ver si existe la columna fecha_creacion
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND TABLE_NAME = 'TblMateriales'
  AND COLUMN_NAME = 'fecha_creacion';

-- Ver un material existente para ver la estructura real
SELECT * FROM TblMateriales WHERE codigo_material = 'MAT-007' LIMIT 1;
