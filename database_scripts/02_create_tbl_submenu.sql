USE kallgwkn_kallpa_bd;

CREATE TABLE IF NOT EXISTS TblSubMenu (
    id_submenu INT PRIMARY KEY AUTO_INCREMENT,
    id_menu INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    ruta VARCHAR(200) NULL,
    icono VARCHAR(50) NULL,
    orden INT DEFAULT 0,
    estado VARCHAR(20) DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_id_menu (id_menu),
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden),
    CONSTRAINT fk_tblsubmenu_tblmenu FOREIGN KEY (id_menu)
        REFERENCES TblMenu(id_menu)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(1, 'Usuario', '/usuarios', 'fa-user', 1, 'ACTIVO'),
(1, 'Marcación', '/marcacion', 'fa-clock', 2, 'ACTIVO'),
(1, 'Reportes', '/reportes', 'fa-file-alt', 3, 'ACTIVO'),
(2, 'Requerimiento', '/requerimiento', 'fa-clipboard-list', 1, 'ACTIVO'),
(2, 'Órdenes de Compra', '/ordenes-compra', 'fa-shopping-cart', 2, 'ACTIVO'),
(3, 'Inventario', '/inventario', 'fa-boxes', 1, 'ACTIVO'),
(4, 'Empresa', '/empresa', 'fa-building', 1, 'ACTIVO'),
(4, 'Rol y Accesos', '/roles', 'fa-shield-alt', 2, 'ACTIVO');
