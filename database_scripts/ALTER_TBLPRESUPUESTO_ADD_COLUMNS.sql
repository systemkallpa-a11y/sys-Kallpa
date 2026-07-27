-- ============================================================================
-- Script: Alterar TblPresupuesto para agregar/corregir campos
-- Propósito: Actualizar tabla para que coincida con estructura de backend
-- Fecha: 10 Julio 2026
-- ============================================================================

-- Verificar estructura actual
SELECT 'Estructura actual de TblPresupuesto:' as paso;
DESCRIBE TblPresupuesto;

-- ============================================================================
-- PASO 1: Agregar/corregir columnas si no existen
-- ============================================================================

-- Si existe 'monto', cambiar a 'monto_total'
ALTER TABLE IF EXISTS TblPresupuesto 
CHANGE COLUMN IF EXISTS monto monto_total DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto total del presupuesto';

-- Agregar monto_aprobado si no existe
ALTER TABLE IF EXISTS TblPresupuesto 
ADD COLUMN IF NOT EXISTS monto_aprobado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto aprobado por cliente';

-- Agregar moneda si no existe
ALTER TABLE IF EXISTS TblPresupuesto 
ADD COLUMN IF NOT EXISTS moneda VARCHAR(10) DEFAULT 'SOL' COMMENT 'Moneda: SOL, USD, EUR, etc';

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT 'Estructura actualizada de TblPresupuesto:' as paso;
DESCRIBE TblPresupuesto;

SELECT 
    'Verificación de columnas:' as paso,
    COUNT(*) as total_columnas
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuesto' AND TABLE_SCHEMA = DATABASE();

-- ============================================================================
-- VERIFICACIÓN DE DATOS
-- ============================================================================

SELECT '✓ Alteraciones completadas' as resultado;
SELECT 
    COUNT(*) as total_presupuestos,
    MIN(fecha_creacion) as fecha_primera,
    MAX(fecha_creacion) as fecha_ultima
FROM TblPresupuesto;

