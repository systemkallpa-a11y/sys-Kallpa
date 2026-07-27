-- ============================================================================
-- SETUP COMPLETO: Proyectos, Obras, Presupuestos y Materiales
-- Relación: 1 Proyecto → N Obras → N Presupuestos
--           1 Material puede estar en N Presupuestos
-- Fecha: 10 Julio 2026
-- ============================================================================

-- ============================================================================
-- IMPORTANTE: Este script requiere que TblMateriales ya exista
-- Ejecutar primero: SETUP_MATERIALES.sql
-- ============================================================================

-- ============================================================================
-- PASO 1: Crear Tabla TblProyecto (SIN DEPENDENCIAS)
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
-- PASO 2: Crear Tabla TblObra (DEPENDE DE TBLPROYECTO)
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
-- PASO 3: Crear Tabla TblPresupuesto (DEPENDE DE TBLOBA, TBLMATERIALES Y TBLUSUARIO)
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblPresupuesto (
    id_presupuesto INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del presupuesto',
    numero_presupuesto VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único del presupuesto (Ej: PRES-001)',
    id_obra INT NOT NULL COMMENT 'Foreign Key: Obra asociada al presupuesto',
    id_material INT NOT NULL COMMENT 'Foreign Key: Material del presupuesto',
    num_documento INT NOT NULL COMMENT 'Foreign Key: Usuario que gestiona presupuesto',
    monto DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto del presupuesto',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, APROBADO, RECHAZADO, EJECUTANDO, COMPLETADO, CANCELADO, ELIMINADO',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    FOREIGN KEY (id_obra) REFERENCES TblObra(id_obra) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_material) REFERENCES TblMateriales(id_material) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (num_documento) REFERENCES TblUsuario(num_documento) ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_numero_presupuesto (numero_presupuesto),
    INDEX idx_id_obra (id_obra),
    INDEX idx_id_material (id_material),
    INDEX idx_num_documento (num_documento),
    INDEX idx_estado (estado),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de presupuestos enlazados con obras, materiales y usuarios';

SELECT 'TblPresupuesto creada ✓' as resultado;

-- ============================================================================
-- PASO 4: Insertar Datos de Ejemplo
-- ============================================================================

-- Insertar proyectos
INSERT INTO TblProyecto (codigo_proyecto, nombre, descripcion)
VALUES 
('PRY-001', 'Casa Verde', 'Construcción de casa unifamiliar en Lima'),
('PRY-002', 'La Floresta', 'Complejo residencial multifamiliar'),
('PRY-003', 'Oficinas Modernas', 'Edificio comercial de 5 pisos'),
('PRY-004', 'Centro Logístico', 'Almacén y centro de distribución');

SELECT 'Proyectos insertados ✓' as resultado;

-- Insertar obras
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

-- Insertar presupuestos (requiere TblUsuario con documentos válidos)
-- NOTA: id_material NO existe en TblPresupuesto (fue removida)
-- Los materiales se especifican en TblPresupuestoDetalle
INSERT INTO TblPresupuesto (numero_presupuesto, id_obra, num_documento, monto, estado)
VALUES 
('PRES-001', 1, 1, 85000.00, 'APROBADO'),
('PRES-002', 2, 1, 125000.00, 'APROBADO'),
('PRES-003', 3, 1, 55000.00, 'PENDIENTE'),
('PRES-004', 4, 1, 45000.00, 'EJECUTANDO'),
('PRES-005', 5, 1, 38000.00, 'PENDIENTE'),
('PRES-006', 6, 1, 62000.00, 'APROBADO'),
('PRES-007', 7, 1, 95000.00, 'APROBADO'),
('PRES-008', 8, 1, 250000.00, 'PENDIENTE'),
('PRES-009', 9, 1, 180000.00, 'EJECUTANDO'),
('PRES-010', 10, 1, 520000.00, 'APROBADO');

SELECT 'Presupuestos insertados ✓' as resultado;

-- ============================================================================
-- PASO 5: Verificación Final
-- ============================================================================

SELECT '========================================' as verificacion;
SELECT '✅ SETUP PROYECTO + OBRA + PRESUPUESTO COMPLETADO' as titulo;
SELECT '========================================' as verificacion;

SELECT 'TblProyecto:' as item;
SELECT COUNT(*) as registros FROM TblProyecto;

SELECT 'TblObra:' as item;
SELECT COUNT(*) as registros FROM TblObra;

SELECT 'TblPresupuesto:' as item;
SELECT COUNT(*) as registros FROM TblPresupuesto;

SELECT '========================================' as verificacion;

-- ============================================================================
-- RELACIONES Y ESTRUCTURA
-- ============================================================================

SELECT 'Ejemplo de relación completa:' as item;
SELECT 
    p.codigo_proyecto as proyecto,
    o.codigo_obra as obra,
    pr.numero_presupuesto as presupuesto,
    per.nombres as usuario,
    m.codigo_material,
    m.nombre as material,
    pr.monto,
    pr.estado
FROM TblProyecto p
LEFT JOIN TblObra o ON p.id_proyecto = o.id_proyecto
LEFT JOIN TblPresupuesto pr ON o.id_obra = pr.id_obra
LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
LEFT JOIN TblMateriales m ON pr.id_material = m.id_material
ORDER BY p.codigo_proyecto, o.codigo_obra, pr.numero_presupuesto
LIMIT 15;

SELECT '========================================' as verificacion;

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================
--
-- RELACIÓN JERÁRQUICA:
--   1 Proyecto → N Obras → N Presupuestos
--   1 Material → N Presupuestos (N:1 desde presupuesto)
--
-- FOREIGN KEYS:
--   TblObra → TblProyecto: ON DELETE RESTRICT, ON UPDATE CASCADE
--     (No se puede eliminar proyecto si tiene obras)
--   TblPresupuesto → TblObra: ON DELETE RESTRICT, ON UPDATE CASCADE
--     (No se puede eliminar obra si tiene presupuestos)
--   TblPresupuesto → TblMateriales: ON DELETE RESTRICT, ON UPDATE CASCADE
--     (No se puede eliminar material si está en presupuesto)
--
-- CAMPOS OBLIGATORIOS (NOT NULL):
--   - TblPresupuesto: numero_presupuesto, id_obra, id_material, cliente, monto_total, estado
--   - TblObra: codigo_obra, nombre, id_proyecto
--   - TblProyecto: codigo_proyecto, nombre
--
-- ÍNDICES CREADOS:
--   - codigo_proyecto, nombre en TblProyecto
--   - codigo_obra, nombre, id_proyecto, tipo_obra en TblObra
--   - numero_presupuesto, id_obra, id_material, estado, cliente en TblPresupuesto
--
-- CAMPOS REMOVIDOS DE TBLPRESUPUESTO:
--   - descripcion (LONGTEXT)
--   - fecha_vencimiento (DATE)
--   - contacto (VARCHAR)
--   - email_cliente (VARCHAR)
--
-- CAMPOS NUEVOS EN TBLPRESUPUESTO:
--   - id_material (FK) → Enlaza con materiales
--
-- ============================================================================
