-- ============================================================================
-- SCRIPT: CREATE_TABLAS_FLUJO_APROBACION.sql
-- PROPÓSITO: Crear tablas para el sistema de flujo de aprobación
-- FECHA: 13/07/2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- TABLA 1: TblTipoDocumentoAprobacion
-- DESCRIPCIÓN: Tipos de documentos que requieren aprobación
-- EJEMPLOS: Presupuesto, Requerimiento, Orden de Compra, Orden de Servicio
-- ============================================================================

DROP TABLE IF EXISTS TblFlujoAprobacion;
DROP TABLE IF EXISTS TblTipoDocumentoAprobacion;

CREATE TABLE TblTipoDocumentoAprobacion (
    id_tipo_documento INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del tipo de documento',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del tipo (Presupuesto, Requerimiento, etc)',
    descripcion VARCHAR(500) COMMENT 'Descripción del tipo de documento',
    icono VARCHAR(50) COMMENT 'Icono para la interfaz (ej: fa-file-invoice)',
    color VARCHAR(20) COMMENT 'Color para la interfaz (ej: blue, green, red)',
    requiere_aprobacion TINYINT DEFAULT 1 COMMENT '1=Sí requiere, 0=No requiere',
    activo TINYINT DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    orden INT DEFAULT 0 COMMENT 'Orden de visualización',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización',
    
    INDEX idx_nombre (nombre),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tipos de documentos que requieren aprobación en el sistema';

-- ============================================================================
-- TABLA 2: TblFlujoAprobacion
-- DESCRIPCIÓN: Define el flujo de aprobación para cada tipo de documento
-- EJEMPLO: Presupuesto → Paso 1: Gerente Proyecto, Paso 2: Director Ejecución, Paso 3: Gerente General
-- ============================================================================

CREATE TABLE TblFlujoAprobacion (
    id_flujo_aprobacion INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del flujo',
    id_tipo_documento INT NOT NULL COMMENT 'FK a TblTipoDocumentoAprobacion',
    numero_paso INT NOT NULL COMMENT 'Número de paso en el flujo (1, 2, 3, etc)',
    id_cargo INT NOT NULL COMMENT 'FK a TblCargo - cargo que debe aprobar en este paso',
    nombre_paso VARCHAR(100) COMMENT 'Nombre descriptivo del paso (ej: Revisión Inicial, Aprobación Final)',
    descripcion VARCHAR(500) COMMENT 'Descripción de qué se valida en este paso',
    es_final TINYINT DEFAULT 0 COMMENT '1=Es el paso final de aprobación, 0=No es final',
    es_requerido TINYINT DEFAULT 1 COMMENT '1=Aprobación requerida para continuar, 0=Es opcional',
    permite_rechazo TINYINT DEFAULT 1 COMMENT '1=Puede rechazar, 0=Solo puede aprobar',
    activo TINYINT DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización',
    
    FOREIGN KEY fk_tipo_documento (id_tipo_documento) 
        REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    FOREIGN KEY fk_cargo (id_cargo) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    UNIQUE KEY uk_flujo_paso (id_tipo_documento, numero_paso),
    INDEX idx_tipo_documento (id_tipo_documento),
    INDEX idx_cargo (id_cargo),
    INDEX idx_numero_paso (numero_paso),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Define los pasos de aprobación para cada tipo de documento';



-- ============================================================================
-- DATOS INICIALES - Tipos de Documentos
-- ============================================================================

INSERT INTO TblTipoDocumentoAprobacion (nombre, descripcion, icono, color, requiere_aprobacion, orden) VALUES
    ('Presupuesto', 'Presupuestos de proyectos y obras', 'fa-file-invoice-dollar', 'blue', 1, 1),
    ('Requerimiento', 'Requerimientos de materiales y servicios', 'fa-tasks', 'green', 1, 2),
    ('Orden de Compra', 'Órdenes de compra a proveedores', 'fa-shopping-cart', 'orange', 1, 3),
    ('Orden de Servicio', 'Órdenes de servicio a contratistas', 'fa-wrench', 'purple', 1, 4),
    ('Hoja de Salida', 'Solicitud de salida de materiales del almacén', 'fa-dolly', 'red', 0, 5);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Presupuesto
-- ============================================================================

-- Flujo: Presupuesto → Gerente Proyectos (48) → Gerente Operaciones (54) → Director General (13)

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1),
    (1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1),
    (1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Requerimiento
-- ============================================================================

-- Flujo: Requerimiento → Coordinador Operaciones (55) → Gerente Compras (51)

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1),
    (2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Orden de Compra
-- ============================================================================

-- Flujo: Orden Compra → Especialista Compras (52) → Gerente Compras (51) → Director General (13)

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (3, 1, 52, 'Validación de Proveedor', 'Especialista Compras valida proveedor y términos', 0, 1, 1),
    (3, 2, 51, 'Aprobación Gerencial', 'Gerente Compras aprueba orden', 0, 1, 1),
    (3, 3, 13, 'Aprobación Final', 'Director General aprueba emisión de orden', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Orden de Servicio
-- ============================================================================

-- Flujo: Orden Servicio → Gerente Proyectos (48) → Gerente Operaciones (54) → Director General (13)

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (4, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida alcance del servicio', 0, 1, 1),
    (4, 2, 54, 'Aprobación de Términos', 'Gerente Operaciones valida términos y condiciones', 0, 1, 1),
    (4, 3, 13, 'Aprobación Final', 'Director General aprueba contratación', 1, 1, 1);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '=== TABLA: TblTipoDocumentoAprobacion ===' as Info;
SELECT * FROM TblTipoDocumentoAprobacion;

SELECT '=== TABLA: TblFlujoAprobacion ===' as Info;
SELECT * FROM TblFlujoAprobacion;

SELECT '=== VERIFICACIÓN: Flujo Presupuesto ===' as Info;
SELECT 
    tp.nombre as 'Tipo Documento',
    fa.numero_paso as 'Paso',
    c.nombre as 'Cargo Aprobador',
    fa.nombre_paso as 'Nombre del Paso',
    fa.es_final as 'Es Final'
FROM TblFlujoAprobacion fa
JOIN TblTipoDocumentoAprobacion tp ON fa.id_tipo_documento = tp.id_tipo_documento
JOIN TblCargo c ON fa.id_cargo = c.id_cargo
ORDER BY tp.id_tipo_documento, fa.numero_paso;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
