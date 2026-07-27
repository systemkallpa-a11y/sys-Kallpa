-- ============================================================================
-- SETUP: Insertar data de prueba en TblPresupuestoDetalle
-- Propósito: Poblar tabla con items para presupuestos de prueba
-- Fecha: 10 Julio 2026
-- Datos: 20 items distribuidos en 5 presupuestos
-- ============================================================================

-- VERIFICACIÓN PREVIA
SELECT 'Verificando data existente...' as verificacion;

-- Contar presupuestos existentes
SELECT COUNT(*) as total_presupuestos FROM TblPresupuesto;

-- Contar materiales disponibles
SELECT COUNT(*) as total_materiales FROM TblMateriales;

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO #1
-- Presupuesto: PRES-2026-001 (La Finca - Cimentación)
-- ============================================================================

INSERT INTO TblPresupuestoDetalle (
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    observaciones,
    fecha_creacion
) VALUES
(1, 1, 50.00, 25.50, 'Cemento Portland para cimentación', NOW()),
(1, 5, 100.00, 18.75, 'Arena gruesa clasificada', NOW()),
(1, 8, 50.00, 12.30, 'Grava para base', NOW()),
(1, 15, 25.00, 150.00, 'Acero estructural para zapatas', NOW());

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO #2
-- Presupuesto: PRES-2026-002 (La Floresta - Estructura)
-- ============================================================================

INSERT INTO TblPresupuestoDetalle (
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    observaciones,
    fecha_creacion
) VALUES
(2, 15, 100.00, 150.00, 'Acero estructural para columnas', NOW()),
(2, 2, 75.00, 22.50, 'Cemento de albañilería', NOW()),
(2, 5, 200.00, 18.75, 'Arena fina para mortero', NOW()),
(2, 20, 500.00, 8.50, 'Ladrillos cerámicos 18 huecos', NOW());

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO #3
-- Presupuesto: PRES-2026-003 (La Arboleda - Acabados)
-- ============================================================================

INSERT INTO TblPresupuestoDetalle (
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    observaciones,
    fecha_creacion
) VALUES
(3, 3, 50.00, 45.00, 'Pintura acrílica de exterior', NOW()),
(3, 12, 100.00, 35.50, 'Cerámicas para piso 50x50', NOW()),
(3, 25, 200.00, 15.00, 'Pasta muro para acabado', NOW()),
(3, 4, 30.00, 55.75, 'Cemento cola blanco', NOW());

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO #4
-- Presupuesto: PRES-2026-004 (Villa Verde - Instalaciones)
-- ============================================================================

INSERT INTO TblPresupuestoDetalle (
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    observaciones,
    fecha_creacion
) VALUES
(4, 6, 200.00, 5.50, 'Tubo PVC 2" para agua', NOW()),
(4, 7, 150.00, 6.75, 'Tubo PVC 4" para desagüe', NOW()),
(4, 10, 50.00, 25.00, 'Cable eléctrico 2.5mm', NOW()),
(4, 11, 30.00, 45.00, 'Breaker monofásico 20A', NOW());

-- ============================================================================
-- INSERTAR ITEMS PARA PRESUPUESTO #5
-- Presupuesto: PRES-2026-005 (El Guindal - Varios)
-- ============================================================================

INSERT INTO TblPresupuestoDetalle (
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    observaciones,
    fecha_creacion
) VALUES
(5, 1, 30.00, 25.50, 'Cemento Portland adicional', NOW()),
(5, 5, 50.00, 18.75, 'Arena fina para acabado', NOW()),
(5, 9, 100.00, 14.50, 'Madera 2x2 para encofrado', NOW()),
(5, 18, 200.00, 12.00, 'Clavos de 2.5" variados', NOW());

-- ============================================================================
-- VERIFICACIÓN POST-INSERCIÓN
-- ============================================================================

SELECT 'Data insertada exitosamente ✓' as resultado;

-- Contar total de items por presupuesto
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    COUNT(pd.id_detalle) as total_items,
    SUM(pd.cantidad * pd.precio_unitario) as monto_calculado
FROM TblPresupuesto p
LEFT JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
WHERE p.id_presupuesto IN (1,2,3,4,5)
GROUP BY p.id_presupuesto, p.numero_presupuesto
ORDER BY p.id_presupuesto;

-- Ver detalle de todos los items
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

-- Resumen de totales
SELECT 
    COUNT(DISTINCT pd.id_presupuesto) as total_presupuestos,
    COUNT(pd.id_detalle) as total_items,
    SUM(pd.subtotal) as monto_total_general
FROM TblPresupuestoDetalle pd
WHERE pd.id_presupuesto IN (1,2,3,4,5);

-- ============================================================================
-- INFORMACIÓN DE PRESUPUESTOS POBLADOS
-- ============================================================================
-- 
-- PRES-2026-001 (La Finca - Cimentación)
--   ├─ Cemento Portland: 50 × 25.50 = 1,275.00
--   ├─ Arena gruesa: 100 × 18.75 = 1,875.00
--   ├─ Grava: 50 × 12.30 = 615.00
--   └─ Acero: 25 × 150.00 = 3,750.00
--   TOTAL: 7,515.00
--
-- PRES-2026-002 (La Floresta - Estructura)
--   ├─ Acero estructural: 100 × 150.00 = 15,000.00
--   ├─ Cemento albañilería: 75 × 22.50 = 1,687.50
--   ├─ Arena fina: 200 × 18.75 = 3,750.00
--   └─ Ladrillos: 500 × 8.50 = 4,250.00
--   TOTAL: 24,687.50
--
-- PRES-2026-003 (La Arboleda - Acabados)
--   ├─ Pintura: 50 × 45.00 = 2,250.00
--   ├─ Cerámicas: 100 × 35.50 = 3,550.00
--   ├─ Pasta muro: 200 × 15.00 = 3,000.00
--   └─ Cemento cola: 30 × 55.75 = 1,672.50
--   TOTAL: 10,472.50
--
-- PRES-2026-004 (Villa Verde - Instalaciones)
--   ├─ Tubo PVC 2": 200 × 5.50 = 1,100.00
--   ├─ Tubo PVC 4": 150 × 6.75 = 1,012.50
--   ├─ Cable: 50 × 25.00 = 1,250.00
--   └─ Breaker: 30 × 45.00 = 1,350.00
--   TOTAL: 4,712.50
--
-- PRES-2026-005 (El Guindal - Varios)
--   ├─ Cemento: 30 × 25.50 = 765.00
--   ├─ Arena: 50 × 18.75 = 937.50
--   ├─ Madera: 100 × 14.50 = 1,450.00
--   └─ Clavos: 200 × 12.00 = 2,400.00
--   TOTAL: 5,552.50
--
-- GRAN TOTAL: 52,940.00
--
-- ============================================================================
