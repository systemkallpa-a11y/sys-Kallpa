-- ============================================================================
-- TABLA: TblAuditoriaTriggers
-- PROPÓSITO: Registrar cada disparo del trigger tr_ActualizarPresupuestoEstado
-- FECHA: 22 de Julio de 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblAuditoriaTriggers (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro',
    nombre_trigger VARCHAR(100) NOT NULL COMMENT 'Nombre del trigger',
    tabla_afectada VARCHAR(100) NOT NULL COMMENT 'Tabla que dispara el trigger',
    id_presupuesto INT NOT NULL COMMENT 'ID del presupuesto afectado',
    numero_presupuesto VARCHAR(50) COMMENT 'Número del presupuesto',
    accion_trigger VARCHAR(255) NOT NULL COMMENT 'Descripción de la acción (ej: Cambio a APROBADO)',
    estado_anterior VARCHAR(50) COMMENT 'Estado anterior del presupuesto',
    estado_nuevo VARCHAR(50) NOT NULL COMMENT 'Nuevo estado del presupuesto',
    pasos_aprobados INT COMMENT 'Cantidad de pasos aprobados',
    pasos_totales INT COMMENT 'Cantidad total de pasos requeridos',
    fecha_disparo DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha/hora del disparo',
    
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_nombre_trigger (nombre_trigger),
    INDEX idx_fecha_disparo (fecha_disparo),
    INDEX idx_estado_nuevo (estado_nuevo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Auditoría de disparos de triggers';

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
