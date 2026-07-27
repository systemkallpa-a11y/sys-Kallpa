-- ============================================================================
-- FIX: Remover correctamente id_material de TblPresupuesto
-- El error anterior indica que hay múltiples FKs relacionadas a id_material
-- ============================================================================

-- PASO 1: Identificar TODAS las FKs en TblPresupuesto
SELECT 'Paso 1: Identificando todas las Foreign Keys...' as paso;
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

-- PASO 2: Remover TODAS las FKs que usen id_material
-- Primero la que ya sabemos
ALTER TABLE TblPresupuesto 
DROP FOREIGN KEY TblPresupuesto_ibfk_3;

-- Luego la segunda (TblPresupuesto_ibfk_2)
ALTER TABLE TblPresupuesto 
DROP FOREIGN KEY TblPresupuesto_ibfk_2;

SELECT 'Paso 2: Foreign Keys removidas' as paso;

-- PASO 3: Remover la columna
ALTER TABLE TblPresupuesto 
DROP COLUMN id_material;

SELECT 'Paso 3: Columna id_material removida' as paso;

-- PASO 4: Verificar que la columna ya no existe
SELECT 'Paso 4: Verificando estructura final...' as paso;
DESCRIBE TblPresupuesto;

SELECT 'Paso 5: ✅ PROCESO COMPLETADO' as paso;
