-- ============================================================================
-- SETUP: Proyectos y Obras (Simplificado)
-- Crea tablas TblProyecto y TblObra con relación 1:N
-- Fecha: 10 Julio 2026
-- ============================================================================

-- ============================================================================
-- PASO 1: Crear Tabla TblProyecto
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblProyecto (
    id_proyecto INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del proyecto',
    codigo_proyecto VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único (Ej: PRY-001)',
    nombre VARCHAR(200) NOT NULL COMMENT 'Nombre del proyecto',
    descripcion LONGTEXT COMMENT 'Descripción detallada',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Actualización',
    
    INDEX idx_codigo_proyecto (codigo_proyecto),
    INDEX idx_nombre (nombre),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de proyectos';

SELECT 'TblProyecto creada ✓' as resultado;

-- ============================================================================
-- PASO 2: Crear Tabla TblObra
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblObra (
    id_obra INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la obra',
    codigo_obra VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único (Ej: OBR-001)',
    nombre VARCHAR(200) NOT NULL COMMENT 'Nombre de la obra',
    descripcion LONGTEXT COMMENT 'Descripción detallada',
    id_proyecto INT NOT NULL COMMENT 'Foreign Key: Proyecto',
    tipo_obra VARCHAR(100) COMMENT 'Tipo de obra',
    observaciones LONGTEXT COMMENT 'Observaciones',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Actualización',
    
    FOREIGN KEY (id_proyecto) REFERENCES TblProyecto(id_proyecto) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_codigo_obra (codigo_obra),
    INDEX idx_nombre (nombre),
    INDEX idx_id_proyecto (id_proyecto),
    INDEX idx_tipo_obra (tipo_obra),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de obras dentro de proyectos';

SELECT 'TblObra creada ✓' as resultado;

-- ============================================================================
-- PASO 3: Insertar Datos de Ejemplo
-- ============================================================================

INSERT INTO TblProyecto (codigo_proyecto, nombre, descripcion)
VALUES 
('PRY-001', 'Casa Verde', 'Construcción de casa unifamiliar en Lima'),
('PRY-002', 'La Floresta', 'Complejo residencial multifamiliar'),
('PRY-003', 'Oficinas Modernas', 'Edificio comercial de 5 pisos'),
('PRY-004', 'Centro Logístico', 'Almacén y centro de distribución');

SELECT 'Proyectos insertados ✓' as resultado;

INSERT INTO TblObra (codigo_obra, nombre, descripcion, id_proyecto, tipo_obra)
VALUES 
('OBR-001', 'Excavación y Cimientos', 'Excavación del terreno y construcción de cimientos', 1, 'Excavación'),
('OBR-002', 'Estructura y Columnas', 'Estructura de concreto armado y columnas', 1, 'Estructura'),
('OBR-003', 'Muros y Tabiques', 'Levantamiento de muros y tabiques', 1, 'Mampostería'),
('OBR-004', 'Instalaciones Eléctricas', 'Red eléctrica completa de la vivienda', 1, 'Instalaciones'),
('OBR-005', 'Instalaciones Sanitarias', 'Redes de agua, desagüe y gas', 1, 'Instalaciones'),
('OBR-006', 'Demolición', 'Demolición de estructura antigua del terreno', 2, 'Demolición'),
('OBR-007', 'Excavación La Floresta', 'Preparación y movimiento de tierras', 2, 'Excavación'),
('OBR-008', 'Estructura Edificio', 'Estructura de concreto armado', 3, 'Estructura'),
('OBR-009', 'Acabados y Detalles', 'Acabados interiores y detalles finales', 3, 'Acabados'),
('OBR-010', 'Infraestructura Logística', 'Pisos y techos industriales', 4, 'Industrial');

SELECT 'Obras insertadas ✓' as resultado;

-- ============================================================================
-- PASO 4: Verificación Final
-- ============================================================================

SELECT '========================================' as verificacion;
SELECT '✅ SETUP PROYECTO + OBRA COMPLETADO' as titulo;
SELECT '========================================' as verificacion;

SELECT 'TblProyecto:' as item;
SELECT COUNT(*) as registros FROM TblProyecto;

SELECT 'TblObra:' as item;
SELECT COUNT(*) as registros FROM TblObra;

SELECT 'Relaciones (Ejemplo):' as item;
SELECT 
    p.codigo_proyecto,
    p.nombre as proyecto,
    COUNT(o.id_obra) as total_obras
FROM TblProyecto p
LEFT JOIN TblObra o ON p.id_proyecto = o.id_proyecto
GROUP BY p.id_proyecto
ORDER BY p.codigo_proyecto;

SELECT '========================================' as verificacion;

-- ============================================================================
-- ESTRUCTURA DE LAS TABLAS
-- ============================================================================
--
-- TblProyecto (SIMPLE):
--   id_proyecto (PK)
--   codigo_proyecto (UNIQUE)
--   nombre
--   descripcion
--   fecha_creacion
--   fecha_actualizacion
--
-- TblObra (SIMPLE):
--   id_obra (PK)
--   codigo_obra (UNIQUE)
--   nombre
--   descripcion
--   id_proyecto (FK) → TblProyecto
--   tipo_obra
--   observaciones
--   fecha_creacion
--   fecha_actualizacion
--
-- Relación: 1 Proyecto → N Obras
-- Foreign Key: ON DELETE RESTRICT, ON UPDATE CASCADE
--
-- ============================================================================
