-- ============================================================================
-- SCRIPT SIMPLE: Crear tabla de múltiples aprobadores (SIN ERRORES)
-- PROPÓSITO: Permitir que varios cargos aprueben un paso
-- FECHA: 17 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Crear tabla intermedia
-- ============================================================================

SELECT '===== PASO 1: Creando tabla TblFlujoAprobacionCargos =====' as paso;

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

CREATE TABLE TblFlujoAprobacionCargos (
    id_flujo_cargo INT AUTO_INCREMENT PRIMARY KEY,
    id_flujo_aprobacion INT NOT NULL,
    id_cargo INT NOT NULL,
    orden_visualizacion INT DEFAULT 0,
    activo TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_fac_flujo 
        FOREIGN KEY (id_flujo_aprobacion) 
        REFERENCES TblFlujoAprobacion(id_flujo_aprobacion) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_fac_cargo 
        FOREIGN KEY (id_cargo) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE RESTRICT,
    
    CONSTRAINT uk_fac_flujo_cargo 
        UNIQUE (id_flujo_aprobacion, id_cargo),
    
    INDEX idx_fac_flujo (id_flujo_aprobacion),
    INDEX idx_fac_cargo (id_cargo)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SELECT '✓ Tabla creada' as resultado;

-- ============================================================================
-- PASO 2: Migrar datos existentes
-- ============================================================================

SELECT '===== PASO 2: Migrando datos de flujos actuales =====' as paso;

INSERT INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
SELECT id_flujo_aprobacion, id_cargo, 0
FROM TblFlujoAprobacion
WHERE id_cargo IS NOT NULL;

SELECT CONCAT('✓ ', COUNT(*), ' registros migrados') as resultado
FROM TblFlujoAprobacionCargos;

-- ============================================================================
-- PASO 3: Crear vista de compatibilidad
-- ============================================================================

SELECT '===== PASO 3: Creando vistas =====' as paso;

DROP VIEW IF EXISTS vw_flujo_aprobacion_con_cargos;

CREATE VIEW vw_flujo_aprobacion_con_cargos AS
SELECT 
    fa.id_flujo_aprobacion,
    fa.id_tipo_documento,
    fa.numero_paso,
    fa.nombre_paso,
    fa.descripcion,
    fa.es_final,
    fa.es_requerido,
    fa.permite_rechazo,
    fa.activo,
    GROUP_CONCAT(DISTINCT c.nombre SEPARATOR ' | ') as nombres_cargos,
    COUNT(DISTINCT fc.id_cargo) as cantidad_cargos
FROM TblFlujoAprobacion fa
LEFT JOIN TblFlujoAprobacionCargos fc ON fa.id_flujo_aprobacion = fc.id_flujo_aprobacion AND fc.activo = 1
LEFT JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fa.activo = 1
GROUP BY fa.id_flujo_aprobacion;

SELECT '✓ Vista creada' as resultado;

-- ============================================================================
-- PASO 4: Crear procedimiento para obtener cargos
-- ============================================================================

SELECT '===== PASO 4: Creando procedimiento =====' as paso;

DROP PROCEDURE IF EXISTS sp_ObtenerCargosPorPaso;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerCargosPorPaso(
    IN p_id_tipo_documento INT,
    IN p_numero_paso INT
)
BEGIN
    SELECT 
        fc.id_cargo,
        c.nombre,
        c.descripcion,
        fc.orden_visualizacion
    FROM TblFlujoAprobacionCargos fc
    JOIN TblFlujoAprobacion fa ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
    JOIN TblCargo c ON fc.id_cargo = c.id_cargo
    WHERE fa.id_tipo_documento = p_id_tipo_documento
    AND fa.numero_paso = p_numero_paso
    AND fc.activo = 1
    ORDER BY fc.orden_visualizacion;
END$$

DELIMITER ;

SELECT '✓ Procedimiento creado' as resultado;

-- ============================================================================
-- PASO 5: Ver configuración actual
-- ============================================================================

SELECT '===== PASO 5: Verificación =====' as paso;

SELECT 
    td.nombre as Tipo_Documento,
    fa.numero_paso as Paso,
    fa.nombre_paso as Nombre_Paso,
    GROUP_CONCAT(DISTINCT c.nombre SEPARATOR ' | ') as Cargos_Aprobadores,
    COUNT(DISTINCT fc.id_cargo) as Cantidad_Opciones
FROM TblFlujoAprobacionCargos fc
JOIN TblFlujoAprobacion fa ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
JOIN TblTipoDocumentoAprobacion td ON fa.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1 AND fa.activo = 1
GROUP BY fa.id_flujo_aprobacion
ORDER BY td.nombre, fa.numero_paso;

-- ============================================================================
-- FIN
-- ============================================================================

SELECT '✅ SETUP COMPLETADO' as estado;
SELECT 'Tabla TblFlujoAprobacionCargos creada y lista para usar' as nota;
