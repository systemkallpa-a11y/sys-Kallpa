-- ============================================================================
-- Tabla: TblOT (Órdenes de Trabajo)
-- Propósito: Almacenar órdenes de trabajo del sistema
-- Fecha: 9 Julio 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblOT (
    id_ot INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la O.T',
    numero_ot VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único de la O.T (Ej: OT-001)',
    descripcion LONGTEXT NOT NULL COMMENT 'Descripción detallada de la O.T',
    proyecto VARCHAR(150) NOT NULL COMMENT 'Nombre del proyecto',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, EN_PROCESO, COMPLETADA, CANCELADA, ELIMINADA',
    monto_presupuestado DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto presupuestado en soles',
    monto_gastado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto gastado en soles',
    obs_presupuesto LONGTEXT COMMENT 'Observaciones sobre el presupuesto',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación de la O.T',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_numero_ot (numero_ot),
    INDEX idx_estado (estado),
    INDEX idx_proyecto (proyecto),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de órdenes de trabajo';

-- ============================================================================
-- Datos de ejemplo (opcional - comentar si no es necesario)
-- ============================================================================

-- INSERT INTO TblOT (numero_ot, descripcion, proyecto, estado, monto_presupuestado, monto_gastado, obs_presupuesto)
-- VALUES 
-- ('OT-001', 'Instalación de sistema eléctrico', 'Casa Verde', 'EN_PROCESO', 15000.00, 8500.00, 'En progreso'),
-- ('OT-002', 'Pintura y acabados', 'La Floresta', 'PENDIENTE', 8000.00, 0.00, 'Pendiente de aprobación'),
-- ('OT-003', 'Reparación de tuberías', 'Villa Los Pinos', 'COMPLETADA', 5000.00, 5000.00, 'Completado exitosamente');
