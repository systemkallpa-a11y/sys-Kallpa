-- ============================================================================
-- SP: sp_CrearPresupuestoCompleto - VERSIÓN CON DESGLOSE EDITABLE
-- Fecha: 2026-07-22
-- Permite valores personalizados para gastos_generales, utilidad, supervision_obra
-- IGV se calcula automáticamente como 18% de (subtotal + desglose)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoCompleto;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearPresupuestoCompleto`(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),
    IN p_utilidad DECIMAL(12,2),
    IN p_supervision_obra DECIMAL(12,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
BEGIN
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;

    -- ========================================================================
    -- 1. Generar número de presupuesto automáticamente
    -- ========================================================================
    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(CAST(SUBSTRING(numero_presupuesto, 6) AS UNSIGNED)), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM TblPresupuesto
    WHERE numero_presupuesto LIKE 'PRES-%';

    -- ========================================================================
    -- 2. Calcular subtotal base (materiales + servicios)
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
    -- 3. Calcular IGV automáticamente sobre (subtotal + desglose)
    -- ========================================================================
    -- IGV = 18% de (subtotal + gastos_generales + utilidad + supervision_obra)
    SET v_igv = ROUND((v_subtotal_base + p_gastos_generales + p_utilidad + p_supervision_obra) * 0.18, 2);

    -- Calcular monto total
    SET v_monto_total = v_subtotal_base + p_gastos_generales + p_utilidad + p_supervision_obra + v_igv;

    -- ========================================================================
    -- 4. Insertar presupuesto CON valores editables del frontend
    -- ========================================================================
    INSERT INTO TblPresupuesto (
        id_empresa,
        numero_presupuesto,
        id_obra,
        num_documento,
        monto,
        monto_total,
        monto_aprobado,
        gastos_generales,
        utilidad,
        igv,
        supervision_obra,
        estado,
        observaciones,
        fecha_creacion
    ) VALUES (
        p_id_empresa,
        v_numero_presupuesto,
        p_id_obra,
        p_num_documento,
        v_subtotal_base,
        v_monto_total,
        0,
        p_gastos_generales,
        p_utilidad,
        v_igv,
        p_supervision_obra,
        'PENDIENTE',
        p_comentarios,
        NOW()
    );

    SET p_id_presupuesto_created = LAST_INSERT_ID();

    -- ========================================================================
    -- 5. Insertar materiales
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
        p_id_presupuesto_created,
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
    -- 6. Insertar servicios
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
        p_id_presupuesto_created,
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

END$$

DELIMITER ;

-- Verificar que se creó correctamente
SHOW PROCEDURE STATUS WHERE Name = 'sp_CrearPresupuestoCompleto';

SELECT '✅ SP ACTUALIZADO CON DESGLOSE EDITABLE' AS RESULTADO;