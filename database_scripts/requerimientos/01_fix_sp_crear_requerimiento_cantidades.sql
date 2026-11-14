-- ============================================================================
-- FIX: sp_CrearRequerimientoCompleto debe respetar las cantidades del formulario
-- ============================================================================
-- Problema detectado:
--   El SP original insertaba TblRequerimientoDetalle usando siempre
--   pd.cantidad (la cantidad original del presupuesto) e ignoraba la cantidad
--   enviada por el usuario en el JSON.
--
--   Resultado: el usuario pedía 5 unidades y el requerimiento guardaba 100.
--
-- Solución:
--   Leer jt.cantidad desde el JSON enviado por /api/requerimientos/crear y
--   usarla para:
--     1. TblRequerimiento.cantidad
--     2. TblRequerimientoDetalle.cantidad
--     3. TblPresupuestoDetalle.cantidad_consumida
--     4. TblPresupuesto.cantidad_consumida
--
-- Ejecutar este script sobre la base de datos de Kallpa.
-- Es idempotente: reemplaza el SP si ya existe.
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoCompleto`;

DELIMITER $$

CREATE PROCEDURE `sp_CrearRequerimientoCompleto`(
    IN p_num_usuario INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    IN p_id_presupuesto INT,
    OUT p_id_requerimiento_created INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_cantidad_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE v_id_tipo_documento INT DEFAULT 2;
    DECLARE v_numero_paso INT;
    DECLARE v_id_cargo INT;
    DECLARE done INT DEFAULT FALSE;

    DECLARE flujo_cursor CURSOR FOR
        SELECT numero_paso, id_cargo
        FROM `TblFlujoAprobacionCargos`
        WHERE id_tipo_documento = v_id_tipo_documento
          AND activo = 1
          AND es_requerido = 1
        ORDER BY numero_paso;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF p_num_usuario IS NULL OR p_num_usuario <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'num_usuario invalido o nulo';
    END IF;

    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos';
    END IF;

    -- Código generado por la BD: REQ-00001, REQ-00002, ...
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM `TblRequerimiento`
    WHERE codigo LIKE 'REQ-%';

    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;

    -- Si el frontend no envía id_presupuesto, se deduce del primer detalle.
    IF p_id_presupuesto IS NULL THEN
        SELECT COALESCE(pd.id_presupuesto, NULL)
        INTO p_id_presupuesto
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto',
            cantidad DECIMAL(10, 2) PATH '$.cantidad'
        )) jt
        INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle
        LIMIT 1;
    END IF;

    -- Total del requerimiento: suma de las cantidades solicitadas en el formulario.
    SELECT COALESCE(SUM(COALESCE(jt.cantidad, pd.cantidad, 1)), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_detalle INT PATH '$.id_detalle_presupuesto',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle;

    INSERT INTO `TblRequerimiento` (
        codigo, num_usuario, id_presupuesto, descripcion,
        cantidad, estado, observaciones, fecha_creacion
    ) VALUES (
        v_codigo, p_num_usuario, p_id_presupuesto, p_descripcion,
        COALESCE(v_cantidad_total, 0), 'PENDIENTE', COALESCE(p_observaciones, ''), NOW()
    );

    SET p_id_requerimiento_created = LAST_INSERT_ID();

    -- Detalles: id_inventario + cantidad solicitada por el usuario.
    INSERT INTO `TblRequerimientoDetalle` (
        id_requerimiento,
        id_inventario,
        tipo_item,
        descripcion,
        cantidad,
        observaciones,
        fecha_creacion
    )
    SELECT
        p_id_requerimiento_created,
        pd.id_inventario,
        COALESCE(pd.tipo_item, 'MATERIAL'),
        CASE
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') IN ('SERVICIO','PARTIDA')
                THEN COALESCE(pd.descripcion, 'Servicio o partida sin descripción')
            ELSE COALESCE(i.nombre, pd.descripcion, 'Material sin especificar')
        END,
        COALESCE(jt.cantidad, pd.cantidad, 1),
        NULL,
        NOW()
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_detalle INT PATH '$.id_detalle_presupuesto',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario;

    -- Consumo del presupuesto con la cantidad solicitada, no con pd.cantidad.
    UPDATE `TblPresupuestoDetalle` pd
    INNER JOIN (
        SELECT jt.id_detalle, COALESCE(jt.cantidad, pd2.cantidad, 1) AS cantidad_requerida
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto',
            cantidad DECIMAL(10, 2) PATH '$.cantidad'
        )) jt
        INNER JOIN `TblPresupuestoDetalle` pd2 ON pd2.id_detalle = jt.id_detalle
    ) req ON pd.id_detalle = req.id_detalle
    SET
        pd.cantidad_consumida = pd.cantidad_consumida + req.cantidad_requerida,
        pd.fecha_actualizacion = NOW()
    WHERE pd.id_presupuesto = p_id_presupuesto;

    UPDATE `TblPresupuesto`
    SET
        cantidad_consumida = cantidad_consumida + v_cantidad_total,
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    -- Flujo de aprobación: un registro PENDIENTE por cada paso/cargo configurado.
    OPEN flujo_cursor;

    read_loop: LOOP
        FETCH flujo_cursor INTO v_numero_paso, v_id_cargo;
        IF done THEN LEAVE read_loop; END IF;

        INSERT INTO `TblRegistroAprobacion` (
            id_tipo_documento, id_documento_referencia, numero_paso,
            id_cargo_aprobador, num_documento_aprobador, estado_aprobacion,
            comentario, fecha_asignacion, fecha_aprobacion
        ) VALUES (
            v_id_tipo_documento, p_id_requerimiento_created, v_numero_paso,
            v_id_cargo, NULL, 'PENDIENTE', NULL, NOW(), NULL
        );
    END LOOP;

    CLOSE flujo_cursor;

END$$

DELIMITER ;
