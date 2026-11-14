-- ============================================================================
-- REQUERIMIENTO ADMINISTRATIVO - 03: PROCEDIMIENTOS PROPIOS DEL MÓDULO
-- FECHA: 13/11/2026
--
-- Tipo de documento de aprobación: 7 (creado en 01_respaldos_y_configuracion.sql)
-- Tipo de requerimiento:            1 = Administrativo
--
-- SP:
--   sp_CrearRequerimientoAdministrativo        crear + descontar stock + SALIDA + paso PENDIENTE
--   sp_AprobarRequerimientoAdministrativo      aprueba el paso del cargo del usuario
--   sp_RechazarRequerimientoAdministrativo     rechaza + repone stock (DEVOLUCION)
--   sp_ActualizarRequerimientoAdministrativo   edita descripción/observaciones (solo PENDIENTE)
--   sp_EliminarRequerimientoAdministrativo     repone stock + elimina (solo PENDIENTE)
--   sp_ObtenerRequerimientosGeneral            lista de Logística (obras + administrativos)
--   sp_ObtenerPasosRequerimientoAdministrativo línea de pasos del detalle
--   sp_RQA_ReponerStock                        (interno) devuelve el stock de un requerimiento
--
-- Errores de negocio: SIGNAL SQLSTATE '45000' con un mensaje legible para el usuario.
-- No modifica ningún SP existente.
-- ============================================================================


