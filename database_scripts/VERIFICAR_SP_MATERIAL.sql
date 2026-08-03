-- ==============================================================================
-- VERIFICACIÓN: Stored Procedure sp_CrearMaterialConCodigoAuto
-- ==============================================================================
-- Ejecuta este script para verificar que el SP funcione correctamente
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ==============================================================================
-- PASO 1: Verificar que el SP existe
-- ==============================================================================
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED,
    LAST_ALTERED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
  AND ROUTINE_NAME = 'sp_CrearMaterialConCodigoAuto';
  
-- Si retorna 1 fila: ✅ SP existe
-- Si retorna 0 filas: ❌ SP NO existe, debes ejecutar sp_CrearMaterialConCodigoAuto.sql

-- ==============================================================================
-- PASO 2: Verificar estructura de TblMateriales
-- ==============================================================================
DESCRIBE TblMateriales;

-- Debe tener estas columnas:
-- id_material, codigo_material, nombre, descripcion, id_categoria, id_unidad
-- cantidad_stock, cantidad_minima, precio_unitario, observaciones, id_proveedor
-- fecha_ultimo_compra, estado, fecha_creacion

-- ==============================================================================
-- PASO 3: Ver materiales existentes con código MAT-XXX
-- ==============================================================================
SELECT 
    codigo_material,
    nombre,
    estado,
    fecha_creacion
FROM TblMateriales 
WHERE codigo_material LIKE 'MAT-%'
ORDER BY codigo_material DESC
LIMIT 10;

-- ==============================================================================
-- PASO 4: Probar el SP manualmente
-- ==============================================================================
CALL sp_CrearMaterialConCodigoAuto(
    'Material de Prueba Manual',  -- nombre
    'Descripción de prueba desde MySQL',  -- descripcion
    NULL,  -- id_categoria (opcional)
    1,  -- id_unidad (1 = Unidad, ajusta según tu BD)
    0.00,  -- precio_unitario
    0,  -- cantidad_stock
    0,  -- cantidad_minima
    'Observaciones de prueba',  -- observaciones
    @id_creado,  -- OUT id_material_creado
    @codigo_gen,  -- OUT codigo_generado
    @resultado  -- OUT resultado
);

-- Ver los resultados
SELECT 
    @id_creado as 'ID Creado', 
    @codigo_gen as 'Código Generado', 
    @resultado as 'Resultado (1=éxito, 0=error)';

-- Si Resultado = 1: ✅ SP funciona correctamente
-- Si Resultado = 0: ❌ Hay un error en el SP

-- ==============================================================================
-- PASO 5: Si resultado=0, verificar errores comunes
-- ==============================================================================

-- Verificar que id_unidad=1 existe
SELECT * FROM TblUnidadMedida WHERE id_unidad = 1;

-- Ver todas las unidades disponibles
SELECT id_unidad, nombre, abreviatura, estado 
FROM TblUnidadMedida 
WHERE estado = 'ACTIVO'
ORDER BY nombre;

-- ==============================================================================
-- PASO 6: Si el SP no existe, ejecutar la creación
-- ==============================================================================
-- Abre y ejecuta el archivo: sp_CrearMaterialConCodigoAuto.sql
-- Luego vuelve a ejecutar este script desde el PASO 1

-- ==============================================================================
-- FIN VERIFICACIÓN
-- ==============================================================================
