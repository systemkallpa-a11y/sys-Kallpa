-- ========================================================================
-- CORRECCIÓN: Actualizar columna tipo_item para permitir MATERIAL y SERVICIO
-- Ejecutar en MySQL Workbench después de la migración principal
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Actualizar la columna tipo_item para que permita MATERIAL y SERVICIO
ALTER TABLE TblRequerimientoDetalle 
MODIFY COLUMN tipo_item VARCHAR(20) NOT NULL DEFAULT 'MATERIAL' 
COMMENT 'Tipo de item: MATERIAL o SERVICIO';

-- Verificar que la estructura es correcta
DESC TblRequerimientoDetalle;

-- Query de prueba para verificar tipos de items existentes
SELECT 
    tipo_item,
    COUNT(*) as cantidad
FROM TblRequerimientoDetalle 
GROUP BY tipo_item;

-- Verificar items con id_material NULL (deberían ser servicios)
SELECT 
    rd.id_detalle,
    rd.descripcion,
    rd.tipo_item,
    rd.id_material,
    CASE 
        WHEN rd.id_material IS NULL THEN 'SERVICIO (sin material)'
        ELSE 'MATERIAL (con id_material)'
    END as clasificacion
FROM TblRequerimientoDetalle rd
ORDER BY rd.id_detalle DESC
LIMIT 10;

SELECT '✅ CORRECCIÓN TIPO_ITEM COMPLETADA' AS RESULTADO;