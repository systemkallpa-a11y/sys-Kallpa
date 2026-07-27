-- ============================================================================
-- SCRIPT: Agregar FK id_usuario a TblRequerimiento
-- DESCRIPCIÓN: 
--   1. Agregar columna id_usuario (FK a TblUsuario)
--   2. Eliminar columnas no necesarias: solicitante, departamento, unidad_medida, num_documento
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Eliminar constraints existentes si existen
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_usuario;
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_persona;

-- PASO 2: Eliminar columnas no necesarias
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS solicitante;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS departamento;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS unidad_medida;
ALTER TABLE TblRequerimiento DROP COLUMN IF EXISTS num_documento;

-- PASO 3: Agregar columna id_usuario (FK a TblUsuario)
ALTER TABLE TblRequerimiento ADD COLUMN id_usuario INT NOT NULL AFTER id_requerimiento;

-- PASO 4: Crear la FK apuntando a TblUsuario
ALTER TABLE TblRequerimiento 
ADD CONSTRAINT fk_requerimiento_usuario 
FOREIGN KEY (id_usuario) 
REFERENCES TblUsuario(id_usuario) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 5: Agregar índice para mejorar búsquedas
ALTER TABLE TblRequerimiento ADD INDEX idx_id_usuario (id_usuario);

-- VERIFICACIÓN
DESCRIBE TblRequerimiento;
SHOW KEYS FROM TblRequerimiento;

SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'id_usuario';
