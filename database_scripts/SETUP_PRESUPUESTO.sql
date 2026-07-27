-- ============================================================================
-- SETUP: Crear tabla TblPresupuesto
-- Fecha: 9 Julio 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblPresupuesto (
    id_presupuesto INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del presupuesto',
    numero_presupuesto VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único del presupuesto (Ej: PRES-001)',
    descripcion LONGTEXT NOT NULL COMMENT 'Descripción detallada del presupuesto',
    cliente VARCHAR(150) NOT NULL COMMENT 'Nombre del cliente',
    proyecto VARCHAR(150) COMMENT 'Nombre del proyecto',
    monto_total DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto total del presupuesto',
    monto_aprobado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto aprobado por cliente',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, APROBADO, RECHAZADO, EJECUTANDO, COMPLETADO, CANCELADO, ELIMINADO',
    fecha_vencimiento DATE COMMENT 'Fecha de vencimiento del presupuesto',
    moneda VARCHAR(10) DEFAULT 'SOL' COMMENT 'Moneda (SOL, USD, etc)',
    contacto VARCHAR(150) COMMENT 'Contacto del cliente',
    email_cliente VARCHAR(100) COMMENT 'Email del cliente',
    telefono_cliente VARCHAR(20) COMMENT 'Teléfono del cliente',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_numero_presupuesto (numero_presupuesto),
    INDEX idx_estado (estado),
    INDEX idx_cliente (cliente),
    INDEX idx_proyecto (proyecto),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de presupuestos';

-- ============================================================================
-- Verificación
-- ============================================================================

SELECT '✅ TABLA TBLPRESUPUESTO CREADA' as resultado;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TblPresupuesto';

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
