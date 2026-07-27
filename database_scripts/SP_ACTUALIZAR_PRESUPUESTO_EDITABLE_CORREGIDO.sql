-- ============================================================================
-- SP: sp_ActualizarPresupuestoCompleto - VERSIÓN CORREGIDA CON DESGLOSE EDITABLE
-- Fecha: 2026-07-22
-- Modifica el SP actual para aceptar valores editables del frontend
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
    IN p_gastos_generales DECIMAL(12,2),    -- ⭐ NUEVO PARÁMETRO
    IN p_utilidad DECIMAL(12,2),            -- ⭐ NUEVO PARÁMETRO
    IN p_supervision_obra DECIMAL(12,2),    -- ⭐ NUEVO PARÁMETRO
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2);
    DECLARE v_igv DECIMAL(12,2);
    DECLARE v_monto_total DECIMAL(12,2);

    -- Calcular total de materiales
    SELECT COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    -- ✅ CALCULAR IGV AUTOMÁTICAMENTE SOBRE (subtotal + desglose editable)
    -- IGV = 18% de (subtotal + gastos_generales + utilidad + supervision_obra)
    SET v_igv = ROUND((v_total_monto + p_gastos_generales + p_utilidad + p_supervision_obra) * 0.18, 2);

    -- Calcular Monto Total con valores editables
    SET v_monto_total = v_total_monto + p_gastos_generales + p_utilidad + p_supervision_obra + v_igv;

    -- ✅ Actualizar presupuesto CON VALORES EDITABLES DEL FRONTEND
    UPDATE TblPresupuesto 
    SET 
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = p_num_documento,
        monto = v_total_monto,
        monto_total = v_monto_total,
        gastos_generales = p_gastos_generales,    -- ⭐ USAR VALOR EDITABLE
        utilidad = p_utilidad,                    -- ⭐ USAR VALOR EDITABLE
        igv = v_igv,                              -- ⭐ CALCULADO AUTOMÁTICAMENTE
        supervision_obra = p_supervision_obra,    -- ⭐ USAR VALOR EDITABLE
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

END$$

DELIMITER ;

-- Verificar que se creó correctamente
SHOW PROCEDURE STATUS WHERE Name = 'sp_ActualizarPresupuestoCompleto';

SELECT '✅ SP sp_ActualizarPresupuestoCompleto CORREGIDO CON DESGLOSE EDITABLE' AS RESULTADO;