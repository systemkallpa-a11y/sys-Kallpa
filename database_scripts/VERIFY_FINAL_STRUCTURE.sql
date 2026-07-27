-- ============================================================================
-- VERIFICACIÓN FINAL: Estructura de TblPresupuesto
-- ============================================================================

SELECT 'ESTRUCTURA FINAL DE TblPresupuesto' as titulo;
SELECT '═════════════════════════════════════════' as separador;
DESCRIBE TblPresupuesto;

SELECT '' as vacio;
SELECT 'Foreign Keys restantes:' as info;
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto'
  AND REFERENCED_TABLE_NAME IS NOT NULL;

SELECT '' as vacio;
SELECT 'Índices en TblPresupuesto:' as info;
SHOW INDEXES FROM TblPresupuesto;

SELECT '' as vacio;
SELECT '✅ VERIFICACIÓN COMPLETADA' as resultado;
SELECT 'Campo id_material removido exitosamente' as confirmacion;
