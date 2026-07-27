-- ============================================================================
-- SETUP: Integración Presupuesto + Materiales
-- Crea tabla TblPresupuestoDetalle que enlaza presupuestos con materiales
-- Fecha: 10 Julio 2026
-- Requisitos previos: TblPresupuesto, TblMateriales
-- ============================================================================

-- ============================================================================
-- VERIFICACIÓN DE REQUISITOS
-- ============================================================================

-- Verificar que TblPresupuesto existe
SELECT 'Verificando TblPresupuesto...' as paso;
SELECT COUNT(*) as presupuestos FROM TblPresupuesto;

-- Verificar que TblMateriales existe
SELECT 'Verificando TblMateriales...' as paso;
SELECT COUNT(*) as materiales FROM TblMateriales;

-- ============================================================================
-- PASO 1: Crear Tabla TblPresupuestoDetalle
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblPresupuestoDetalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del detalle',
    id_presupuesto INT NOT NULL COMMENT 'Foreign Key: Presupuesto',
    id_material INT NOT NULL COMMENT 'Foreign Key: Material',
    cantidad INT NOT NULL DEFAULT 1 COMMENT 'Cantidad del material',
    precio_unitario DECIMAL(10, 2) NOT NULL COMMENT 'Precio unitario al momento del presupuesto',
    subtotal DECIMAL(12, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED COMMENT 'Subtotal (cantidad x precio)',
    descuento_porcentaje DECIMAL(5, 2) DEFAULT 0 COMMENT 'Descuento porcentual',
    descuento_monto DECIMAL(10, 2) GENERATED ALWAYS AS (subtotal * descuento_porcentaje / 100) STORED COMMENT 'Monto de descuento',
    total DECIMAL(12, 2) GENERATED ALWAYS AS (subtotal - descuento_monto) STORED COMMENT 'Total con descuento',
    observaciones LONGTEXT COMMENT 'Observaciones del material en este presupuesto',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO, ELIMINADO',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    FOREIGN KEY (id_presupuesto) REFERENCES TblPresupuesto(id_presupuesto) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_material) REFERENCES TblMateriales(id_material) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_material (id_material),
    INDEX idx_estado (estado),
    UNIQUE KEY uk_presupuesto_material (id_presupuesto, id_material)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Detalles de materiales por presupuesto';

SELECT 'TblPresupuestoDetalle creada ✓' as resultado;

-- ============================================================================
-- PASO 2: Insertar Datos de Ejemplo
-- ============================================================================

-- Obtener IDs de presupuestos y materiales para el ejemplo
-- Asumiendo que existen presupuestos y materiales

-- Ejemplo: Agregar materiales al presupuesto PRES-001
-- (Si existen registros en TblPresupuesto y TblMateriales)

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, descuento_porcentaje, observaciones)
SELECT 
    (SELECT id_presupuesto FROM TblPresupuesto LIMIT 1),
    (SELECT id_material FROM TblMateriales WHERE id_material = 1 LIMIT 1),
    10,
    25.50,
    5,
    'Material de ejemplo para presupuesto'
WHERE EXISTS (SELECT 1 FROM TblPresupuesto LIMIT 1)
  AND EXISTS (SELECT 1 FROM TblMateriales WHERE id_material = 1 LIMIT 1);

SELECT 'Datos de ejemplo insertados (si existen presupuestos y materiales)' as resultado;

-- ============================================================================
-- PASO 3: Verificación de Estructura
-- ============================================================================

SELECT 'Tabla TblPresupuestoDetalle:' as item;
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    EXTRA
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuestoDetalle' AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- PASO 4: Verificar Relaciones (Foreign Keys)
-- ============================================================================

SELECT 'Relaciones (Foreign Keys):' as item;
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuestoDetalle' AND TABLE_SCHEMA = DATABASE();

-- ============================================================================
-- PASO 5: Verificación Final
-- ============================================================================

SELECT '========================================' as verificacion;
SELECT '✅ SETUP PRESUPUESTO + MATERIALES COMPLETADO' as titulo;
SELECT '========================================' as verificacion;

SELECT 'TblPresupuestoDetalle:' as item;
SELECT COUNT(*) as registros FROM TblPresupuestoDetalle;

SELECT 'Estructura de la tabla:' as item;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuestoDetalle' AND TABLE_SCHEMA = DATABASE();

SELECT '========================================' as verificacion;

-- ============================================================================
-- NOTA IMPORTANTE
-- ============================================================================
-- 
-- Campos calculados automáticamente (GENERATED ALWAYS AS ... STORED):
--   • subtotal = cantidad * precio_unitario
--   • descuento_monto = subtotal * descuento_porcentaje / 100
--   • total = subtotal - descuento_monto
--
-- Estos campos se actualizan automáticamente sin necesidad de triggers
-- cuando se modifica cantidad, precio_unitario o descuento_porcentaje
--
-- Foreign Keys:
--   • id_presupuesto → ON DELETE CASCADE (borra detalle al borrar presupuesto)
--   • id_material → ON DELETE RESTRICT (no borra material si está en presupuesto)
--
-- Restricción UNIQUE:
--   • No permite agregar el mismo material dos veces al mismo presupuesto
--   • Evita duplicados
--
-- ============================================================================
