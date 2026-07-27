-- ============================================================================
-- SCRIPT: Verificar y agregar columna observaciones a TblRequerimientoDetalle
-- DESCRIPCIÓN: Si la columna observaciones no existe, la agregará
-- FECHA: 2026-07-17
-- ============================================================================

-- Verificar si la columna existe, si no, agregarla
ALTER TABLE TblRequerimientoDetalle 
ADD COLUMN IF NOT EXISTS observaciones TEXT NULL AFTER unidad_medida;

-- Confirmar que se agregó
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblRequerimientoDetalle' 
AND COLUMN_NAME IN ('id_detalle', 'id_requerimiento', 'descripcion', 'cantidad', 'unidad_medida', 'observaciones', 'fecha_creacion');
