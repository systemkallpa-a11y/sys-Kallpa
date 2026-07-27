-- ============================================================================
-- FIX: sp_ActualizarPresupuestoCompleto - Corrigiendo inserción de detalles
-- ============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto$$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2) DEFAULT 0;
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Actualizar presupuesto
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        monto = v_total_monto,
        observaciones = p_comentarios,
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Eliminar detalles viejos
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Insertar materiales nuevos (con conversiones de tipo correctas)
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- Insertar servicios nuevos (SIN id_material, que es NULL para servicios)
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
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
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
END$$

DELIMITER ;
