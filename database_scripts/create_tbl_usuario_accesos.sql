-- ============================================================================
-- CREATE TABLE: TblUsuarioAccesos
-- DESCRIPCIÓN: Tabla de relación entre usuarios y sus accesos a menús/submenús
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Crear tabla TblUsuarioAccesos
CREATE TABLE IF NOT EXISTS TblUsuarioAccesos (
    id_usuario_acceso INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del acceso de usuario',
    num_documento INT NOT NULL COMMENT 'FK a TblUsuario.num_documento',
    id_menu INT NOT NULL COMMENT 'FK a TblMenu.id_menu',
    id_submenu INT NULL COMMENT 'FK a TblSubMenu.id_submenu (NULL si es acceso solo a menú)',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del acceso (ACTIVO, INACTIVO)',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Índices
    INDEX idx_num_documento (num_documento),
    INDEX idx_id_menu (id_menu),
    INDEX idx_id_submenu (id_submenu),
    INDEX idx_estado (estado),
    
    -- Índice único: Un usuario no puede tener dos veces el mismo acceso
    UNIQUE INDEX unique_usuario_menu_submenu (num_documento, id_menu, id_submenu),
    
    -- Foreign Keys
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
-- DESCRIPCIÓN DE CAMPOS
-- ============================================================================

/*
id_usuario_acceso (INT, PK, AUTO_INCREMENT):
  - ID único de cada acceso
  - Se incrementa automáticamente

num_documento (INT, FK, NOT NULL):
  - Referencia a TblUsuario.num_documento
  - Identifica al usuario
  - Tiene restricción CASCADE

id_menu (INT, FK, NOT NULL):
  - Referencia a TblMenu.id_menu
  - Menú al que el usuario tiene acceso
  - Tiene restricción CASCADE

id_submenu (INT, FK, NULL):
  - Referencia a TblSubMenu.id_submenu
  - Submenú específico al que el usuario tiene acceso
  - NULL si es acceso solo al menú (acceso general)
  - Tiene restricción CASCADE

estado (VARCHAR(20), DEFAULT 'ACTIVO'):
  - ACTIVO: El acceso está vigente
  - INACTIVO: El acceso fue revocado

fecha_creacion (TIMESTAMP):
  - Se registra automáticamente

fecha_actualizacion (TIMESTAMP):
  - Se actualiza automáticamente

UNIQUE INDEX:
  - unique_usuario_menu_submenu: Evita duplicados
  - Un usuario no puede tener dos veces el mismo acceso (mismo menu/submenu)

FOREIGN KEYS:
  - fk_tblusuarioacc_tblusuario: Relación con TblUsuario
  - fk_tblusuarioacc_tblmenu: Relación con TblMenu
  - fk_tblusuarioacc_tblsubmenu: Relación con TblSubMenu
  - Todas con ON DELETE CASCADE

NOTAS IMPORTANTES:
  - Si id_submenu es NULL: El usuario tiene acceso al menú completo
  - Si id_submenu no es NULL: El usuario tiene acceso solo a ese submenú específico
  - Si se borra un usuario, se eliminan automáticamente sus accesos
  - Si se borra un menú o submenú, se eliminan automáticamente los accesos asociados
*/

-- ============================================================================
-- EJEMPLO: Insertar accesos de ejemplo
-- ============================================================================

/*
-- Usuario administrador (documento 12345678) tiene acceso a todo
INSERT INTO TblUsuarioAccesos (num_documento, id_menu, id_submenu, estado) VALUES
(12345678, 1, NULL, 'ACTIVO'),  -- Acceso a todo el menú RR.HH
(12345678, 2, NULL, 'ACTIVO'),  -- Acceso a todo el menú Logística
(12345678, 3, NULL, 'ACTIVO'),  -- Acceso a todo el menú Almacén
(12345678, 4, NULL, 'ACTIVO');  -- Acceso a todo el menú Configuración

-- Usuario normal (documento 87654321) tiene acceso limitado
INSERT INTO TblUsuarioAccesos (num_documento, id_menu, id_submenu, estado) VALUES
(87654321, 1, 1, 'ACTIVO'),    -- Acceso solo a Usuario (RR.HH)
(87654321, 1, 2, 'ACTIVO');    -- Acceso solo a Marcación (RR.HH)
*/

-- ============================================================================
-- VERIFICACIÓN: Consultar accesos de un usuario
-- ============================================================================

/*
-- Ver todos los accesos de un usuario con detalles
SELECT 
    ua.id_usuario_acceso,
    ua.num_documento,
    m.nombre as menu_nombre,
    sm.nombre as submenu_nombre,
    ua.estado,
    ua.fecha_creacion
FROM TblUsuarioAccesos ua
JOIN TblMenu m ON ua.id_menu = m.id_menu
LEFT JOIN TblSubMenu sm ON ua.id_submenu = sm.id_submenu
WHERE ua.num_documento = 12345678
ORDER BY m.orden, sm.orden;
*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
