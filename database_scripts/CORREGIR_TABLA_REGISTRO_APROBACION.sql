-- ============================================================================
-- SCRIPT: CORREGIR_TABLA_REGISTRO_APROBACION.sql
-- PROPÓSITO: Corregir la tabla TblRegistroAprobacion con FKs correctas
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Eliminar tabla si existe
DROP TABLE IF EXISTS TblRegistroAprobacion;

-- Crear tabla corregida
CREATE TABLE TblRegistroAprobacion (
    id_registro INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro',
    id_tipo_documento INT NOT NULL COMMENT 'FK a TblTipoDocumentoAprobacion',
    id_documento_referencia INT NOT NULL COMMENT 'ID del documento (presupuesto, requerimiento, etc)',
    numero_paso INT NOT NULL COMMENT 'Número de paso completado',
    id_cargo_aprobador INT COMMENT 'FK a TblCargo del aprobador',
    num_documento_aprobador INT COMMENT 'FK a TblPersona del usuario que aprobó',
    estado_aprobacion ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO') DEFAULT 'PENDIENTE' COMMENT 'Estado de la aprobación',
    comentario TEXT COMMENT 'Comentarios del aprobador',
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha cuando se asignó al aprobador',
    fecha_aprobacion TIMESTAMP NULL COMMENT 'Fecha cuando se aprobó/rechazó',
    
    FOREIGN KEY fk_tipo_documento (id_tipo_documento) 
        REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    FOREIGN KEY fk_cargo (id_cargo_aprobador) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    FOREIGN KEY fk_persona (num_documento_aprobador) 
        REFERENCES TblPersona(num_documento) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_tipo_documento (id_tipo_documento),
    INDEX idx_documento_referencia (id_documento_referencia),
    INDEX idx_estado (estado_aprobacion),
    INDEX idx_fecha_aprobacion (fecha_aprobacion),
    INDEX idx_aprobador (num_documento_aprobador)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro de auditoría de todas las aprobaciones realizadas';

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

DESCRIBE TblRegistroAprobacion;

SELECT 'Tabla TblRegistroAprobacion creada correctamente' as Estado;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
