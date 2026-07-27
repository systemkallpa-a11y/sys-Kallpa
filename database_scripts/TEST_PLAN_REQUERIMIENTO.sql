-- ============================================================================
-- PLAN DE PRUEBAS: Sistema de Requerimientos Kallpa
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 0: Setup Initial (SOLO UNA VEZ)
-- Ejecutar en este orden:
-- 1. CREATE_TBL_REQUERIMIENTO_DETALLE.sql
-- 2. SETUP_REQUERIMIENTO_FINAL.sql
-- 3. sp_CrearRequerimientoCompleto.sql

-- ============================================================================
-- TEST 1: Verificar estructura de tablas
-- ============================================================================

SELECT '=== TEST 1: Estructura de Tablas ===' as test;

-- Verificar TblRequerimiento
SHOW COLUMNS FROM TblRequerimiento;

-- Verificar TblRequerimientoDetalle - NO debe tener FK en id_material
DESCRIBE TblRequerimientoDetalle;

-- Listar todas las constraints/FKs
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME IN ('TblRequerimiento', 'TblRequerimientoDetalle')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- ============================================================================
-- TEST 2: Obtener un presupuesto para probar
-- ============================================================================

SELECT '=== TEST 2: Presupuesto de Prueba ===' as test;

-- Obtener ID de presupuesto (limitado a 1)
SELECT 
    @test_pres_id:=id_presupuesto,
    numero_presupuesto,
    estado,
    monto
FROM TblPresupuesto
WHERE estado = 'Pendiente' OR estado = 'Aprobado'
LIMIT 1;

SELECT 'Presupuesto ID:' as info, @test_pres_id as id;

-- Ver detalles del presupuesto
SELECT 
    'DETALLES DEL PRESUPUESTO' as seccion,
    id_detalle,
    id_material,
    tipo_item,
    descripcion,
    cantidad,
    observaciones
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @test_pres_id;

-- ============================================================================
-- TEST 3: Obtener usuario de prueba
-- ============================================================================

SELECT '=== TEST 3: Usuario de Prueba ===' as test;

SELECT 
    @test_usuario:=num_usuario,
    usuario,
    num_documento
FROM TblUsuario
WHERE estado = 'Activo'
LIMIT 1;

SELECT 'Usuario ID:' as info, @test_usuario as id;

-- ============================================================================
-- TEST 4: Probar SP con JSON
-- ============================================================================

SELECT '=== TEST 4: Ejecutar SP sp_CrearRequerimientoCompleto ===' as test;

-- Preparar JSON de detalles (usando IDs de presupuesto detalle real)
SET @test_json = JSON_ARRAY(
    JSON_OBJECT('id_detalle_presupuesto', (SELECT MIN(id_detalle) FROM TblPresupuestoDetalle WHERE id_presupuesto = @test_pres_id)),
    JSON_OBJECT('id_detalle_presupuesto', (SELECT MAX(id_detalle) FROM TblPresupuestoDetalle WHERE id_presupuesto = @test_pres_id))
);

SELECT 'JSON preparado:' as info, @test_json as json;

-- Llamar SP
CALL sp_CrearRequerimientoCompleto(
    @test_usuario,
    'Requerimiento de prueba desde SP',
    'Observaciones de prueba',
    @test_json,
    @new_req_id
);

SELECT 'Nuevo requerimiento creado con ID:' as info, @new_req_id as id;

-- ============================================================================
-- TEST 5: Verificar requerimiento creado
-- ============================================================================

SELECT '=== TEST 5: Verificar Requerimiento Creado ===' as test;

-- Ver requerimiento creado
SELECT 
    'REQUERIMIENTO' as tabla,
    *
FROM TblRequerimiento
WHERE id_requerimiento = @new_req_id;

-- Ver detalles del requerimiento
SELECT 
    'DETALLES DEL REQUERIMIENTO' as tabla,
    id_detalle,
    id_requerimiento,
    id_material,
    tipo_item,
    descripcion,
    cantidad,
    unidad_medida,
    observaciones
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @new_req_id;

-- ============================================================================
-- TEST 6: Validar id_material se insertó correctamente
-- ============================================================================

SELECT '=== TEST 6: Validar id_material ===' as test;

SELECT 
    'Validación id_material' as validacion,
    COUNT(*) as total_items,
    SUM(CASE WHEN tipo_item = 'MATERIAL' AND id_material IS NULL THEN 1 ELSE 0 END) as materiales_sin_id,
    SUM(CASE WHEN tipo_item = 'MATERIAL' AND id_material IS NOT NULL THEN 1 ELSE 0 END) as materiales_con_id,
    SUM(CASE WHEN tipo_item = 'SERVICIO' AND id_material IS NULL THEN 1 ELSE 0 END) as servicios_ok,
    SUM(CASE WHEN tipo_item = 'SERVICIO' AND id_material IS NOT NULL THEN 1 ELSE 0 END) as servicios_error
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @new_req_id;

-- Mostrar detalles con descripción de estado
SELECT 
    rd.id_detalle,
    rd.tipo_item,
    CASE 
        WHEN rd.tipo_item = 'MATERIAL' AND rd.id_material IS NOT NULL THEN 'MATERIAL - OK'
        WHEN rd.tipo_item = 'MATERIAL' AND rd.id_material IS NULL THEN 'MATERIAL - FALTA id_material'
        WHEN rd.tipo_item = 'SERVICIO' AND rd.id_material IS NULL THEN 'SERVICIO - OK'
        WHEN rd.tipo_item = 'SERVICIO' AND rd.id_material IS NOT NULL THEN 'SERVICIO - DEBERÍA SER NULL'
        ELSE 'DESCONOCIDO'
    END as estado,
    rd.descripcion,
    COALESCE(m.nombre, 'N/A') as material_nombre
FROM TblRequerimientoDetalle rd
LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
WHERE rd.id_requerimiento = @new_req_id;

-- ============================================================================
-- TEST 7: Limpiar datos de prueba (OPCIONAL)
-- ============================================================================

SELECT '=== TEST 7: Limpieza (OPCIONAL) ===' as test;

-- Para eliminar el requerimiento de prueba, descomenta:
-- SET SQL_SAFE_UPDATES = 0;
-- DELETE FROM TblRequerimientoDetalle WHERE id_requerimiento = @new_req_id;
-- DELETE FROM TblRequerimiento WHERE id_requerimiento = @new_req_id;
-- SET SQL_SAFE_UPDATES = 1;
