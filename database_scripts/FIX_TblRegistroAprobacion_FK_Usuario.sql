-- ============================================================================
-- SCRIPT: Arreglar TblRegistroAprobacion - Renombrar y Agregar FK a Usuario
-- DESCRIPCIÓN:
--   1. Renombrar num_documento_aprobador → num_documento
--   2. Agregar Foreign Key a TblUsuario.num_documento
--   3. Garantizar integridad referencial del aprobador
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  Arreglando TblRegistroAprobacion                              ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: Verificar estructura actual
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 1: Verificando estructura actual de TblRegistroAprobacion' as paso;

DESCRIBE TblRegistroAprobacion;

-- ============================================================================
-- PASO 2: Verificar si existe el campo num_documento_aprobador
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 2: Verificando existencia de campos' as paso;

SELECT IF(
    EXISTS (
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'TblRegistroAprobacion'
        AND COLUMN_NAME = 'num_documento_aprobador'
    ),
    '✓ Campo num_documento_aprobador existe',
    '✗ Campo num_documento_aprobador NO existe'
) as resultado;

-- ============================================================================
-- PASO 3: Eliminar FK existente si la hay
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 3: Eliminando FK antigua si existe' as paso;

-- Intentar eliminar la FK si existe (ignorar si no existe)
ALTER TABLE TblRegistroAprobacion DROP FOREIGN KEY IF EXISTS fk_registro_aprobacion_usuario_old;

SELECT '✓ FK antigua eliminada o no existía' as resultado;

-- ============================================================================
-- PASO 4: Renombrar columna
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 4: Renombrando num_documento_aprobador → num_documento' as paso;

ALTER TABLE TblRegistroAprobacion
CHANGE COLUMN num_documento_aprobador num_documento INT(11) NULL;

SELECT '✓ Columna renombrada' as resultado;

-- ============================================================================
-- PASO 5: Agregar Foreign Key a TblUsuario
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 5: Agregando Foreign Key a TblUsuario' as paso;

ALTER TABLE TblRegistroAprobacion
ADD CONSTRAINT fk_registro_aprobacion_usuario
FOREIGN KEY (num_documento)
REFERENCES TblUsuario(num_documento)
ON DELETE SET NULL
ON UPDATE CASCADE;

SELECT '✓ Foreign Key agregada' as resultado;

-- ============================================================================
-- PASO 6: Verificación final
-- ============================================================================
SELECT '' as paso;
SELECT 'PASO 6: Verificación Final' as paso;

SELECT 'Estructura de TblRegistroAprobacion después de cambios:' as verificacion;
DESCRIBE TblRegistroAprobacion;

SELECT '' as paso;
SELECT 'Foreign Keys de TblRegistroAprobacion:' as verificacion;
SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME = 'TblRegistroAprobacion'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- ============================================================================
-- RESUMEN
-- ============================================================================
SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ TABLA ARREGLADA EXITOSAMENTE                   ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS REALIZADOS:' as cambios;
SELECT '  ✓ num_documento_aprobador → num_documento' as cambio1;
SELECT '  ✓ Foreign Key agregada a TblUsuario.num_documento' as cambio2;
SELECT '  ✓ Integridad referencial garantizada' as cambio3;
SELECT '';
SELECT 'SIGNIFICADO:' as significado;
SELECT 'El campo num_documento ahora:' as sig1;
SELECT '  • Almacena el documento del usuario que aprobó' as sig2;
SELECT '  • Está vinculado a TblUsuario.num_documento' as sig3;
SELECT '  • Garantiza que solo usuarios existentes pueden aprobar' as sig4;
