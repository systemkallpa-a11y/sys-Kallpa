-- ============================================================================
-- FIX: Limpiar y agregar FK a TblRequerimiento
-- DESCRIPCIÓN: 
--   1. Deshabilitar safe mode
--   2. Identificar registros huérfanos
--   3. Limpiar registros inválidos
--   4. Agregar FK correctamente
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 0: Deshabilitar safe update mode
SET SQL_SAFE_UPDATES = 0;

-- PASO 1: Verificar registros con num_usuario inválidos
SELECT 
    r.id_requerimiento,
    r.num_usuario,
    r.codigo,
    CASE WHEN u.num_usuario IS NULL THEN 'HUÉRFANO' ELSE 'OK' END as estado
FROM TblRequerimiento r
LEFT JOIN TblUsuario u ON r.num_usuario = u.num_usuario;

-- PASO 2: Eliminar registros huérfanos (si no tienes datos importantes)
DELETE FROM TblRequerimiento 
WHERE id_requerimiento IN (
    SELECT r.id_requerimiento
    FROM TblRequerimiento r
    LEFT JOIN TblUsuario u ON r.num_usuario = u.num_usuario
    WHERE r.num_usuario IS NULL OR u.num_usuario IS NULL
);

-- PASO 3: Ahora sí, agregar la FK (después de limpiar)
ALTER TABLE TblRequerimiento DROP FOREIGN KEY IF EXISTS fk_requerimiento_usuario;

ALTER TABLE TblRequerimiento 
ADD CONSTRAINT fk_requerimiento_usuario 
FOREIGN KEY (num_usuario) 
REFERENCES TblUsuario(num_usuario) 
ON DELETE RESTRICT 
ON UPDATE CASCADE;

-- PASO 4: Reactivar safe update mode
SET SQL_SAFE_UPDATES = 1;

-- PASO 5: Verificar que la FK se creó correctamente
SHOW KEYS FROM TblRequerimiento;

SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' AND COLUMN_NAME = 'num_usuario';

