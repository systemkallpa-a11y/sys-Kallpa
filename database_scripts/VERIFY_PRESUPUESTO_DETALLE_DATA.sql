-- ============================================================================
-- VERIFICACIÓN: Data en TblPresupuestoDetalle
-- ============================================================================

SELECT '═══════════════════════════════════════════════════════════════════' as separator;
SELECT 'VERIFICACIÓN DE DATA EN TblPresupuestoDetalle' as titulo;
SELECT '═══════════════════════════════════════════════════════════════════' as separator;

-- 1. Total de items
SELECT CONCAT('✅ Total de items insertados: ', COUNT(*)) as resultado
FROM TblPresupuestoDetalle;

-- 2. Items por presupuesto
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'ITEMS POR PRESUPUESTO:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT 
    p.numero_presupuesto as presupuesto,
    COUNT(pd.id_detalle) as total_items,
    CONCAT('S/. ', FORMAT(COALESCE(SUM(pd.subtotal), 0), 2)) as monto_total
FROM TblPresupuesto p
LEFT JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
GROUP BY p.id_presupuesto, p.numero_presupuesto
HAVING COUNT(pd.id_detalle) > 0
ORDER BY p.numero_presupuesto;

-- 3. Detalle de todos los items
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'DETALLE COMPLETO DE ITEMS:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT 
    p.numero_presupuesto,
    m.codigo_material,
    m.nombre as material,
    CONCAT(pd.cantidad, ' ', COALESCE(u.nombre, 'UND')) as cantidad_unidad,
    CONCAT('S/. ', FORMAT(pd.precio_unitario, 2)) as precio_unitario,
    CONCAT('S/. ', FORMAT(pd.subtotal, 2)) as subtotal,
    pd.observaciones
FROM TblPresupuestoDetalle pd
INNER JOIN TblPresupuesto p ON pd.id_presupuesto = p.id_presupuesto
INNER JOIN TblMateriales m ON pd.id_material = m.id_material
LEFT JOIN TblUnidadMedida u ON m.id_unidad_medida = u.id_unidad_medida
ORDER BY p.numero_presupuesto, m.codigo_material;

-- 4. Resumen total
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'RESUMEN TOTAL:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT 
    COUNT(DISTINCT pd.id_presupuesto) as total_presupuestos,
    COUNT(pd.id_detalle) as total_items,
    CONCAT('S/. ', FORMAT(COALESCE(SUM(pd.subtotal), 0), 2)) as monto_total_general
FROM TblPresupuestoDetalle pd;

-- 5. Validación de ForeignKeys
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'VALIDACIÓN DE INTEGRIDAD:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✅ Todos los items tienen presupuesto válido'
    ELSE CONCAT('❌ ', COUNT(*), ' items sin presupuesto válido')
END as validacion_presupuesto
FROM TblPresupuestoDetalle pd
LEFT JOIN TblPresupuesto p ON pd.id_presupuesto = p.id_presupuesto
WHERE p.id_presupuesto IS NULL;

SELECT CASE 
    WHEN COUNT(*) = 0 THEN '✅ Todos los items tienen material válido'
    ELSE CONCAT('❌ ', COUNT(*), ' items con material inválido')
END as validacion_material
FROM TblPresupuestoDetalle pd
LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
WHERE m.id_material IS NULL;

-- 6. Verificación de cálculos GENERATED
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'VALIDACIÓN DE CÁLCULOS GENERADOS:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT 
    CASE 
        WHEN COUNT(CASE WHEN ABS(subtotal - (cantidad * precio_unitario)) > 0.01 THEN 1 END) = 0
        THEN '✅ Todos los subtotales están correctamente calculados'
        ELSE CONCAT('❌ ', COUNT(CASE WHEN ABS(subtotal - (cantidad * precio_unitario)) > 0.01 THEN 1 END), ' subtotales con error')
    END as validacion_subtotales
FROM TblPresupuestoDetalle;

-- 7. Listado de presupuestos con sus totales
SELECT '
───────────────────────────────────────────────────────────────────' as separator;
SELECT 'PRESUPUESTOS POBLADOS:' as seccion;
SELECT '───────────────────────────────────────────────────────────────────' as separator;

SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    COUNT(pd.id_detalle) as items,
    CONCAT('S/. ', FORMAT(SUM(pd.subtotal), 2)) as monto_calculado,
    p.estado,
    DATE_FORMAT(p.fecha_creacion, '%d/%m/%Y %H:%i') as fecha_creacion
FROM TblPresupuesto p
LEFT JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
WHERE pd.id_presupuesto IS NOT NULL
GROUP BY p.id_presupuesto, p.numero_presupuesto, p.estado, p.fecha_creacion
ORDER BY p.numero_presupuesto;

SELECT '
═══════════════════════════════════════════════════════════════════' as separator;
SELECT '✅ VERIFICACIÓN COMPLETADA EXITOSAMENTE' as resultado;
SELECT '═══════════════════════════════════════════════════════════════════' as separator;
