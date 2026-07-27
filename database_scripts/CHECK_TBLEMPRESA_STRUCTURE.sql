-- =====================================================
-- SCRIPT: CHECK_TBLEMPRESA_STRUCTURE.sql
-- PROPOSITO: Verificar estructura de TblEmpresa
-- FECHA: 10 Julio 2026
-- =====================================================

USE kallgwkn_kallpa_bd;

-- Ver estructura de la tabla
DESCRIBE TblEmpresa;

-- Ver todas las columnas y sus tipos
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblEmpresa' 
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
ORDER BY ORDINAL_POSITION;

-- Ver si existen índices
SHOW INDEX FROM TblEmpresa;

-- =====================================================
