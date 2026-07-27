-- ============================================================================
-- SCRIPT: Test End-to-End - Crear Requerimiento Completo
-- DESCRIPCIÓN: Simula el flujo completo desde presupuesto hasta requerimiento
-- FECHA: 2026-07-16
-- ============================================================================

-- PASO 0: Seleccionar una BD (asegurar que estamos en la correcta)
-- ============================================================================
USE kallgwkn_kallpa_bd;
SELECT DATABASE() as base_datos_actual;

-- PASO 1: Obtener datos de muestra
-- ============================================================================
SELECT '====== PASO 1: OBTENER DATOS DE MUESTRA ======' as paso;

-- 1a. Obtener un presupuesto válido
SELECT 
    @test_pres_id:=id_presupuesto,
    @test_pres_num:=numero_presupuesto,
    estado,
    monto
FROM TblPresupuesto
WHERE estado IN ('Pendiente', 'Aprobado')
LIMIT 1;

SELECT '✓ Presupuesto seleccionado' as info;

-- Mostrar si no hay presupuestos
SELECT CASE 
    WHEN @test_pres_id IS NULL THEN '⚠️ NO HAY PRESUPUESTOS DISPONIBLES - Mostrando primeros 5:'
    ELSE CONCAT('✓ ID: ', @test_pres_id, ', Número: ', @test_pres_num)
END as presupuesto_info;

SELECT * FROM TblPresupuesto LIMIT 5;

-- 1b. Obtener usuario activo
SELECT 
    @test_usuario:=num_usuario,
    @test_usuario_nombre:=usuario,
    @test_usuario_doc:=num_documento
FROM TblUsuario
WHERE estado = 'Activo'
LIMIT 1;

SELECT CASE 
    WHEN @test_usuario IS NULL THEN '⚠️ NO HAY USUARIOS ACTIVOS'
    ELSE CONCAT('✓ Usuario: ', @test_usuario_nombre, ' (ID: ', @test_usuario, ')')
END as usuario_info;

-- 1c. Ver detalles del presupuesto
SELECT 'DETALLES DEL PRESUPUESTO SELECCIONADO:' as seccion;
SELECT 
    id_detalle,
    id_material,
    tipo_item,
    SUBSTRING(descripcion, 1, 50) as descripcion_corta,
    cantidad,
    precio_unitario,
    subtotal
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @test_pres_id
ORDER BY id_detalle;

-- Guardar los IDs de detalle para usar después
SELECT 
    @detalle_id_1:=MIN(id_detalle),
    @detalle_id_2:=MAX(id_detalle)
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @test_pres_id;

SELECT CONCAT('✓ Detalles disponibles: ', @detalle_id_1, ' al ', @detalle_id_2) as info;

-- PASO 2: Preparar JSON para el SP
-- ============================================================================
SELECT '====== PASO 2: PREPARAR JSON ======' as paso;

-- Crear JSON con 2 items (el primero y el último del presupuesto)
SET @json_items = JSON_ARRAY(
    JSON_OBJECT('id_detalle_presupuesto', @detalle_id_1, 'tipo_item', 'MATERIAL'),
    JSON_OBJECT('id_detalle_presupuesto', @detalle_id_2, 'tipo_item', (
        SELECT COALESCE(tipo_item, 'MATERIAL') FROM TblPresupuestoDetalle 
        WHERE id_detalle = @detalle_id_2
    ))
);

SELECT CONCAT('✓ JSON preparado: ', @json_items) as info;
SELECT @json_items as json_content;

-- PASO 3: Llamar el SP
-- ============================================================================
SELECT '====== PASO 3: EJECUTAR SP ======' as paso;

CALL sp_CrearRequerimientoCompleto(
    @test_usuario,
    'Test Requerimiento End-to-End',
    'Este es un test del sistema',
    @json_items,
    @nuevo_req_id
);

SELECT CONCAT('✓ Requerimiento creado con ID: ', @nuevo_req_id) as info;

-- PASO 4: Verificar Requerimiento Creado
-- ============================================================================
SELECT '====== PASO 4: VERIFICAR REQUERIMIENTO ======' as paso;

SELECT 'REQUERIMIENTO CREADO:' as seccion;
SELECT 
    id_requerimiento,
    codigo,
    num_usuario,
    descripcion,
    cantidad,
    estado,
    observaciones,
    fecha_creacion
