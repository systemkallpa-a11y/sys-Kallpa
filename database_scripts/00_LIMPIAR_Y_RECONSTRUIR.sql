-- ============================================================================
-- SCRIPT: Limpiar y Reconstruir - Arquitectura Correcta
-- DESCRIPCIÓN: 
--   1. Elimina columnas incorrectas de TblPresupuesto
--   2. Elimina tabla TblRequerimientoAuditoria (incompleta)
--   3. Agrega columnas correctas a TblPresupuestoDetalle
--   4. Recrea tabla TblRequerimientoAuditoria correctamente
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  LIMPIAR Y RECONSTRUIR CON ARQUITECTURA CORRECTA              ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: ELIMINAR COLUMNAS INCORRECTAS DE TblPresupuesto
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Eliminando columnas de TblPresupuesto' as paso;

ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_saldo;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_consumida;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_original;

SELECT '✓ Columnas eliminadas de TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 2: ELIMINAR TABLA DE AUDITORÍA INCOMPLETA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Eliminando tabla de auditoría (se recreará)' as paso;

DROP TABLE IF EXISTS TblRequerimientoAuditoria;
DROP VIEW IF EXISTS vw_requerimiento_auditoria;

SELECT '✓ Tabla y vista eliminadas' as resultado;

-- ============================================================================
-- PASO 3: AGREGAR COLUMNAS A TblPresupuestoDetalle
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Agregando columnas a TblPresupuestoDetalle' as paso;

-- Agregar cantidad_original (copia de cantidad para control)
ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_original DECIMAL(10, 2)
COMMENT 'Cantidad presupuestada originalmente'
AFTER cantidad;

-- Agregar cantidad_consumida (suma de requerimientos que usan este item)
ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_consumida DECIMAL(10, 2) DEFAULT 0
COMMENT 'Cantidad usada en requerimientos'
AFTER cantidad_original;

-- Agregar cantidad_saldo (calculada: original - consumida)
ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_saldo DECIMAL(10, 2) GENERATED ALWAYS AS (COALESCE(cantidad_original, 0) - COALESCE(cantidad_consumida, 0)) STORED
COMMENT 'Saldo disponible = original - consumida'
AFTER cantidad_consumida;

-- Agregar índice
ALTER TABLE TblPresupuestoDetalle 
ADD INDEX IF NOT EXISTS idx_cantidad_saldo (cantidad_saldo);

SELECT '✓ Columnas agregadas a TblPresupuestoDetalle' as resultado;

-- ============================================================================
-- PASO 4: INICIALIZAR cantidad_original
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 4: Inicializando cantidad_original = cantidad' as paso;

-- Desactivar safe mode temporalmente
SET SQL_SAFE_UPDATES = 0;

UPDATE TblPresupuestoDetalle
SET cantidad_original = cantidad
WHERE cantidad_original IS NULL;

-- Reactivar safe mode
SET SQL_SAFE_UPDATES = 1;

SELECT 'Detalles inicializados' as resultado;

-- ============================================================================
-- PASO 5: CREAR TABLA DE AUDITORÍA CORRECTA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 5: Creando tabla de auditoría correcta' as paso;

