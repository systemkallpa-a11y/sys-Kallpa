-- ============================================================================
-- Script de Alteración: TblPresupuestoDetalle
-- Propósito: Agregar soporte para Servicios además de Materiales
-- Fecha: 10 Julio 2026
-- Cambios:
--   1. Hacer id_material NULLABLE (para permitir servicios sin material asociado)
--   2. Agregar campo 'tipo_item' para diferenciar MATERIAL vs SERVICIO
--   3. Agregar campo 'descripcion' para servicios sin tabla asociada
-- ============================================================================

-- Paso 1: Modificar id_material para que sea NULLABLE
ALTER TABLE TblPresupuestoDetalle 
MODIFY COLUMN id_material INT NULL;

-- Paso 2: Agregar campo tipo_item
ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN tipo_item ENUM('MATERIAL', 'SERVICIO') NOT NULL DEFAULT 'MATERIAL' 
AFTER id_material;

-- Paso 3: Agregar campo descripcion para servicios
ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN descripcion VARCHAR(500) NULL 
AFTER tipo_item;

-- Paso 4: Ajustar la Foreign Key de id_material para permitir NULL
-- Primero, eliminar la FK existente
ALTER TABLE TblPresupuestoDetalle 
DROP FOREIGN KEY TblPresupuestoDetalle_ibfk_2;

-- Luego, crear la FK nuevamente (ahora permitirá NULL)
ALTER TABLE TblPresupuestoDetalle 
ADD CONSTRAINT fk_presupuesto_material 
FOREIGN KEY (id_material) REFERENCES TblMateriales(id_material) 
ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Alteración completada exitosamente ✓' as resultado;

SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    COLUMN_DEFAULT,
    COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuestoDetalle' 
AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- ESTRUCTURA NUEVA
-- ============================================================================
--
-- TblPresupuestoDetalle (ACTUALIZADA):
--   id_detalle (PK)
--   id_presupuesto (FK) → TblPresupuesto
--   id_material (FK, NULLABLE) → TblMateriales (NULL para servicios)
--   tipo_item (ENUM) - 'MATERIAL' o 'SERVICIO'
--   descripcion (VARCHAR) - Para servicios que no tienen tabla asociada
--   cantidad (DECIMAL) - Cantidad (mismo para material y servicio)
--   precio_unitario (DECIMAL) - Precio por unidad
--   subtotal (GENERATED) - Calculado automáticamente
--   observaciones (LONGTEXT) - Notas del item
--   fecha_creacion (DATETIME)
--   fecha_actualizacion (DATETIME)
--
-- EJEMPLOS DE USO:
--
-- 1. MATERIAL (con id_material):
--    id_detalle: 1
--    id_presupuesto: 1
--    id_material: 5 (Cemento Portland)
--    tipo_item: 'MATERIAL'
--    descripcion: NULL
--    cantidad: 10
--    precio_unitario: 25.00
--    subtotal: 250.00
--
-- 2. SERVICIO (sin id_material):
--    id_detalle: 2
--    id_presupuesto: 1
--    id_material: NULL
--    tipo_item: 'SERVICIO'
--    descripcion: 'Mano de obra - Excavación y compactación'
--    cantidad: 1
--    precio_unitario: 500.00
--    subtotal: 500.00
--
-- 3. SERVICIO CON CANTIDAD:
--    id_detalle: 3
--    id_presupuesto: 1
--    id_material: NULL
--    tipo_item: 'SERVICIO'
--    descripcion: 'Transporte de materiales'
--    cantidad: 5 (5 viajes)
--    precio_unitario: 100.00
--    subtotal: 500.00
--
-- ============================================================================

