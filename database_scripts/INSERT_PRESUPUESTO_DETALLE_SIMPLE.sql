-- ============================================================================
-- Script SIMPLE: Insertar datos en TblPresupuestoDetalle
-- Versión simplificada sin verificaciones
-- Fecha: 10 Julio 2026
-- ============================================================================

-- Limpiar datos anteriores (opcional, comentado por defecto)
-- DELETE FROM TblPresupuestoDetalle;
-- ALTER TABLE TblPresupuestoDetalle AUTO_INCREMENT = 1;

-- ============================================================================
-- Inserción directa de datos
-- ============================================================================

-- Presupuesto 1: 3 items
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (1, 1, 100, 25.50);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (1, 2, 50, 15.75);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (1, 3, 30, 18.50);

-- Presupuesto 2: 2 items
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (2, 5, 500, 8.50);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (2, 4, 5000, 0.75);

-- Presupuesto 3: 2 items
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (3, 1, 150, 25.50);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (3, 2, 80, 15.75);

-- Presupuesto 4: 5 items
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (4, 1, 500, 25.50);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (4, 2, 200, 15.75);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (4, 3, 150, 18.50);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (4, 4, 8000, 0.75);

INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (4, 5, 800, 8.50);

-- Presupuesto 5: 1 item
INSERT INTO TblPresupuestoDetalle (id_presupuesto, id_material, cantidad, precio_unitario) 
VALUES (5, 5, 1000, 8.50);

-- ============================================================================
-- Verificación final
-- ============================================================================

SELECT '✓ Datos insertados exitosamente' as resultado;
SELECT COUNT(*) as total_items_insertados FROM TblPresupuestoDetalle;

