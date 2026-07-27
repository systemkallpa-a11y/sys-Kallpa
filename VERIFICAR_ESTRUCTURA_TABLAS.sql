-- ========================================================================
-- VERIFICAR ESTRUCTURA DE TABLAS RELACIONADAS
-- Ejecutar en MySQL Workbench para conocer las columnas correctas
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Verificar estructura de TblMateriales
SELECT 'ESTRUCTURA TblMateriales:' AS info;
DESC TblMateriales;

-- Verificar estructura de TblUnidadMedida
SELECT 'ESTRUCTURA TblUnidadMedida:' AS info;
DESC TblUnidadMedida;

-- Verificar estructura de TblRequerimientoDetalle
SELECT 'ESTRUCTURA TblRequerimientoDetalle:' AS info;
DESC TblRequerimientoDetalle;

-- Ver algunos datos de muestra de TblMateriales
SELECT 'MUESTRA TblMateriales:' AS info;
SELECT * FROM TblMateriales LIMIT 5;

-- Ver algunos datos de muestra de TblUnidadMedida
SELECT 'MUESTRA TblUnidadMedida:' AS info;
SELECT * FROM TblUnidadMedida LIMIT 5;

-- Ver el último requerimiento creado
SELECT 'ÚLTIMO REQUERIMIENTO:' AS info;
SELECT * FROM TblRequerimientoDetalle 
WHERE id_requerimiento = (SELECT MAX(id_requerimiento) FROM TblRequerimiento)
LIMIT 5;