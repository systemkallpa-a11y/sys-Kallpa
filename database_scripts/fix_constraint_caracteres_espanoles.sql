-- ============================================================================
-- FIX: Permitir caracteres españoles (ñ, á, é, í, ó, ú) en nombres
-- ============================================================================
-- PROBLEMA: Los constraints solo permiten a-z A-Z, no aceptan ñ ni acentos
-- ERROR: Check constraint 'chk_apellido_materno_solo_letras' is violated
-- ============================================================================

USE `kallpasystem$kallgwkn_kallpa_bd`;

-- ============================================================================
-- 0. VERIFICAR CONSTRAINTS EXISTENTES
-- ============================================================================
SELECT '📋 PASO 0: Verificando constraints existentes...' as info;

SELECT 
    tc.CONSTRAINT_NAME,
    cc.CHECK_CLAUSE
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc 
    ON tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA 
    AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND tc.TABLE_NAME = 'TblPersona'
  AND tc.CONSTRAINT_TYPE = 'CHECK'
ORDER BY tc.CONSTRAINT_NAME;

-- ============================================================================
-- 1. ELIMINAR CONSTRAINTS ANTIGUOS (solo letras básicas)
-- ============================================================================
SELECT '🗑️ PASO 1: Eliminando constraints antiguos...' as info;

-- Para versiones de MySQL anteriores a 8.0.19, usamos DROP CONSTRAINT directo
ALTER TABLE TblPersona DROP CONSTRAINT chk_nombres_solo_letras;
ALTER TABLE TblPersona DROP CONSTRAINT chk_apellido_paterno_solo_letras;
ALTER TABLE TblPersona DROP CONSTRAINT chk_apellido_materno_solo_letras;

SELECT '✓ Constraints antiguos eliminados' as resultado;

-- ============================================================================
-- 2. CREAR NUEVOS CONSTRAINTS (con caracteres españoles)
-- ============================================================================
SELECT '✨ PASO 2: Creando nuevos constraints con soporte para español...' as info;

-- Nombres: Permite letras minúsculas, mayúsculas, espacios, ñ, Ñ, y vocales acentuadas
ALTER TABLE TblPersona ADD CONSTRAINT chk_nombres_solo_letras 
CHECK (REGEXP_LIKE(nombres, '^[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ ]+$'));

-- Apellido Paterno: Permite letras minúsculas, mayúsculas, espacios, ñ, Ñ, y vocales acentuadas
ALTER TABLE TblPersona ADD CONSTRAINT chk_apellido_paterno_solo_letras 
CHECK (REGEXP_LIKE(apellido_paterno, '^[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ ]+$'));

-- Apellido Materno: Permite letras minúsculas, mayúsculas, espacios, ñ, Ñ, y vocales acentuadas
-- (Permite NULL o vacío ya que es opcional)
ALTER TABLE TblPersona ADD CONSTRAINT chk_apellido_materno_solo_letras 
CHECK (apellido_materno IS NULL OR apellido_materno = '' OR REGEXP_LIKE(apellido_materno, '^[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ ]+$'));

SELECT '✓ Constraints actualizados con soporte para español' as resultado;

-- ============================================================================
-- 3. VERIFICAR NUEVOS CONSTRAINTS
-- ============================================================================
SELECT '🔍 PASO 3: Verificando nuevos constraints...' as info;

SELECT 
    tc.CONSTRAINT_NAME,
    cc.CHECK_CLAUSE
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.CHECK_CONSTRAINTS cc 
    ON tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA 
    AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND tc.TABLE_NAME = 'TblPersona'
  AND tc.CONSTRAINT_TYPE = 'CHECK'
  AND tc.CONSTRAINT_NAME LIKE 'chk_%letras'
ORDER BY tc.CONSTRAINT_NAME;

-- ============================================================================
-- 4. PRUEBA OPCIONAL (Comentado por seguridad)
-- ============================================================================

-- Descomenta estas líneas para probar que funciona:

/*
-- Crear persona de prueba con caracteres españoles
INSERT INTO TblPersona (
    num_documento, 
    documento_numero,
    tipo_documento,
    nombres, 
    apellido_paterno, 
    apellido_materno,
    email
) VALUES (
    9999999991,
    '99999999',
    'DNI',
    'José María', 
    'Peña', 
    'Núñez',
    'jose.nunez@test.com'
);

-- Si funciona, eliminar la prueba:
DELETE FROM TblPersona WHERE num_documento = 9999999991;
*/

-- ============================================================================
-- RESULTADO FINAL
-- ============================================================================

SELECT '✅ FIX APLICADO CORRECTAMENTE' as estado;
SELECT 'Ahora se aceptan los siguientes caracteres:' as info;
SELECT '  • Letras básicas: a-z, A-Z' as caracteres_1;
SELECT '  • Letra ñ: ñ, Ñ' as caracteres_2;
SELECT '  • Vocales acentuadas: á, é, í, ó, ú, Á, É, Í, Ó, Ú' as caracteres_3;
SELECT '  • Diéresis: ü, Ü' as caracteres_4;
SELECT '  • Espacios (para nombres compuestos)' as caracteres_5;

-- ============================================================================
-- EJEMPLOS DE NOMBRES VÁLIDOS:
-- ============================================================================
-- ✓ José María
-- ✓ María Ángeles
-- ✓ Peña
-- ✓ Núñez
-- ✓ Señán
-- ✓ Muñoz
-- ✓ Hernández
-- ============================================================================
