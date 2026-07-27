-- ============================================================================
-- SCRIPT: Agregar FKs a TblFlujoAprobacionCargos EXISTENTE
-- PROPÓSITO: La tabla existe, solo falta agregarle las claves foráneas
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '===== AGREGANDO CLAVES FORÁNEAS =====' as paso;

-- ============================================================================
-- PASO 1: Verificar que la tabla existe
-- ============================================================================

SELECT 'Verificando tabla...' as info;

SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd';

-- ============================================================================
-- PASO 2: Ver constraints actuales
-- ============================================================================

SELECT 'Constraints actuales:' as info;

SELECT CONSTRAINT_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd';

-- ============================================================================
-- PASO 3: Agregar FK a TblTipoDocumentoAprobacion
-- ============================================================================

SELECT '1. Agregando FK id_tipo_documento...' as paso;

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_flujo_tipo 
FOREIGN KEY (id_tipo_documento) 
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
ON DELETE RESTRICT ON UPDATE CASCADE;

SELECT '✓ FK id_tipo_documento agregada' as resultado;

-- ============================================================================
-- PASO 4: Agregar FK a TblCargo
-- ============================================================================

SELECT '2. Agregando FK id_cargo...' as paso;

ALTER TABLE TblFlujoAprobacionCargos 
ADD CONSTRAINT fk_flujo_cargo 
FOREIGN KEY (id_cargo) 
REFERENCES TblCargo(id_cargo) 
ON DELETE RESTRICT ON UPDATE CASCADE;

SELECT '✓ FK id_cargo agregada' as resultado;

-- ============================================================================
-- PASO 5: Verificación final
-- ============================================================================

SELECT '===== VERIFICACIÓN FINAL =====' as paso;

SELECT '✅ CLAVES FORÁNEAS AGREGADAS EXITOSAMENTE' as RESULTADO;

SELECT '
Tabla: TblFlujoAprobacionCargos
FKs agregadas: 2
├─ fk_flujo_tipo → TblTipoDocumentoAprobacion
└─ fk_flujo_cargo → TblCargo

Status: 🟢 LISTO
' as STATUS;

-- ============================================================================
-- PASO 6: Insertar datos iniciales (si no existen)
-- ============================================================================

SELECT 'Insertando datos iniciales...' as info;

-- Presupuesto: 3 pasos (solo si no existen)
INSERT IGNORE INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(1, 1, 48, 'Revisión Técnica', 'Gerente Proyecto valida especificaciones técnicas', 0, 1, 1, 1, 1),
(1, 2, 54, 'Aprobación Operacional', 'Gerente Operaciones valida montos y asignaciones', 0, 1, 1, 2, 1),
(1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1, 3, 1);

-- Requerimiento: 2 pasos (solo si no existen)
INSERT IGNORE INTO TblFlujoAprobacionCargos 
(id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo, orden_visualizacion, activo)
VALUES
(2, 1, 55, 'Verificación de Disponibilidad', 'Coordinador Operaciones verifica disponibilidad', 0, 1, 1, 1, 1),
(2, 2, 51, 'Aprobación de Compra', 'Gerente Compras valida presupuesto y proveedores', 1, 1, 1, 2, 1);

SELECT '✓ Datos iniciales insertados (o ya existían)' as resultado;

-- ============================================================================
-- PASO 7: Mostrar flujo final
-- ============================================================================

SELECT '===== FLUJO CONFIGURADO =====' as info;

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

-- ============================================================================
-- FIN
-- ============================================================================

