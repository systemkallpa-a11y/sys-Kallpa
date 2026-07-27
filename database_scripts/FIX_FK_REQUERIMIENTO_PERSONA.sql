-- ============================================================================
-- FIX: Crear FK correctamente en TblRequerimiento con TblPersona
-- DESCRIPCIÓN: 
--   1. Asegurar que TblPersona.num_documento sea PRIMARY KEY
--   2. Crear FK en TblRequerimiento apuntando a TblPersona
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Eliminar constraint si existe
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_usuario;
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_persona;

-- PASO 2: Asegurar que la columna num_documento existe y tiene el tipo correcto
ALTER TABLE TblRequerimiento ADD COLUMN IF NOT EXISTS num_documento VARCHAR(20);

-- PASO 3: Convertir a tipo compatible
ALTER TABLE TblRequerimiento MODIFY COLUMN num_documento VARCHAR(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- PASO 4: Crear la FK apuntando a TblPersona.num_documento
ALTER TABLE TblRequerimiento 
ADD CONSTRAINT fk_requerimiento_persona 
FOREIGN KEY (num_documento) 
REFERENCES TblPersona(num_documento) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 5: Agregar índice
ALTER TABLE TblRequerimiento ADD INDEX idx_num_documento (num_documento);

-- VERIFICACIÓN
SHOW KEYS FROM TblRequerimiento;

SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'num_documento';
