-- ============================================================================
-- SCRIPT: Corrección - Control de Saldo por Item (TblPresupuestoDetalle)
-- DESCRIPCIÓN: El saldo debe controlarse por cada item del presupuesto
--              NO por el presupuesto completo
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  CORRECCIÓN: Saldo por Item del Presupuesto                   ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: ELIMINAR COLUMNAS DE TblPresupuesto (INCORRECTO)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Eliminando columnas de TblPresupuesto (no son necesarias)' as paso;

ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_saldo;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_consumida;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_original;

SELECT '✓ Columnas eliminadas de TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 2: AGREGAR COLUMNAS A TblPresupuestoDetalle (CORRECTO)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Agregando columnas de control a TblPresupuestoDetalle' as paso;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_original DECIMAL(10, 2) 
COMMENT 'Cantidad presupuestada originalmente'
AFTER cantidad;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_consumida DECIMAL(10, 2) DEFAULT 0
COMMENT 'Cantidad usada en requerimientos'
AFTER cantidad_original;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_saldo DECIMAL(10, 2) GENERATED ALWAYS AS (COALESCE(cantidad_original, 0) - COALESCE(cantidad_consumida, 0)) STORED
COMMENT 'Saldo disponible = original - consumida'
AFTER cantidad_consumida;

ALTER TABLE TblPresupuestoDetalle 
ADD INDEX IF NOT EXISTS idx_cantidad_saldo (cantidad_saldo);

SELECT '✓ Columnas agregadas a TblPresupuestoDetalle' as resultado;

-- ============================================================================
-- PASO 3: INICIALIZAR cantidad_original EN DETALLES EXISTENTES
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Inicializando cantidad_original = cantidad' as paso;

UPDATE TblPresupuestoDetalle
SET cantidad_original = cantidad
WHERE cantidad_original IS NULL;

SELECT 'Detalles inicializados' as resultado;

-- ============================================================================
-- PASO 4: VERIFICACIÓN
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 4: Verificación de estructura' as paso;

SELECT 'TblPresupuestoDetalle - Nuevas columnas:' as verificacion;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuestoDetalle'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%'
ORDER BY ORDINAL_POSITION;

SELECT '' as linea;
SELECT 'Muestra de datos:' as muestra;
SELECT 
    id_detalle,
    cantidad,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo,
    descripcion
FROM TblPresupuestoDetalle
LIMIT 5;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ CORRECCIÓN COMPLETADA                          ║';
SELECT '║                                                                ║';
SELECT '║  Ahora el control de saldo es POR ITEM:                       ║';
SELECT '║  - Cada item del presupuesto tiene su saldo                   ║';
SELECT '║  - Múltiples requerimientos pueden usar el mismo item          ║';
SELECT '║  - Se controla el consumo individual                          ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
