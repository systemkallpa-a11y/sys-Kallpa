-- ============================================================================
-- Script: Insertar Presupuesto Padre Faltante
-- Propósito: Insertar el presupuesto con id=1 que hace falta
-- Problema: Los detalles existen pero el presupuesto padre no
-- Fecha: 10 Julio 2026
-- ============================================================================

-- Verificar datos actuales
SELECT 'ANTES - TblPresupuesto:' as paso;
SELECT COUNT(*) as total_presupuestos FROM TblPresupuesto;

SELECT 'ANTES - TblPresupuestoDetalle:' as paso;
SELECT COUNT(*) as total_detalles FROM TblPresupuestoDetalle;

-- Insertar presupuesto con id=1 (si no existe)
-- Este presupuesto será el padre de los detalles que ya existen
INSERT IGNORE INTO TblPresupuesto (id_presupuesto, numero_presupuesto, id_obra, num_documento, monto, estado, observaciones)
VALUES 
(1, 'PRES-001', 1, 1, 3892.50, 'PENDIENTE', 'Presupuesto de excavación y cimientos');

SELECT 'Presupuesto insertado/verificado ✓' as resultado;

-- Verificar que el presupuesto existe
SELECT 'DESPUÉS - TblPresupuesto:' as paso;
SELECT * FROM TblPresupuesto WHERE id_presupuesto = 1;

-- Verificar relación presupuesto-detalles
SELECT 'DESPUÉS - Detalles del presupuesto 1:' as paso;
SELECT 
    d.id_detalle,
    d.id_presupuesto,
    d.id_material,
    d.cantidad,
    d.precio_unitario,
    d.subtotal,
    p.numero_presupuesto,
    p.monto,
    p.estado
FROM TblPresupuestoDetalle d
LEFT JOIN TblPresupuesto p ON d.id_presupuesto = p.id_presupuesto
WHERE d.id_presupuesto = 1
ORDER BY d.id_detalle;

-- Probar el SP
SELECT 'PRUEBA - Llamando SP:' as paso;
CALL sp_obtener_presupuesto_detalle_completo(1);
