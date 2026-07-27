-- =====================================================
-- SCRIPT: ALTER_TBLEMPRESA_ADD_LOGO.sql
-- PROPOSITO: Agregar campo Logo a TblEmpresa
-- FECHA: 10 Julio 2026
-- =====================================================

-- Verificar si la tabla existe
USE kallgwkn_kallpa_bd;

-- Agregar columna Logo si no existe
ALTER TABLE TblEmpresa
ADD COLUMN logo LONGBLOB NULL COMMENT 'Logo de la empresa en formato PNG';

-- Verificar que el campo fue agregado correctamente
DESCRIBE TblEmpresa;

-- =====================================================
-- INFORMACIÓN TÉCNICA
-- =====================================================
-- logo: LONGBLOB
--   - Almacena el archivo PNG binario
--   - Máximo 4GB (suficiente para imágenes)
--   - NULL por defecto (logo opcional)
-- =====================================================
