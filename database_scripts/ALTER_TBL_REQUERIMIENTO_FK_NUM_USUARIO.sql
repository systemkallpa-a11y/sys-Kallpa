-- ============================================================================
-- SCRIPT: Agregar FK num_usuario a TblRequerimiento
-- DESCRIPCIÓN: 
--   1. Agregar columna num_usuario (FK a TblUsuario.num_usuario)
--   2. Eliminar columnas no necesarias
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Eliminar constraints existentes si existen
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_usuario;
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_persona;

-- PASO 2: Eliminar columnas no necesarias
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS solicitante;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS departamento;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS unidad_medida;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS id_usuario;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS num_documento;

-- PASO 3: Agregar columna num_usuario (FK a TblUsuario)
ALTER TABLE TblRequerimiento ADD COLUMN num_usuario INT NOT NULL AFTER id_requerimiento;

-- PASO 4: Crear la FK apuntando a TblUsuario.num_usuario (PRIMARY KEY)
ALTER TABLE TblRequerimiento 
ADD CONSTRAINT fk_requerimiento_usuario 
FOREIGN KEY (num_usuario) 
REFERENCES TblUsuario(num_usuario) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 5: Agregar índice para mejorar búsquedas
ALTER TABLE TblRequerimiento ADD INDEX idx_num_usuario (num_usuario);

-- VERIFICACIÓN
DESCRIBE TblRequerimiento;
SHOW KEYS FROM TblRequerimiento;

SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'num_usuario';
