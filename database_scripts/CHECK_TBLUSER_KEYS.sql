-- ============================================================================
-- VERIFICAR: Estructura de TblUsuario y sus índices
-- ============================================================================

-- Ver estructura completa
DESCRIBE TblUsuario;

-- Ver claves y índices
SHOW KEYS FROM TblUsuario;

-- Ver información de constraints
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblUsuario';

-- Ver si num_documento es UNIQUE o PRIMARY KEY
SELECT 
    COLUMN_NAME,
    COLUMN_KEY,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblUsuario' AND COLUMN_NAME = 'num_documento';

-- Ver todas las columnas de TblUsuario
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblUsuario'
ORDER BY ORDINAL_POSITION;
