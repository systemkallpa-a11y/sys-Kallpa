-- ============================================================================
-- NUEVA ESTRUCTURA: Flujo de Aprobación SIMPLIFICADA
-- PROPÓSITO: Solo 2 tablas (TblTipoDocumentoAprobacion + TblFlujoAprobacionCargos)
-- FECHA: 20 de Julio de 2026
-- VENTAJA: Sin redundancia, más flexible, más simple
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Eliminar TblFlujoAprobacion (no la necesitamos)
-- ============================================================================

DROP TABLE IF EXISTS TblFlujoAprobacion;

-- ============================================================================
-- PASO 2: TABLA TblTipoDocumentoAprobacion (ya existe, sin cambios)
-- ============================================================================

/*
TblTipoDocumentoAprobacion:
├─ id_tipo_documento (PK)
├─ nombre (Presupuesto, Requerimiento, etc)
├─ requiere_aprobacion (1=sí, 0=no)
└─ ... (campos descriptivos)

SIN CAMBIOS - Esta tabla es perfecta para definir qué tipos necesitan aprobación
*/

-- ============================================================================
-- PASO 3: TABLA TblFlujoAprobacionCargos (ESTRUCTURA NUEVA - COMPLETA)
-- ============================================================================

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

CREATE TABLE TblFlujoAprobacionCargos (
    id_flujo_cargo INT AUTO_INCREMENT PRIMARY KEY 
        COMMENT 'ID único del flujo de aprobación',
    
    -- RELACIONES
    id_tipo_documento INT NOT NULL 
        COMMENT 'FK a TblTipoDocumentoAprobacion',
    id_cargo INT NOT NULL 
        COMMENT 'FK a TblCargo - Cargo que aprueba en este paso',
    
    -- DEFINICIÓN DEL PASO
    numero_paso INT NOT NULL 
        COMMENT 'Número de paso en el flujo (1, 2, 3...)',
    nombre_paso VARCHAR(100) NOT NULL DEFAULT 'Paso' 
        COMMENT 'Nombre del paso (ej: Revisión Técnica)',
    descripcion VARCHAR(500) 
        COMMENT 'Descripción de qué se valida en este paso',
    
    -- CONTROL DEL FLUJO
    es_final TINYINT DEFAULT 0 
        COMMENT '1=Es el paso final de aprobación, 0=No es final',
    es_requerido TINYINT DEFAULT 1 
        COMMENT '1=Aprobación obligatoria, 0=Aprobación opcional',
    permite_rechazo TINYINT DEFAULT 1 
        COMMENT '1=Puede rechazar, 0=Solo puede aprobar',
    
    -- ORDEN Y ESTADO
    orden_visualizacion INT DEFAULT 0 
        COMMENT 'Orden de visualización en interfaces',
    activo TINYINT DEFAULT 1 
        COMMENT '1=Activo, 0=Inactivo (deshabilitado)',
    
    -- AUDITORÍA
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
        COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
        COMMENT 'Última actualización',
    
    -- RELACIONES CON CLAVES FORÁNEAS
    FOREIGN KEY fk_tipo_documento (id_tipo_documento) 
        REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    FOREIGN KEY fk_cargo (id_cargo) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- ÍNDICES
    UNIQUE KEY uk_flujo_paso (id_tipo_documento, numero_paso, id_cargo),
    INDEX idx_tipo_documento (id_tipo_documento),
    INDEX idx_cargo (id_cargo),
    INDEX idx_numero_paso (numero_paso),
    INDEX idx_activo (activo)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Define los pasos de aprobación y los cargos que aprueban en cada paso';

-- ============================================================================
-- PASO 4: DATOS INICIALES - Flujo para PRESUPUESTO
-- ============================================================================

INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion)
VALUES
    -- Presupuesto (id_tipo_documento = 1)
    (1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1, 1),
    (1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1, 2),
    (1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1, 3);

-- ============================================================================
-- PASO 5: DATOS INICIALES - Flujo para REQUERIMIENTO
-- ============================================================================

INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion)
VALUES
    -- Requerimiento (id_tipo_documento = 2)
    (2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1, 1),
    (2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1, 2);

-- ============================================================================
-- PASO 6: VISTA DE COMPATIBILIDAD (para queries simples)
-- ============================================================================

DROP VIEW IF EXISTS vw_flujo_aprobacion;

