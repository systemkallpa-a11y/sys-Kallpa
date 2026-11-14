-- ============================================================================
-- MÓDULO: ENTREGAS A PERSONAL
-- Base de datos: kallpasystem$kallgwkn_kallpa_bd
-- Crea las tablas de cabecera y detalle para registrar una entrega con
-- varios materiales (carrito) a una persona.
--
-- Ejecutar manualmente en la base de datos de producción.
-- No elimina ni modifica tablas existentes.
-- ============================================================================

SET NAMES utf8mb4;

-- ----------------------------------------------------------------------------
-- CABECERA: una fila por cada entrega aceptada
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `TblEntregaPersonal` (
    `id_entrega` INT NOT NULL AUTO_INCREMENT COMMENT 'Identificador de la entrega',
    `codigo` VARCHAR(30) NOT NULL COMMENT 'Código único (ej. ENT-2026-000001)',
    `num_documento_personal` INT NOT NULL COMMENT 'Persona que recibe (TblPersona.num_documento)',
    `id_almacen` INT NULL COMMENT 'Almacén de origen (TblAlmacen.id_almacen)',
    `fecha_entrega` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora de la entrega',
    `entregado_por` INT NULL COMMENT 'Persona que entrega (TblPersona.num_documento)',
    `documento_referencia` VARCHAR(100) NULL COMMENT 'Documento externo: requerimiento, memo, etc.',
    `observaciones` TEXT NULL COMMENT 'Observaciones de la entrega',
    `estado` ENUM('REGISTRADA','ANULADA','DEVUELTA') NOT NULL DEFAULT 'REGISTRADA' COMMENT 'Estado de la entrega',
    `fecha_creacion` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación del registro',
    `fecha_actualizacion` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización',
    PRIMARY KEY (`id_entrega`),
    UNIQUE KEY `uk_entregapersonal_codigo` (`codigo`),
    KEY `idx_entregapersonal_persona` (`num_documento_personal`),
    KEY `idx_entregapersonal_almacen` (`id_almacen`),
    KEY `idx_entregapersonal_fecha` (`fecha_entrega`),
    KEY `idx_entregapersonal_estado` (`estado`),
    KEY `idx_entregapersonal_entregador` (`entregado_por`),
    CONSTRAINT `fk_entregapersonal_persona` FOREIGN KEY (`num_documento_personal`)
        REFERENCES `TblPersona` (`num_documento`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `fk_entregapersonal_almacen` FOREIGN KEY (`id_almacen`)
        REFERENCES `TblAlmacen` (`id_almacen`)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT `fk_entregapersonal_entregador` FOREIGN KEY (`entregado_por`)
        REFERENCES `TblPersona` (`num_documento`)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Cabecera de entregas de materiales a personal';

-- ----------------------------------------------------------------------------
-- DETALLE: materiales incluidos en cada entrega
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `TblEntregaPersonalDetalle` (
    `id_detalle` INT NOT NULL AUTO_INCREMENT COMMENT 'Identificador del detalle',
    `id_entrega` INT NOT NULL COMMENT 'Entrega a la que pertenece (TblEntregaPersonal.id_entrega)',
    `id_inventario` INT NOT NULL COMMENT 'Material entregado (TblInventario.id_inventario)',
    `cantidad` DECIMAL(10,2) NOT NULL COMMENT 'Cantidad entregada',
    `costo_unitario` DECIMAL(10,2) NULL COMMENT 'Costo unitario al momento de la entrega',
    `costo_total` DECIMAL(12,2) GENERATED ALWAYS AS (`cantidad` * `costo_unitario`) STORED COMMENT 'Costo total del material',
    `observaciones` VARCHAR(255) NULL COMMENT 'Observación del material entregado',
    `fecha_creacion` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación del registro',
    PRIMARY KEY (`id_detalle`),
    UNIQUE KEY `uk_entregadetalle_entrega_inventario` (`id_entrega`, `id_inventario`),
    KEY `idx_entregadetalle_entrega` (`id_entrega`),
    KEY `idx_entregadetalle_inventario` (`id_inventario`),
    CONSTRAINT `fk_entregadetalle_entrega` FOREIGN KEY (`id_entrega`)
        REFERENCES `TblEntregaPersonal` (`id_entrega`)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `fk_entregadetalle_inventario` FOREIGN KEY (`id_inventario`)
        REFERENCES `TblInventario` (`id_inventario`)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT `chk_entregadetalle_cantidad` CHECK (`cantidad` > 0),
    CONSTRAINT `chk_entregadetalle_costo` CHECK (`costo_unitario` IS NULL OR `costo_unitario` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Detalle de materiales de una entrega a personal';

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN
-- ----------------------------------------------------------------------------
SHOW TABLES LIKE 'TblEntregaPersonal%';