FROM TblRequerimiento
WHERE id_requerimiento = @nuevo_req_id;

-- PASO 5: Verificar Detalles Insertados
-- ============================================================================
SELECT '====== PASO 5: VERIFICAR DETALLES ======' as paso;

SELECT 'DETALLES DEL REQUERIMIENTO:' as seccion;
SELECT 
    rd.id_detalle,
    rd.id_requerimiento,
    rd.id_material,
    rd.tipo_item,
    rd.descripcion,
    rd.cantidad,
    rd.unidad_medida,
    COALESCE(m.nombre, 'N/A') as material_nombre
FROM TblRequerimientoDetalle rd
LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
WHERE rd.id_requerimiento = @nuevo_req_id
ORDER BY rd.id_detalle;

-- PASO 6: VALIDACIÓN CRÍTICA
-- ============================================================================
SELECT '====== PASO 6: VALIDACIÓN CRÍTICA ======' as paso;

SELECT 
    'VALIDACIÓN' as tipo,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ NO HAY DETALLES'
        ELSE CONCAT('✓ ', COUNT(*), ' detalles encontrados')
    END as resultado
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @nuevo_req_id;

-- Validar que id_material se insertó correctamente para MATERIALES
SELECT 
    'id_material para MATERIALES' as validacion,
    COUNT(*) as total_materiales,
    SUM(CASE WHEN id_material IS NOT NULL THEN 1 ELSE 0 END) as con_id_material,
    SUM(CASE WHEN id_material IS NULL THEN 1 ELSE 0 END) as sin_id_material
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @nuevo_req_id 
AND tipo_item = 'MATERIAL';

-- Validar que id_material es NULL para SERVICIOS
SELECT 
    'id_material para SERVICIOS' as validacion,
    COUNT(*) as total_servicios,
    SUM(CASE WHEN id_material IS NULL THEN 1 ELSE 0 END) as correctos_null,
    SUM(CASE WHEN id_material IS NOT NULL THEN 1 ELSE 0 END) as incorrectos_no_null
FROM TblRequerimientoDetalle
WHERE id_requerimiento = @nuevo_req_id 
AND tipo_item = 'SERVICIO';

-- PASO 7: Detalles Comparativos
-- ============================================================================
SELECT '====== PASO 7: COMPARATIVA (Presupuesto vs Requerimiento) ======' as paso;

SELECT 
    'PRESUPUESTO' as origen,
    pd.id_detalle as item_id,
    pd.tipo_item,
    SUBSTRING(pd.descripcion, 1, 40) as descripcion,
    pd.cantidad,
    pd.id_material,
    COALESCE(m1.nombre, 'N/A') as material_nombre
FROM TblPresupuestoDetalle pd
LEFT JOIN TblMateriales m1 ON pd.id_material = m1.id_material
WHERE pd.id_presupuesto = @test_pres_id
AND pd.id_detalle IN (@detalle_id_1, @detalle_id_2)

UNION ALL

SELECT 
    'REQUERIMIENTO' as origen,
    rd.id_detalle,
    rd.tipo_item,
    SUBSTRING(rd.descripcion, 1, 40),
    rd.cantidad,
    rd.id_material,
    COALESCE(m2.nombre, 'N/A')
FROM TblRequerimientoDetalle rd
LEFT JOIN TblMateriales m2 ON rd.id_material = m2.id_material
WHERE rd.id_requerimiento = @nuevo_req_id;

-- PASO 8: Resumen Final
-- ============================================================================
SELECT '====== PASO 8: RESUMEN FINAL ======' as paso;

SELECT 
    CONCAT(
        'Requerimiento: ', 
        (SELECT codigo FROM TblRequerimiento WHERE id_requerimiento = @nuevo_req_id),
        ' | Usuario: ',
        @test_usuario_nombre,
        ' | Items: ',
        (SELECT COUNT(*) FROM TblRequerimientoDetalle WHERE id_requerimiento = @nuevo_req_id)
    ) as resumen;

-- Listar los IDs para referencia posterior
SELECT 
    @nuevo_req_id as id_requerimiento_creado,
    @test_pres_id as id_presupuesto_origen,
    @test_usuario as num_usuario_solicitante;

SELECT '✅ TEST COMPLETADO' as resultado;
