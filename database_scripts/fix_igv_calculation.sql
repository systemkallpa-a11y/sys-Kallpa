-- ============================================================================
-- SCRIPT: Corregir Cálculo del IGV en Presupuestos
-- FECHA: 05 Agosto 2026
-- DESCRIPCIÓN: El IGV debe calcularse sobre el SUB TOTAL (Costos Directos + GG + Utilidad)
--              NO sobre Costos Directos + GG + Utilidad + Supervisión
-- ============================================================================

USE Kallpa;

-- ============================================================================
-- 1. MODIFICAR sp_CrearPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearPresupuestoCompleto(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios TEXT,
    IN p_gastos_generales DECIMAL(15,2),
    IN p_utilidad DECIMAL(15,2),
    IN p_supervision_obra DECIMAL(15,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
BEGIN
    DECLARE v_monto_total DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_costos_directos DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_sub_total DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_igv DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_id_presupuesto_created = NULL;
    END;

    START TRANSACTION;

    -- ====== CALCULAR COSTOS DIRECTOS (Suma de materiales + servicios) ======
    
    -- Sumar materiales
    SET v_count = JSON_LENGTH(p_materiales_json);
    WHILE v_idx < v_count DO
        SET v_costos_directos = v_costos_directos + CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2));
        SET v_idx = v_idx + 1;
    END WHILE;
    
    -- Sumar servicios
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_servicios_json);
    WHILE v_idx < v_count DO
        SET v_costos_directos = v_costos_directos + CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2));
        SET v_idx = v_idx + 1;
    END WHILE;

    -- ====== CALCULAR SUB TOTAL = Costos Directos + GG + Utilidad (SIN Supervisión) ======
    SET v_sub_total = v_costos_directos + p_gastos_generales + p_utilidad;
    
    -- ====== CALCULAR IGV = 18% del SUB TOTAL ======
    SET v_igv = ROUND(v_sub_total * 0.18, 2);
    
    -- ====== CALCULAR MONTO TOTAL = SUB TOTAL + IGV + Supervisión ======
    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;
    
    -- ====== GENERAR NÚMERO DE PRESUPUESTO ======
    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(id_presupuesto), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM TblPresupuesto;

    -- ====== INSERTAR PRESUPUESTO ======
    INSERT INTO TblPresupuesto (
        numero_presupuesto,
        id_empresa,
        id_obra,
        num_documento,
        monto,
        estado,
        observaciones,
        gastos_generales,
        utilidad,
        igv,
        supervision_obra,
        fecha_creacion,
        fecha_actualizacion
    ) VALUES (
        v_numero_presupuesto,
        p_id_empresa,
        p_id_obra,
        p_num_documento,
        v_monto_total,
        'PENDIENTE',
        p_comentarios,
        p_gastos_generales,
        p_utilidad,
        v_igv,  -- IGV calculado correctamente
        p_supervision_obra,
        NOW(),
        NOW()
    );

    SET p_id_presupuesto_created = LAST_INSERT_ID();

    -- ====== INSERTAR MATERIALES ======
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_materiales_json);
    WHILE v_idx < v_count DO
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            tipo_detalle,
            id_material,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal
        ) VALUES (
            p_id_presupuesto_created,
            'MATERIAL',
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].id_material'))) AS UNSIGNED),
            JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].nombre'))),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].cantidad'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].precio_unitario'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2))
        );
        SET v_idx = v_idx + 1;
    END WHILE;

    -- ====== INSERTAR SERVICIOS ======
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_servicios_json);
    WHILE v_idx < v_count DO
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            tipo_detalle,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal
        ) VALUES (
            p_id_presupuesto_created,
            'SERVICIO',
            JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].descripcion'))),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].cantidad'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].precio_unitario'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2))
        );
        SET v_idx = v_idx + 1;
    END WHILE;

    COMMIT;
END$$

DELIMITER ;


-- ============================================================================
-- 2. MODIFICAR sp_ActualizarPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios TEXT,
    IN p_gastos_generales DECIMAL(15,2),
    IN p_utilidad DECIMAL(15,2),
    IN p_supervision_obra DECIMAL(15,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_monto_total DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_costos_directos DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_sub_total DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_igv DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_count INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- ====== CALCULAR COSTOS DIRECTOS (Suma de materiales + servicios) ======
    
    -- Sumar materiales
    SET v_count = JSON_LENGTH(p_materiales_json);
    WHILE v_idx < v_count DO
        SET v_costos_directos = v_costos_directos + CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2));
        SET v_idx = v_idx + 1;
    END WHILE;
    
    -- Sumar servicios
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_servicios_json);
    WHILE v_idx < v_count DO
        SET v_costos_directos = v_costos_directos + CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2));
        SET v_idx = v_idx + 1;
    END WHILE;

    -- ====== CALCULAR SUB TOTAL = Costos Directos + GG + Utilidad (SIN Supervisión) ======
    SET v_sub_total = v_costos_directos + p_gastos_generales + p_utilidad;
    
    -- ====== CALCULAR IGV = 18% del SUB TOTAL ======
    SET v_igv = ROUND(v_sub_total * 0.18, 2);
    
    -- ====== CALCULAR MONTO TOTAL = SUB TOTAL + IGV + Supervisión ======
    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;

    -- ====== ACTUALIZAR PRESUPUESTO ======
    UPDATE TblPresupuesto SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        observaciones = p_comentarios,
        monto = v_monto_total,
        gastos_generales = p_gastos_generales,
        utilidad = p_utilidad,
        igv = v_igv,  -- IGV calculado correctamente
        supervision_obra = p_supervision_obra,
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    -- ====== ELIMINAR DETALLES ANTERIORES ======
    DELETE FROM TblPresupuestoDetalle WHERE id_presupuesto = p_id_presupuesto;

    -- ====== INSERTAR MATERIALES ======
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_materiales_json);
    WHILE v_idx < v_count DO
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            tipo_detalle,
            id_material,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal
        ) VALUES (
            p_id_presupuesto,
            'MATERIAL',
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].id_material'))) AS UNSIGNED),
            JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].nombre'))),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].cantidad'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].precio_unitario'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2))
        );
        SET v_idx = v_idx + 1;
    END WHILE;

    -- ====== INSERTAR SERVICIOS ======
    SET v_idx = 0;
    SET v_count = JSON_LENGTH(p_servicios_json);
    WHILE v_idx < v_count DO
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            tipo_detalle,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal
        ) VALUES (
            p_id_presupuesto,
            'SERVICIO',
            JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].descripcion'))),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].cantidad'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].precio_unitario'))) AS DECIMAL(15,2)),
            CAST(JSON_UNQUOTE(JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_idx, '].subtotal'))) AS DECIMAL(15,2))
        );
        SET v_idx = v_idx + 1;
    END WHILE;

    COMMIT;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Stored procedures actualizados correctamente' AS mensaje;
SELECT 'Ahora el IGV se calcula correctamente sobre el SUB TOTAL (Costos Directos + GG + Utilidad)' AS nota;
