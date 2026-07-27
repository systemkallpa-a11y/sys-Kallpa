-- ============================================================================
-- SCRIPT: Diagnóstico de estructura de TblUsuario
-- DESCRIPCIÓN: Verifica qué columnas tiene TblUsuario
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '========== VERIFICANDO ESTRUCTURA DE TblUsuario ==========' as paso;

-- PASO 1: Describir tabla
SELECT 'PASO 1: Estructura de TblUsuario' as paso;
DESCRIBE TblUsuario;

-- PASO 2: Ver todas las columnas con detalles
SELECT 'PASO 2: Columnas con información detallada' as paso;
SELECT 
    COLUMN_NAME as columna,
    DATA_TYPE as tipo_dato,
    IS_NULLABLE as nullable,
    COLUMN_KEY as clave,
    COLUMN_DEFAULT as valor_defecto
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblUsuario'
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- PASO 3: Ver sample de datos
SELECT 'PASO 3: Sample de datos (primeros 3 usuarios)' as paso;
SELECT * FROM TblUsuario LIMIT 3;

-- PASO 4: Verificar qué columnas tienen "nombre" o "nombre_usuario"
SELECT 'PASO 4: Buscando columnas con nombre' as paso;
SELECT 
    COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblUsuario'
  AND TABLE_SCHEMA = DATABASE()
  AND (COLUMN_NAME LIKE '%nombre%' OR COLUMN_NAME LIKE '%usuario%')
ORDER BY ORDINAL_POSITION;

SELECT '========== DIAGNÓSTICO COMPLETADO ==========' as estado;
