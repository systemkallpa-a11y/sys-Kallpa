-- ==============================================================================
-- DEBUG: Probar SP paso a paso
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ==============================================================================
-- PASO 1: Ver último código MAT-XXX
-- ==============================================================================
SELECT 
    codigo_material,
    SUBSTRING(codigo_material, 5) as parte_numerica,
    CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED) as numero
FROM TblMateriales
WHERE codigo_material LIKE 'MAT-%'
  AND codigo_material REGEXP '^MAT-[0-9]+$'
ORDER BY CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED) DESC
LIMIT 5;

-- Debería mostrar MAT-007 con número = 7

-- ==============================================================================
-- PASO 2: Calcular el siguiente código
-- ==============================================================================
SELECT 
    COALESCE(MAX(CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED)), 0) as ultimo_numero,
    COALESCE(MAX(CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED)), 0) + 1 as siguiente_numero,
    CONCAT('MAT-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED)), 0) + 1, 3, '0')) as nuevo_codigo
FROM TblMateriales
WHERE codigo_material LIKE 'MAT-%'
  AND codigo_material REGEXP '^MAT-[0-9]+$';

-- Debería mostrar: ultimo_numero=7, siguiente_numero=8, nuevo_codigo=MAT-008

-- ==============================================================================
-- PASO 3: Ver estructura de TblMateriales
-- ==============================================================================
SHOW COLUMNS FROM TblMateriales;

-- ==============================================================================
-- PASO 4: Probar INSERT manual (sin SP)
-- ==============================================================================
-- Probar si podemos insertar manualmente con los mismos datos

INSERT INTO TblMateriales (
    codigo_material,
    nombre,
    descripcion,
    id_categoria,
    id_unidad,
    cantidad_stock,
    cantidad_minima,
    precio_unitario,
    observaciones,
    id_proveedor,
    fecha_ultimo_compra,
    estado,
    fecha_creacion
) VALUES (
    'MAT-999',  -- código de prueba
    'PRUEBA MANUAL',
    'Descripción de prueba',
    25,  -- tu id_categoria
    1,   -- tu id_unidad
    0,
    0,
    0.00,
    'Observaciones de prueba',
    NULL,
    NULL,
    'ACTIVO',
    NOW()
);

-- Si esto funciona, el problema NO es la tabla
-- Si esto falla, nos dará el error exacto

-- Ver el registro creado
SELECT * FROM TblMateriales WHERE codigo_material = 'MAT-999';

-- Eliminar la prueba
DELETE FROM TblMateriales WHERE codigo_material = 'MAT-999';

-- ==============================================================================
-- PASO 5: Probar el SP con datos simples
-- ==============================================================================
CALL sp_CrearMaterialConCodigoAuto(
    'Casco Blanco',  -- nombre
    'Casco de staff',  -- descripcion
    25,  -- id_categoria (el que usaste)
    1,   -- id_unidad (el que usaste)
    0.00,  -- precio_unitario
    0,  -- cantidad_stock
    0,  -- cantidad_minima
    'test',  -- observaciones
    @id_creado,
    @codigo_gen,
    @resultado
);

-- Ver resultado
SELECT 
    @id_creado as 'ID Creado', 
    @codigo_gen as 'Código Generado', 
    @resultado as 'Resultado (1=éxito, 0=error)',
    CASE 
        WHEN @resultado = 1 THEN '✅ ÉXITO'
        WHEN @resultado = 0 THEN '❌ ERROR - Revisar handler'
        ELSE '⚠️ DESCONOCIDO'
    END as Estado;

-- Si resultado = 1, ver el material creado
SELECT * FROM TblMateriales 
WHERE id_material = @id_creado;

-- ==============================================================================
-- PASO 6: Verificar que el SP existe
-- ==============================================================================
SELECT 
    ROUTINE_NAME as 'Nombre SP',
    CREATED as 'Fecha Creación',
    LAST_ALTERED as 'Última Modificación'
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND ROUTINE_NAME = 'sp_CrearMaterialConCodigoAuto';

-- Si retorna 0 filas: ❌ El SP NO existe, debes ejecutar sp_CrearMaterialConCodigoAuto.sql
-- Si retorna 1 fila: ✅ El SP existe

-- ==============================================================================
-- FIN DEBUG
-- ==============================================================================
