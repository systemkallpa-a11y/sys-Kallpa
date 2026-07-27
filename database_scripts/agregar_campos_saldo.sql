-- ============================================================================
-- SCRIPT: Agregar columnas de saldo a TblPresupuesto
-- PROPÓSITO: Rastrear cantidad_consumida y cantidad_saldo por presupuesto
-- FECHA: 22 de Julio de 2026
-- ============================================================================

-- PASO 1: Agregar columnas si no existen
ALTER TABLE TblPresupuesto
ADD COLUMN IF NOT EXISTS cantidad_consumida DECIMAL(12,2) DEFAULT 0.00 
COMMENT 'Cantidad total consumida por requerimientos',
ADD COLUMN IF NOT EXISTS cantidad_saldo DECIMAL(12,2) DEFAULT 0.00 
COMMENT 'Cantidad disponible (monto - cantidad_consumida)';

-- PASO 2: Crear índices para optimizar búsquedas
CREATE INDEX idx_cantidad_saldo ON TblPresupuesto(cantidad_saldo);
CREATE INDEX idx_cantidad_consumida ON TblPresupuesto(cantidad_consumida);

-- PASO 3: Recalcular saldos para presupuestos existentes
UPDATE TblPresupuesto p
SET 
    cantidad_consumida = COALESCE((
        SELECT SUM(rd.cantidad)
        FROM TblRequerimiento tr
        INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
        WHERE tr.id_presupuesto = p.id_presupuesto
        AND tr.estado != 'ELIMINADO'
    ), 0),
    fecha_actualizacion = NOW()
WHERE id_presupuesto IN (
    SELECT DISTINCT id_presupuesto 
    FROM TblRequerimiento 
    WHERE id_presupuesto IS NOT NULL
);

-- PASO 4: Calcular cantidad_saldo
UPDATE TblPresupuesto
SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
WHERE id_presupuesto > 0;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ Columnas agregadas a TblPresupuesto' as estado;

-- Ver estructura actualizada
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto'
AND COLUMN_NAME IN ('cantidad_consumida', 'cantidad_saldo', 'monto')
ORDER BY ORDINAL_POSITION;

-- ============================================================================
