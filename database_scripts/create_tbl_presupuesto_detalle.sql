-- ============================================================================
-- Tabla: TblPresupuestoDetalle
-- Propósito: Almacenar los items/materiales de cada presupuesto
-- Relación: 1 Presupuesto → N Items de Materiales
-- Fecha: 10 Julio 2026
-- Requiere: TblPresupuesto, TblMateriales
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblPresupuestoDetalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del item',
    id_presupuesto INT NOT NULL COMMENT 'Foreign Key: Presupuesto padre',
    id_material INT NOT NULL COMMENT 'Foreign Key: Material del item',
    cantidad DECIMAL(10, 2) NOT NULL DEFAULT 1 COMMENT 'Cantidad del material',
    precio_unitario DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Precio unitario del material',
    subtotal DECIMAL(12, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED COMMENT 'Subtotal calculado (cantidad × precio)',
    observaciones LONGTEXT COMMENT 'Observaciones del item',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    -- Foreign Keys
    FOREIGN KEY (id_presupuesto) REFERENCES TblPresupuesto(id_presupuesto) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_material) REFERENCES TblMateriales(id_material) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_material (id_material),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de detalles/items de presupuestos';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblPresupuestoDetalle creada exitosamente ✓' as resultado;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuestoDetalle' AND TABLE_SCHEMA = DATABASE();

-- ============================================================================
-- ESTRUCTURA DE LA TABLA
-- ============================================================================
--
-- TblPresupuestoDetalle:
--   id_detalle (PK)
--   id_presupuesto (FK) → TblPresupuesto
--   id_material (FK) → TblMateriales
--   cantidad (DECIMAL) - Cantidad del material
--   precio_unitario (DECIMAL) - Precio por unidad
--   subtotal (GENERATED) - Calculado automáticamente (cantidad × precio)
--   observaciones (LONGTEXT) - Notas del item
--   fecha_creacion (DATETIME)
--   fecha_actualizacion (DATETIME)
--
-- RELACIÓN:
--   1 Presupuesto → N Items de Materiales
--   ON DELETE CASCADE: Si se elimina presupuesto, se eliminan sus items
--   ON UPDATE CASCADE: Si cambia id_presupuesto, se actualiza en items
--
-- EJEMPLO DE USO:
--   Presupuesto PRES-001:
--     └─ Item 1: Cemento Portland, 10 bolsas × S/. 25.00 = S/. 250.00
--     └─ Item 2: Acero Estructural, 5 kg × S/. 100.00 = S/. 500.00
--     └─ Item 3: Arena, 2 m³ × S/. 150.00 = S/. 300.00
--   Total: S/. 1,050.00
--
-- ============================================================================
