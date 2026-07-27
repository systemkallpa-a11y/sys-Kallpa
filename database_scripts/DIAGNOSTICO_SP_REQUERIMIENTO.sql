-- ============================================================================
-- SCRIPT: Diagnóstico - Verificar datos en TblPresupuestoDetalle
-- FECHA: 2026-07-16
-- ============================================================================

-- 1. Obtener un presupuesto de muestra
SELECT 
    @id_presupuesto:=id_presupuesto,
    numero_presupuesto,
    estado,
    monto
FROM TblPresupuesto
LIMIT 1;

-- 2. Mostrar ID del presupuesto seleccionado
SELECT 'ID Presupuesto Seleccionado' as info, @id_presupuesto as valor;

-- 3. Verificar detalles del presupuesto - MOSTRAR TODOS LOS CAMPOS
SELECT 
    'PRESUPUESTO DETALLE' as Seccion,
    id_detalle,
    id_presupuesto,
    id_material,
    tipo_item,
    descripcion,
    cantidad,
    precio_unitario,
    subtotal,
    observaciones
FROM TblPresupuestoDetalle
WHERE id_presupuesto = @id_presupuesto
ORDER BY id_detalle;

-- 4. Para cada material en el presupuesto, verificar si existe en TblMateriales
SELECT 
    'MATERIALES VALIDACIÓN' as Seccion,
    pd.id_detalle,
    pd.id_material,
    pd.tipo_item,
    CASE 
        WHEN pd.tipo_item = 'MATERIAL' AND pd.id_material IS NULL THEN 'MATERIAL SIN id_material'
        WHEN pd.tipo_item = 'MATERIAL' AND pd.id_material IS NOT NULL AND m.id_material IS NULL THEN 'MATERIAL id_material NO EXISTE'
        WHEN pd.tipo_item = 'MATERIAL' AND m.id_material IS NOT NULL THEN CONCAT('OK - ', m.nombre)
        WHEN pd.tipo_item = 'SERVICIO' THEN 'SERVICIO - OK (sin material)'
        ELSE 'DESCONOCIDO'
    END as estado_material,
    m.nombre as material_nombre
FROM TblPresupuestoDetalle pd
LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
WHERE pd.id_presupuesto = @id_presupuesto
ORDER BY pd.id_detalle;

-- 5. Probar el JSON_TABLE con datos de ejemplo
SELECT 'TEST JSON_TABLE' as test;
SET @test_json = '[{"id_detalle_presupuesto": 1}, {"id_detalle_presupuesto": 2}]';
SELECT 
    jt.id_detalle,
    pd.id_material,
    pd.tipo_item,
    pd.descripcion
FROM JSON_TABLE(@test_json, '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')) jt
LEFT JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle;