CREATE TABLE IF NOT EXISTS TblRequerimientoAuditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de auditoría',
    
    -- Referencias (AHORA INCLUYE id_detalle)
    id_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuesto',
    id_detalle_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuestoDetalle - EL ITEM',
    id_requerimiento INT NOT NULL COMMENT 'FK a TblRequerimiento',
    
    -- Valores de control
    cantidad_requerida INT NOT NULL COMMENT 'Cantidad solicitada en el requerimiento',
    cantidad_anterior_consumida INT COMMENT 'Consumo del item ANTES',
    cantidad_nueva_consumida INT COMMENT 'Consumo del item DESPUÉS',
    saldo_anterior INT COMMENT 'Saldo del item ANTES',
    saldo_nuevo INT COMMENT 'Saldo del item DESPUÉS',
    
    -- Metadata
    accion VARCHAR(20) NOT NULL COMMENT 'CREAR, ACTUALIZAR, CANCELAR',
    num_usuario INT COMMENT 'Usuario que realizó la acción',
    observaciones LONGTEXT COMMENT 'Notas adicionales',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Cuándo ocurrió',
    
    -- Constraints
    CONSTRAINT fk_auditoria_presupuesto 
        FOREIGN KEY (id_presupuesto) 
        REFERENCES TblPresupuesto(id_presupuesto) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_detalle 
        FOREIGN KEY (id_detalle_presupuesto) 
        REFERENCES TblPresupuestoDetalle(id_detalle) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_requerimiento 
        FOREIGN KEY (id_requerimiento) 
        REFERENCES TblRequerimiento(id_requerimiento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_detalle (id_detalle_presupuesto),
    INDEX idx_id_requerimiento (id_requerimiento),
    INDEX idx_accion (accion),
    INDEX idx_fecha_registro (fecha_registro)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Auditoría de cambios en items de presupuesto';

SELECT '✓ Tabla de auditoría creada' as resultado;

-- ============================================================================
-- PASO 6: CREAR VISTA DE AUDITORÍA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 6: Creando vista de auditoría' as paso;

CREATE VIEW vw_requerimiento_auditoria AS
SELECT 
    a.id_auditoria,
    a.fecha_registro,
    a.accion,
    p.numero_presupuesto,
    a.id_presupuesto,
    pd.descripcion as item_descripcion,
    a.id_detalle_presupuesto,
    r.codigo as requerimiento_codigo,
    a.id_requerimiento,
    a.cantidad_requerida,
    a.cantidad_anterior_consumida,
    a.cantidad_nueva_consumida,
    a.saldo_anterior,
    a.saldo_nuevo,
    a.num_usuario
FROM TblRequerimientoAuditoria a
LEFT JOIN TblPresupuesto p ON a.id_presupuesto = p.id_presupuesto
LEFT JOIN TblPresupuestoDetalle pd ON a.id_detalle_presupuesto = pd.id_detalle
LEFT JOIN TblRequerimiento r ON a.id_requerimiento = r.id_requerimiento;

SELECT '✓ Vista creada' as resultado;

-- ============================================================================
-- PASO 7: VERIFICACIÓN
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 7: Verificación final' as paso;

SELECT 'Estructura TblPresupuesto:' as verificacion1;
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%';

SELECT '' as linea;
SELECT 'Estructura TblPresupuestoDetalle:' as verificacion2;
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuestoDetalle'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%'
ORDER BY ORDINAL_POSITION;

SELECT '' as linea;
SELECT 'Tabla TblRequerimientoAuditoria existe:' as verificacion3;
SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TblRequerimientoAuditoria' AND TABLE_SCHEMA = DATABASE()),
    '✓ SÍ',
    '✗ NO'
) as resultado;

-- ============================================================================
-- PASO 8: RESUMEN
-- ============================================================================
SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ LIMPIEZA Y RECONSTRUCCIÓN COMPLETA             ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS REALIZADOS:' as resumen;
SELECT '  1. ✓ Eliminadas columnas incorrectas de TblPresupuesto' as cambio1;
SELECT '  2. ✓ Eliminada tabla de auditoría incompleta' as cambio2;
SELECT '  3. ✓ Agregadas columnas a TblPresupuestoDetalle:' as cambio3;
SELECT '     - cantidad_original' as cambio3a;
SELECT '     - cantidad_consumida' as cambio3b;
SELECT '     - cantidad_saldo (generada)' as cambio3c;
SELECT '  4. ✓ Recreada tabla TblRequerimientoAuditoria CORRECTA' as cambio4;
SELECT '     - Incluye FK a TblPresupuestoDetalle' as cambio4a;
SELECT '  5. ✓ Creada vista vw_requerimiento_auditoria' as cambio5;
SELECT '';
SELECT 'AHORA:' as siguiente;
SELECT '  • Saldo controlado por ITEM (id_detalle)' as ahora1;
SELECT '  • Múltiples requerimientos pueden usar el mismo item' as ahora2;
SELECT '  • Auditoría registra cambios por item' as ahora3;
SELECT '  • Arquitectura correcta ✓' as ahora4;
