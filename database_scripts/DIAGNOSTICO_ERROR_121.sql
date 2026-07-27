-- ============================================================================
-- SCRIPT: Diagnosticar Error 1005 errno 121
-- PROPÓSITO: Identificar qué está causando el conflicto de claves
-- FECHA: 20 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '===== DIAGNÓSTICO DE ERROR 1005 ERRNO 121 =====' as paso;

-- ============================================================================
-- PASO 1: Ver si la tabla existe y su estado actual
-- ============================================================================

SELECT '===== INFORMACIÓN DE TABLA =====' as paso;

SELECT TABLE_NAME, ENGINE, TABLE_COLLATION
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd';

-- ============================================================================
-- PASO 2: Ver todas las constraints de la tabla
-- ============================================================================

SELECT '===== CONSTRAINTS ACTUALES =====' as paso;

SELECT 
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
ORDER BY CONSTRAINT_NAME;

-- ============================================================================
-- PASO 3: Ver definición completa de la tabla
-- ============================================================================

SELECT '===== DEFINICIÓN COMPLETA =====' as paso;

SHOW CREATE TABLE TblFlujoAprobacionCargos\G

-- ============================================================================
-- PASO 4: Ver índices y sus duplicados
-- ============================================================================

SELECT '===== ÍNDICES =====' as paso;

SELECT 
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX,
    NON_UNIQUE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
ORDER BY INDEX_NAME, SEQ_IN_INDEX;

-- ============================================================================
-- PASO 5: Ver triggers si los hay
-- ============================================================================

SELECT '===== TRIGGERS =====' as paso;

SHOW TRIGGERS LIKE 'TblFlujoAprobacionCargos%';

-- ============================================================================
-- PASO 6: Ver qué tablas referencian a TblFlujoAprobacionCargos
-- ============================================================================

SELECT '===== TABLAS QUE REFERENCIAN ESTA TABLA =====' as paso;

SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME = 'TblFlujoAprobacionCargos'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd';

-- ============================================================================
-- PASO 7: Verificar integridad referencial
-- ============================================================================

SELECT '===== VERIFICACIÓN DE INTEGRIDAD =====' as paso;

-- Contar registros
SELECT COUNT(*) as total_registros FROM TblFlujoAprobacionCargos;

-- Ver si hay duplicados en clave única
SELECT 
    id_tipo_documento, 
    numero_paso, 
    id_cargo, 
    COUNT(*) as cantidad
FROM TblFlujoAprobacionCargos
GROUP BY id_tipo_documento, numero_paso, id_cargo
HAVING COUNT(*) > 1;

-- ============================================================================
-- PASO 8: RECOMENDACIÓN
-- ============================================================================

SELECT '
⚠️ ANÁLISIS COMPLETADO

El error errno 121 generalmente significa:
1. Hay una constraint duplicada
2. Hay un índice conflictivo
3. Hay una definición de FK que entra en conflicto

PASOS PARA SOLUCIONAR:

Opción A: Si los índices están duplicados
────────────────────────────────────────
ALTER TABLE TblFlujoAprobacionCargos DROP INDEX nombre_indice_duplicado;

Opción B: Si hay constraints conflictivas
──────────────────────────────────────────
ALTER TABLE TblFlujoAprobacionCargos DROP FOREIGN KEY nombre_fk;

Opción C: NUCLEAR - Eliminar tabla completamente
──────────────────────────────────────────────
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS TblFlujoAprobacionCargos;
DROP TABLE IF EXISTS TblFlujoAprobacionCargos_backup;
SET FOREIGN_KEY_CHECKS = 1;

Luego ejecutar: LIMPIAR_Y_CREAR_FLUJO_CARGOS_ULTRA_LIMPIO.sql

' as RECOMENDACIONES;

-- ============================================================================
-- FIN
-- ============================================================================

