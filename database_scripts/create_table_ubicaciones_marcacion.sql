-- ============================================================================
-- SCRIPT: Crear Tabla TblUbicacionMarcacion
-- FECHA: 05 Agosto 2026
-- DESCRIPCIÓN: Tabla para gestionar ubicaciones permitidas para marcación
-- ============================================================================

USE Kallpa;

-- ============================================================================
-- CREAR TABLA SI NO EXISTE
-- ============================================================================

CREATE TABLE IF NOT EXISTS `TblUbicacionMarcacion` (
    `id_ubicacion` INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la ubicación',
    `num_documento` VARCHAR(20) NOT NULL COMMENT 'Documento del usuario asignado',
    `nombre_zona` VARCHAR(200) NOT NULL COMMENT 'Nombre descriptivo de la zona',
    `latitud_centro` DECIMAL(10, 8) NOT NULL COMMENT 'Latitud del centro de la zona',
    `longitud_centro` DECIMAL(11, 8) NOT NULL COMMENT 'Longitud del centro de la zona',
    `radio_metros` INT NOT NULL DEFAULT 100 COMMENT 'Radio permitido en metros',
    `direccion_referencia` VARCHAR(500) COMMENT 'Dirección de referencia',
    `tipo_zona` VARCHAR(50) DEFAULT 'OFICINA' COMMENT 'Tipo: OFICINA, OBRA, PROYECTO, CLIENTE, OTRO',
    `descripcion` TEXT COMMENT 'Descripción adicional',
    `estado` VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'ACTIVO o INACTIVO',
    `creado_por` VARCHAR(20) COMMENT 'Usuario que creó el registro',
    `fecha_creacion` DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    `fecha_actualizacion` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización',
    
    -- Restricciones
    CONSTRAINT `fk_ubicacion_usuario` 
        FOREIGN KEY (num_documento) 
        REFERENCES TblUsuario(num_documento) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    
    -- Índices para optimización
    INDEX `idx_num_documento` (num_documento),
    INDEX `idx_estado` (estado),
    INDEX `idx_tipo_zona` (tipo_zona),
    INDEX `idx_fecha_creacion` (fecha_creacion)
    
) ENGINE=InnoDB 
  DEFAULT CHARSET=utf8mb4 
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Ubicaciones permitidas para marcación de asistencia';


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME,
    TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'Kallpa'
  AND TABLE_NAME = 'TblUbicacionMarcacion';

SELECT '✓ Tabla TblUbicacionMarcacion creada/verificada correctamente' AS mensaje;


-- ============================================================================
-- EJEMPLO DE USO
-- ============================================================================

/*
-- Insertar ubicación de ejemplo
INSERT INTO TblUbicacionMarcacion (
    num_documento,
    nombre_zona,
    latitud_centro,
    longitud_centro,
    radio_metros,
    direccion_referencia,
    tipo_zona,
    descripcion,
    estado,
    creado_por
) VALUES (
    '12345678',
    'Oficina Central',
    -12.0464,
    -77.0428,
    100,
    'Av. Javier Prado 123, San Isidro, Lima',
    'OFICINA',
    'Sede principal de la empresa',
    'ACTIVO',
    '12345678'
);

-- Consultar ubicaciones de un usuario
SELECT * FROM TblUbicacionMarcacion 
WHERE num_documento = '12345678' 
  AND estado = 'ACTIVO';

-- Validar si una coordenada está dentro del radio permitido
SELECT 
    id_ubicacion,
    nombre_zona,
    radio_metros,
    ST_Distance_Sphere(
        POINT(longitud_centro, latitud_centro),
        POINT(-77.0428, -12.0464)
    ) AS distancia_metros
FROM TblUbicacionMarcacion
WHERE num_documento = '12345678'
  AND estado = 'ACTIVO'
HAVING distancia_metros <= radio_metros;
*/
