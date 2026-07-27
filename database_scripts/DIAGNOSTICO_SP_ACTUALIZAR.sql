-- ============================================================================
-- DIAGNOSTICO: Ver qué versión del SP existe
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  DIAGNÓSTICO: SP sp_ActualizarPresupuestoCompleto            ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

SELECT '' as linea;
SELECT 'Verificando si el SP existe:' as paso;

SHOW PROCEDURE STATUS WHERE Name = 'sp_ActualizarPresupuestoCompleto';

SELECT '' as linea;
SELECT 'Mostrando el código del SP:' as paso;

SELECT ROUTINE_NAME, ROUTINE_DEFINITION 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_NAME = 'sp_ActualizarPresupuestoCompleto' 
AND ROUTINE_SCHEMA = DATABASE();
