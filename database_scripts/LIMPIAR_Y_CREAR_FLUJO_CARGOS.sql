-- ============================================================================
-- SCRIPT: Limpiar y Crear TblFlujoAprobacionCargos (AGRESIVO)
-- PROPÓSITO: Eliminar TODAS las referencias antes de recrear
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '===== INICIANDO LIMPIEZA AGRESIVA =====' as paso;

-- ============================================================================
-- PASO 1: Desactivar restricciones de claves foráneas
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;

SELECT '✓ Restricciones de FK desactivadas' as resultado;

-- ============================================================================
-- PASO 2: Eliminar vistas que dependen de la tabla
-- ============================================================================

DROP VIEW IF EXISTS vw_flujo_aprobacion;
DROP VIEW IF EXISTS vw_flujo_aprobacion_con_cargos;

SELECT '✓ Vistas eliminadas' as resultado;

-- ============================================================================
-- PASO 3: Eliminar procedimientos que usan la tabla
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerFlujoAprobacion;
DROP PROCEDURE IF EXISTS sp_ObtenerSiguientePaso;
DROP PROCEDURE IF EXISTS sp_ContarPasosFlujo;
DROP PROCEDURE IF EXISTS sp_ObtenerCargosPorPaso;

SELECT '✓ Procedimientos eliminados' as resultado;

-- ============================================================================
-- PASO 4: Eliminar tabla completamente
-- ============================================================================

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

SELECT '✓ Tabla TblFlujoAprobacionCargos eliminada' as resultado;

-- ============================================================================
-- PASO 5: Reactivar restricciones
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 1;

SELECT '✓ Restricciones de FK reactivadas' as resultado;

-- ============================================================================
-- PASO 6: CREAR TABLA NUEVA LIMPIA
-- ============================================================================

SELECT '===== CREANDO TABLA NUEVA =====' as paso;

CREATE TABLE TblFlujoAprobacionCargos (
    id_flujo_cargo INT AUTO_INCREMENT PRIMARY KEY,
    id_tipo_documento INT NOT NULL,
    id_cargo INT NOT NULL,
    numero_paso INT NOT NULL,
    nombre_paso VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),
    es_final TINYINT DEFAULT 0,
    es_requerido TINYINT DEFAULT 1,
    permite_rechazo TINYINT DEFAULT 1,
    orden_visualizacion INT DEFAULT 0,
    activo TINYINT DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT '✓ Tabla creada sin constraints' as resultado;

-- ============================================================================
-- PASO 7: AGREGAR CONSTRAINTS CON NOMBRES ÚNICOS
-- ============================================================================

SELECT '===== AGREGANDO CONSTRAINTS =====' as paso;

-- FK a TblTipoDocumentoAprobacion
ALTER TABLE TblFlujoAprobacionCargos
ADD CONSTRAINT fk_flujo_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT ON UPDATE CASCADE;

SELECT '✓ FK id_tipo_documento agregada' as resultado;

-- FK a TblCargo
ALTER TABLE TblFlujoAprobacionCargos
ADD CONSTRAINT fk_flujo_cargo_ref
FOREIGN KEY (id_cargo)
REFERENCES TblCargo(id_cargo)
ON DELETE RESTRICT ON UPDATE CASCADE;

SELECT '✓ FK id_cargo agregada' as resultado;

-- ============================================================================
-- PASO 8: AGREGAR ÍNDICES
-- ============================================================================

SELECT '===== AGREGANDO ÍNDICES =====' as paso;

ALTER TABLE TblFlujoAprobacionCargos
ADD UNIQUE KEY uk_flujo_tipo_paso_cargo (id_tipo_documento, numero_paso, id_cargo);

ALTER TABLE TblFlujoAprobacionCargos
ADD INDEX idx_flujo_tipo (id_tipo_documento);

ALTER TABLE TblFlujoAprobacionCargos
ADD INDEX idx_flujo_cargo (id_cargo);

ALTER TABLE TblFlujoAprobacionCargos
ADD INDEX idx_flujo_paso (numero_paso);

ALTER TABLE TblFlujoAprobacionCargos
ADD INDEX idx_flujo_activo (activo);

SELECT '✓ Índices agregados' as resultado;

-- ============================================================================
-- PASO 9: INSERTAR DATOS INICIALES
-- ============================================================================

SELECT '===== INSERTANDO DATOS =====' as paso;

-- Presupuesto: 3 pasos
INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1, 1, 1),
(1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1, 2, 1),
(1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1, 3, 1);

SELECT '✓ 3 pasos de Presupuesto insertados' as resultado;

-- Requerimiento: 2 pasos
INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1, 1, 1),
(2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1, 2, 1);

SELECT '✓ 2 pasos de Requerimiento insertados' as resultado;

-- ============================================================================
-- PASO 10: CREAR VISTA
-- ============================================================================

SELECT '===== CREANDO VISTA =====' as paso;

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
    c.nombre as cargo_nombre
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
ORDER BY td.id_tipo_documento, fc.numero_paso;

SELECT '✓ Vista vw_flujo_aprobacion creada' as resultado;

-- ============================================================================
-- PASO 11: VERIFICACIÓN FINAL
-- ============================================================================

SELECT '===== VERIFICACIÓN FINAL =====' as paso;

SELECT COUNT(*) as total_registros FROM TblFlujoAprobacionCargos;

SELECT 
    td.nombre as Tipo,
    fc.numero_paso as Paso,
    c.nombre as Cargo,
    fc.nombre_paso as Nombre
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
ORDER BY td.id_tipo_documento, fc.numero_paso;

-- ============================================================================
-- PASO 12: RESUMEN
-- ============================================================================

SELECT '✅ TABLA TblFlujoAprobacionCargos CREADA Y CONFIGURADA CORRECTAMENTE' as ESTADO;

SELECT 'Tabla estructura:
┌─ id_flujo_cargo (PK, AUTO_INCREMENT)
├─ id_tipo_documento (FK → TblTipoDocumentoAprobacion)
├─ id_cargo (FK → TblCargo)
├─ numero_paso (1, 2, 3...)
├─ nombre_paso (texto)
├─ es_final, es_requerido, permite_rechazo (0/1)
└─ fecha_creacion, fecha_actualizacion' as ESTRUCTURA;

SELECT 'Datos insertados:
✓ Presupuesto: 3 pasos
✓ Requerimiento: 2 pasos
Total: 5 registros' as DATOS;

-- ============================================================================
-- FIN
-- ============================================================================

