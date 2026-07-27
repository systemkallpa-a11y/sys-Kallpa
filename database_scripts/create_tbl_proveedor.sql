-- ============================================================================
-- Tabla: TblProveedor
-- Propósito: Almacenar información de proveedores de materiales
-- Fecha: 10 Julio 2026
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

-- ============================================================================
-- INSERTAR PROVEEDORES DE EJEMPLO
-- ============================================================================

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

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblProveedor creada exitosamente' as resultado;
SELECT COUNT(*) as total_proveedores FROM TblProveedor;
SELECT id_proveedor, nombre, contacto, telefono FROM TblProveedor ORDER BY id_proveedor;
