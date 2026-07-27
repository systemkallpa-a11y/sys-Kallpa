-- ============================================================================
-- SCRIPT: Verificar setup de TblRequerimiento y TblRequerimientoDetalle
-- FECHA: 2026-07-16
-- ============================================================================

-- 1. Verificar estructura de TblRequerimiento
SHOW COLUMNS FROM TblRequerimiento;
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento';

-- 2. Verificar estructura de TblRequerimientoDetalle
SHOW COLUMNS FROM TblRequerimientoDetalle;
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle';

-- 3. Verificar que TblPresupuestoDetalle tiene id_material
SHOW COLUMNS FROM TblPresupuestoDetalle;

-- 4. Contar registros en cada tabla
SELECT 
    'TblRequerimiento' as tabla,
    COUNT(*) as total
FROM TblRequerimiento
UNION ALL
SELECT 
    'TblRequerimientoDetalle' as tabla,
    COUNT(*) as total
FROM TblRequerimientoDetalle;

-- 5. Obtener sample de presupuesto detalle
SELECT 
    id_detalle,
    id_presupuesto,
    id_material,
    tipo_item,
    descripcion,
    cantidad,
    observaciones,
    precio_unitario
FROM TblPresupuestoDetalle
LIMIT 5;
