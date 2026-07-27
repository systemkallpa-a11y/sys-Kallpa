-- =====================================================
-- SCRIPT: RENAME_TBLEMPRESA.sql
-- PROPOSITO: Renombrar tabla tblEmpresa a TblEmpresa
-- FECHA: 10 Julio 2026
-- =====================================================

USE kallgwkn_kallpa_bd;

-- Renombrar la tabla
RENAME TABLE tblEmpresa TO TblEmpresa;

-- Verificar que el cambio fue exitoso
SHOW TABLES LIKE 'TblEmpresa';

-- =====================================================
-- INFORMACIÓN
-- =====================================================
-- La tabla tblEmpresa ha sido renombrada a TblEmpresa
-- Todas las referencias en el código Python ahora coinciden
-- con el nombre de la tabla en la base de datos
-- =====================================================
