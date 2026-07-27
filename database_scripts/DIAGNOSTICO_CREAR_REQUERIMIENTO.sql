-- ============================================================================
-- SCRIPT: Diagnóstico de error en sp_CrearRequerimientoCompleto
-- DESCRIPCIÓN: Verifica la estructura actual de TblRequerimiento
--              y ejecuta los SPs necesarios
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 1: Mostrar estructura actual de TblRequerimiento
SELECT 'PASO 1: Verificando estructura de TblRequerimiento' as paso;
DESCRIBE TblRequerimiento;

-- PASO 2: Verificar que las columnas requeridas existen
SELECT 'PASO 2: Verificando columnas requeridas' as paso;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblRequerimiento'
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- PASO 3: Verificar que TblUsuario existe y tiene num_usuario
SELECT 'PASO 3: Verificando TblUsuario' as paso;
DESCRIBE TblUsuario;

-- PASO 4: Verificar que TblPresupuesto y TblPresupuestoDetalle existen
SELECT 'PASO 4: Verificando TblPresupuestoDetalle' as paso;
DESCRIBE TblPresupuestoDetalle;

-- PASO 5: Verificar que TblRequerimientoDetalle existe
SELECT 'PASO 5: Verificando TblRequerimientoDetalle' as paso;
DESCRIBE TblRequerimientoDetalle;

-- PASO 6: Listar SPs existentes relacionados con requerimientos
SELECT 'PASO 6: SPs existentes' as paso;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name LIKE '%Requerimiento%';

-- PASO 7: Información adicional
SELECT 'PASO 7: Información de InnoDB' as paso;
SELECT * FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = DATABASE() 
  AND TABLE_NAME LIKE '%Requerimiento%';
