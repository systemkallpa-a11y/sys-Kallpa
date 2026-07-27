-- ============================================================================
-- Tabla: TblObra
-- Propósito: Almacenar información de obras/trabajos dentro de un proyecto (simplificada)
-- Fecha: 10 Julio 2026
-- Requiere: TblProyecto
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblObra (
    id_obra INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la obra',
    codigo_obra VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único de la obra (Ej: OBR-001)',
    nombre VARCHAR(200) NOT NULL COMMENT 'Nombre de la obra',
    descripcion LONGTEXT COMMENT 'Descripción detallada de la obra',
    id_proyecto INT NOT NULL COMMENT 'Foreign Key: Proyecto al que pertenece',
    tipo_obra VARCHAR(100) COMMENT 'Tipo de obra (Excavación, Estructura, etc)',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización',
    
    -- Foreign Key
    FOREIGN KEY (id_proyecto) REFERENCES TblProyecto(id_proyecto) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_codigo_obra (codigo_obra),
    INDEX idx_nombre (nombre),
    INDEX idx_id_proyecto (id_proyecto),
    INDEX idx_tipo_obra (tipo_obra),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de obras dentro de proyectos';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblObra creada exitosamente' as resultado;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblObra' AND TABLE_SCHEMA = DATABASE();
