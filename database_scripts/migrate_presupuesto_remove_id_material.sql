-- ============================================================================
-- MIGRACIÓN: Eliminar campo id_material de TblPresupuesto
-- Justificación: Los materiales ahora están en TblPresupuestoDetalle
-- Fecha: 10 Julio 2026
-- ============================================================================

-- PASO 1: Verificar estado actual
SELECT 'Verificando estructura actual de TblPresupuesto...' as paso;
SELECT COUNT(*) as total_presupuestos FROM TblPresupuesto;

-- PASO 2: Identificar Foreign Keys en id_material
SELECT 'Identificando Foreign Keys...' as paso;
SELECT CONSTRAINT_NAME 
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto' 
  AND COLUMN_NAME = 'id_material'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- PASO 3: Remover Foreign Key primero
ALTER TABLE TblPresupuesto 
DROP FOREIGN KEY TblPresupuesto_ibfk_3;

SELECT 'Foreign Key removida' as paso;

-- PASO 4: Remover columna (esto automáticamente remueve el índice asociado)
ALTER TABLE TblPresupuesto 
DROP COLUMN id_material;

SELECT 'Columna id_material removida exitosamente ✓' as resultado;

-- PASO 5: Verificación final
DESCRIBE TblPresupuesto;

SELECT 'Estructura final verificada' as paso;

-- ============================================================================
-- ESTRUCTURA FINAL DE TblPresupuesto (sin id_material):
-- ============================================================================
-- id_presupuesto (PK)
-- numero_presupuesto (UNIQUE)
-- id_obra (FK → TblObra)
-- num_documento (FK → TblUsuario)
-- monto (auto-calculado desde TblPresupuestoDetalle)
-- estado
-- observaciones
-- fecha_creacion
-- fecha_actualizacion
-- ============================================================================
