-- ============================================================================
-- Script: AGREGAR_CAMPOS_PRESUPUESTO.sql
-- Propósito: Agregar campos de Gastos Generales, Utilidad, IGV y Supervisión de Obra
-- Fecha: 20 Julio 2026
-- ============================================================================

-- Verificar y agregar columnas a TblPresupuesto
ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS gastos_generales DECIMAL(12, 2) DEFAULT 0 COMMENT 'Gastos generales del presupuesto',
ADD COLUMN IF NOT EXISTS utilidad DECIMAL(12, 2) DEFAULT 0 COMMENT 'Utilidad/Margen de ganancia',
ADD COLUMN IF NOT EXISTS igv DECIMAL(12, 2) DEFAULT 0 COMMENT 'IGV (Impuesto General a las Ventas)',
ADD COLUMN IF NOT EXISTS supervision_obra DECIMAL(12, 2) DEFAULT 0 COMMENT 'Costo de supervisión de obra',
ADD COLUMN IF NOT EXISTS monto_total DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto total del presupuesto con desglose (subtotal × 1.48)',
ADD COLUMN IF NOT EXISTS monto_aprobado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto aprobado del presupuesto';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Campos agregados exitosamente a TblPresupuesto ✓' as resultado;

-- Mostrar estructura actualizada
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto' 
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- RESUMEN DE CAMBIOS
-- ============================================================================
-- 
-- Nuevos campos agregados a TblPresupuesto:
--   1. gastos_generales (DECIMAL 12,2) - DEFAULT 0
--   2. utilidad (DECIMAL 12,2) - DEFAULT 0
--   3. igv (DECIMAL 12,2) - DEFAULT 0
--   4. supervision_obra (DECIMAL 12,2) - DEFAULT 0
--   5. monto_total (DECIMAL 12,2) - DEFAULT 0
--   6. monto_aprobado (DECIMAL 12,2) - DEFAULT 0
--
-- Estos campos permiten:
--   - Desglosar costos de gastos generales
--   - Controlar la utilidad/margen
--   - Calcular IGV de forma separada
--   - Incluir costos de supervisión
--   - Almacenar el monto total calculado
--   - Registrar montos aprobados en flujo de aprobación
--
-- Fórmula de cálculo recomendada:
--   monto_total = subtotal_materiales + subtotal_servicios + gastos_generales + supervision_obra + utilidad + igv
--   O simplemente: monto_total = subtotal * 1.48
--
-- ============================================================================
