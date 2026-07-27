-- ============================================================================
-- SCRIPT: Arreglar TblRegistroAprobacion - Simple y Directo
-- DESCRIPCIÓN:
--   1. Renombrar num_documento_aprobador → num_documento
--   2. Agregar Foreign Key a TblUsuario.num_documento
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  Arreglando TblRegistroAprobacion                              ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- Estructura actual
SELECT '' as paso;
SELECT 'ANTES: Estructura de TblRegistroAprobacion' as paso;
DESCRIBE TblRegistroAprobacion;

-- Renombrar columna
SELECT '' as paso;
SELECT 'Paso 1: Renombrando num_documento_aprobador → num_documento' as paso;

ALTER TABLE TblRegistroAprobacion
CHANGE COLUMN num_documento_aprobador num_documento INT(11) NULL;

SELECT '✓ Columna renombrada' as resultado;

-- Agregar FK (eliminar primero si existe)
SELECT '' as paso;
SELECT 'Paso 2: Agregando Foreign Key a TblUsuario' as paso;

ALTER TABLE TblRegistroAprobacion 
DROP FOREIGN KEY IF EXISTS fk_registro_aprobacion_usuario;

ALTER TABLE TblRegistroAprobacion
ADD CONSTRAINT fk_registro_aprobacion_usuario
FOREIGN KEY (num_documento)
REFERENCES TblUsuario(num_documento)
ON DELETE SET NULL
ON UPDATE CASCADE;

SELECT '✓ Foreign Key agregada' as resultado;

-- Verificación final
SELECT '' as paso;
SELECT 'DESPUÉS: Estructura de TblRegistroAprobacion' as paso;
DESCRIBE TblRegistroAprobacion;

SELECT '' as paso;
SELECT 'Foreign Keys:' as verificacion;
SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
AND TABLE_NAME = 'TblRegistroAprobacion'
AND REFERENCED_TABLE_NAME IS NOT NULL;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ TABLA ARREGLADA EXITOSAMENTE                   ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS REALIZADOS:' as cambios;
SELECT '  ✓ num_documento_aprobador → num_documento' as cambio1;
SELECT '  ✓ Foreign Key a TblUsuario.num_documento' as cambio2;
SELECT '  ✓ Integridad referencial del aprobador garantizada' as cambio3;
