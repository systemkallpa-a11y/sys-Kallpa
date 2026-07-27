-- ============================================================================
-- Tabla: TblRequerimiento
-- Propósito: Almacenar requerimientos logísticos del sistema
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblRequerimiento (
    id_requerimiento INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del requerimiento',
    codigo VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del requerimiento (Ej: REQ-001)',
    descripcion LONGTEXT NOT NULL COMMENT 'Descripción detallada del requerimiento',
    cantidad INT NOT NULL COMMENT 'Cantidad solicitada',
    unidad_medida VARCHAR(50) DEFAULT 'UND' COMMENT 'Unidad de medida (UND, KG, LT, MTS, CAJA, PAQUETE)',
    solicitante VARCHAR(150) NOT NULL COMMENT 'Nombre de quien solicita',
    departamento VARCHAR(100) COMMENT 'Departamento que solicita',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, APROBADO, EN_PROCESO, COMPLETADO, CANCELADO, ELIMINADO',
    observaciones LONGTEXT COMMENT 'Observaciones o notas adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación del requerimiento',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_codigo (codigo),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de requerimientos logísticos';

-- ============================================================================
-- Datos de ejemplo (opcional - comentar si no es necesario)
-- ============================================================================

-- INSERT INTO TblRequerimiento (codigo, descripcion, cantidad, unidad_medida, solicitante, departamento, estado, observaciones)
-- VALUES 
-- ('REQ-001', 'Suministros de oficina', 100, 'UND', 'Juan Pérez', 'RR.HH', 'PENDIENTE', 'Tinta azul para bolígrafos'),
-- ('REQ-002', 'Repuestos para equipo', 5, 'UND', 'María García', 'Mantenimiento', 'APROBADO', 'Filtros para compresor');