CREATE VIEW vw_flujo_aprobacion AS
SELECT 
    fc.id_flujo_cargo,
    fc.id_tipo_documento,
    fc.numero_paso,
    fc.id_cargo,
    fc.nombre_paso,
    fc.descripcion,
    fc.es_final,
    fc.es_requerido,
    fc.permite_rechazo,
    fc.activo,
    td.nombre as tipo_documento,
    c.nombre as cargo_nombre,
    c.descripcion as cargo_descripcion
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1 AND td.activo = 1
ORDER BY td.id_tipo_documento, fc.numero_paso;

-- ============================================================================
-- PASO 7: PROCEDIMIENTOS ALMACENADOS
-- ============================================================================

-- SP 1: Obtener flujo completo de aprobación
DROP PROCEDURE IF EXISTS sp_ObtenerFlujoAprobacion;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerFlujoAprobacion(
    IN p_id_tipo_documento INT
)
BEGIN
    SELECT 
        fc.numero_paso,
        fc.id_cargo,
        c.nombre as cargo_nombre,
        fc.nombre_paso,
        fc.descripcion,
        fc.es_final,
        fc.es_requerido,
        fc.permite_rechazo
    FROM TblFlujoAprobacionCargos fc
    JOIN TblCargo c ON fc.id_cargo = c.id_cargo
    WHERE fc.id_tipo_documento = p_id_tipo_documento
    AND fc.activo = 1
    ORDER BY fc.numero_paso;
END$$

DELIMITER ;

-- SP 2: Obtener siguiente paso del flujo
DROP PROCEDURE IF EXISTS sp_ObtenerSiguientePaso;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerSiguientePaso(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT
)
BEGIN
    SELECT 
        fc.numero_paso,
        fc.id_cargo,
        c.nombre as cargo_nombre,
        fc.nombre_paso,
        fc.es_final,
        fc.permite_rechazo
    FROM TblFlujoAprobacionCargos fc
    JOIN TblCargo c ON fc.id_cargo = c.id_cargo
    WHERE fc.id_tipo_documento = p_id_tipo_documento
    AND fc.numero_paso > COALESCE(
        (SELECT MAX(numero_paso) 
         FROM TblRegistroAprobacion 
         WHERE id_documento_referencia = p_id_documento 
         AND id_tipo_documento = p_id_tipo_documento 
         AND estado_aprobacion = 'APROBADO'),
        0
    )
    AND fc.es_requerido = 1
    AND fc.activo = 1
    LIMIT 1;
END$$

DELIMITER ;

-- SP 3: Contar pasos totales del flujo
DROP PROCEDURE IF EXISTS sp_ContarPasosFlujo;

DELIMITER $$

CREATE PROCEDURE sp_ContarPasosFlujo(
    IN p_id_tipo_documento INT,
    OUT p_pasos_totales INT
)
BEGIN
    SELECT COUNT(DISTINCT numero_paso) INTO p_pasos_totales
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND es_requerido = 1
    AND activo = 1;
END$$

DELIMITER ;

-- ============================================================================
-- PASO 8: VERIFICACIÓN
-- ============================================================================

SELECT '===== ESTRUCTURA DE FLUJO SIMPLIFICADA =====' as titulo;

SELECT 
    td.nombre as Tipo_Documento,
    fc.numero_paso as Paso,
    fc.nombre_paso as Nombre_Paso,
    c.nombre as Cargo_Aprobador,
    fc.es_final as Es_Final,
    fc.es_requerido as Es_Requerido,
    fc.permite_rechazo as Permite_Rechazo
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1 AND td.activo = 1
ORDER BY td.id_tipo_documento, fc.numero_paso;

-- ============================================================================
-- PASO 9: RESUMEN
-- ============================================================================

SELECT '✅ ESTRUCTURA SIMPLIFICADA LISTA' as estado;

SELECT 'Tablas activas:
1. TblTipoDocumentoAprobacion (define tipos de documentos)
2. TblFlujoAprobacionCargos (define pasos + cargos - TODO EN UNA TABLA)
3. TblRegistroAprobacion (auditoría de aprobaciones)' as ARQUITECTURA;

SELECT 'Ventajas:
✓ Sin redundancia
✓ Más flexible (múltiples cargos por paso si es necesario)
✓ Queries más simples
✓ Mantenimiento más fácil' as VENTAJAS;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================

