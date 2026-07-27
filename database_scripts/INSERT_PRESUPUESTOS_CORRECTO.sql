-- ============================================================================
-- Script: Insertar Presupuestos Correctos
-- Propósito: Insertar presupuestos sin la columna id_material (que fue removida)
-- Fecha: 10 Julio 2026
-- Nota: Ejecutar después de SETUP_PROYECTO_OBRA_PRESUPUESTO.sql
-- ============================================================================

-- PASO 1: Limpiar presupuestos anteriores (opcional)
-- DELETE FROM TblPresupuesto;
-- ALTER TABLE TblPresupuesto AUTO_INCREMENT = 1;

-- PASO 2: Insertar presupuestos CORRECTOS (sin id_material)
-- La columna id_material NO existe en TblPresupuesto
-- Los materiales se especifican en TblPresupuestoDetalle

INSERT INTO TblPresupuesto (numero_presupuesto, id_obra, num_documento, monto, estado, observaciones)
VALUES 
('PRES-001', 1, 1, 85000.00, 'APROBADO', 'Presupuesto para excavación y cimientos'),
('PRES-002', 2, 1, 125000.00, 'APROBADO', 'Presupuesto para La Floresta'),
('PRES-003', 3, 1, 55000.00, 'PENDIENTE', 'Presupuesto para muros y tabiques'),
('PRES-004', 4, 1, 45000.00, 'EJECUTANDO', 'Presupuesto para instalaciones eléctricas'),
('PRES-005', 5, 1, 38000.00, 'PENDIENTE', 'Presupuesto para instalaciones sanitarias'),
('PRES-006', 6, 1, 62000.00, 'APROBADO', 'Presupuesto para demolición'),
('PRES-007', 7, 1, 95000.00, 'APROBADO', 'Presupuesto para excavación La Floresta'),
('PRES-008', 8, 1, 250000.00, 'PENDIENTE', 'Presupuesto para estructura edificio'),
('PRES-009', 9, 1, 180000.00, 'EJECUTANDO', 'Presupuesto para acabados y detalles'),
('PRES-010', 10, 1, 520000.00, 'APROBADO', 'Presupuesto para infraestructura logística');

SELECT 'Presupuestos insertados correctamente ✓' as resultado;
SELECT COUNT(*) as total_presupuestos FROM TblPresupuesto;

-- PASO 3: Ver los presupuestos insertados
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    o.nombre as nombre_obra,
    per.nombres as usuario,
    p.monto,
    p.estado,
    p.fecha_creacion
FROM TblPresupuesto p
INNER JOIN TblObra o ON p.id_obra = o.id_obra
INNER JOIN TblUsuario u ON p.num_documento = u.num_documento
INNER JOIN TblPersona per ON u.num_documento = per.num_documento
ORDER BY p.id_presupuesto;

-- ============================================================================
-- NOTA IMPORTANTE
-- ============================================================================
-- Los materiales se especifican en TblPresupuestoDetalle, no en TblPresupuesto
-- Estructura:
-- 1 Presupuesto → N Items (PresupuestoDetalle)
-- Cada Item → 1 Material (con id_material, cantidad, precio)
-- ============================================================================
