-- ============================================================================
-- DIAGNÓSTICO: Verificar tipos de datos para FK
-- ============================================================================

-- Ver estructura de TblUsuario
DESCRIBE TblUsuario;

-- Ver estructura actual de TblRequerimiento
DESCRIBE TblRequerimiento;

-- Verificar el tipo exacto de num_documento en TblUsuario
SELECT COLUMN_NAME, COLUMN_TYPE, COLLATION_NAME, CHARACTER_SET_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblUsuario' AND COLUMN_NAME = 'num_documento';

-- Verificar el tipo exacto de num_documento en TblRequerimiento
SELECT COLUMN_NAME, COLUMN_TYPE, COLLATION_NAME, CHARACTER_SET_NAME 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'num_documento';

-- Ver todas las columnas de ambas tablas
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    COLLATION_NAME
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME IN ('TblUsuario', 'TblRequerimiento')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
