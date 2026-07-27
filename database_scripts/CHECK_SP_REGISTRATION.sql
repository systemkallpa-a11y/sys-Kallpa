-- ============================================================================
-- SCRIPT: Verificar que los SPs están registrados
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '====== VERIFICACIÓN DE SPs ======' as paso;

-- Verificar que sp_CrearRequerimientoCompleto existe
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    ROUTINE_SCHEMA,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE() 
AND ROUTINE_NAME = 'sp_CrearRequerimientoCompleto';

SELECT '---' as sep;

-- Verificar que sp_ObtenerRequerimientoDetalles existe
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    ROUTINE_SCHEMA,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE() 
AND ROUTINE_NAME = 'sp_ObtenerRequerimientoDetalles';

SELECT '---' as sep;

-- Listar todos los SPs relacionados con presupuesto
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE() 
AND (ROUTINE_NAME LIKE '%Presupuesto%' OR ROUTINE_NAME LIKE '%Requerimiento%')
ORDER BY ROUTINE_NAME;

SELECT '====== VERIFICACIÓN COMPLETA ======' as resultado;
