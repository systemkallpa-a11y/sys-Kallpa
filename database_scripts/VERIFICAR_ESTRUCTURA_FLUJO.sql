-- ============================================================================
-- VERIFICAR ESTRUCTURA ACTUAL DE TABLAS DE FLUJO
-- Ejecuta esto para diagnosticar la causa del error 500
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- 1. VER TODAS LAS TABLAS RELACIONADAS
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 1: VERIFICAR EXISTENCIA DE TABLAS                     ║
╚════════════════════════════════════════════════════════════╝
' AS info;

SELECT 
    TABLE_NAME,
    CASE WHEN TABLE_NAME = 'TblFlujoAprobacion' THEN '⭐ CRÍTICA'
         WHEN TABLE_NAME = 'TblFlujoAprobacionCargos' THEN '🆕 NUEVA'
         ELSE '📦 SOPORTE'
    END as tipo
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND TABLE_NAME IN ('TblFlujoAprobacion', 'TblFlujoAprobacionCargos', 'TblTipoDocumentoAprobacion', 'TblCargo', 'TblArea', 'TblRegistroAprobacion')
ORDER BY TABLE_NAME;

-- 2. VER ESTRUCTURA DE TblFlujoAprobacion (MÁS IMPORTANTE)
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 2: ESTRUCTURA DE TblFlujoAprobacion                   ║
║ ¿Tiene columna id_cargo?                                   ║
║ Si NO → Está en estructura NUEVA (tabla intermedia)        ║
║ Si SÍ → Está en estructura ANTIGUA (deprecated)            ║
╚════════════════════════════════════════════════════════════╝
' AS info;

SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    COLUMN_KEY,
    CASE 
        WHEN COLUMN_NAME = 'id_cargo' THEN '⚠️ ANTIGUA ESTRUCTURA'
        WHEN COLUMN_NAME IN ('id_flujo_aprobacion', 'id_tipo_documento') THEN '✅ CORRECTA'
        ELSE ''
    END as nota
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND TABLE_NAME = 'TblFlujoAprobacion'
ORDER BY ORDINAL_POSITION;

-- 3. VER SI EXISTE TABLA INTERMEDIA
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 3: ¿EXISTE TblFlujoAprobacionCargos?                  ║
╚════════════════════════════════════════════════════════════╝
' AS info;

CASE 
    WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA='kallgwkn_kallpa_bd' 
        AND TABLE_NAME='TblFlujoAprobacionCargos'
    ) THEN SELECT '✅ SÍ EXISTE - Estructura NUEVA está instalada' as estado
    ELSE SELECT '❌ NO EXISTE - Necesita instalarse con IMPLEMENTAR_FLUJO_APROBACION_MULTIPLES_CARGOS.sql' as estado
END;

-- 4. VER DATOS DE EJEMPLO
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 4: DATOS DE EJEMPLO EN TblFlujoAprobacion             ║
╚════════════════════════════════════════════════════════════╝
' AS info;

SELECT * FROM TblFlujoAprobacion LIMIT 3;

-- 5. INTENTAR EJECUTAR LA QUERY NUEVA (ESTRUCTURA CON TABLA INTERMEDIA)
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 5: TEST QUERY NUEVA (con tabla intermedia)            ║
║ Si hay error = Tabla intermedia no existe                  ║
╚════════════════════════════════════════════════════════════╝
' AS info;

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
LIMIT 5;

-- 6. SI FALLA ARRIBA, INTENTAR QUERY ANTIGUA (SIN TABLA INTERMEDIA)
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 6: TEST QUERY ANTIGUA (sin tabla intermedia)          ║
║ Esto es fallback si no existe TblFlujoAprobacionCargos      ║
╚════════════════════════════════════════════════════════════╝
' AS info;

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
    fa.id_cargo,
    c.nombre as cargo_nombre,
    a.nombre as area_nombre,
    0 as orden_visualizacion
FROM TblFlujoAprobacion fa
LEFT JOIN TblTipoDocumentoAprobacion td ON fa.id_tipo_documento = td.id_tipo_documento
LEFT JOIN TblCargo c ON fa.id_cargo = c.id_cargo
LEFT JOIN TblArea a ON c.id_area = a.id_area
ORDER BY fa.id_tipo_documento ASC, fa.numero_paso ASC
LIMIT 5;

-- 7. CONTAR REGISTROS EN CADA TABLA
SELECT '
╔════════════════════════════════════════════════════════════╗
║ PASO 7: CANTIDAD DE REGISTROS                              ║
╚════════════════════════════════════════════════════════════╝
' AS info;

SELECT 
    'TblTipoDocumentoAprobacion' as tabla, COUNT(*) as registros FROM TblTipoDocumentoAprobacion
UNION ALL
SELECT 'TblFlujoAprobacion', COUNT(*) FROM TblFlujoAprobacion
UNION ALL
SELECT 'TblFlujoAprobacionCargos', COUNT(*) FROM TblFlujoAprobacionCargos
UNION ALL
SELECT 'TblCargo', COUNT(*) FROM TblCargo
UNION ALL
SELECT 'TblArea', COUNT(*) FROM TblArea;

SELECT '
╔════════════════════════════════════════════════════════════╗
║ ✅ DIAGNÓSTICO COMPLETADO                                 ║
║                                                            ║
║ Si ves datos en PASO 5 → Estructura NUEVA está OK          ║
║ Si PASO 5 falla pero PASO 6 funciona → Usar estructura ANTIGUA
║ Si ambas fallan → Problema de datos o configuración        ║
╚════════════════════════════════════════════════════════════╝
' AS resultado;
