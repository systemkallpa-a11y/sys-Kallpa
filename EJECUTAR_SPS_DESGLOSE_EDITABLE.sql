-- ============================================================================
-- SCRIPT: EJECUTAR_SPS_DESGLOSE_EDITABLE.sql
-- Fecha: 2026-07-22
-- Propósito: Ejecutar los nuevos SPs para presupuestos con desglose editable
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '🔄 INICIANDO ACTUALIZACIÓN DE SPs PARA DESGLOSE EDITABLE' AS MENSAJE;
SELECT '';

-- ============================================================================
-- 1. EJECUTAR SP DE CREAR PRESUPUESTO
-- ============================================================================

SELECT '📋 PASO 1: Actualizando SP_CrearPresupuestoCompleto...' AS PASO;

-- Ejecutar el script del SP de crear
SOURCE database_scripts/SP_CREAR_PRESUPUESTO_CON_DESGLOSE_EDITABLE.sql;

SELECT '✅ SP_CrearPresupuestoCompleto actualizado' AS RESULTADO;
SELECT '';

-- ============================================================================
-- 2. EJECUTAR SP DE ACTUALIZAR PRESUPUESTO  
-- ============================================================================

SELECT '📋 PASO 2: Actualizando SP_ActualizarPresupuestoCompleto...' AS PASO;

-- Ejecutar el script del SP de actualizar
SOURCE database_scripts/SP_ACTUALIZAR_PRESUPUESTO_CON_DESGLOSE_EDITABLE.sql;

SELECT '✅ SP_ActualizarPresupuestoCompleto actualizado' AS RESULTADO;
SELECT '';

-- ============================================================================
-- 3. VERIFICAR QUE LOS SPs EXISTEN
-- ============================================================================

SELECT '🔍 PASO 3: Verificando SPs creados...' AS PASO;

SHOW PROCEDURE STATUS WHERE 
    Name IN ('sp_CrearPresupuestoCompleto', 'sp_ActualizarPresupuestoCompleto')
    AND Db = 'kallgwkn_kallpa_bd';

SELECT '';

-- ============================================================================
-- 4. MOSTRAR ESTRUCTURA ACTUALIZADA
-- ============================================================================

SELECT '📊 PASO 4: Mostrando parámetros de los SPs...' AS PASO;

SELECT 
    ROUTINE_NAME as 'Stored Procedure',
    PARAMETER_NAME as 'Parámetro',
    DATA_TYPE as 'Tipo',
    PARAMETER_MODE as 'Modo'
FROM INFORMATION_SCHEMA.PARAMETERS 
WHERE SPECIFIC_SCHEMA = 'kallgwkn_kallpa_bd'
  AND ROUTINE_NAME IN ('sp_CrearPresupuestoCompleto', 'sp_ActualizarPresupuestoCompleto')
ORDER BY ROUTINE_NAME, ORDINAL_POSITION;

SELECT '';
SELECT '✅ ACTUALIZACIÓN COMPLETADA CON ÉXITO' AS RESULTADO_FINAL;
SELECT '';
SELECT 'CAMBIOS IMPLEMENTADOS:' AS CAMBIOS;
SELECT '  ✓ sp_CrearPresupuestoCompleto - Ahora acepta gastos_generales, utilidad, supervision_obra editables' AS C1;
SELECT '  ✓ sp_ActualizarPresupuestoCompleto - Ahora acepta gastos_generales, utilidad, supervision_obra editables' AS C2;
SELECT '  ✓ IGV se calcula automáticamente como 18% de (subtotal + desglose)' AS C3;
SELECT '  ✓ Frontend puede editar campos de desglose en modales Crear/Editar' AS C4;