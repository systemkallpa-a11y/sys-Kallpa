-- ============================================================================
-- FIX: sp_ActualizarPresupuestoCompleto - AGREGANDO CÁLCULO DE DESGLOSE
-- Fecha: 20 Julio 2026
-- Propósito: Al editar presupuesto, calcular automáticamente los campos:
--   - gastos_generales (10% del subtotal)
--   - utilidad (15% del subtotal)
--   - igv (18% del subtotal)
--   - supervision_obra (5% del subtotal)
--   - monto_total (subtotal × 1.48)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarPresupuestoCompleto`(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2);
    DECLARE v_gastos_generales DECIMAL(12,2);
    DECLARE v_utilidad DECIMAL(12,2);
    DECLARE v_igv DECIMAL(12,2);
    DECLARE v_supervision_obra DECIMAL(12,2);
    DECLARE v_monto_total DECIMAL(12,2);
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- ✅ CALCULAR DESGLOSE FINANCIERO
    -- Gastos Generales = Subtotal × 10%
    SET v_gastos_generales = ROUND(v_total_monto * 0.10, 2);
    
    -- Utilidad = Subtotal × 15%
    SET v_utilidad = ROUND(v_total_monto * 0.15, 2);
    
    -- IGV = Subtotal × 18%
    SET v_igv = ROUND(v_total_monto * 0.18, 2);
    
    -- Supervisión de Obra = Subtotal × 5%
    SET v_supervision_obra = ROUND(v_total_monto * 0.05, 2);
    
    -- Monto Total = Subtotal × 1.48
    SET v_monto_total = ROUND(v_total_monto * 1.48, 2);
    
    -- ✅ Actualizar presupuesto CON num_documento, desglose y CAMBIAR A PENDIENTE
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = p_num_documento,
        monto = v_total_monto,
        monto_total = v_monto_total,
        gastos_generales = v_gastos_generales,
        utilidad = v_utilidad,
        igv = v_igv,
        supervision_obra = v_supervision_obra,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- 🆕 BORRAR REGISTROS DE APROBACIÓN/RECHAZO CUANDO SE EDITA
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Eliminar detalles viejos
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Insertar materiales nuevos
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')) AS UNSIGNED),
        'MATERIAL',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- Insertar servicios nuevos
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto,
        NULL,
        'SERVICIO',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ SP sp_ActualizarPresupuestoCompleto actualizado con cálculo de desglose' as resultado;

-- Mostrar el SP
SHOW CREATE PROCEDURE sp_ActualizarPresupuestoCompleto;

-- ============================================================================
-- RESUMEN DE CAMBIOS
-- ============================================================================
-- 
-- El SP ahora calcula automáticamente al editar presupuesto:
--   1. Recalcula subtotal_base (materiales + servicios)
--   2. Calcula gastos_generales = subtotal × 10%
--   3. Calcula utilidad = subtotal × 15%
--   4. Calcula igv = subtotal × 18%
--   5. Calcula supervision_obra = subtotal × 5%
--   6. Calcula monto_total = subtotal × 1.48
--   7. Actualiza TblPresupuesto con todos los valores
--
-- Antes: Los campos desglose NO se actualizaban al editar
-- Después: Los campos desglose se actualizan automáticamente
--
-- ============================================================================


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ SP sp_ActualizarPresupuestoCompleto actualizado con cálculo de desglose' as resultado;

-- ============================================================================
-- RESUMEN DE CAMBIOS
-- ============================================================================
-- 
-- El SP ahora calcula automáticamente al editar presupuesto:
--   1. Calcula v_total_monto (materiales + servicios)
--   2. Calcula gastos_generales = monto × 10%
--   3. Calcula utilidad = monto × 15%
--   4. Calcula igv = monto × 18%
--   5. Calcula supervision_obra = monto × 5%
--   6. Calcula monto_total = monto × 1.48
--   7. Actualiza TblPresupuesto con TODOS los valores:
--      - monto (subtotal)
--      - monto_total (con desglose)
--      - gastos_generales
--      - utilidad
--      - igv
--      - supervision_obra
--   8. Establece estado a 'PENDIENTE'
--   9. Borra registros de aprobación/rechazo
--   10. Reinserta detalles de materiales y servicios
--
-- Antes: Los campos desglose NO se actualizaban al editar
-- Después: Los campos desglose se actualizan automáticamente
--
-- ============================================================================
