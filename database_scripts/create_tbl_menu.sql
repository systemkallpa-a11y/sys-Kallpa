-- ============================================================================
-- CREATE TABLE: TblMenu
-- DESCRIPCIÓN: Tabla principal de menús del sistema
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Crear tabla TblMenu
CREATE TABLE IF NOT EXISTS TblMenu (
    id_menu INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del menú',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del menú',
    icono VARCHAR(50) NULL COMMENT 'Icono del menú (ej: fa-users, fa-cog)',
    orden INT DEFAULT 0 COMMENT 'Orden de visualización',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del menú (ACTIVO, INACTIVO)',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Índices
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de menús principales del sistema';

-- ============================================================================
-- INSERTAR DATOS DE EJEMPLO
-- ============================================================================

INSERT INTO TblMenu (nombre, icono, orden, estado) VALUES
('RR.HH', 'fa-users', 1, 'ACTIVO'),
('Logística', 'fa-boxes', 2, 'ACTIVO'),
('Almacén', 'fa-warehouse', 3, 'ACTIVO'),
('Configuración', 'fa-cog', 4, 'ACTIVO');

-- ============================================================================
-- DESCRIPCIÓN DE CAMPOS
-- ============================================================================

/*
id_menu (INT, PK, AUTO_INCREMENT):
  - ID único de cada menú
  - Se incrementa automáticamente

nombre (VARCHAR(100), NOT NULL, UNIQUE):
  - Nombre del menú
  - Debe ser único en la tabla
  - Ejemplos: RR.HH, Logística, Almacén, Configuración

icono (VARCHAR(50), NULL):
  - Nombre del icono Font Awesome
  - Ejemplos: fa-users, fa-boxes, fa-warehouse, fa-cog

orden (INT, DEFAULT 0):
  - Número de orden para visualización
  - Menor número = más arriba en el menú

estado (VARCHAR(20), DEFAULT 'ACTIVO'):
  - ACTIVO: Menú visible en el sistema
  - INACTIVO: Menú oculto

fecha_creacion (TIMESTAMP):
  - Se registra automáticamente al crear

fecha_actualizacion (TIMESTAMP):
  - Se actualiza automáticamente al modificar
*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
