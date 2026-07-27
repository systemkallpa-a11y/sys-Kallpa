-- ============================================================================
-- SCRIPT: DIAGNOSTICO_ERROR_500_FLUJO_APROBACION.sql
-- PROPÓSITO: Diagnosticar el error 500 del endpoint /api/flujo-aprobacion/obtener-flujos
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '╔════════════════════════════════════════════════════════════════╗' as diagnostico;
SELECT '║  DIAGNÓSTICO: ERROR 500 FLUJO APROBACIÓN                      ║' as diagnostico;
SELECT '║  Endpoint: /api/flujo-aprobacion/obtener-flujos              ║' as diagnostico;
SELECT '╚════════════════════════════════════════════════════════════════╝' as diagnostico;

-- ============================================================================
-- PASO 1: VERIFICAR EXISTENCIA DE TABLAS
-- ============================================================================

SELECT '
═══════════════════════════════════════════════════════════════
✓ PASO 1: VERIFICAR EXISTENCIA DE TABLAS REQUERIDAS
═══════════════════════════════════════════════════════════════' as paso;

SELECT 
    TABLE_NAME,
    CASE WHEN TABLE_NAME IS NOT NULL THEN '✅ EXISTE' ELSE '❌ NO EXISTE' END as Estado
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND TABLE_NAME IN (
    'TblFlujoAprobacion',
    'TblTipoDocumentoAprobacion', 
    'TblFlujoAprobacionCargos',
    'TblCargo',
    'TblArea',
    'TblRegistroAprobacion'
)
ORDER BY TABLE_NAME;

-- ============================================================================
-- PASO 2: INFORMACIÓN DE DEBUG
-- ============================================================================

SELECT '
═══════════════════════════════════════════════════════════════
✓ PASO 2: MUESTRA DETALLADA DE DATOS
═══════════════════════════════════════════════════════════════' as paso;

SELECT 'Ejecutando Query del Endpoint:' as query_info;

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

-- ============================================================================
-- FIN DE DIAGNÓSTICO
-- ============================================================================
