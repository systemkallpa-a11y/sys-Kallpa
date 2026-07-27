-- ============================================================================
-- DIAGNÓSTICO: Estructura completa de TblUsuario
-- ============================================================================

-- Ver estructura
DESCRIBE TblUsuario;

-- Ver claves e índices
SHOW KEYS FROM TblUsuario;

-- Ver información detallada de columnas
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblUsuario'
ORDER BY ORDINAL_POSITION;

-- Ver constraints
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblUsuario';

-- Ver si id_usuario existe y es PK
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblUsuario' AND COLUMN_NAME = 'id_usuario';