-- ============================================================================
-- (interno) sp_RQA_ReponerStock
-- Debe llamarse DENTRO de una transacción abierta por el SP que lo invoca.
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_RQA_ReponerStock`;

DELIMITER $$

CREATE PROCEDURE `sp_RQA_ReponerStock`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    IN p_motivo VARCHAR(300)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_bloqueados INT DEFAULT 0;

    -- Bloquear las filas de inventario involucradas
    SELECT COUNT(*) INTO v_bloqueados
    FROM `TblInventario` i
    INNER JOIN `TblRequerimientoDetalle` d ON d.id_inventario = i.id_inventario
    WHERE d.id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    -- Movimiento DEVOLUCION por material (código único por requerimiento + material)
    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_destino, tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
    )
    SELECT
        CONCAT('DEV-RQA', LPAD(p_id_requerimiento, 6, '0'), '-', LPAD(i.id_inventario, 5, '0')),
        i.id_inventario,
        'DEVOLUCION',
        d.cantidad,
        i.id_almacen,
        'REQUERIMIENTO',
        p_id_requerimiento,
        i.precio_compra,
        d.cantidad * COALESCE(i.precio_compra, 0),
        p_motivo,
        NOW(),
        p_num_documento
    FROM (
        SELECT id_inventario, SUM(cantidad) AS cantidad
        FROM `TblRequerimientoDetalle`
        WHERE id_requerimiento = p_id_requerimiento
          AND id_inventario IS NOT NULL
        GROUP BY id_inventario
    ) d
    INNER JOIN `TblInventario` i ON i.id_inventario = d.id_inventario;

    -- Devolver el stock
    UPDATE `TblInventario` i
    INNER JOIN (
        SELECT id_inventario, SUM(cantidad) AS cantidad
        FROM `TblRequerimientoDetalle`
        WHERE id_requerimiento = p_id_requerimiento
          AND id_inventario IS NOT NULL
        GROUP BY id_inventario
    ) d ON d.id_inventario = i.id_inventario
    SET i.stock_actual = COALESCE(i.stock_actual, 0) + d.cantidad;
END$$

DELIMITER ;


-- ============================================================================
-- sp_CrearRequerimientoAdministrativo
-- p_detalles_json: [{"id_inventario": 41, "cantidad": 2}, ...]
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_CrearRequerimientoAdministrativo`(
    IN p_num_usuario INT,
    IN p_num_documento INT,
    IN p_fecha_solicitud DATE,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_id_requerimiento INT,
    OUT p_codigo VARCHAR(20)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_id_tipo_documento INT DEFAULT 7;
    DECLARE v_id_req INT;
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_items INT DEFAULT 0;
    DECLARE v_encontrados INT DEFAULT 0;
    DECLARE v_cantidad_total DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_pasos INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;
        RESIGNAL;
    END;

    SET p_id_requerimiento = NULL;
    SET p_codigo = NULL;

    -- ---- Validaciones de entrada -------------------------------------------
    IF p_num_usuario IS NULL OR p_num_usuario <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no válido';
    END IF;

    IF p_descripcion IS NULL OR TRIM(p_descripcion) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La descripción es obligatoria';
    END IF;

    IF p_detalles_json IS NULL OR JSON_VALID(p_detalles_json) = 0 OR JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe agregar al menos un material';
    END IF;

    -- Items agrupados por material (si el mismo material viene 2 veces, se suma)
    DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;
    CREATE TEMPORARY TABLE tmp_rqa_items (
        id_inventario INT NULL,
        cantidad DECIMAL(10, 2) NULL,
        KEY (id_inventario)
    );

    INSERT INTO tmp_rqa_items (id_inventario, cantidad)
    SELECT jt.id_inventario, SUM(jt.cantidad)
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_inventario INT PATH '$.id_inventario',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    GROUP BY jt.id_inventario;

    IF EXISTS (SELECT 1 FROM tmp_rqa_items WHERE id_inventario IS NULL OR cantidad IS NULL OR cantidad <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Todos los materiales deben tener una cantidad mayor a 0';
    END IF;

    START TRANSACTION;

    -- ---- Materiales válidos (y bloqueo de sus filas de inventario) ---------
    SELECT COUNT(*) INTO v_items FROM tmp_rqa_items;

    SELECT COUNT(*) INTO v_encontrados
    FROM `TblInventario` i
    INNER JOIN tmp_rqa_items t ON t.id_inventario = i.id_inventario
    WHERE i.estado = 'ACTIVO'
      AND i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
    FOR UPDATE;

    IF v_encontrados < v_items THEN
        SELECT CONCAT('El material con id ', t.id_inventario,
                      ' no existe, está inactivo o no es un material de almacén')
        INTO v_msg
        FROM tmp_rqa_items t
        LEFT JOIN `TblInventario` i
               ON i.id_inventario = t.id_inventario
              AND i.estado = 'ACTIVO'
              AND i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
        WHERE i.id_inventario IS NULL
        LIMIT 1;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- ---- Stock suficiente --------------------------------------------------
    SELECT CONCAT('Stock insuficiente para "', i.nombre, '": disponible ',
                  FORMAT(COALESCE(i.stock_actual, 0), 2), ', solicitado ', FORMAT(t.cantidad, 2))
    INTO v_msg
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario
    WHERE COALESCE(i.stock_actual, 0) < t.cantidad
    LIMIT 1;

    IF v_msg IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- ---- Código RQA-00001 (numeración propia) ------------------------------
    SELECT CONCAT('RQA-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM `TblRequerimiento`
    WHERE codigo LIKE 'RQA-%'
    FOR UPDATE;

    SELECT COALESCE(SUM(cantidad), 0) INTO v_cantidad_total FROM tmp_rqa_items;

    -- ---- Cabecera ----------------------------------------------------------
    INSERT INTO `TblRequerimiento` (
        id_tipo_requerimiento, id_tipo_documento, num_usuario, id_presupuesto,
        codigo, descripcion, cantidad, estado, observaciones, fecha_creacion
    ) VALUES (
        1, v_id_tipo_documento, p_num_usuario, NULL,
        v_codigo, TRIM(p_descripcion), ROUND(v_cantidad_total), 'PENDIENTE',
        COALESCE(p_observaciones, ''),
        TIMESTAMP(COALESCE(p_fecha_solicitud, CURDATE()), CURTIME())
    );

    SET v_id_req = LAST_INSERT_ID();

    -- ---- Detalle -----------------------------------------------------------
    INSERT INTO `TblRequerimientoDetalle` (
        id_requerimiento, id_inventario, tipo_item, descripcion, cantidad, observaciones, fecha_creacion
    )
    SELECT v_id_req, i.id_inventario, 'MATERIAL', i.nombre, t.cantidad, NULL, NOW()
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario;

    -- ---- Movimiento SALIDA (código único por requerimiento + material) ----
    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_origen, tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
    )
    SELECT
        CONCAT('SAL-RQA', LPAD(v_id_req, 6, '0'), '-', LPAD(i.id_inventario, 5, '0')),
        i.id_inventario,
        'SALIDA',
        t.cantidad,
        i.id_almacen,
        'REQUERIMIENTO',
        v_id_req,
        i.precio_compra,
        t.cantidad * COALESCE(i.precio_compra, 0),
        CONCAT('Requerimiento administrativo ', v_codigo),
        NOW(),
        p_num_documento
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario;

    -- ---- Descontar stock ---------------------------------------------------
    UPDATE `TblInventario` i
    INNER JOIN tmp_rqa_items t ON t.id_inventario = i.id_inventario
    SET i.stock_actual = COALESCE(i.stock_actual, 0) - t.cantidad;

    -- ---- Pasos de aprobación (flujo del tipo 7) ----------------------------
    INSERT INTO `TblRegistroAprobacion` (
        id_tipo_documento, id_documento_referencia, numero_paso,
        id_cargo_aprobador, num_documento_aprobador, estado_aprobacion,
        comentario, fecha_asignacion, fecha_aprobacion
    )
    SELECT v_id_tipo_documento, v_id_req, f.numero_paso, f.id_cargo, NULL, 'PENDIENTE', NULL, NOW(), NULL
    FROM `TblFlujoAprobacionCargos` f
    WHERE f.id_tipo_documento = v_id_tipo_documento
      AND f.activo = 1
      AND f.es_requerido = 1
    ORDER BY f.numero_paso;

    SET v_pasos = ROW_COUNT();

    IF v_pasos = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No hay flujo de aprobación configurado para Requerimiento Administrativo';
    END IF;

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;

    SET p_id_requerimiento = v_id_req;
    SET p_codigo = v_codigo;
END$$

DELIMITER ;


-- ============================================================================
-- sp_AprobarRequerimientoAdministrativo
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_AprobarRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_AprobarRequerimientoAdministrativo`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    IN p_comentario TEXT,
    OUT p_aprobacion_completa BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_id_cargo INT DEFAULT NULL;
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    DECLARE v_tipo_doc INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50) DEFAULT NULL;
    DECLARE v_id_registro INT DEFAULT NULL;
    DECLARE v_paso INT DEFAULT NULL;
    DECLARE v_previos_pendientes INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;
    DECLARE v_aprobados INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_aprobacion_completa = FALSE;
    SET p_mensaje = NULL;

    SELECT id_cargo INTO v_id_cargo
    FROM `TblUsuario`
    WHERE num_documento = p_num_documento AND estado = 'Activo'
    LIMIT 1;

    IF v_id_cargo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tu usuario no tiene un cargo asignado o no está activo';
    END IF;

    START TRANSACTION;

    SELECT estado, id_tipo_documento, codigo INTO v_estado, v_tipo_doc, v_codigo
    FROM `TblRequerimiento`
    WHERE id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    IF v_tipo_doc <> 7 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No es un requerimiento administrativo';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('El requerimiento ya está ', v_estado);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_mensaje;
    END IF;

    SELECT id_registro, numero_paso INTO v_id_registro, v_paso
    FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento
      AND id_cargo_aprobador = v_id_cargo
      AND estado_aprobacion = 'PENDIENTE'
    ORDER BY numero_paso
    LIMIT 1
    FOR UPDATE;

    IF v_id_registro IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes un paso pendiente de aprobación en este requerimiento';
    END IF;

    SELECT COUNT(*) INTO v_previos_pendientes
    FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento
      AND numero_paso < v_paso
      AND estado_aprobacion <> 'APROBADO';

    IF v_previos_pendientes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aún hay pasos anteriores sin aprobar';
    END IF;

    UPDATE `TblRegistroAprobacion`
    SET estado_aprobacion = 'APROBADO',
        num_documento_aprobador = p_num_documento,
        comentario = p_comentario,
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;

    SELECT COUNT(*), COALESCE(SUM(estado_aprobacion = 'APROBADO'), 0)
    INTO v_total, v_aprobados
    FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento;

    IF v_total = v_aprobados THEN
        UPDATE `TblRequerimiento`
        SET estado = 'APROBADO', fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;

        SET p_aprobacion_completa = TRUE;
        SET p_mensaje = CONCAT('Requerimiento ', v_codigo, ' APROBADO');
    ELSE
        SET p_mensaje = CONCAT('Paso aprobado. Progreso: ', v_aprobados, '/', v_total);
    END IF;

    COMMIT;
END$$

DELIMITER ;


-- ============================================================================
-- sp_RechazarRequerimientoAdministrativo  (repone stock)
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_RechazarRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_RechazarRequerimientoAdministrativo`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    IN p_comentario TEXT,
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_id_cargo INT DEFAULT NULL;
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    DECLARE v_tipo_doc INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50) DEFAULT NULL;
    DECLARE v_id_registro INT DEFAULT NULL;
    DECLARE v_paso INT DEFAULT NULL;
    DECLARE v_previos_pendientes INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_mensaje = NULL;

    IF p_comentario IS NULL OR TRIM(p_comentario) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe indicar el motivo del rechazo';
    END IF;

    SELECT id_cargo INTO v_id_cargo
    FROM `TblUsuario`
    WHERE num_documento = p_num_documento AND estado = 'Activo'
    LIMIT 1;

    IF v_id_cargo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tu usuario no tiene un cargo asignado o no está activo';
    END IF;

    START TRANSACTION;

    SELECT estado, id_tipo_documento, codigo INTO v_estado, v_tipo_doc, v_codigo
    FROM `TblRequerimiento`
    WHERE id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    IF v_tipo_doc <> 7 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No es un requerimiento administrativo';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('El requerimiento ya está ', v_estado);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_mensaje;
    END IF;

    SELECT id_registro, numero_paso INTO v_id_registro, v_paso
    FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento
      AND id_cargo_aprobador = v_id_cargo
      AND estado_aprobacion = 'PENDIENTE'
    ORDER BY numero_paso
    LIMIT 1
    FOR UPDATE;

    IF v_id_registro IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes un paso pendiente de aprobación en este requerimiento';
    END IF;

    SELECT COUNT(*) INTO v_previos_pendientes
    FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento
      AND numero_paso < v_paso
      AND estado_aprobacion <> 'APROBADO';

    IF v_previos_pendientes > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aún hay pasos anteriores sin aprobar';
    END IF;

    UPDATE `TblRegistroAprobacion`
    SET estado_aprobacion = 'RECHAZADO',
        num_documento_aprobador = p_num_documento,
        comentario = TRIM(p_comentario),
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;

    UPDATE `TblRequerimiento`
    SET estado = 'RECHAZADO', fecha_actualizacion = NOW()
    WHERE id_requerimiento = p_id_requerimiento;

    CALL sp_RQA_ReponerStock(p_id_requerimiento, p_num_documento,
                             CONCAT('Rechazo del requerimiento administrativo ', v_codigo));

    COMMIT;

    SET p_mensaje = CONCAT('Requerimiento ', v_codigo, ' RECHAZADO. Stock repuesto.');
END$$

DELIMITER ;


-- ============================================================================
-- sp_ActualizarRequerimientoAdministrativo  (solo PENDIENTE)
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_ActualizarRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_ActualizarRequerimientoAdministrativo`(
    IN p_id_requerimiento INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    DECLARE v_tipo_req INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_mensaje = NULL;

    IF p_descripcion IS NULL OR TRIM(p_descripcion) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La descripción es obligatoria';
    END IF;

    START TRANSACTION;

    SELECT estado, id_tipo_requerimiento, codigo INTO v_estado, v_tipo_req, v_codigo
    FROM `TblRequerimiento`
    WHERE id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    IF v_tipo_req <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No es un requerimiento administrativo';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('Solo se puede editar un requerimiento PENDIENTE (está ', v_estado, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_mensaje;
    END IF;

    UPDATE `TblRequerimiento`
    SET descripcion = TRIM(p_descripcion),
        observaciones = COALESCE(p_observaciones, ''),
        fecha_actualizacion = NOW()
    WHERE id_requerimiento = p_id_requerimiento;

    COMMIT;

    SET p_mensaje = CONCAT('Requerimiento ', v_codigo, ' actualizado');
END$$

DELIMITER ;


-- ============================================================================
-- sp_EliminarRequerimientoAdministrativo  (solo PENDIENTE, repone stock)
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_EliminarRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_EliminarRequerimientoAdministrativo`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    OUT p_codigo VARCHAR(50),
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(50) DEFAULT NULL;
    DECLARE v_tipo_req INT DEFAULT NULL;
    DECLARE v_codigo VARCHAR(50) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_codigo = NULL;
    SET p_mensaje = NULL;

    START TRANSACTION;

    SELECT estado, id_tipo_requerimiento, codigo INTO v_estado, v_tipo_req, v_codigo
    FROM `TblRequerimiento`
    WHERE id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    IF v_tipo_req <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No es un requerimiento administrativo';
    END IF;
    IF v_estado <> 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('Solo se puede eliminar un requerimiento PENDIENTE (está ', v_estado, ')');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_mensaje;
    END IF;

    CALL sp_RQA_ReponerStock(p_id_requerimiento, p_num_documento,
                             CONCAT('Eliminación del requerimiento administrativo ', v_codigo));

    DELETE FROM `TblRegistroAprobacion`
    WHERE id_tipo_documento = 7
      AND id_documento_referencia = p_id_requerimiento;

    DELETE FROM `TblRequerimientoDetalle`
    WHERE id_requerimiento = p_id_requerimiento;

    DELETE FROM `TblRequerimiento`
    WHERE id_requerimiento = p_id_requerimiento;

    COMMIT;

    SET p_codigo = v_codigo;
    SET p_mensaje = CONCAT('Requerimiento ', v_codigo, ' eliminado. Stock repuesto.');
END$$

DELIMITER ;


-- ============================================================================
-- sp_ObtenerRequerimientosGeneral  (Logística: obras + administrativos)
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientosGeneral`;

DELIMITER $$

CREATE PROCEDURE `sp_ObtenerRequerimientosGeneral`()
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
        tr.id_tipo_requerimiento,
        COALESCE(ttr.nombre, '') AS tipo_requerimiento,
        COALESCE(ttr.color_badge, '#6B7280') AS tipo_color,
        tr.id_tipo_documento,

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
        CASE WHEN ra.estado_aprobacion = 'RECHAZADO' THEN ra.comentario ELSE NULL END AS comentario_rechazo,
        tr.id_presupuesto,
        pres.numero_presupuesto

    FROM TblRequerimiento tr

    LEFT JOIN TblTipoRequerimiento ttr ON ttr.id_tipo_requerimiento = tr.id_tipo_requerimiento

    LEFT JOIN TblUsuario u_sol ON tr.num_usuario = u_sol.num_usuario
    LEFT JOIN TblPersona p_sol ON u_sol.num_documento = p_sol.num_documento

    -- Última decisión (aprobación o rechazo) registrada
    LEFT JOIN TblRegistroAprobacion ra ON (
        ra.id_registro = (
            SELECT MAX(ra2.id_registro)
            FROM TblRegistroAprobacion ra2
            WHERE ra2.id_documento_referencia = tr.id_requerimiento
              AND ra2.id_tipo_documento = tr.id_tipo_documento
              AND ra2.estado_aprobacion IN ('APROBADO', 'RECHAZADO')
        )
    )

    LEFT JOIN TblPersona p_apr ON ra.num_documento_aprobador = p_apr.num_documento

    LEFT JOIN TblPresupuesto pres ON tr.id_presupuesto = pres.id_presupuesto

    WHERE tr.estado <> 'ELIMINADO'

    ORDER BY tr.fecha_creacion DESC;
END$$

DELIMITER ;


-- ============================================================================
-- sp_ObtenerPasosRequerimientoAdministrativo
-- ============================================================================
DROP PROCEDURE IF EXISTS `sp_ObtenerPasosRequerimientoAdministrativo`;

DELIMITER $$

CREATE PROCEDURE `sp_ObtenerPasosRequerimientoAdministrativo`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    SELECT
        ra.numero_paso,
        COALESCE(f.nombre_paso, '') AS nombre_paso,
        1 AS es_requerido,
        ra.id_cargo_aprobador,
        ra.estado_aprobacion AS estado,
        TRIM(CONCAT(
            COALESCE(per.nombres, ''), ' ',
            COALESCE(per.apellido_paterno, ''), ' ',
            COALESCE(per.apellido_materno, '')
        )) AS nombre_aprobador,
        c.nombre AS nombre_cargo,
        ra.fecha_aprobacion,
        ra.fecha_asignacion,
        ra.comentario
    FROM TblRegistroAprobacion ra
    LEFT JOIN TblFlujoAprobacionCargos f
           ON f.id_tipo_documento = ra.id_tipo_documento
          AND f.numero_paso = ra.numero_paso
          AND f.id_cargo = ra.id_cargo_aprobador
    LEFT JOIN TblCargo c ON c.id_cargo = ra.id_cargo_aprobador
    LEFT JOIN TblPersona per ON per.num_documento = ra.num_documento_aprobador
    WHERE ra.id_tipo_documento = 7
      AND ra.id_documento_referencia = p_id_requerimiento
    ORDER BY ra.numero_paso;
END$$

DELIMITER ;
