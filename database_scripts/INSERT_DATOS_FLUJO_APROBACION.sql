-- ============================================================================
-- SCRIPT: INSERT_DATOS_FLUJO_APROBACION.sql
-- PROPÓSITO: Insertar datos iniciales en las tablas de flujo de aprobación
-- NOTAS: Se usan los ID de cargos reales de la BD
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- Limpiar datos existentes (si existen)
-- ============================================================================

DELETE FROM TblFlujoAprobacion WHERE 1=1;
DELETE FROM TblTipoDocumentoAprobacion WHERE 1=1;

-- ============================================================================
-- DATOS INICIALES - Tipos de Documentos
-- ============================================================================

INSERT INTO TblTipoDocumentoAprobacion (nombre, descripcion, icono, color, requiere_aprobacion, orden) VALUES
    ('Presupuesto', 'Presupuestos de proyectos y obras', 'fa-file-invoice-dollar', 'blue', 1, 1),
    ('Requerimiento', 'Requerimientos de materiales y servicios', 'fa-tasks', 'green', 1, 2),
    ('Orden de Compra', 'Órdenes de compra a proveedores', 'fa-shopping-cart', 'orange', 1, 3),
    ('Orden de Servicio', 'Órdenes de servicio a contratistas', 'fa-wrench', 'purple', 1, 4),
    ('Hoja de Salida', 'Solicitud de salida de materiales del almacén', 'fa-dolly', 'red', 0, 5);

-- Verificar que se insertaron
SELECT '=== TIPOS DE DOCUMENTOS INSERTADOS ===' as Info;
SELECT * FROM TblTipoDocumentoAprobacion;

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Presupuesto (ID=1)
-- Paso 1: Gerente Proyectos (48)
-- Paso 2: Gerente Operaciones (54)
-- Paso 3: Director General (13) - Final
-- ============================================================================

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (1, 1, 48, 'Revisión Técnica', 'Gerente de Proyectos valida especificaciones técnicas', 0, 1, 1),
    (1, 2, 54, 'Aprobación Operativa', 'Gerente de Operaciones valida recursos y viabilidad', 0, 1, 1),
    (1, 3, 13, 'Aprobación Final', 'Director General da visto bueno final', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Requerimiento (ID=2)
-- Paso 1: Gerente de Compras (51)
-- Paso 2: Gerente de Operaciones (54) - Final
-- ============================================================================

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (2, 1, 51, 'Verificación de Disponibilidad', 'Gerente de Compras verifica disponibilidad y proveedores', 0, 1, 1),
    (2, 2, 54, 'Aprobación de Presupuesto', 'Gerente de Operaciones valida presupuesto', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Orden de Compra (ID=3)
-- Paso 1: Gerente de Compras (51)
-- Paso 2: Director General (13) - Final
-- ============================================================================

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (3, 1, 51, 'Validación de Proveedor', 'Gerente de Compras valida proveedor y términos', 0, 1, 1),
    (3, 2, 13, 'Aprobación Final', 'Director General aprueba emisión de orden', 1, 1, 1);

-- ============================================================================
-- DATOS INICIALES - Flujo de Aprobación para Orden de Servicio (ID=4)
-- Paso 1: Gerente de Proyectos (48)
-- Paso 2: Gerente de Operaciones (54)
-- Paso 3: Director General (13) - Final
-- ============================================================================

INSERT INTO TblFlujoAprobacion (id_tipo_documento, numero_paso, id_cargo, nombre_paso, descripcion, es_final, es_requerido, permite_rechazo) VALUES
    (4, 1, 48, 'Revisión Técnica', 'Gerente de Proyectos valida alcance del servicio', 0, 1, 1),
    (4, 2, 54, 'Aprobación de Términos', 'Gerente de Operaciones valida términos y condiciones', 0, 1, 1),
    (4, 3, 13, 'Aprobación Final', 'Director General aprueba contratación', 1, 1, 1);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '=== FLUJO PRESUPUESTO ===' as Info;
SELECT 
    tp.id_tipo_documento,
    tp.nombre as 'Tipo Documento',
    fa.numero_paso as 'Paso',
    c.nombre as 'Cargo Aprobador',
    fa.nombre_paso as 'Nombre del Paso',
    fa.es_final as 'Es Final'
FROM TblFlujoAprobacion fa
JOIN TblTipoDocumentoAprobacion tp ON fa.id_tipo_documento = tp.id_tipo_documento
JOIN TblCargo c ON fa.id_cargo = c.id_cargo
WHERE tp.id_tipo_documento = 1
ORDER BY fa.numero_paso;

SELECT '=== FLUJO REQUERIMIENTO ===' as Info;
SELECT 
    tp.id_tipo_documento,
    tp.nombre as 'Tipo Documento',
    fa.numero_paso as 'Paso',
    c.nombre as 'Cargo Aprobador',
    fa.nombre_paso as 'Nombre del Paso',
    fa.es_final as 'Es Final'
FROM TblFlujoAprobacion fa
JOIN TblTipoDocumentoAprobacion tp ON fa.id_tipo_documento = tp.id_tipo_documento
JOIN TblCargo c ON fa.id_cargo = c.id_cargo
WHERE tp.id_tipo_documento = 2
ORDER BY fa.numero_paso;

SELECT '=== FLUJO ORDEN DE COMPRA ===' as Info;
SELECT 
    tp.id_tipo_documento,
    tp.nombre as 'Tipo Documento',
    fa.numero_paso as 'Paso',
    c.nombre as 'Cargo Aprobador',
    fa.nombre_paso as 'Nombre del Paso',
    fa.es_final as 'Es Final'
FROM TblFlujoAprobacion fa
JOIN TblTipoDocumentoAprobacion tp ON fa.id_tipo_documento = tp.id_tipo_documento
JOIN TblCargo c ON fa.id_cargo = c.id_cargo
WHERE tp.id_tipo_documento = 3
ORDER BY fa.numero_paso;

SELECT '=== FLUJO ORDEN DE SERVICIO ===' as Info;
SELECT 
    tp.id_tipo_documento,
    tp.nombre as 'Tipo Documento',
    fa.numero_paso as 'Paso',
    c.nombre as 'Cargo Aprobador',
    fa.nombre_paso as 'Nombre del Paso',
    fa.es_final as 'Es Final'
FROM TblFlujoAprobacion fa
JOIN TblTipoDocumentoAprobacion tp ON fa.id_tipo_documento = tp.id_tipo_documento
JOIN TblCargo c ON fa.id_cargo = c.id_cargo
WHERE tp.id_tipo_documento = 4
ORDER BY fa.numero_paso;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
