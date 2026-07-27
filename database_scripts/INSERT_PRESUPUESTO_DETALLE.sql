-- ============================================================================
-- Script: INSERT_PRESUPUESTO_DETALLE.sql
-- Propósito: Insertar datos de prueba en TblPresupuestoDetalle
-- Fecha: 10 Julio 2026
-- Descripción: Vincula presupuestos con materiales, cantidades y precios
-- ============================================================================

-- VERIFICACIÓN PREVIA
-- ============================================================================

SELECT '=== VERIFICACIÓN PREVIA ===' as paso;

-- Verificar que TblPresupuesto tiene datos
SELECT 'Presupuestos existentes:' as info;
SELECT COUNT(*) as total_presupuestos FROM TblPresupuesto;

-- Verificar que TblMateriales tiene datos
SELECT 'Materiales existentes:' as info;
SELECT COUNT(*) as total_materiales FROM TblMateriales;

-- ============================================================================
-- LIMPIAR DATOS ANTERIORES (OPCIONAL - COMENTADO)
-- ============================================================================

-- DELETE FROM TblPresupuestoDetalle;
-- ALTER TABLE TblPresupuestoDetalle AUTO_INCREMENT = 1;

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO 1 (PRES-001)
-- Presupuesto: Casa Verde - Excavación y Cimientos
-- ============================================================================

SELECT '=== INSERTAR ITEMS PRESUPUESTO 1 ===' as paso;

-- Item 1: Cemento Portland
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (1, 1, 100, 25.50, 'Cemento Portland para cimientos - Bolsas de 50kg');

-- Item 2: Arena Gruesa
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (1, 2, 50, 15.75, 'Arena gruesa para mezcla');

-- Item 3: Grava
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (1, 3, 30, 18.50, 'Grava para base de excavación');

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO 2 (PRES-002)
-- Presupuesto: La Arboleda - Estructuras
-- ============================================================================

SELECT '=== INSERTAR ITEMS PRESUPUESTO 2 ===' as paso;

-- Item 1: Acero Estructural
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (2, 5, 500, 8.50, 'Acero corrugado para estructuras');

-- Item 2: Ladrillos
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (2, 4, 5000, 0.75, 'Ladrillos cerámicos para muro');

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO 3 (PRES-003)
-- Presupuesto: Casa Verde - Acabados
-- ============================================================================

SELECT '=== INSERTAR ITEMS PRESUPUESTO 3 ===' as paso;

-- Item 1: Cemento
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (3, 1, 150, 25.50, 'Cemento para acabados y repellos');

-- Item 2: Arena para acabados
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (3, 2, 80, 15.75, 'Arena fina para acabados');

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO 4 (PRES-004)
-- Presupuesto: Nuevo Tambo - Proyecto Completo
-- ============================================================================

SELECT '=== INSERTAR ITEMS PRESUPUESTO 4 ===' as paso;

-- Item 1: Cemento
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (4, 1, 500, 25.50, 'Cemento Portland - Proyecto completo');

-- Item 2: Arena
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (4, 2, 200, 15.75, 'Arena para mezclas');

-- Item 3: Grava
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (4, 3, 150, 18.50, 'Grava para bases');

-- Item 4: Ladrillos
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (4, 4, 8000, 0.75, 'Ladrillos cerámicos');

-- Item 5: Acero
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (4, 5, 800, 8.50, 'Acero corrugado');

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO 5 (PRES-005)
-- Presupuesto: Prado Verde - Estructuras
-- ============================================================================

SELECT '=== INSERTAR ITEMS PRESUPUESTO 5 ===' as paso;

-- Item 1: Acero principal
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario, observaciones)
VALUES (5, 5, 1000, 8.50, 'Acero corrugado para estructura principal');

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT '=== VERIFICACIÓN FINAL ===' as paso;

SELECT 'Total items insertados:' as info;
SELECT COUNT(*) as total_items FROM TblPresupuestoDetalle;

SELECT 'Resumen por presupuesto:' as info;
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    COUNT(d.id_detalle) as cantidad_items,
    SUM(d.cantidad * d.precio_unitario) as monto_total
FROM TblPresupuesto p
LEFT JOIN TblPresupuestoDetalle d ON p.id_presupuesto = d.id_presupuesto
GROUP BY p.id_presupuesto, p.numero_presupuesto
ORDER BY p.id_presupuesto;

SELECT 'Detalle completo:' as info;
SELECT 
    d.id_detalle,
    p.numero_presupuesto,
    m.codigo_material,
    m.nombre as material,
    d.cantidad,
    d.precio_unitario,
    d.subtotal,
    d.observaciones
FROM TblPresupuestoDetalle d
JOIN TblPresupuesto p ON d.id_presupuesto = p.id_presupuesto
JOIN TblMateriales m ON d.id_material = m.id_material
ORDER BY p.numero_presupuesto, d.id_detalle;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

SELECT 'Script completado exitosamente ✓' as resultado;

