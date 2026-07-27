-- ============================================================================
-- CREATE TABLE: TblSubMenu
-- DESCRIPCIÓN: Tabla de submenús, relacionada con TblMenu
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Crear tabla TblSubMenu
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
    
    -- Índices
    INDEX idx_id_menu (id_menu),
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado),
    INDEX idx_orden (orden),
    
    -- Foreign Key
    CONSTRAINT fk_tblsubmenu_tblmenu FOREIGN KEY (id_menu)
        REFERENCES TblMenu(id_menu)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de submenús del sistema';

-- ============================================================================
-- INSERTAR DATOS DE EJEMPLO
-- ============================================================================

-- Submenús de RR.HH (id_menu = 1)
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(1, 'Usuario', '/usuarios', 'fa-user', 1, 'ACTIVO'),
(1, 'Marcación', '/marcacion', 'fa-clock', 2, 'ACTIVO'),
(1, 'Reportes', '/reportes', 'fa-file-alt', 3, 'ACTIVO');

-- Submenús de Logística (id_menu = 2)
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(2, 'Requerimiento', '/requerimiento', 'fa-clipboard-list', 1, 'ACTIVO'),
(2, 'Órdenes de Compra', '/ordenes-compra', 'fa-shopping-cart', 2, 'ACTIVO');

-- Submenús de Almacén (id_menu = 3)
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(3, 'Inventario', '/inventario', 'fa-boxes', 1, 'ACTIVO');

-- Submenús de Configuración (id_menu = 4)
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado) VALUES
(4, 'Empresa', '/empresa', 'fa-building', 1, 'ACTIVO'),
(4, 'Rol y Accesos', '/roles', 'fa-shield-alt', 2, 'ACTIVO');

-- ============================================================================
-- DESCRIPCIÓN DE CAMPOS
-- ============================================================================

/*
id_submenu (INT, PK, AUTO_INCREMENT):
  - ID único de cada submenú
  - Se incrementa automáticamente

id_menu (INT, FK, NOT NULL):
  - Referencia a TblMenu.id_menu
  - Identifica a qué menú pertenece este submenú
  - Tiene restricción CASCADE (si se borra menú, se borran submenús)

nombre (VARCHAR(100), NOT NULL):
  - Nombre del submenú
  - Ejemplos: Usuario, Marcación, Reportes, Empresa, Rol y Accesos

ruta (VARCHAR(200), NULL):
  - Ruta o URL del submenú
  - Ejemplos: /usuarios, /marcacion, /empresa, /roles

icono (VARCHAR(50), NULL):
  - Nombre del icono Font Awesome
  - Ejemplos: fa-user, fa-clock, fa-building, fa-shield-alt

orden (INT, DEFAULT 0):
  - Número de orden para visualización dentro de su menú
  - Menor número = más arriba

estado (VARCHAR(20), DEFAULT 'ACTIVO'):
  - ACTIVO: Submenú visible
  - INACTIVO: Submenú oculto

fecha_creacion (TIMESTAMP):
  - Se registra automáticamente

fecha_actualizacion (TIMESTAMP):
  - Se actualiza automáticamente

FOREIGN KEY:
  - fk_tblsubmenu_tblmenu: Relación con TblMenu
  - ON DELETE CASCADE: Si se borra un menú, se borran sus submenús
  - ON UPDATE CASCADE: Si cambia id_menu en TblMenu, se actualiza en TblSubMenu
*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
