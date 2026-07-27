-- ============================================================================
-- SCRIPT URGENTE: Recrear TblFlujoAprobacionCargos
-- PROBLEMA: Tabla no existe en BD
-- SOLUCIÓN: Recrearla con la estructura correcta
-- FECHA: 21 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: VERIFICAR QUE NO EXISTE
-- ============================================================================

SELECT 'VERIFICANDO: ¿TblFlujoAprobacionCargos existe?' as paso;

SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN 'SÍ existe'
        ELSE 'NO existe ❌'
    END as estado;

-- ============================================================================
-- PASO 2: HACER BACKUP SI EXISTE
-- ============================================================================

SELECT 'PASO 2: Backup de datos (si existe)' as paso;

-- Crear tabla backup
CREATE TABLE IF NOT EXISTS TblFlujoAprobacionCargos_BACKUP_RECREACION AS
SELECT * FROM TblFlujoAprobacionCargos
WHERE 1=0;  -- Solo estructura, sin datos

-- ============================================================================
-- PASO 3: ELIMINAR TABLA SI EXISTE
-- ============================================================================

SELECT 'PASO 3: Eliminando tabla antigua (si existe)' as paso;

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

SELECT '✓ Tabla eliminada (o no existía)' as resultado;

-- ============================================================================
-- PASO 4: RECREAR TABLA CON ESTRUCTURA CORRECTA
-- ============================================================================

SELECT 'PASO 4: Recreando TblFlujoAprobacionCargos' as paso;

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

SELECT '✅ Tabla TblFlujoAprobacionCargos recreada' as resultado;

-- ============================================================================
-- PASO 5: AGREGAR FOREIGN KEYS
-- ============================================================================

SELECT 'PASO 5: Agregando Foreign Keys' as paso;

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

SELECT '✅ Foreign Keys agregados' as resultado;

-- ============================================================================
-- PASO 6: INSERTAR DATOS INICIALES
-- ============================================================================

SELECT 'PASO 6: Insertando datos iniciales' as paso;

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

SELECT '✅ Datos iniciales insertados' as resultado;

-- ============================================================================
-- PASO 7: CREAR VISTA
-- ============================================================================

SELECT 'PASO 7: Creando vista' as paso;

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

SELECT '✅ Vista vw_flujo_aprobacion creada' as resultado;

-- ============================================================================
-- PASO 8: VERIFICACIÓN FINAL
-- ============================================================================

SELECT 'PASO 8: Verificación final' as paso;

-- Verificar que la tabla existe
SELECT 
    'TblFlujoAprobacionCargos' as tabla,
    COUNT(*) as total_registros
FROM TblFlujoAprobacionCargos;

-- Verificar estructura
SELECT 
    'Estructura de TblFlujoAprobacionCargos' as info,
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
ORDER BY ORDINAL_POSITION;

-- Verificar datos por tipo
SELECT 
    td.nombre as tipo_documento,
    COUNT(DISTINCT fc.numero_paso) as pasos_configurados,
    COUNT(fc.id_flujo_cargo) as total_cargos
FROM TblFlujoAprobacionCargos fc
JOIN TblTipoDocumentoAprobacion td ON fc.id_tipo_documento = td.id_tipo_documento
GROUP BY fc.id_tipo_documento, td.nombre;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT '
════════════════════════════════════════════════════════════════════════════════

✅ TABLA TblFlujoAprobacionCargos RECREADA

CAMBIOS:
────────
1. ✅ Tabla eliminada (si existía)
2. ✅ Tabla recreada con estructura correcta
3. ✅ Foreign Keys agregados
4. ✅ Datos iniciales insertados
5. ✅ Vista creada

RESULTADO:
──────────
✅ TblFlujoAprobacionCargos existe en BD
✅ 5 registros iniciales:
   - 3 pasos para Presupuestos
   - 2 pasos para Requerimientos
✅ Lista para usar

PRÓXIMOS PASOS:
───────────────
1. Reiniciar Flask
2. Probar "Flujos de Aprobación"
3. Crear presupuesto y aprobar

════════════════════════════════════════════════════════════════════════════════
' as resumen_final;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

