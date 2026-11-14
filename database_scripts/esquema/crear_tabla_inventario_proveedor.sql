-- ============================================================================
-- MÓDULO: INVENTARIO - PROVEEDORES
-- Base de datos: kallpasystem$kallgwkn_kallpa_bd
-- Crea la tabla intermedia para la relación muchos a muchos entre
-- TblInventario (productos) y TblProveedores (proveedores).
--
-- Ejecutar manualmente en la base de datos de producción.
-- No elimina ni modifica tablas existentes.
-- ============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `TblInventarioProveedor` (
    `id_inventario_proveedor` INT NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador de la relación inventario-proveedor',
    `id_inventario` INT NOT NULL
        COMMENT 'Producto (TblInventario.id_inventario)',
    `ruc_proveedor` VARCHAR(11) COLLATE utf8mb4_unicode_ci NOT NULL
        COMMENT 'Proveedor (TblProveedores.ruc)',
    `codigo_proveedor` VARCHAR(50) NULL
        COMMENT 'Código que el proveedor usa para este producto',
    `precio_compra` DECIMAL(10,2) NULL
        COMMENT 'Precio de compra de este proveedor para este producto',
    `moneda` ENUM('SOLES','DOLARES') NOT NULL DEFAULT 'SOLES'
        COMMENT 'Moneda del precio de compra',
    `plazo_entrega_dias` INT NULL
        COMMENT 'Plazo de entrega específico para este producto',
    `es_principal` TINYINT(1) NOT NULL DEFAULT 0
        COMMENT 'Indica si es el proveedor principal del producto',
    `estado` ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO'
        COMMENT 'Estado de la relación producto-proveedor',
    `observaciones` TEXT NULL
        COMMENT 'Observaciones de la relación producto-proveedor',
    `creado_por` VARCHAR(20) NULL
        COMMENT 'DNI del usuario que creó la relación',
    `fecha_creacion` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'Fecha de creación de la relación',
    `actualizado_por` VARCHAR(20) NULL
        COMMENT 'DNI del último usuario que actualizó la relación',
    `fecha_actualizacion` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización de la relación',
    PRIMARY KEY (`id_inventario_proveedor`),
    UNIQUE KEY `uk_inventario_proveedor` (`id_inventario`, `ruc_proveedor`),
    KEY `idx_inventario_proveedor_inventario` (`id_inventario`),
    KEY `idx_inventario_proveedor_ruc` (`ruc_proveedor`),
    KEY `idx_inventario_proveedor_codigo` (`codigo_proveedor`),
    KEY `idx_inventario_proveedor_estado` (`estado`),
    CONSTRAINT `fk_inventario_proveedor_inventario`
        FOREIGN KEY (`id_inventario`) REFERENCES `TblInventario` (`id_inventario`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_inventario_proveedor_proveedor`
        FOREIGN KEY (`ruc_proveedor`) REFERENCES `TblProveedores` (`ruc`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Relación muchos a muchos entre inventario y proveedores';

-- Notas:
-- - Un producto no puede repetir el mismo proveedor (UNIQUE).
-- - Solo debería existir un proveedor principal por producto;
--   esa validación se controla en la aplicación.
-- - Las columnas agregadas son datos de la relación y se pueden
--   modificar o eliminar sin afectar las llaves foráneas.

SHOW TABLES LIKE 'TblInventarioProveedor';
