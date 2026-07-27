-- ============================================================================
-- SCRIPT: Crear TblFlujoAprobacionCargos (FIX para error errno 121)
-- PROPÓSITO: Eliminar tabla anterior y recrear correctamente
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Eliminar constraints y tabla
-- ============================================================================

SELECT '===== PASO 1: Limpiando tabla anterior =====' as paso;

-- Desactivar checks de claves foráneas temporalmente
SET FOREIGN_KEY_CHECKS = 0;

-- Eliminar la tabla si existe
DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

-- Reactivar checks
SET FOREIGN_KEY_CHECKS = 1;

SELECT '✓ Tabla anterior eliminada' as resultado;

-- ============================================================================
-- PASO 2: Crear tabla NUEVA sin conflictos
-- ============================================================================

SELECT '===== PASO 2: Creando tabla nueva =====' as paso;

CREATE TABLE TblFlujoAprobacionCargos (
    id_flujo_cargo INT AUTO_INCREMENT PRIMARY KEY 
        COMMENT 'ID único del flujo de aprobación',
    
    id_tipo_documento INT NOT NULL 
        COMMENT 'FK a TblTipoDocumentoAprobacion',
    id_cargo INT NOT NULL 
        COMMENT 'FK a TblCargo - Cargo que aprueba en este paso',
    
    numero_paso INT NOT NULL 
        COMMENT 'Número de paso en el flujo (1, 2, 3...)',
    nombre_paso VARCHAR(100) NOT NULL DEFAULT 'Paso' 
        COMMENT 'Nombre del paso (ej: Revisión Técnica)',
    descripcion VARCHAR(500) 
        COMMENT 'Descripción de qué se valida en este paso',
    
    es_final TINYINT DEFAULT 0 
        COMMENT '1=Es el paso final de aprobación, 0=No es final',
    es_requerido TINYINT DEFAULT 1 
        COMMENT '1=Aprobación obligatoria, 0=Aprobación opcional',
    permite_rechazo TINYINT DEFAULT 1 
        COMMENT '1=Puede rechazar, 0=Solo puede aprobar',
    
    orden_visualizacion INT DEFAULT 0 
        COMMENT 'Orden de visualización en interfaces',
    activo TINYINT DEFAULT 1 
        COMMENT '1=Activo, 0=Inactivo (deshabilitado)',
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
        COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
        COMMENT 'Última actualización'
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Define los pasos de aprobación y los cargos que aprueban en cada paso';

SELECT '✓ Tabla TblFlujoAprobacionCargos creada' as resultado;

-- ============================================================================
-- PASO 3: Agregar claves foráneas
-- ============================================================================

SELECT '===== PASO 3: Agregando claves foráneas =====' as paso;

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_fac_tipo_documento 
FOREIGN KEY (id_tipo_documento) 
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_fac_cargo 
FOREIGN KEY (id_cargo) 
REFERENCES TblCargo(id_cargo) 
ON DELETE RESTRICT ON UPDATE CASCADE;

SELECT '✓ Claves foráneas agregadas' as resultado;

-- ============================================================================
-- PASO 4: Agregar índices
-- ============================================================================

SELECT '===== PASO 4: Agregando índices =====' as paso;

ALTER TABLE TblFlujoAprobacionCargos 
ADD UNIQUE KEY uk_flujo_paso (id_tipo_documento, numero_paso, id_cargo);

ALTER TABLE TblFlujoAprobacionCargos 
ADD INDEX idx_tipo_documento (id_tipo_documento);

ALTER TABLE TblFlujoAprobacionCargos 
ADD INDEX idx_cargo (id_cargo);

ALTER TABLE TblFlujoAprobacionCargos 
ADD INDEX idx_numero_paso (numero_paso);

ALTER TABLE TblFlujoAprobacionCargos 
ADD INDEX idx_activo (activo);

SELECT '✓ Índices agregados' as resultado;

-- ============================================================================
-- PASO 5: Insertar datos iniciales (PRESUPUESTO)
-- ============================================================================

SELECT '===== PASO 5: Insertando datos iniciales =====' as paso;

INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
    -- Presupuesto (id_tipo_documento = 1)
    (1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1, 1, 1),
    (1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1, 2, 1),
    (1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1, 3, 1);

SELECT CONCAT('✓ ', ROW_COUNT(), ' registros insertados para Presupuesto') as resultado;

-- ============================================================================
-- PASO 6: Insertar datos iniciales (REQUERIMIENTO)
-- ============================================================================

INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
    -- Requerimiento (id_tipo_documento = 2)
    (2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1, 1, 1),
    (2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1, 2, 1);

SELECT CONCAT('✓ ', ROW_COUNT(), ' registros insertados para Requerimiento') as resultado;

-- ============================================================================
-- PASO 7: Crear vista de compatibilidad
-- ============================================================================

SELECT '===== PASO 7: Creando vista de compatibilidad =====' as paso;

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

SELECT '✓ Vista vw_flujo_aprobacion creada' as resultado;

-- ============================================================================
-- PASO 8: VERIFICACIÓN
-- ============================================================================

SELECT '===== PASO 8: VERIFICACIÓN =====' as paso;

SELECT 
    fc.id_flujo_cargo,
    td.nombre as tipo_documento,
    fc.numero_paso,
    c.nombre as cargo_aprobador,
    fc.nombre_paso,
    fc.es_final,
    fc.es_requerido,
    fc.permite_rechazo,
    fc.activo
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
ORDER BY td.id_tipo_documento, fc.numero_paso;

-- ============================================================================
-- PASO 9: INFORMACIÓN DEL FLUJO
-- ============================================================================

SELECT '===== INFORMACIÓN DEL FLUJO CONFIGURADO =====' as titulo;

SELECT 
    td.nombre as 'Tipo de Documento',
    COUNT(DISTINCT fc.numero_paso) as 'Pasos Totales',
    GROUP_CONCAT(fc.nombre_paso SEPARATOR ' → ') as 'Flujo',
    GROUP_CONCAT(DISTINCT c.nombre SEPARATOR ', ') as 'Cargos Involucrados'
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
GROUP BY td.id_tipo_documento, td.nombre;

-- ============================================================================
-- PASO 10: RESUMEN FINAL
-- ============================================================================

SELECT '✅ TABLA TblFlujoAprobacionCargos CREADA EXITOSAMENTE' as ESTADO;

SELECT 'ESTRUCTURA:
┌─ id_flujo_cargo (PK)
├─ id_tipo_documento (FK) → TblTipoDocumentoAprobacion
├─ id_cargo (FK) → TblCargo
├─ numero_paso (1, 2, 3...)
├─ nombre_paso (Revisión Técnica, Aprobación Final, etc)
├─ es_final (1 si es último paso)
├─ es_requerido (1 si es obligatorio)
├─ permite_rechazo (1 si permite rechazar)
├─ activo (1 si está activo)
└─ fecha_creacion, fecha_actualizacion' as ESTRUCTURA;

SELECT 'DATOS CONFIGURADOS:
✓ Presupuesto: 3 pasos
  1. Revisión Técnica (Gerente Proyecto)
  2. Aprobación Operacional (Gerente Operaciones)
  3. Aprobación Final (Director General)
  
✓ Requerimiento: 2 pasos
  1. Verificación de Disponibilidad (Coordinador Operaciones)
  2. Aprobación de Compra (Gerente Compras)' as DATOS_CONFIGURADOS;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================

