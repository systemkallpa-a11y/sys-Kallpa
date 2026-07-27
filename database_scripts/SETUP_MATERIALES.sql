-- ============================================================================
-- SETUP COMPLETO: GESTIÓN DE MATERIALES
-- Crea todas las tablas necesarias en orden correcto
-- Fecha: 10 Julio 2026
-- Orden: UnidadMedida → CategoriaMaterial → Proveedor → Materiales
-- ============================================================================

-- ============================================================================
-- PASO 1: Crear Tabla TblUnidadMedida (PRIMERO - Sin dependencias)
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

SELECT 'TblUnidadMedida creada ✓' as resultado;

-- ============================================================================
-- PASO 2: Crear Tabla TblCategoriaMaterial (SEGUNDO - Sin dependencias)
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblCategoriaMaterial (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la categoría',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre de la categoría',
    descripcion LONGTEXT COMMENT 'Descripción detallada de la categoría',
    icono VARCHAR(50) COMMENT 'Ícono para la UI (Font Awesome class)',
    color VARCHAR(20) COMMENT 'Color hexadecimal para la UI (#FF5733)',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_nombre (nombre),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de categorías de materiales de construcción';

INSERT INTO TblCategoriaMaterial (nombre, descripcion, icono, color, estado)
VALUES 
('Cemento y Concreto', 'Cemento, concreto, mortero y productos relacionados', 'fa-cube', '#8B7355', 'ACTIVO'),
('Acero y Fierro', 'Varillas, tuberías, ángulos y productos de acero', 'fa-bars', '#696969', 'ACTIVO'),
('Agregados', 'Arena, grava, piedra chancada y áridos', 'fa-rocks', '#A9A9A9', 'ACTIVO'),
('Tuberías y Conexiones', 'Tuberías PVC, metal, conexiones y accesorios', 'fa-water', '#4169E1', 'ACTIVO'),
('Madera y Derivados', 'Maderas, tableros, plywood y productos de madera', 'fa-tree', '#8B4513', 'ACTIVO'),
('Vidrio y Espejos', 'Vidrio plano, espejos, vidrio templado', 'fa-image', '#E0FFFF', 'ACTIVO'),
('Pintura y Acabados', 'Pinturas, barnices, masillas, selladores', 'fa-paint-brush', '#FF6347', 'ACTIVO'),
('Herramientas Manuales', 'Herramientas de mano, destornilladores, martillos', 'fa-hammer', '#D2691E', 'ACTIVO'),
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

SELECT 'TblCategoriaMaterial creada ✓' as resultado;

-- ============================================================================
-- PASO 3: Crear Tabla TblProveedor (TERCERO - Sin dependencias)
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblProveedor (
    id_proveedor INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del proveedor',
    nombre VARCHAR(150) NOT NULL UNIQUE COMMENT 'Nombre del proveedor',
    contacto VARCHAR(150) COMMENT 'Persona de contacto del proveedor',
    email VARCHAR(100) COMMENT 'Email del proveedor',
    telefono VARCHAR(20) COMMENT 'Teléfono del proveedor',
    celular VARCHAR(20) COMMENT 'Celular del proveedor',
    direccion LONGTEXT COMMENT 'Dirección del proveedor',
    ciudad VARCHAR(100) COMMENT 'Ciudad',
    distrito VARCHAR(100) COMMENT 'Distrito',
    ruc VARCHAR(11) COMMENT 'RUC del proveedor',
    razon_social VARCHAR(200) COMMENT 'Razón social',
    web VARCHAR(150) COMMENT 'Sitio web',
    condicion_pago VARCHAR(100) COMMENT 'Condición de pago (Contado, 30 días, etc)',
    descuento DECIMAL(5, 2) DEFAULT 0 COMMENT 'Descuento porcentual habitual',
    calificacion INT COMMENT 'Calificación de 1 a 5',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO, SUSPENDIDO, ELIMINADO',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_nombre (nombre),
    INDEX idx_ruc (ruc),
    INDEX idx_estado (estado),
    INDEX idx_ciudad (ciudad),
    INDEX idx_calificacion (calificacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de proveedores de materiales';

INSERT INTO TblProveedor (nombre, contacto, email, telefono, celular, ciudad, distrito, condicion_pago, descuento, calificacion, estado)
VALUES 
('Distribuidor Construcción S.A.', 'Carlos López', 'contacto@distribconstruccion.com', '01-4456789', '999111222', 'Lima', 'San Isidro', 'Contado', 5, 4, 'ACTIVO'),
('Aceros Nacionales', 'Patricia Rodríguez', 'ventas@acerosnacionales.pe', '01-5678901', '999222333', 'Lima', 'La Victoria', '30 días', 10, 5, 'ACTIVO'),
('Cantera Los Andes', 'Juan Morales', 'contacto@canteralosandes.com', '01-6789012', '999333444', 'Callao', 'Callao', 'Contado', 0, 4, 'ACTIVO'),
('Tuberías del Norte', 'Miguel Torres', 'ventas@tuberiasdelNorte.pe', '01-7890123', '999444555', 'Lima', 'Cercado', '15 días', 8, 4, 'ACTIVO'),
('Maderas Premium', 'Sandra García', 'info@maderaspreArium.pe', '01-8901234', '999555666', 'Lima', 'San Martín', 'Contado', 3, 3, 'ACTIVO'),
('Vidrios y Espejos Perú', 'Roberto Martínez', 'ventas@vidiosyespejos.pe', '01-1234567', '999666777', 'Lima', 'Lince', '30 días', 7, 4, 'ACTIVO'),
('Pinturas y Acabados Total', 'Verónica Salazar', 'contacto@pinturastotal.pe', '01-2345678', '999777888', 'Lima', 'Miraflores', 'Contado', 5, 5, 'ACTIVO'),
('Herramientas Industrial', 'Andrés Vilcapoma', 'ventas@herramientasindustrial.pe', '01-3456789', '999888999', 'Lima', 'Rímac', '15 días', 12, 4, 'ACTIVO'),
('Equipos de Seguridad Plus', 'Diana Castro', 'contacto@equiposseguridadplus.pe', '01-4567890', '999111222', 'Lima', 'Surco', 'Contado', 8, 5, 'ACTIVO'),
('Azulejos y Cerámicos Lima', 'Fernando Noriega', 'ventas@azulejoylima.pe', '01-5678901', '999222333', 'Lima', 'Breña', '30 días', 6, 4, 'ACTIVO'),
('Cables y Conexiones Eléc.', 'Gabriela Flores', 'info@cablesconexiones.pe', '01-6789012', '999333444', 'Lima', 'San Juan', 'Contado', 10, 4, 'ACTIVO'),
('Sanitarios y Grifería Moderna', 'Lucas Mendoza', 'ventas@sanitariosmoderna.pe', '01-7890123', '999444555', 'Lima', 'Comas', '15 días', 9, 4, 'ACTIVO'),
('Estructuras Metálicas Perú', 'Rosario Gutierrez', 'contacto@estructurasmetalicas.pe', '01-8901234', '999555666', 'Callao', 'Ventanilla', 'Contado', 5, 5, 'ACTIVO'),
('Yeso y Productos Afines', 'Javier Ruiz', 'ventas@yesoproductos.pe', '01-1234567', '999666777', 'Lima', 'Lima', '30 días', 4, 3, 'ACTIVO'),
('Puertas y Ventanas Elite', 'Adriana Silva', 'info@puertasventanaselite.pe', '01-2345678', '999777888', 'Lima', 'La Molina', 'Contado', 7, 5, 'ACTIVO');

SELECT 'TblProveedor creada ✓' as resultado;

-- ============================================================================
-- PASO 4: Crear Tabla TblMateriales (CUARTO - Con Foreign Keys)
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblMateriales (
    id_material INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del material',
    codigo_material VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único del material (Ej: MAT-001)',
    nombre VARCHAR(150) NOT NULL COMMENT 'Nombre del material',
    descripcion LONGTEXT COMMENT 'Descripción detallada del material',
    id_categoria INT COMMENT 'Foreign Key: Categoría del material',
    id_unidad INT NOT NULL COMMENT 'Foreign Key: Unidad de medida',
    cantidad_stock INT NOT NULL DEFAULT 0 COMMENT 'Cantidad actual en stock',
    cantidad_minima INT DEFAULT 10 COMMENT 'Cantidad mínima recomendada',
    precio_unitario DECIMAL(10, 2) NOT NULL DEFAULT 0 COMMENT 'Precio unitario del material',
    id_proveedor INT COMMENT 'Foreign Key: Proveedor habitual',
    fecha_ultimo_compra DATE COMMENT 'Fecha de la última compra',
    estado VARCHAR(50) NOT NULL DEFAULT 'ACTIVO' COMMENT 'Estado: ACTIVO, INACTIVO, DESCONTINUADO, ELIMINADO',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    FOREIGN KEY (id_categoria) REFERENCES TblCategoriaMaterial(id_categoria) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (id_unidad) REFERENCES TblUnidadMedida(id_unidad) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_proveedor) REFERENCES TblProveedor(id_proveedor) ON DELETE SET NULL ON UPDATE CASCADE,
    
    INDEX idx_codigo_material (codigo_material),
    INDEX idx_nombre (nombre),
    INDEX idx_id_categoria (id_categoria),
    INDEX idx_id_unidad (id_unidad),
    INDEX idx_id_proveedor (id_proveedor),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de materiales del proyecto';

SELECT 'TblMateriales creada ✓' as resultado;

-- ============================================================================
-- PASO 5: Insertar Datos de Ejemplo en TblMateriales
-- ============================================================================

INSERT INTO TblMateriales (codigo_material, nombre, descripcion, id_categoria, id_unidad, cantidad_stock, cantidad_minima, precio_unitario, id_proveedor)
VALUES 
('MAT-001', 'Cemento Portland', 'Cemento Portland tipo I', 1, 13, 150, 50, 25.50, 1),
('MAT-002', 'Acero Corrugado 1/2"', 'Varilla acero corrugado 1/2 pulgada', 2, 14, 200, 100, 45.00, 2),
('MAT-003', 'Arena Gruesa', 'Arena gruesa para concreto', 3, 9, 50, 20, 80.00, 3),
('MAT-004', 'Grava 3/4"', 'Grava de 3/4 pulgada', 3, 9, 40, 15, 120.00, 3),
('MAT-005', 'Tubo PVC 4"', 'Tubería PVC de 4 pulgadas', 4, 14, 100, 30, 35.00, 4);

SELECT 'Datos de ejemplo insertados ✓' as resultado;

-- ============================================================================
-- PASO 6: Crear Menú y SubMenú
-- ============================================================================

INSERT INTO TblMenu (nombre, ruta, icono, orden, estado)
VALUES ('Almacén', '/almacen', 'fa-warehouse', 6, 'ACTIVO');

INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado)
VALUES (6, 'Materiales', '/materiales', 'fa-cubes', 1, 'ACTIVO');

SELECT 'Menú y SubMenú creados ✓' as resultado;

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT '========================================' as verificacion;
SELECT '✅ SETUP COMPLETADO EXITOSAMENTE' as titulo;
SELECT '========================================' as verificacion;

SELECT 'TblUnidadMedida:' as item;
SELECT COUNT(*) as total FROM TblUnidadMedida;

SELECT 'TblCategoriaMaterial:' as item;
SELECT COUNT(*) as total FROM TblCategoriaMaterial;

SELECT 'TblProveedor:' as item;
SELECT COUNT(*) as total FROM TblProveedor;

SELECT 'TblMateriales:' as item;
SELECT COUNT(*) as total FROM TblMateriales;

SELECT 'TblMenu (Almacén):' as item;
SELECT id_menu, nombre FROM TblMenu WHERE id_menu = 6;

SELECT 'TblSubMenu (Materiales):' as item;
SELECT id_submenu, nombre FROM TblSubMenu WHERE id_menu = 6;

SELECT '========================================' as verificacion;
