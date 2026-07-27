-- ============================================================================
-- Tabla: TblCategoriaMaterial
-- Propósito: Almacenar categorías de materiales de construcción
-- Fecha: 10 Julio 2026
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblCategoriaMaterial (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la categoría',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre de la categoría (Ej: Cemento, Acero, etc)',
    descripcion LONGTEXT COMMENT 'Descripción detallada de la categoría',
    icono VARCHAR(50) COMMENT 'Ícono para la UI (Font Awesome class)',
    color VARCHAR(20) COMMENT 'Color hexadecimal para la UI (#FF5733)',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de categorías de materiales de construcción';

-- ============================================================================
-- INSERTAR CATEGORÍAS DE MATERIALES DE CONSTRUCCIÓN
-- ============================================================================

INSERT INTO TblCategoriaMaterial (nombre, descripcion, icono, color, estado)
VALUES 
('Cemento y Concreto', 'Cemento, concreto, mortero y productos relacionados', 'fa-cube', '#8B7355', 'ACTIVO'),
('Acero y Fierro', 'Varillas, tuberías, ángulos y productos de acero', 'fa-bars', '#696969', 'ACTIVO'),
('Agregados', 'Arena, grava, piedra chancada y áridos', 'fa-rocks', '#A9A9A9', 'ACTIVO'),
('Tuberías y Conexiones', 'Tuberías PVC, metal, conexiones y accesorios', 'fa-water', '#4169E1', 'ACTIVO'),
('Madera y Derivados', 'Maderas, tableros, plywood y productos de madera', 'fa-tree', '#8B4513', 'ACTIVO'),
('Vidrio y Espejos', 'Vidrio plano, espejos, vidrio templado', 'fa-image', '#E0FFFF', 'ACTIVO'),
('Pintura y Acabados', 'Pinturas, barnices, masillas, selladores', 'fa-paint-brush', '#FF6347', 'ACTIVO'),
('Herramientas Manuales', 'Herramientas de mano, destornilladores, martillos, etc', 'fa-hammer', '#D2691E', 'ACTIVO'),
('Herramientas Eléctricas', 'Taladros, sierras, amoladoras, equipos eléctricos', 'fa-plug', '#FFD700', 'ACTIVO'),
('Equipos de Seguridad', 'Cascos, guantes, arneses, protección personal', 'fa-shield', '#FF4500', 'ACTIVO'),
('Mallas y Telas', 'Malla de gallinero, geotextil, telas de construcción', 'fa-network-wired', '#808080', 'ACTIVO'),
('Cerámicos y Azulejos', 'Baldosas, azulejos, porcellanato, mosaicos', 'fa-layer-group', '#CD853F', 'ACTIVO'),
('Impermeabilizantes', 'Membranas, impermeabilizantes, selladores', 'fa-droplet', '#87CEEB', 'ACTIVO'),
('Aislamiento Térmico', 'Lanas de vidrio, poliestireno, aislantes', 'fa-thermometer', '#F0F8FF', 'ACTIVO'),
('Cables y Alambres', 'Cables eléctricos, alambres, conductores', 'fa-microchip', '#FFD700', 'ACTIVO'),
('Materiales Eléctricos', 'Interruptores, tomacorrientes, breakers, luminarias', 'fa-lightbulb', '#FFEB3B', 'ACTIVO'),
('Sanitarios', 'Inodoros, lavatorios, duchas, griferías', 'fa-water', '#ADD8E6', 'ACTIVO'),
('Puertas y Ventanas', 'Marcos, puertas, ventanas, herrajes', 'fa-door-closed', '#8B4513', 'ACTIVO'),
('Estructuras Metálicas', 'Columnas, vigas, perfiles, estructuras', 'fa-gopuram', '#778899', 'ACTIVO'),
('Adhesivos y Colas', 'Colas, pegamentos, adhesivos especiales', 'fa-glue', '#A0522D', 'ACTIVO'),
('Yeso y Productos Afines', 'Yeso, bloques, placas de yeso', 'fa-cubes', '#E5E5E5', 'ACTIVO'),
('Escaleras y Andamios', 'Escaleras, escalerillas, andamios metálicos', 'fa-stairs', '#696969', 'ACTIVO'),
('Toldos y Lonas', 'Toldos, lonas, membranas textiles', 'fa-tent', '#4682B4', 'ACTIVO'),
('Decoración', 'Molduras, cornisas, elementos decorativos', 'fa-leaf', '#DC143C', 'ACTIVO'),
('Otros Materiales', 'Materiales varios no clasificados', 'fa-box', '#C0C0C0', 'ACTIVO');

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblCategoriaMaterial creada exitosamente' as resultado;
SELECT COUNT(*) as total_categorias FROM TblCategoriaMaterial;
SELECT id_categoria, nombre, icono FROM TblCategoriaMaterial ORDER BY id_categoria;
