USE kallgwkn_kallpa_bd;

CREATE TABLE IF NOT EXISTS TblMenu (
    id_menu INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    icono VARCHAR(50) NULL,
    orden INT DEFAULT 0,
    estado VARCHAR(20) DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO TblMenu (nombre, icono, orden, estado) VALUES
('RR.HH', 'fa-users', 1, 'ACTIVO'),
('Logística', 'fa-boxes', 2, 'ACTIVO'),
('Almacén', 'fa-warehouse', 3, 'ACTIVO'),
('Configuración', 'fa-cog', 4, 'ACTIVO');
