-- ============================================================================
-- SCRIPT: Agregar id_presupuesto a TblRequerimiento
-- DESCRIPCIÓN: Agregar FK a TblPresupuesto para rastrear origen del requerimiento
-- FECHA: 2026-07-16
-- ============================================================================

SET SQL_SAFE_UPDATES = 0;

-- PASO 1: Verificar que TblRequerimiento existe
SELECT 'PASO 1: Verificando TblRequerimiento' as paso;
SHOW TABLES LIKE 'TblRequerimiento';

-- PASO 2: Agregar columna id_presupuesto si no existe
SELECT 'PASO 2: Agregando columna id_presupuesto' as paso;

ALTER TABLE TblRequerimiento 
ADD COLUMN id_presupuesto INT NULL COMMENT 'FK a TblPresupuesto - origen del requerimiento'
AFTER num_usuario;

-- PASO 3: Crear FK constraint
SELECT 'PASO 3: Creando FK constraint' as paso;

ALTER TABLE TblRequerimiento
ADD CONSTRAINT fk_requerimiento_presupuesto 
FOREIGN KEY (id_presupuesto) 
REFERENCES TblPresupuesto(id_presupuesto) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 4: Crear índice para búsquedas rápidas
SELECT 'PASO 4: Creando índice' as paso;

ALTER TABLE TblRequerimiento
ADD INDEX idx_id_presupuesto (id_presupuesto);

SET SQL_SAFE_UPDATES = 1;

-- PASO 5: Verificación final
SELECT 'PASO 5: Verificación final' as paso;

SHOW COLUMNS FROM TblRequerimiento;

SELECT 'CONSTRAINTS Y KEYS:' as info;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento'
ORDER BY CONSTRAINT_NAME;

SELECT '✓ Script completado' as resultado;
