-- ============================================================================
-- SCRIPT MAESTRO: Crear todas las tablas de menú y accesos
-- ORDEN DE CREACIÓN:
-- 1. TblMenu (tabla base)
-- 2. TblSubMenu (depende de TblMenu)
-- 3. TblUsuarioAccesos (depende de TblMenu y TblSubMenu)
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Crear TblMenu
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblMenu (
    id_menu INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del menú',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del menú',
    icono VARCHAR(50) NULL COMMENT 'Icono del menú (ej: fa-users, fa-cog)',
    orden INT DEFAULT 0 COMMENT 'Orden de visualización',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del menú (ACTIVO, INACTIVO)',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de menús principales del sistema';

-- ============================================================================
-- PASO 2: Crear TblSubMenu
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblSubMenu (
    id_submenu INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del submenú',
    id_menu INT NOT NULL COMMENT 'FK a TblMenu.id_menu',
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre del submenú',
    ruta VARCHAR(200) NULL COMMENT 'Ruta o URL del submenú',
    icono VARCHAR(50) NULL COMMENT 'Icono del submenú (ej: fa-user, fa-clock)',
    orden INT DEFAULT 0 COMMENT 'Orden de visualización dentro del menú',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del submenú (ACTIVO, INACTIVO)',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    INDEX idx_id_menu (id_menu),
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden),
    
    CONSTRAINT fk_tblsubmenu_tblmenu FOREIGN KEY (id_menu)
        REFERENCES TblMenu(id_menu)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de submenús del sistema';

-- ============================================================================
-- PASO 3: Crear TblUsuarioAccesos
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblUsuarioAccesos (
    id_usuario_acceso INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del acceso de usuario',
    num_documento INT NOT NULL COMMENT 'FK a TblUsuario.num_documento',
    id_menu INT NOT NULL COMMENT 'FK a TblMenu.id_menu',
    id_submenu INT NULL COMMENT 'FK a TblSubMenu.id_submenu (NULL si es acceso solo a menú)',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del acceso (ACTIVO, INACTIVO)',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    INDEX idx_num_documento (num_documento),
    INDEX idx_id_menu (id_menu),
    INDEX idx_id_submenu (id_submenu),
    INDEX idx_estado (estado),
    
    UNIQUE INDEX unique_usuario_menu_submenu (num_documento, id_menu, id_submenu),
    
    CONSTRAINT fk_tblusuarioacc_tblusuario FOREIGN KEY (num_documento)
        REFERENCES TblUsuario(num_documento)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_tblusuarioacc_tblmenu FOREIGN KEY (id_menu)
        REFERENCES TblMenu(id_menu)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    
    CONSTRAINT fk_tblusuarioacc_tblsubmenu FOREIGN KEY (id_submenu)
        REFERENCES TblSubMenu(id_submenu)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de accesos de usuarios a menús y submenús';

-- ============================================================================
-- PASO 4: Insertar datos iniciales en TblMenu
-- ============================================================================

INSERT IGNORE INTO TblMenu (nombre, icono, orden, estado) VALUES
('RR.HH', 'fa-users', 1, 'ACTIVO'),
('Logística', 'fa-boxes', 2, 'ACTIVO'),
('Almacén', 'fa-warehouse', 3, 'ACTIVO'),
('Configuración', 'fa-cog', 4, 'ACTIVO');

-- ============================================================================
-- PASO 5: Insertar datos iniciales en TblSubMenu
-- ============================================================================

-- Submenús de RR.HH (id_menu = 1)
INSERT IGNORE INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(1, 'Usuario', '/usuarios', 'fa-user', 1, 'ACTIVO'),
(1, 'Marcación', '/marcacion', 'fa-clock', 2, 'ACTIVO'),
(1, 'Reportes', '/reportes', 'fa-file-alt', 3, 'ACTIVO');

-- Submenús de Logística (id_menu = 2)
INSERT IGNORE INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(2, 'Requerimiento', '/requerimiento', 'fa-clipboard-list', 1, 'ACTIVO'),
(2, 'Órdenes de Compra', '/ordenes-compra', 'fa-shopping-cart', 2, 'ACTIVO');

-- Submenús de Almacén (id_menu = 3)
INSERT IGNORE INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(3, 'Inventario', '/inventario', 'fa-boxes', 1, 'ACTIVO');

-- Submenús de Configuración (id_menu = 4)
INSERT IGNORE INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(4, 'Empresa', '/empresa', 'fa-building', 1, 'ACTIVO'),
(4, 'Rol y Accesos', '/roles', 'fa-shield-alt', 2, 'ACTIVO');

-- ============================================================================
-- VERIFICACIÓN: Consultar estructura creada
-- ============================================================================

SELECT 'TblMenu creada correctamente' as estado;
SELECT COUNT(*) as total_menus FROM TblMenu;

SELECT 'TblSubMenu creada correctamente' as estado;
SELECT COUNT(*) as total_submenus FROM TblSubMenu;

SELECT 'TblUsuarioAccesos creada correctamente' as estado;
SELECT COUNT(*) as total_accesos FROM TblUsuarioAccesos;

-- ============================================================================
-- Mostrar estructura de menús y submenús
-- ============================================================================

SELECT 
    m.id_menu,
    m.nombre as menu,
    m.icono,
    COUNT(sm.id_submenu) as total_submenus
FROM TblMenu m
LEFT JOIN TblSubMenu sm ON m.id_menu = sm.id_menu
GROUP BY m.id_menu, m.nombre, m.icono
ORDER BY m.orden;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
