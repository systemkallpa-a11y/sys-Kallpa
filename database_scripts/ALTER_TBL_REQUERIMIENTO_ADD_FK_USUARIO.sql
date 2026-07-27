-- ============================================================================
-- SCRIPT: Migración de TblRequerimiento
-- DESCRIPCIÓN: 
--   1. Eliminar campo 'solicitante', 'departamento', 'unidad_medida'
--   2. Agregar/corregir campo 'num_documento' como FK a TblUsuario
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Verificar y eliminar constraint existente si existe
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_usuario;

-- PASO 2: Eliminar columnas no necesarias
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS solicitante;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS departamento;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS unidad_medida;

-- PASO 3: Verificar si num_documento existe
-- Si no existe, agregarlo con el tipo correcto
ALTER TABLE TblRequerimiento ADD COLUMN IF NOT EXISTS num_documento VARCHAR(20);

-- PASO 4: Convertir num_documento a tipo correcto si es necesario
-- Cambiar el tipo a VARCHAR(20) y NOT NULL (igual a TblUsuario)
ALTER TABLE TblRequerimiento MODIFY COLUMN num_documento VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;

-- PASO 5: Agregar Foreign Key a TblUsuario
ALTER TABLE TblRequerimiento 
ADD CONSTRAINT fk_requerimiento_usuario 
FOREIGN KEY (num_documento) 
REFERENCES TblUsuario(num_documento) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 6: Agregar índice para mejorar búsquedas
ALTER TABLE TblRequerimiento ADD INDEX idx_num_documento (num_documento);

-- PASO 7: Verificar estructura actualizada
DESCRIBE TblRequerimiento;

-- PASO 8: Verificar que la FK se creó correctamente
SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'num_documento';

