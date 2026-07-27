-- ============================================================================
-- VERIFICACIÓN: Data en TblPresupuestoDetalle
-- ============================================================================

SELECT 'Total de items insertados:' as info;
SELECT COUNT(*) as total_items
FROM TblPresupuestoDetalle;

SELECT '' as vacio;
SELECT 'Items por Presupuesto:' as info;
SELECT 
    p.numero_presupuesto,
    COUNT(pd.id_detalle) as total_items,
    FORMAT(COALESCE(SUM(pd.subtotal), 0), 2) as monto_total
FROM TblPresupuesto p
LEFT JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
GROUP BY p.id_presupuesto, p.numero_presupuesto
HAVING COUNT(pd.id_detalle) > 0
ORDER BY p.numero_presupuesto;

SELECT '' as vacio;
SELECT 'Detalle completo de items:' as info;
SELECT 
    p.numero_presupuesto,
    m.codigo_material,
    m.nombre as material,
    pd.cantidad,
    pd.precio_unitario,
    pd.subtotal,
    pd.observaciones
FROM TblPresupuestoDetalle pd
INNER JOIN TblPresupuesto p ON pd.id_presupuesto = p.id_presupuesto
INNER JOIN TblMateriales m ON pd.id_material = m.id_material
ORDER BY p.numero_presupuesto, m.codigo_material;

SELECT '' as vacio;
SELECT 'Resumen Total:' as info;
SELECT 
    COUNT(DISTINCT pd.id_presupuesto) as presupuestos,
    COUNT(pd.id_detalle) as items,
    FORMAT(COALESCE(SUM(pd.subtotal), 0), 2) as monto_total
FROM TblPresupuestoDetalle pd;

SELECT '' as vacio;
SELECT 'Validación de integridad referencial:' as info;
SELECT 
    COUNT(*) as items_con_presupuesto_valido
FROM TblPresupuestoDetalle pd
INNER JOIN TblPresupuesto p ON pd.id_presupuesto = p.id_presupuesto;

SELECT 
    COUNT(*) as items_con_material_valido
FROM TblPresupuestoDetalle pd
INNER JOIN TblMateriales m ON pd.id_material = m.id_material;

SELECT '' as vacio;
SELECT 'Validación de cálculos GENERATED:' as info;
SELECT 
    COUNT(*) as total_items,
    COUNT(CASE WHEN ABS(subtotal - (cantidad * precio_unitario)) < 0.01 THEN 1 END) as subtotales_correctos
FROM TblPresupuestoDetalle;

SELECT '' as vacio;
SELECT 'Presupuestos poblados con items:' as info;
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    COUNT(pd.id_detalle) as items,
    FORMAT(SUM(pd.subtotal), 2) as monto,
    p.estado
FROM TblPresupuesto p
INNER JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
GROUP BY p.id_presupuesto, p.numero_presupuesto, p.estado
ORDER BY p.numero_presupuesto;

SELECT '' as vacio;
SELECT 'VERIFICACIÓN COMPLETADA ✅' as resultado;
