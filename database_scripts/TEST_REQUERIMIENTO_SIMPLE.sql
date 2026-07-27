-- ============================================================================
-- SCRIPT: Test Simple - Crear Requerimiento (Sin IF statements)
-- DESCRIPCIÓN: Test completo del sistema de requerimientos
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '====== INICIANDO TEST ======' as paso;

-- ============================================================================
-- PASO 1: Obtener datos de muestra
-- ============================================================================
SELECT '====== PASO 1: DATOS DE MUESTRA ======' as paso;

-- Obtener presupuesto
SELECT 
    @test_pres_id:=id_presupuesto,
    @test_pres_num:=numero_presupuesto,
    estado,
    monto
FROM TblPresupuesto
WHERE estado IN ('Pendiente', 'Aprobado', 'Completado')
LIMIT 1;

-- Obtener usuario
SELECT 
    @test_usuario:=num_usuario,
    @test_usuario_nombre:=usuario
FROM TblUsuario
WHERE estado = 'Activo'
LIMIT 1;

-- Mostrar selección
SELECT @test_pres_id as presupuesto_id, @test_usuario as usuario_id;

-- ============================================================================
-- PASO 2: Ver presupuesto seleccionado
-- ============================================================================
SELECT '====== PASO 2: PRESUPUESTO SELECCIONADO ======' as paso;

SELECT 
    id_detalle,
    id_material,
    tipo_item,
    SUBSTRING(descripcion, 1, 50) as descripcion,
    cantidad,
    precio_unitario,
    subtotal
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @test_pres_id
LIMIT 10;

-- Obtener IDs de detalles para usar en JSON
SELECT 
    @detalle_id_1:=MIN(id_detalle),
    @detalle_id_2:=MAX(id_detalle),
    @detalle_count:=COUNT(*)
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @test_pres_id;

SELECT CONCAT('Detalles encontrados: ', @detalle_count, ' | Rango: ', @detalle_id_1, ' a ', @detalle_id_2) as info;

-- ============================================================================
-- PASO 3: Preparar JSON
-- ============================================================================
SELECT '====== PASO 3: PREPARAR JSON ======' as paso;

SET @json_items = JSON_ARRAY(
    JSON_OBJECT('id_detalle_presupuesto', @detalle_id_1),
    JSON_OBJECT('id_detalle_presupuesto', @detalle_id_2)
);

SELECT CONCAT('JSON: ', @json_items) as json_content;

-- ============================================================================
-- PASO 4: Ejecutar SP
-- ============================================================================
SELECT '====== PASO 4: EJECUTAR SP ======' as paso;

CALL sp_CrearRequerimientoCompleto(
    @test_usuario,
    'Test Requerimiento Simple',
    'Test automático del sistema',
    @json_items,
    @nuevo_req_id
);

SELECT CONCAT('Requerimiento creado con ID: ', @nuevo_req_id) as resultado;

-- ============================================================================
-- PASO 5: Verificar Requerimiento
-- ============================================================================
SELECT '====== PASO 5: REQUERIMIENTO CREADO ======' as paso;

SELECT 
    id_requerimiento,
    codigo,
    num_usuario,
    descripcion,
    cantidad as cantidad_total,
    estado,
    fecha_creacion
FROM TblRequerimiento
WHERE id_requerimiento = @nuevo_req_id;

-- ============================================================================
-- PASO 6: Verificar Detalles
-- ============================================================================
SELECT '====== PASO 6: DETALLES DEL REQUERIMIENTO ======' as paso;

SELECT 
    rd.id_detalle,
    rd.tipo_item,
    rd.id_material,
    rd.descripcion,
    rd.cantidad,
    rd.unidad_medida,
    COALESCE(m.nombre, 'N/A') as material_nombre,
    CASE 
        WHEN rd.tipo_item = 'MATERIAL' AND rd.id_material IS NOT NULL THEN '✓ OK'
        WHEN rd.tipo_item = 'MATERIAL' AND rd.id_material IS NULL THEN '⚠️ FALTA ID'
        WHEN rd.tipo_item = 'SERVICIO' AND rd.id_material IS NULL THEN '✓ OK'
        WHEN rd.tipo_item = 'SERVICIO' AND rd.id_material IS NOT NULL THEN '❌ ERROR'
        ELSE '?'
    END as validacion
FROM TblRequerimientoDetalle rd
LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
WHERE rd.id_requerimiento = @nuevo_req_id;

-- ============================================================================
-- PASO 7: Estadísticas
-- ============================================================================
SELECT '====== PASO 7: ESTADÍSTICAS ======' as paso;

SELECT 
    COUNT(*) as total_items,
    SUM(CASE WHEN tipo_item = 'MATERIAL' THEN 1 ELSE 0 END) as materiales,
    SUM(CASE WHEN tipo_item = 'SERVICIO' THEN 1 ELSE 0 END) as servicios,
    SUM(CASE WHEN id_material IS NOT NULL THEN 1 ELSE 0 END) as items_con_id_material,
    SUM(CASE WHEN id_material IS NULL THEN 1 ELSE 0 END) as items_sin_id_material
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @nuevo_req_id;

-- ============================================================================
-- PASO 8: Comparativa
-- ============================================================================
SELECT '====== PASO 8: COMPARATIVA (Presupuesto → Requerimiento) ======' as paso;

SELECT 
    'PRESUPUESTO' as fuente,
    pd.id_detalle as item_id,
    pd.tipo_item,
    pd.cantidad,
    pd.id_material,
    SUBSTRING(pd.descripcion, 1, 40) as descripcion_corta
FROM TblPresupuestoDetalle pd
WHERE pd.id_presupuesto = @test_pres_id
AND pd.id_detalle IN (@detalle_id_1, @detalle_id_2)

UNION ALL

SELECT 
    'REQUERIMIENTO' as fuente,
    rd.id_detalle,
    rd.tipo_item,
    rd.cantidad,
    rd.id_material,
    SUBSTRING(rd.descripcion, 1, 40)
FROM TblRequerimientoDetalle rd
WHERE rd.id_requerimiento = @nuevo_req_id;

-- ============================================================================
-- PASO 9: Resumen Final
-- ============================================================================
SELECT '====== PASO 9: RESUMEN FINAL ======' as paso;

SELECT 
    @nuevo_req_id as id_requerimiento,
    (SELECT codigo FROM TblRequerimiento WHERE id_requerimiento = @nuevo_req_id) as codigo,
    @test_usuario_nombre as solicitante,
    (SELECT COUNT(*) FROM TblRequerimientoDetalle WHERE id_requerimiento = @nuevo_req_id) as items_creados,
    'Presupuesto ' as origen,
    @test_pres_num as numero_presupuesto;

SELECT '✅ TEST COMPLETADO EXITOSAMENTE' as resultado;
