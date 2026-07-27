-- ============================================================================
-- SP: sp_ActualizarPresupuestoCompleto - VERSIÓN CON DESGLOSE EDITABLE
-- Fecha: 2026-07-22
-- Permite valores personalizados para gastos_generales, utilidad, supervision_obra
-- IGV se calcula automáticamente como 18% de (subtotal + desglose)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarPresupuestoCompleto`(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),
    IN p_utilidad DECIMAL(12,2),
    IN p_supervision_obra DECIMAL(12,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_subtotal_base DECIMAL(12,2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12,2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12,2) DEFAULT 0;

    -- ========================================================================
    -- 1. Calcular subtotal base (materiales + servicios)
    -- ========================================================================
    -- Calcular total de materiales
    SELECT COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    -- Sumar servicios
    SELECT v_subtotal_base + COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    -- ========================================================================
    -- 2. Calcular IGV automáticamente sobre (subtotal + desglose)
    -- ========================================================================
    -- IGV = 18% de (subtotal + gastos_generales + utilidad + supervision_obra)
    SET v_igv = ROUND((v_subtotal_base + p_gastos_generales + p_utilidad + p_supervision_obra) * 0.18, 2);

    -- Calcular monto total
    SET v_monto_total = v_subtotal_base + p_gastos_generales + p_utilidad + p_supervision_obra + v_igv;

    -- ========================================================================
    -- 3. Actualizar presupuesto CON valores editables del frontend
    -- ========================================================================
    UPDATE TblPresupuesto 
    SET 
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        monto = v_subtotal_base,
        monto_total = v_monto_total,
        gastos_generales = p_gastos_generales,
        utilidad = p_utilidad,
        igv = v_igv,
        supervision_obra = p_supervision_obra,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    -- ========================================================================
    -- 4. Eliminar detalles existentes
    -- ========================================================================
    DELETE FROM TblPresupuestoDetalle WHERE id_presupuesto = p_id_presupuesto;

    -- ========================================================================
    -- 5. Insertar materiales actualizados
    -- ========================================================================
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;

    -- ========================================================================
    -- 6. Insertar servicios actualizados
    -- ========================================================================
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

    -- ========================================================================
    -- 7. Limpiar flujo de aprobación (reiniciar proceso)
    -- ========================================================================
    DELETE FROM TblRegistroAprobacion 
    WHERE id_tipo_documento = 1 
      AND id_documento_referencia = p_id_presupuesto;

END$$

DELIMITER ;

-- Verificar que se creó correctamente
SHOW PROCEDURE STATUS WHERE Name = 'sp_ActualizarPresupuestoCompleto';

SELECT '✅ SP ACTUALIZACIÓN CON DESGLOSE EDITABLE' AS RESULTADO;