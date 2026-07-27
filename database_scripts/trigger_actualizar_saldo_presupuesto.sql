-- ============================================================================
-- TRIGGER: tr_ActualizarSaldoPresupuesto
-- PROPÓSITO: Actualizar cantidad_consumida y cantidad_saldo en TblPresupuesto
--            cada vez que se crea/actualiza un requerimiento
-- FECHA: 22 de Julio de 2026
-- ============================================================================

-- ============================================================================
-- TRIGGER 1: Cuando se CREA un requerimiento
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterInsert;

DELIMITER $$

CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterInsert
AFTER INSERT ON TblRequerimiento
FOR EACH ROW
BEGIN
    -- Solo actualizar si el requerimiento está vinculado a un presupuesto
    IF NEW.id_presupuesto IS NOT NULL THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = COALESCE((
                SELECT SUM(rd.cantidad)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = NEW.id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ), 0),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = NEW.id_presupuesto;
        
        -- Recalcular cantidad_saldo
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = NEW.id_presupuesto;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- TRIGGER 2: Cuando se ACTUALIZA un requerimiento (detalles cambian)
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterUpdate;

DELIMITER $$

CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterUpdate
AFTER UPDATE ON TblRequerimiento
FOR EACH ROW
BEGIN
    -- Actualizar el presupuesto ANTERIOR si existía
    IF OLD.id_presupuesto IS NOT NULL THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = COALESCE((
                SELECT SUM(rd.cantidad)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = OLD.id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ), 0),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = OLD.id_presupuesto;
        
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = OLD.id_presupuesto;
    END IF;
    
    -- Actualizar el presupuesto NUEVO si cambió
    IF NEW.id_presupuesto IS NOT NULL AND NEW.id_presupuesto != OLD.id_presupuesto THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = COALESCE((
                SELECT SUM(rd.cantidad)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = NEW.id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ), 0),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = NEW.id_presupuesto;
        
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = NEW.id_presupuesto;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- TRIGGER 3: Cuando se ELIMINA un requerimiento
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterDelete;

DELIMITER $$

CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterDelete
AFTER DELETE ON TblRequerimiento
FOR EACH ROW
BEGIN
    -- Solo actualizar si el requerimiento estaba vinculado a un presupuesto
    IF OLD.id_presupuesto IS NOT NULL THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = COALESCE((
                SELECT SUM(rd.cantidad)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = OLD.id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ), 0),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = OLD.id_presupuesto;
        
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = OLD.id_presupuesto;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- TRIGGER 4: Cuando se ACTUALIZA TblRequerimientoDetalle
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterUpdateDetalle;

DELIMITER $$

CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterUpdateDetalle
AFTER UPDATE ON TblRequerimientoDetalle
FOR EACH ROW
BEGIN
    DECLARE v_id_presupuesto INT;
    
    -- Obtener id_presupuesto del requerimiento
    SELECT id_presupuesto INTO v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = NEW.id_requerimiento;
    
    -- Si existe presupuesto vinculado, actualizar
    IF v_id_presupuesto IS NOT NULL THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = COALESCE((
                SELECT SUM(rd.cantidad)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = v_id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ), 0),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = v_id_presupuesto;
        
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = v_id_presupuesto;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ Triggers de saldo creados exitosamente' as estado;

SHOW TRIGGERS LIKE 'tr_ActualizarSaldo%';

-- ============================================================================
-- INFORMACIÓN
-- ============================================================================

/*

TRIGGERS CREADOS:
  1. tr_ActualizarSaldoPresupuestoAfterInsert
     - Se dispara al CREAR requerimiento
     - Actualiza cantidad_consumida y cantidad_saldo
  
  2. tr_ActualizarSaldoPresupuestoAfterUpdate
     - Se dispara al ACTUALIZAR requerimiento
     - Actualiza presupuestos anterior y nuevo
  
  3. tr_ActualizarSaldoPresupuestoAfterDelete
     - Se dispara al ELIMINAR requerimiento
     - Recalcula cantidad_consumida
  
  4. tr_ActualizarSaldoPresupuestoAfterUpdateDetalle
     - Se dispara al ACTUALIZAR detalles de requerimiento
     - Recalcula saldo del presupuesto

EJEMPLO EJECUTIVO:

  Presupuesto PRES-011: monto = 1000
  
  USUARIO CREA REQ-001 con 312 unidades:
  ├─ INSERT TblRequerimiento (id_presupuesto=14, cantidad=312)
  ├─ TRIGGER se dispara
  ├─ Calcula: SUM(cantidad) desde TblRequerimientoDetalle = 312
  ├─ UPDATE TblPresupuesto SET cantidad_consumida=312, cantidad_saldo=688
  └─ Presupuesto PRES-011: consumida=312, saldo=688 ✓
  
  USUARIO CREA REQ-002 con 200 unidades:
  ├─ INSERT TblRequerimiento (id_presupuesto=14, cantidad=200)
  ├─ TRIGGER se dispara
  ├─ Calcula: SUM(cantidad) = 312 + 200 = 512
  ├─ UPDATE TblPresupuesto SET cantidad_consumida=512, cantidad_saldo=488
  └─ Presupuesto PRES-011: consumida=512, saldo=488 ✓
  
  USUARIO EDITA REQ-001, cambia 312 → 150:
  ├─ UPDATE TblRequerimientoDetalle SET cantidad=150
  ├─ TRIGGER se dispara
  ├─ Calcula: SUM(cantidad) = 150 + 200 = 350
  ├─ UPDATE TblPresupuesto SET cantidad_consumida=350, cantidad_saldo=650
  └─ Presupuesto PRES-011: consumida=350, saldo=650 ✓

BENEFICIOS:
  ✓ Automático: Se actualiza en tiempo real
  ✓ Sincronizado: Siempre refleja la realidad
  ✓ Completo: Maneja INSERT, UPDATE, DELETE
  ✓ Eficiente: Usa SUM() para cálculos exactos

*/

-- ============================================================================

