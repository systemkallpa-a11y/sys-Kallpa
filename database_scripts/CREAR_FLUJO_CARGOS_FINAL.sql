-- ============================================================================
-- SCRIPT FINAL: Crear TblFlujoAprobacionCargos (SIN ERRORES)
-- PROPÓSITO: Crear tabla limpia sin conflictos
-- FECHA: 20 de Julio de 2026
-- NOTA: Script simple, directo, probado en MariaDB
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Eliminar tabla anterior si existe
-- ============================================================================

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

-- ============================================================================
-- PASO 2: Crear tabla limpia
-- ============================================================================

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
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_flujo_paso_cargo (id_tipo_documento, numero_paso, id_cargo),
    INDEX idx_tipo_doc (id_tipo_documento),
    INDEX idx_cargo (id_cargo),
    INDEX idx_paso (numero_paso),
    INDEX idx_activo (activo)
);

-- ============================================================================
-- PASO 3: Agregar claves foráneas UNA A UNA
-- ============================================================================

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_flujo_tipo 
FOREIGN KEY (id_tipo_documento) 
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_flujo_cargo 
FOREIGN KEY (id_cargo) 
REFERENCES TblCargo(id_cargo) 
ON DELETE RESTRICT ON UPDATE CASCADE;

-- ============================================================================
-- PASO 4: Insertar datos iniciales
-- ============================================================================

-- Presupuesto: 3 pasos
INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1, 1, 1),
(1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1, 2, 1),
(1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1, 3, 1);

-- Requerimiento: 2 pasos
INSERT INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1, 1, 1),
(2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1, 2, 1);

-- ============================================================================
-- PASO 5: Crear vista
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
    c.nombre as cargo_nombre
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
ORDER BY td.id_tipo_documento, fc.numero_paso;

-- ============================================================================
-- PASO 6: Verificación
-- ============================================================================

SELECT '✅ TABLA TblFlujoAprobacionCargos CREADA EXITOSAMENTE' as RESULTADO;

SELECT COUNT(*) as total_registros FROM TblFlujoAprobacionCargos;

SELECT 
    td.nombre as tipo_documento,
    fc.numero_paso as paso,
    c.nombre as cargo_aprobador,
    fc.nombre_paso as nombre_paso,
    fc.es_final as es_final
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
ORDER BY td.id_tipo_documento, fc.numero_paso;

SELECT '
════════════════════════════════════════════════════════════
✅ ÉXITO

Tabla: TblFlujoAprobacionCargos
Estado: Creada y lista para usar
Registros: 5 (Presupuesto 3 pasos + Requerimiento 2 pasos)
Vista: vw_flujo_aprobacion

Próximos pasos:
1. Ejecutar sp_AprobarPresupuesto_Progresivo_v2.sql
2. Ejecutar sp_RechazarPresupuesto_Progresivo_v2.sql
3. Editar app/routes/presupuesto.py (2 cambios)
4. Reiniciar Flask
════════════════════════════════════════════════════════════
' as STATUS;

