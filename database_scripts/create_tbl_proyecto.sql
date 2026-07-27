-- ============================================================================
-- Tabla: TblProyecto
-- Propósito: Almacenar información de proyectos (versión simplificada)
-- Fecha: 10 Julio 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblProyecto (
    id_proyecto INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del proyecto',
    codigo_proyecto VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del proyecto (Ej: PRY-001)',
    nombre VARCHAR(200) NOT NULL COMMENT 'Nombre del proyecto',
    descripcion LONGTEXT COMMENT 'Descripción detallada del proyecto',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_codigo_proyecto (codigo_proyecto),
    INDEX idx_nombre (nombre),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de proyectos';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblProyecto creada exitosamente' as resultado;
SELECT COUNT(*) as total_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblProyecto' AND TABLE_SCHEMA = DATABASE();
