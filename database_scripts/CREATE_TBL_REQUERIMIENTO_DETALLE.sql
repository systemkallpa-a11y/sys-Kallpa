-- ============================================================================
-- TABLA: TblRequerimientoDetalle
-- DESCRIPCIÓN: Detalles de items en cada requerimiento
-- RELACIÓN: TblRequerimiento (1 a N)
-- FECHA: 2026-07-16
-- ============================================================================

DROP TABLE IF EXISTS TblRequerimientoDetalle;

CREATE TABLE TblRequerimientoDetalle (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_requerimiento INT NOT NULL,
    id_material INT NULL COMMENT 'FK a TblMateriales (opcional para servicios)',
    tipo_item VARCHAR(20) NOT NULL DEFAULT 'MATERIAL' COMMENT 'MATERIAL o SERVICIO',
    descripcion VARCHAR(500) NOT NULL,
    cantidad DECIMAL(10, 2) NOT NULL DEFAULT 1,
    unidad_medida VARCHAR(50),
    observaciones TEXT,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_requerimiento_detalle FOREIGN KEY (id_requerimiento) 
        REFERENCES TblRequerimiento(id_requerimiento) ON DELETE CASCADE,
    
    INDEX idx_id_requerimiento (id_requerimiento),
    INDEX idx_id_material (id_material)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DESCRIPCIÓN DE COLUMNAS
-- ============================================================================
/*
- id_detalle: Identificador único del detalle
- id_requerimiento: FK a TblRequerimiento
- id_material: Referencia a TblMateriales (NULLABLE para servicios sin material específico)
- tipo_item: MATERIAL o SERVICIO
- descripcion: Descripción del item requerido
- cantidad: Cantidad solicitada
- unidad_medida: Unidad (UND, KG, M3, etc)
- observaciones: Notas adicionales del item
- fecha_creacion: Timestamp de creación
- fecha_actualizacion: Timestamp de última actualización
*/


