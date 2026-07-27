-- ============================================================================
-- Tabla: TblPresupuesto
-- Propósito: Almacenar presupuestos del sistema enlazados con obras, materiales y usuarios
-- Fecha: 10 Julio 2026
-- Requisitos: TblObra, TblProyecto, TblMateriales, TblUsuario
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblPresupuesto (
    id_presupuesto INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del presupuesto',
    numero_presupuesto VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único del presupuesto (Ej: PRES-001)',
    id_obra INT NOT NULL COMMENT 'Foreign Key: Obra asociada al presupuesto',
    id_material INT NOT NULL COMMENT 'Foreign Key: Material del presupuesto',
    num_documento INT NOT NULL COMMENT 'Foreign Key: Usuario que crea/encargado del presupuesto',
    monto_total DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto total del presupuesto',
    monto_aprobado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto aprobado por cliente',
    gastos_generales DECIMAL(12, 2) DEFAULT 0 COMMENT 'Gastos generales del presupuesto',
    utilidad DECIMAL(12, 2) DEFAULT 0 COMMENT 'Utilidad/Margen de ganancia',
    igv DECIMAL(12, 2) DEFAULT 0 COMMENT 'IGV (Impuesto General a las Ventas)',
    supervision_obra DECIMAL(12, 2) DEFAULT 0 COMMENT 'Costo de supervisión de obra',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, APROBADO, RECHAZADO, EJECUTANDO, COMPLETADO, CANCELADO, ELIMINADO',
    moneda VARCHAR(10) DEFAULT 'SOL' COMMENT 'Moneda: SOL, USD, EUR, etc',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    FOREIGN KEY (id_obra) REFERENCES TblObra(id_obra) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_material) REFERENCES TblMateriales(id_material) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (num_documento) REFERENCES TblUsuario(num_documento) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_numero_presupuesto (numero_presupuesto),
    INDEX idx_id_obra (id_obra),
    INDEX idx_id_material (id_material),
    INDEX idx_num_documento (num_documento),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de presupuestos enlazados con obras, materiales y usuarios';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblPresupuesto creada exitosamente ✓' as resultado;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuesto' AND TABLE_SCHEMA = DATABASE();

-- ============================================================================
-- ESTRUCTURA DE LA TABLA
-- ============================================================================
--
-- TblPresupuesto (ACTUAL - SIMPLIFICADA):
--   id_presupuesto (PK)
--   numero_presupuesto (UNIQUE)
--   id_obra (FK) → TblObra
--   id_material (FK) → TblMateriales
--   cliente (VARCHAR) - REQUERIDO
--   monto_total (DECIMAL) - REQUERIDO
--   monto_aprobado (DECIMAL)
--   estado (VARCHAR) - PENDIENTE, APROBADO, RECHAZADO, EJECUTANDO, COMPLETADO, CANCELADO, ELIMINADO
--   moneda (VARCHAR) - SOL, USD, EUR, etc
--   telefono_cliente (VARCHAR)
--   observaciones (LONGTEXT)
--   fecha_creacion (DATETIME) - AUTO
--   fecha_actualizacion (DATETIME) - AUTO
--
-- Relaciones:
--   TblPresupuesto → TblObra (N:1)
--     ON DELETE RESTRICT (no permite eliminar obra si tiene presupuestos)
--     ON UPDATE CASCADE (actualiza id_obra si cambia)
--
--   TblPresupuesto → TblMateriales (N:1)
--     ON DELETE RESTRICT (no permite eliminar material si está en presupuesto)
--     ON UPDATE CASCADE (actualiza id_material si cambia)
--
-- CAMPOS ELIMINADOS:
--   - descripcion (LONGTEXT) - Ahora en TblPresupuestoDetalle si necesario
--   - fecha_vencimiento (DATE) - Simplificación
--   - contacto (VARCHAR) - Simplificación
--   - email_cliente (VARCHAR) - Simplificación
--
-- CAMPOS NUEVOS:
--   - id_material (FK) - Enlaza con materiales del presupuesto
--
-- ============================================================================

