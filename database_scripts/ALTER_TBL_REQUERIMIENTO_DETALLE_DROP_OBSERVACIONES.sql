-- ============================================================================
-- SCRIPT: Remover campo observaciones de TblRequerimientoDetalle
-- DESCRIPCIÓN: El campo observaciones no es necesario en los detalles
-- FECHA: 2026-07-16
-- ============================================================================

SELECT 'Removiendo campo observaciones de TblRequerimientoDetalle' as paso;

SET SQL_SAFE_UPDATES = 0;

-- PASO 1: Verificar que el campo existe
SELECT 'PASO 1: Verificar estructura actual' as paso;
DESCRIBE TblRequerimientoDetalle;

-- PASO 2: Remover la columna observaciones
SELECT 'PASO 2: Removiendo columna observaciones' as paso;

ALTER TABLE TblRequerimientoDetalle 
DROP COLUMN IF EXISTS observaciones;

SET SQL_SAFE_UPDATES = 1;

-- PASO 3: Verificación final
SELECT 'PASO 3: Verificación final' as paso;
DESCRIBE TblRequerimientoDetalle;

SELECT '✓ Campo observaciones removido correctamente' as resultado;
