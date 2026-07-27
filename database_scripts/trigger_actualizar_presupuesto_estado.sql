-- ============================================================================
-- TRIGGER: tr_ActualizarPresupuestoEstado
-- PROPÓSITO: Cambiar estado de TblPresupuesto a APROBADO cuando TODOS
--            los detalles estén aprobados (sin pasos pendientes)
-- FECHA: 22 de Julio de 2026
-- ============================================================================

DROP TRIGGER IF EXISTS tr_ActualizarPresupuestoEstado;

DELIMITER $$

CREATE TRIGGER tr_ActualizarPresupuestoEstado
AFTER UPDATE ON TblRegistroAprobacion
FOR EACH ROW
BEGIN
    DECLARE v_pasos_totales INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_presupuesto_estado VARCHAR(50);
    DECLARE v_id_presupuesto INT;
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_estado_anterior VARCHAR(50);
    
    -- Solo procesar si es un presupuesto (id_tipo_documento = 1)
    -- y si el estado cambió a APROBADO
    IF NEW.id_tipo_documento = 1 AND NEW.estado_aprobacion = 'APROBADO' THEN
        
        -- Obtener ID del presupuesto
        SET v_id_presupuesto = NEW.id_documento_referencia;
        
        -- Obtener estado actual del presupuesto
        SELECT estado, numero_presupuesto INTO v_presupuesto_estado, v_numero_presupuesto
        FROM TblPresupuesto
        WHERE id_presupuesto = v_id_presupuesto;
        
        SET v_estado_anterior = v_presupuesto_estado;
        
        -- Si el presupuesto está PENDIENTE o RECHAZADO, verificar si todos los pasos están aprobados
        IF v_presupuesto_estado IN ('PENDIENTE', 'RECHAZADO') THEN
            
            -- Contar total de pasos requeridos
            SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
            FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = 1
            AND es_requerido = 1
            AND activo = 1;
            
            -- Contar pasos APROBADOS
            SELECT COUNT(*) INTO v_pasos_aprobados
            FROM TblRegistroAprobacion
            WHERE id_documento_referencia = v_id_presupuesto
            AND id_tipo_documento = 1
            AND estado_aprobacion = 'APROBADO';
            
            -- Si TODOS los pasos están aprobados, cambiar estado del presupuesto
            IF v_pasos_totales = v_pasos_aprobados AND v_pasos_totales > 0 THEN
                UPDATE TblPresupuesto
                SET 
                    estado = 'APROBADO',
                    fecha_actualizacion = NOW()
                WHERE id_presupuesto = v_id_presupuesto;
                
                -- ================================================================
                -- REGISTRAR EL DISPARO EN LA TABLA DE AUDITORÍA
                -- ================================================================
                INSERT INTO TblAuditoriaTriggers (
                    nombre_trigger,
                    tabla_afectada,
                    id_presupuesto,
                    numero_presupuesto,
                    accion_trigger,
                    estado_anterior,
                    estado_nuevo,
                    pasos_aprobados,
                    pasos_totales
                ) VALUES (
                    'tr_ActualizarPresupuestoEstado',
                    'TblRegistroAprobacion',
                    v_id_presupuesto,
                    v_numero_presupuesto,
                    CONCAT('Paso ', NEW.numero_paso, ' aprobado - Todos los pasos completados'),
                    v_estado_anterior,
                    'APROBADO',
                    v_pasos_aprobados,
                    v_pasos_totales
                );
            END IF;
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- INFORMACIÓN DEL TRIGGER
-- ============================================================================

/*

PROPÓSITO:
  Automatizar el cambio de estado en TblPresupuesto cuando todos los pasos
  de aprobación estén completados (APROBADO).

EVENTOS:
  - Se dispara DESPUÉS de UPDATE en TblRegistroAprobacion
  - Solo procesa presupuestos (id_tipo_documento = 1)
  - Solo cuando estado_aprobacion = 'APROBADO'

AUDITORÍA:
  - Registra CADA disparo en TblAuditoriaTriggers
  - Incluye: presupuesto, pasos aprobados, timestamp, etc.

*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================

