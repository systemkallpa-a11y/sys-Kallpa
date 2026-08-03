-- ==============================================================================
-- TEST RÁPIDO: Verificar SP
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ==============================================================================
-- 1. ¿El SP existe?
-- ==============================================================================
SELECT 
    ROUTINE_NAME,
    CREATED,
    LAST_ALTERED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND ROUTINE_NAME = 'sp_CrearMaterialConCodigoAuto';

-- Si esto retorna 0 filas → ❌ EL SP NO EXISTE
-- Si retorna 1 fila → ✅ El SP existe

-- ==============================================================================
-- 2. ¿Cuál es el último código MAT-XXX?
-- ==============================================================================
SELECT 
    codigo_material,
    nombre,
    fecha_creacion
FROM TblMateriales
WHERE codigo_material LIKE 'MAT-%'
ORDER BY codigo_material DESC
LIMIT 1;

-- Debe mostrar: MAT-007

-- ==============================================================================
-- 3. Probar el SP
-- ==============================================================================
CALL sp_CrearMaterialConCodigoAuto(
    'Casco Blanco Test',
    'Casco de staff',
    25,
    1,
    0.00,
    0,
    0,
    'test',
    @id,
    @codigo,
    @resultado
);

SELECT @id, @codigo, @resultado;

-- Si @resultado = 0 → ❌ ERROR EN EL SP
-- Si @resultado = 1 → ✅ FUNCIONÓ

-- ==============================================================================
-- 4. Ver el error (si existe)
-- ==============================================================================
SHOW ERRORS;
SHOW WARNINGS;

-- ==============================================================================
-- FIN TEST
-- ==============================================================================
