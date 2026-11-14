-- ============================================================================
-- REQUERIMIENTO ADMINISTRATIVO - 02: AJUSTES MÍNIMOS EN REQUERIMIENTO DE OBRA
-- FECHA: 13/11/2026
--
-- Qué hace:
--   0) Respaldo del código actual de los 2 SP que se reemplazan.
--   1) sp_CrearRequerimientoCompleto:
--        - Incluye el fix pendiente 01_fix_sp_crear_requerimiento_cantidades.sql
--          (respeta la cantidad que envía el usuario).
--        - NUEVO: guarda id_tipo_requerimiento = 2 (Obra) e id_tipo_documento = 2.
--          Sin esto, los requerimientos de obra nuevos quedarían como tipo 1
--          (Administrativo) por el DEFAULT de la columna.
--   2) sp_ObtenerRequerimientosConAprobadores (lista de O.T):
--        - Mismo SELECT de siempre + WHERE tr.id_tipo_requerimiento = 2.
--
-- Firmas (parámetros) SIN CAMBIOS: el código Python de O.T no se toca.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) RESPALDO DE LOS SP (texto del CREATE PROCEDURE actual)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `respaldo_sp_obra_20261113` AS
    SELECT ROUTINE_NAME, ROUTINE_DEFINITION, NOW() AS fecha_respaldo
    FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = DATABASE()
      AND ROUTINE_NAME IN ('sp_CrearRequerimientoCompleto', 'sp_ObtenerRequerimientosConAprobadores');

-- ----------------------------------------------------------------------------
-- 1) sp_CrearRequerimientoCompleto
-- ----------------------------------------------------------------------------
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
    DECLARE v_id_tipo_requerimiento INT DEFAULT 2;   -- 2 = Obra
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
        codigo, id_tipo_requerimiento, id_tipo_documento, num_usuario, id_presupuesto, descripcion,
        cantidad, estado, observaciones, fecha_creacion
    ) VALUES (
        v_codigo, v_id_tipo_requerimiento, v_id_tipo_documento, p_num_usuario, p_id_presupuesto, p_descripcion,
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

-- ----------------------------------------------------------------------------
-- 2) sp_ObtenerRequerimientosConAprobadores (lista O.T) - solo Obra
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientosConAprobadores`;

DELIMITER $$

CREATE PROCEDURE `sp_ObtenerRequerimientosConAprobadores`()
    READS SQL DATA
BEGIN
    SELECT
        tr.id_requerimiento,
        tr.codigo,
        tr.descripcion,
        tr.cantidad,
        tr.estado,
        tr.observaciones,
        tr.fecha_creacion,
        tr.fecha_actualizacion,

        TRIM(CONCAT(
            COALESCE(p_sol.nombres, ''), ' ',
            COALESCE(p_sol.apellido_paterno, ''), ' ',
            COALESCE(p_sol.apellido_materno, '')
        )) AS solicitante,

        TRIM(CONCAT(
            COALESCE(p_apr.nombres, ''), ' ',
            COALESCE(p_apr.apellido_paterno, ''), ' ',
            COALESCE(p_apr.apellido_materno, '')
        )) AS aprobado_rechazado_por,

        ra.fecha_aprobacion AS fecha_aprobacion_rechazo,
        ra.comentario AS comentario_rechazo,
        tr.id_presupuesto,
        pres.numero_presupuesto

    FROM TblRequerimiento tr

    LEFT JOIN TblUsuario u_sol ON tr.num_usuario = u_sol.num_usuario
    LEFT JOIN TblPersona p_sol ON u_sol.num_documento = p_sol.num_documento

    LEFT JOIN TblRegistroAprobacion ra ON (
        ra.id_documento_referencia = tr.id_requerimiento
        AND ra.id_tipo_documento = 2
        AND ra.id_registro = (
            SELECT MAX(ra2.id_registro)
            FROM TblRegistroAprobacion ra2
            WHERE ra2.id_documento_referencia = tr.id_requerimiento
              AND ra2.id_tipo_documento = 2
        )
    )

    LEFT JOIN TblUsuario u_apr ON ra.num_documento_aprobador = u_apr.num_documento
    LEFT JOIN TblPersona p_apr ON u_apr.num_documento = p_apr.num_documento

    LEFT JOIN TblPresupuesto pres ON tr.id_presupuesto = pres.id_presupuesto

    WHERE tr.id_tipo_requerimiento = 2   -- NUEVO: O.T solo muestra requerimientos de Obra

    ORDER BY tr.fecha_creacion DESC;
END$$

DELIMITER ;
