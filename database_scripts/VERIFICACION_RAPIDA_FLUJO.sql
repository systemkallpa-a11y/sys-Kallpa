-- ============================================================================
-- VERIFICACIÓN RÁPIDA: ERROR 500 FLUJO APROBACIÓN
-- Ejecuta esto en MySQL Workbench para diagnosticar el problema
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- 1. ¿EXISTEN LAS TABLAS?
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 1. VERIFICAR EXISTENCIA DE TABLAS                          ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT 
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblFlujoAprobacion') THEN '✅' ELSE '❌' END as 'TblFlujoAprobacion',
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblTipoDocumentoAprobacion') THEN '✅' ELSE '❌' END as 'TblTipoDocumentoAprobacion',
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblFlujoAprobacionCargos') THEN '✅' ELSE '❌' END as 'TblFlujoAprobacionCargos',
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblCargo') THEN '✅' ELSE '❌' END as 'TblCargo',
    CASE WHEN EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblArea') THEN '✅' ELSE '❌' END as 'TblArea';

-- 2. COLUMNAS EN TblFlujoAprobacion
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 2. COLUMNAS EN TblFlujoAprobacion                          ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT COLUMN_NAME, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblFlujoAprobacion' 
ORDER BY ORDINAL_POSITION;

-- 3. COLUMNAS EN TblFlujoAprobacionCargos
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 3. COLUMNAS EN TblFlujoAprobacionCargos                    ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT COLUMN_NAME, COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' AND TABLE_NAME='TblFlujoAprobacionCargos' 
ORDER BY ORDINAL_POSITION;

-- 4. CANTIDAD DE REGISTROS
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 4. CANTIDAD DE REGISTROS                                   ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT 
    (SELECT COUNT(*) FROM TblTipoDocumentoAprobacion) as 'TblTipoDocumentoAprobacion',
    (SELECT COUNT(*) FROM TblFlujoAprobacion) as 'TblFlujoAprobacion',
    (SELECT COUNT(*) FROM TblFlujoAprobacionCargos) as 'TblFlujoAprobacionCargos',
    (SELECT COUNT(*) FROM TblCargo) as 'TblCargo',
    (SELECT COUNT(*) FROM TblArea) as 'TblArea';

-- 5. DATOS MUESTRA - TIPOS DE DOCUMENTO
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 5. DATOS MUESTRA: Tipos de Documento                       ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT id_tipo_documento, nombre, descripcion FROM TblTipoDocumentoAprobacion LIMIT 5;

-- 6. DATOS MUESTRA - FLUJOS
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 6. DATOS MUESTRA: Flujos de Aprobación                     ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT id_flujo_aprobacion, id_tipo_documento, numero_paso, nombre_paso FROM TblFlujoAprobacion LIMIT 5;

-- 7. DATOS MUESTRA - FLUJOS-CARGOS
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 7. DATOS MUESTRA: Flujos - Cargos                          ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT id_flujo_cargo, id_flujo_aprobacion, id_cargo FROM TblFlujoAprobacionCargos LIMIT 5;

-- 8. TEST DE LA QUERY DEL ENDPOINT
SELECT '
╔════════════════════════════════════════════════════════════╗
║ 8. EJECUTAR QUERY DEL ENDPOINT (/obtener-flujos)           ║
╚════════════════════════════════════════════════════════════╝
' AS paso;

SELECT 
    fa.id_flujo_aprobacion,
    fa.id_tipo_documento,
    fa.numero_paso,
    fa.nombre_paso,
    fa.descripcion,
    fa.es_requerido,
    fa.permite_rechazo,
    fa.fecha_creacion,
    td.nombre as tipo_documento_nombre,
    c.id_cargo,
    c.nombre as cargo_nombre,
    a.nombre as area_nombre,
    tfc.orden_visualizacion
FROM TblFlujoAprobacion fa
LEFT JOIN TblTipoDocumentoAprobacion td ON fa.id_tipo_documento = td.id_tipo_documento
LEFT JOIN TblFlujoAprobacionCargos tfc ON fa.id_flujo_aprobacion = tfc.id_flujo_aprobacion
LEFT JOIN TblCargo c ON tfc.id_cargo = c.id_cargo
LEFT JOIN TblArea a ON c.id_area = a.id_area
ORDER BY fa.id_tipo_documento ASC, fa.numero_paso ASC, COALESCE(tfc.orden_visualizacion, 0) ASC
LIMIT 20;

SELECT '
╔════════════════════════════════════════════════════════════╗
║ ✅ DIAGNÓSTICO COMPLETADO                                 ║
║                                                            ║
║ Si ves datos en el paso 8, la estructura es CORRECTA      ║
║ Si ves error, copia el mensaje y busca solución            ║
╚════════════════════════════════════════════════════════════╝
' AS resultado;

