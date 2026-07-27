-- ============================================================================
-- SCRIPT: Agregar columnas de control de saldo a TblPresupuesto
-- DESCRIPCIÓN: Prepara la tabla para rastrear consumo de presupuesto
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '========== AGREGANDO COLUMNAS DE SALDO A TblPresupuesto ==========' as paso;

-- PASO 1: Verificar estructura actual
SELECT 'PASO 1: Estructura actual de TblPresupuesto' as paso;
DESCRIBE TblPresupuesto;

-- PASO 2: Agregar columna cantidad_original
SELECT 'PASO 2: Agregando cantidad_original' as paso;
ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_original INT 
COMMENT 'Cantidad total presupuestada (materiales + servicios)'
AFTER estado;

-- PASO 3: Agregar columna cantidad_consumida
SELECT 'PASO 3: Agregando cantidad_consumida' as paso;
ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_consumida INT DEFAULT 0 
COMMENT 'Cantidad usada en requerimientos'
AFTER cantidad_original;

-- PASO 4: Agregar columna cantidad_saldo (GENERADA)
SELECT 'PASO 4: Agregando cantidad_saldo (columna calculada)' as paso;
ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_saldo INT GENERATED ALWAYS AS (COALESCE(cantidad_original, 0) - COALESCE(cantidad_consumida, 0)) STORED 
COMMENT 'Saldo disponible = original - consumida'
AFTER cantidad_consumida;

-- PASO 5: Agregar índices para búsquedas rápidas
SELECT 'PASO 5: Agregando índices' as paso;
ALTER TABLE TblPresupuesto 
ADD INDEX IF NOT EXISTS idx_cantidad_saldo (cantidad_saldo);

-- PASO 6: Verificar estructura final
SELECT 'PASO 6: Estructura final de TblPresupuesto' as paso;
DESCRIBE TblPresupuesto;

SELECT '========== VERIFICACIÓN COMPLETADA ==========' as estado;
SELECT 'Columnas agregadas:' as resumen;
SELECT '  ✓ cantidad_original (cantidad total presupuestada)' as col1;
SELECT '  ✓ cantidad_consumida (suma de requerimientos)' as col2;
SELECT '  ✓ cantidad_saldo (original - consumida, generada automáticamente)' as col3;
