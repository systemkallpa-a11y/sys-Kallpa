-- =============================================================================
-- FIX: Corregir CHECK CONSTRAINT chk_nombres_solo_letras
-- =============================================================================
-- Problema: La restricción actual SOLO permite letras MINÚSCULAS
-- Actual:   `nombres` regexp '^[a-záéíóúñs]+$'
--           ❌ No permite mayúsculas
--           ❌ No permite espacios
--
-- Corrección: Permitir MAYÚSCULAS, minúsculas, espacios y acentos
-- Nuevo:      `nombres` regexp '^[A-Za-záéíóúñÑ ]+$'
--             ✅ Permite mayúsculas
--             ✅ Permite minúsculas
--             ✅ Permite acentos (á, é, í, ó, ú, Á, É, Í, Ó, Ú)
--             ✅ Permite Ñ mayúscula y minúscula (ñ)
--             ✅ Permite ESPACIOS (Juan Carlos)
--             ❌ No permite espacios al inicio/final (TRIM() lo maneja)
-- =============================================================================

USE kallgwkn_kallpa_bd;

-- Paso 1: Eliminar la restricción antigua
ALTER TABLE TblPersona DROP CONSTRAINT chk_nombres_solo_letras;

-- Paso 2: Agregar la restricción nueva (corregida)
ALTER TABLE TblPersona ADD CONSTRAINT chk_nombres_solo_letras
CHECK (`nombres` REGEXP '^[A-Za-záéíóúñÑ ]+$');

-- Paso 3: Hacer lo mismo para apellido_paterno
ALTER TABLE TblPersona DROP CONSTRAINT chk_apellido_paterno_solo_letras;

ALTER TABLE TblPersona ADD CONSTRAINT chk_apellido_paterno_solo_letras
CHECK (`apellido_paterno` REGEXP '^[A-Za-záéíóúñÑ ]+$');

-- Paso 4: Hacer lo mismo para apellido_materno
ALTER TABLE TblPersona DROP CONSTRAINT chk_apellido_materno_solo_letras;

ALTER TABLE TblPersona ADD CONSTRAINT chk_apellido_materno_solo_letras
CHECK (`apellido_materno` IS NULL OR `apellido_materno` REGEXP '^[A-Za-záéíóúñÑ ]+$');

-- Verificación
SELECT CONSTRAINT_NAME, CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
AND CONSTRAINT_NAME IN (
    'chk_nombres_solo_letras',
    'chk_apellido_paterno_solo_letras',
    'chk_apellido_materno_solo_letras'
);
