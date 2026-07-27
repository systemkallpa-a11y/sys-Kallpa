-- ============================================================================
-- Tabla: TblUnidadMedida
-- Propósito: Almacenar unidades de medida disponibles
-- Fecha: 10 Julio 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblUnidadMedida (
    id_unidad INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la unidad de medida',
    codigo VARCHAR(20) NOT NULL UNIQUE COMMENT 'Código de la unidad (UND, KG, LT, MTS, etc)',
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo de la unidad',
    abreviatura VARCHAR(10) NOT NULL COMMENT 'Abreviatura (kg, lt, m, etc)',
    descripcion VARCHAR(255) COMMENT 'Descripción de la unidad',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_codigo (codigo),
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de unidades de medida';

-- ============================================================================
-- INSERTAR UNIDADES DE MEDIDA
-- ============================================================================

INSERT INTO TblUnidadMedida (codigo, nombre, abreviatura, descripcion, estado)
VALUES 
('UND', 'Unidad', 'und', 'Unidad individual', 'ACTIVO'),
('KG', 'Kilogramo', 'kg', 'Peso en kilogramos', 'ACTIVO'),
('GR', 'Gramo', 'gr', 'Peso en gramos', 'ACTIVO'),
('LT', 'Litro', 'lt', 'Volumen en litros', 'ACTIVO'),
('ML', 'Mililitro', 'ml', 'Volumen en mililitros', 'ACTIVO'),
('M', 'Metro', 'm', 'Longitud en metros', 'ACTIVO'),
('CM', 'Centímetro', 'cm', 'Longitud en centímetros', 'ACTIVO'),
('M2', 'Metro Cuadrado', 'm²', 'Área en metros cuadrados', 'ACTIVO'),
('M3', 'Metro Cúbico', 'm³', 'Volumen en metros cúbicos', 'ACTIVO'),
('CAJA', 'Caja', 'caja', 'Cantidad por caja', 'ACTIVO'),
('PAQUETE', 'Paquete', 'paq', 'Cantidad por paquete', 'ACTIVO'),
('ROLLO', 'Rollo', 'rollo', 'Cantidad por rollo', 'ACTIVO'),
('BOLSA', 'Bolsa', 'bolsa', 'Cantidad por bolsa', 'ACTIVO'),
('VARA', 'Vara', 'vara', 'Longitud comercial (vara)', 'ACTIVO'),
('DOCENA', 'Docena', 'doc', 'Cantidad 12 unidades', 'ACTIVO'),
('PARES', 'Pares', 'pares', 'Cantidad en pares', 'ACTIVO'),
('GALÓN', 'Galón', 'gal', 'Volumen en galones', 'ACTIVO'),
('TAZA', 'Taza', 'taza', 'Volumen en tazas', 'ACTIVO'),
('TON', 'Tonelada', 'ton', 'Peso en toneladas', 'ACTIVO'),
('HORA', 'Hora', 'hr', 'Unidad de tiempo', 'ACTIVO');

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblUnidadMedida creada exitosamente' as resultado;
SELECT COUNT(*) as total_unidades FROM TblUnidadMedida;
SELECT id_unidad, codigo, nombre, abreviatura FROM TblUnidadMedida ORDER BY id_unidad;
