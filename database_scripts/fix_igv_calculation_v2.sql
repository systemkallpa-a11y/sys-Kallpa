-- ============================================================================
-- SCRIPT: Corregir Cálculo del IGV en Stored Procedures
-- FECHA: 05 Agosto 2026
-- DESCRIPCIÓN: Actualizar ambos SPs para calcular correctamente:
--              SUB TOTAL = Costos Directos + GG + Utilidad
--              IGV = 18% × SUB TOTAL
--              MONTO TOTAL = SUB TOTAL + IGV + Supervisión
-- ============================================================================

USE Kallpa;

-- ============================================================================
-- 1. ACTUALIZAR sp_CrearPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_CrearPresupuestoCompleto`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearPresupuestoCompleto`(
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
    DECLARE v_sub_total DECIMAL(12, 2) DEFAULT 0;
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
    -- 3. CALCULAR SUB TOTAL = Costos Directos + GG + Utilidad (SIN Supervisión)
    -- ========================================================================
    SET v_sub_total = v_subtotal_base + p_gastos_generales + p_utilidad;

    -- ========================================================================
    -- 4. CALCULAR IGV = 18% del SUB TOTAL (✓ CORREGIDO)
    -- ========================================================================
    SET v_igv = ROUND(v_sub_total * 0.18, 2);

    -- ========================================================================
    -- 5. CALCULAR MONTO TOTAL = SUB TOTAL + IGV + Supervisión
    -- ========================================================================
    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;

    -- ========================================================================
    -- 6. Insertar presupuesto
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
        v_igv,  -- ✓ IGV calculado correctamente sobre SUB TOTAL
        p_supervision_obra,
        'PENDIENTE',
        p_comentarios,
        NOW()
    );

    SET p_id_presupuesto_created = LAST_INSERT_ID();

    -- ========================================================================
    -- 7. Insertar materiales (SIN subtotal - se calcula automáticamente)
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
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;

    -- ========================================================================
    -- 8. Insertar servicios (SIN subtotal - se calcula automáticamente)
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
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

    -- ========================================================================
    -- 9. Crear registros de flujo de aprobación
    -- ========================================================================
    INSERT INTO TblRegistroAprobacion (
        id_tipo_documento,
        id_documento_referencia,
        numero_paso,
        id_cargo_aprobador,
        estado_aprobacion,
        fecha_asignacion
    )
    SELECT 
        fac.id_tipo_documento,
        p_id_presupuesto_created,
        fac.numero_paso,
        fac.id_cargo,
        'PENDIENTE',
        NOW()
    FROM TblFlujoAprobacionCargos fac
    WHERE fac.id_tipo_documento = 1  -- Presupuesto
      AND fac.activo = 1
    ORDER BY fac.numero_paso;

END$$

DELIMITER ;

-- ============================================================================
-- 2. ACTUALIZAR sp_ActualizarPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_ActualizarPresupuestoCompleto`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarPresupuestoCompleto`(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento INT,
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),
    IN p_utilidad DECIMAL(12,2),
    IN p_supervision_obra DECIMAL(12,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_sub_total DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;
    
    -- ========================================================================
    -- 1. Calcular subtotal base (materiales + servicios)
    -- ========================================================================
    -- Calcular total de materiales
    SELECT COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_subtotal_base + COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- ========================================================================
    -- 2. CALCULAR SUB TOTAL = Costos Directos + GG + Utilidad (SIN Supervisión)
    -- ========================================================================
    SET v_sub_total = v_subtotal_base + p_gastos_generales + p_utilidad;
    
    -- ========================================================================
    -- 3. CALCULAR IGV = 18% del SUB TOTAL (✓ CORREGIDO)
    -- ========================================================================
    SET v_igv = ROUND(v_sub_total * 0.18, 2);
    
    -- ========================================================================
    -- 4. CALCULAR MONTO TOTAL = SUB TOTAL + IGV + Supervisión
    -- ========================================================================
    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;
    
    -- ========================================================================
    -- 5. Actualizar presupuesto principal
    -- ========================================================================
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = p_num_documento,
        monto = v_subtotal_base,
        monto_total = v_monto_total,
        observaciones = p_comentarios,
        gastos_generales = p_gastos_generales,
        utilidad = p_utilidad,
        igv = v_igv,  -- ✓ IGV calculado correctamente sobre SUB TOTAL
        supervision_obra = p_supervision_obra,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- 6. Eliminar aprobaciones anteriores
    -- ========================================================================
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
      AND id_tipo_documento = 1;
    
    -- ========================================================================
    -- 7. Eliminar detalles viejos
    -- ========================================================================
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- 8. Insertar materiales nuevos (SIN subtotal - se calcula automáticamente)
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
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- ========================================================================
    -- 9. Insertar servicios nuevos (SIN subtotal - se calcula automáticamente)
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
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
    
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ sp_CrearPresupuestoCompleto actualizado correctamente' AS mensaje;
SELECT '✓ sp_ActualizarPresupuestoCompleto actualizado correctamente' AS mensaje;
SELECT '✓ El IGV ahora se calcula como 18% del SUB TOTAL (Costos Directos + GG + Utilidad)' AS nota;

