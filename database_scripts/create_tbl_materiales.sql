-- ============================================================================
-- Tabla: TblMateriales
-- Propósito: Almacenar materiales utilizados en proyectos/O.T
-- Fecha: 10 Julio 2026
-- Requiere: TblCategoriaMaterial, TblUnidadMedida, TblProveedor
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblMateriales (
    id_material INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del material',
    codigo_material VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del material (Ej: MAT-001)',
    nombre VARCHAR(150) NOT NULL COMMENT 'Nombre del material',
    descripcion LONGTEXT COMMENT 'Descripción detallada del material',
    id_categoria INT COMMENT 'Foreign Key: Categoría del material',
    id_unidad INT NOT NULL COMMENT 'Foreign Key: Unidad de medida',
    cantidad_stock INT NOT NULL DEFAULT 0 COMMENT 'Cantidad actual en stock',
    cantidad_minima INT DEFAULT 10 COMMENT 'Cantidad mínima recomendada',
    precio_unitario DECIMAL(10, 2) NOT NULL DEFAULT 0 COMMENT 'Precio unitario del material',
    id_proveedor INT COMMENT 'Foreign Key: Proveedor habitual',
    fecha_ultimo_compra DATE COMMENT 'Fecha de la última compra',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO, DESCONTINUADO, ELIMINADO',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    -- Foreign Keys
    FOREIGN KEY (id_categoria) REFERENCES TblCategoriaMaterial(id_categoria) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (id_unidad) REFERENCES TblUnidadMedida(id_unidad) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_proveedor) REFERENCES TblProveedor(id_proveedor) ON DELETE SET NULL ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_codigo_material (codigo_material),
    INDEX idx_nombre (nombre),
    INDEX idx_id_categoria (id_categoria),
    INDEX idx_id_unidad (id_unidad),
    INDEX idx_id_proveedor (id_proveedor),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de materiales del proyecto';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblMateriales creada exitosamente' as resultado;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblMateriales' AND TABLE_SCHEMA = DATABASE();
