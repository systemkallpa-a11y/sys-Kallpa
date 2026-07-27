-- ============================================================================
-- TRIGGER: tr_ActualizarSaldoPresupuesto
-- PROPÓSITO: Actualizar cantidad_consumida y cantidad_saldo en TblPresupuesto
--            cada vez que se crea/actualiza un requerimiento
-- FECHA: 22 de Julio de 2026
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterInsert;
CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterInsert
AFTER INSERT ON TblRequerimiento
FOR EACH ROW
BEGIN
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
        
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = NEW.id_presupuesto;
    END IF;
END;

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterUpdate;
CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterUpdate
AFTER UPDATE ON TblRequerimiento
FOR EACH ROW
BEGIN
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
END;

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterDelete;
CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterDelete
AFTER DELETE ON TblRequerimiento
FOR EACH ROW
BEGIN
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
END;

DROP TRIGGER IF EXISTS tr_ActualizarSaldoPresupuestoAfterUpdateDetalle;
CREATE TRIGGER tr_ActualizarSaldoPresupuestoAfterUpdateDetalle
AFTER UPDATE ON TblRequerimientoDetalle
FOR EACH ROW
BEGIN
    DECLARE v_id_presupuesto INT;
    
    SELECT id_presupuesto INTO v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = NEW.id_requerimiento;
    
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
END;
