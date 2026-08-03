-- ============================================================================
-- TABLA: TblOrdenCompra
-- DESCRIPCIÓN: Tabla para almacenar órdenes de compra
-- RELACIÓN: TblRequerimiento (1 a N)
-- FECHA: 2026-07-30
-- ============================================================================

DROP TABLE IF EXISTS TblOrdenCompra;

CREATE TABLE TblOrdenCompra (
    id_orden_compra INT AUTO_INCREMENT PRIMARY KEY,
    numero_oc VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único de la orden de compra (OC-YYYYMMDDHHMMSS)',
    id_requerimiento INT NOT NULL COMMENT 'FK a TblRequerimiento',
    num_usuario VARCHAR(20) COMMENT 'Usuario que crea la OC',
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'PENDIENTE, ENVIADA, RECIBIDA, CANCELADA',
    monto_total DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto total de la orden',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_orden_requerimiento FOREIGN KEY (id_requerimiento)
        REFERENCES TblRequerimiento(id_requerimiento) ON DELETE CASCADE,
    
    INDEX idx_numero_oc (numero_oc),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion),
    INDEX idx_id_requerimiento (id_requerimiento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLA: TblOrdenCompraDetalle
-- DESCRIPCIÓN: Detalles de items en cada orden de compra
-- RELACIÓN: TblOrdenCompra (1 a N)
-- FECHA: 2026-07-30
-- ============================================================================

DROP TABLE IF EXISTS TblOrdenCompraDetalle;

CREATE TABLE TblOrdenCompraDetalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_orden_compra INT NOT NULL COMMENT 'FK a TblOrdenCompra',
    id_material INT COMMENT 'FK a TblMateriales (opcional)',
    descripcion VARCHAR(500) NOT NULL COMMENT 'Descripción del item',
    cantidad DECIMAL(10, 2) NOT NULL DEFAULT 1 COMMENT 'Cantidad solicitada',
    precio_unitario DECIMAL(10, 2) NOT NULL DEFAULT 0 COMMENT 'Precio unitario',
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Cantidad * Precio unitario',
    observaciones TEXT COMMENT 'Observaciones del item',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_orden_compra_detalle FOREIGN KEY (id_orden_compra)
        REFERENCES TblOrdenCompra(id_orden_compra) ON DELETE CASCADE,
    
    INDEX idx_id_orden_compra (id_orden_compra),
    INDEX idx_id_material (id_material)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- ÍNDICES ADICIONALES PARA OPTIMIZACIÓN
-- ============================================================================

ALTER TABLE TblOrdenCompra 
ADD INDEX idx_num_usuario (num_usuario),
ADD INDEX idx_estado_fecha (estado, fecha_creacion);

-- ============================================================================
-- COMENTARIOS DE COLUMNAS
-- ============================================================================
/*
TblOrdenCompra:
- id_orden_compra: Identificador único de la orden de compra
- numero_oc: Código único de la orden (formato: OC-20260730104532)
- id_requerimiento: Referencia a la orden de requerimiento
- num_usuario: Usuario que generó la orden
- estado: Estado actual de la OC (PENDIENTE, ENVIADA, RECIBIDA, CANCELADA)
- monto_total: Monto total de la orden
- observaciones: Notas adicionales
- fecha_creacion: Timestamp de creación
- fecha_actualizacion: Timestamp de última actualización

TblOrdenCompraDetalle:
- id_detalle: Identificador único del detalle
- id_orden_compra: FK a TblOrdenCompra
- id_material: Referencia a TblMateriales (puede ser NULL)
- descripcion: Descripción del item a comprar
- cantidad: Cantidad solicitada
- precio_unitario: Precio unitario del item
- subtotal: Resultado de cantidad * precio_unitario
- observaciones: Notas del item
- fecha_creacion: Timestamp de creación
- fecha_actualizacion: Timestamp de última actualización
*/
