-- Definicion ACTUAL de SP, funciones, vistas y triggers exportada de la BD
-- Fecha: 2026-11-13 23:08
-- 118 rutinas, 6 vistas, 0 triggers
-- Es la referencia vigente: reemplaza a los scripts de migracion ya aplicados.

SET NAMES utf8mb4;
DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_ActualizarEmpresa`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarEmpresa`(
    IN p_id_empresa   INT,
    IN p_ruc          VARCHAR(11),
    IN p_nombre       VARCHAR(255),
    IN p_latitud      DECIMAL(10,8),
    IN p_longitud     DECIMAL(11,8),
    IN p_radio_metros INT,
    IN p_logo         LONGBLOB
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count FROM TblEmpresa WHERE id_empresa = p_id_empresa;
    IF v_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Empresa no encontrada';
    END IF;

    SELECT COUNT(*) INTO v_count FROM TblEmpresa
     WHERE ruc = p_ruc AND id_empresa <> p_id_empresa;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una empresa con ese RUC';
    END IF;

    SELECT COUNT(*) INTO v_count FROM TblEmpresa
     WHERE nombre = p_nombre AND id_empresa <> p_id_empresa;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una empresa con ese nombre';
    END IF;

    -- logo = NULL desde el backend significa "no modificar"
    UPDATE TblEmpresa
       SET ruc          = p_ruc,
           nombre       = p_nombre,
           latitud      = p_latitud,
           longitud     = p_longitud,
           radio_metros = p_radio_metros,
           logo         = IF(p_logo IS NOT NULL, p_logo, logo)
     WHERE id_empresa = p_id_empresa;
END$$

DROP PROCEDURE IF EXISTS `sp_ActualizarPresupuestoCompleto`$$
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
    DECLARE v_costos_directos DECIMAL(12,2) DEFAULT 0;
    DECLARE v_sub_total DECIMAL(12,2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12,2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12,2) DEFAULT 0;

    CALL `sp_GuardarSnapshotAntesDeEditar`(p_id_presupuesto, p_num_documento);

    SELECT COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) *
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_costos_directos
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SELECT v_costos_directos + COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) *
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_costos_directos
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SET v_sub_total = v_costos_directos + p_gastos_generales + p_utilidad;
    SET v_igv = ROUND(v_sub_total * 0.18, 2);
    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;

    UPDATE `TblPresupuesto`
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = p_num_documento,
        monto = v_costos_directos,
        monto_total = v_monto_total,
        observaciones = p_comentarios,
        gastos_generales = p_gastos_generales,
        utilidad = p_utilidad,
        igv = v_igv,
        supervision_obra = p_supervision_obra,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    DELETE FROM `TblRegistroAprobacion`
    WHERE id_documento_referencia = p_id_presupuesto
      AND id_tipo_documento = 1;

    DELETE FROM `TblPresupuestoDetalle`
    WHERE id_presupuesto = p_id_presupuesto;

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
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
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'SERVICIO' THEN 'SERVICIO'
            ELSE 'MATERIAL'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
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
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            ELSE 'SERVICIO'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

    INSERT INTO `TblRegistroAprobacion` (
        id_tipo_documento,
        id_documento_referencia,
        numero_paso,
        id_cargo_aprobador,
        estado_aprobacion,
        fecha_asignacion
    )
    SELECT
        fac.id_tipo_documento,
        p_id_presupuesto,
        fac.numero_paso,
        fac.id_cargo,
        'PENDIENTE',
        NOW()
    FROM `TblFlujoAprobacionCargos` fac
    WHERE fac.id_tipo_documento = 1
      AND fac.activo = 1
    ORDER BY fac.numero_paso;

END$$

DROP PROCEDURE IF EXISTS `sp_ActualizarProveedor`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarProveedor`(
    IN p_ruc_actual VARCHAR(11),
    IN p_ruc_nuevo VARCHAR(11),
    IN p_razon_social VARCHAR(255),
    IN p_nombre_comercial VARCHAR(255),
    IN p_tipo_contribuyente VARCHAR(20),
    IN p_telefono VARCHAR(20),
    IN p_telefono_alternativo VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_email_facturacion VARCHAR(100),
    IN p_sitio_web VARCHAR(255),
    IN p_direccion_fiscal TEXT,
    IN p_departamento VARCHAR(100),
    IN p_provincia VARCHAR(100),
    IN p_distrito VARCHAR(100),
    IN p_ubigeo VARCHAR(6),
    IN p_referencia TEXT,
    IN p_contacto_nombre VARCHAR(255),
    IN p_contacto_cargo VARCHAR(100),
    IN p_contacto_telefono VARCHAR(20),
    IN p_contacto_email VARCHAR(100),
    IN p_contacto_dni VARCHAR(8),
    IN p_banco_1 VARCHAR(100),
    IN p_cuenta_banco_1 VARCHAR(50),
    IN p_tipo_cuenta_1 VARCHAR(20),
    IN p_moneda_1 VARCHAR(10),
    IN p_cci_1 VARCHAR(20),
    IN p_banco_2 VARCHAR(100),
    IN p_cuenta_banco_2 VARCHAR(50),
    IN p_tipo_cuenta_2 VARCHAR(20),
    IN p_moneda_2 VARCHAR(10),
    IN p_cci_2 VARCHAR(20),
    IN p_rubro_negocio VARCHAR(255),
    IN p_categoria VARCHAR(20),
    IN p_calificacion VARCHAR(20),
    IN p_condicion_pago VARCHAR(100),
    IN p_plazo_entrega VARCHAR(100),
    IN p_descuento_comercial DECIMAL(5,2),
    IN p_es_agente_retencion TINYINT(1),
    IN p_es_buen_contribuyente TINYINT(1),
    IN p_tiene_certificado_calidad TINYINT(1),
    IN p_certificados_adjuntos TEXT,
    IN p_estado VARCHAR(20),
    IN p_motivo_inactivo TEXT,
    IN p_observaciones TEXT,
    IN p_notas_internas TEXT,
    IN p_actualizado_por VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc_actual) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Proveedor no encontrado';
    END IF;

    IF IFNULL(p_ruc_nuevo, p_ruc_actual) <> p_ruc_actual
       AND EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc_nuevo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El RUC ya está registrado';
    END IF;

    UPDATE TblProveedores SET
        ruc                   = IFNULL(p_ruc_nuevo, ruc),
        razon_social          = IFNULL(p_razon_social, razon_social),
        nombre_comercial      = IFNULL(p_nombre_comercial, nombre_comercial),
        tipo_contribuyente    = IFNULL(p_tipo_contribuyente, tipo_contribuyente),
        telefono              = IFNULL(p_telefono, telefono),
        telefono_alternativo  = IFNULL(p_telefono_alternativo, telefono_alternativo),
        email                 = IFNULL(p_email, email),
        email_facturacion     = IFNULL(p_email_facturacion, email_facturacion),
        sitio_web             = IFNULL(p_sitio_web, sitio_web),
        direccion_fiscal      = IFNULL(p_direccion_fiscal, direccion_fiscal),
        departamento          = IFNULL(p_departamento, departamento),
        provincia             = IFNULL(p_provincia, provincia),
        distrito              = IFNULL(p_distrito, distrito),
        ubigeo                = IFNULL(p_ubigeo, ubigeo),
        referencia            = IFNULL(p_referencia, referencia),
        contacto_nombre       = IFNULL(p_contacto_nombre, contacto_nombre),
        contacto_cargo        = IFNULL(p_contacto_cargo, contacto_cargo),
        contacto_telefono     = IFNULL(p_contacto_telefono, contacto_telefono),
        contacto_email        = IFNULL(p_contacto_email, contacto_email),
        contacto_dni          = IFNULL(p_contacto_dni, contacto_dni),
        banco_1               = IFNULL(p_banco_1, banco_1),
        cuenta_banco_1        = IFNULL(p_cuenta_banco_1, cuenta_banco_1),
        tipo_cuenta_1         = IFNULL(p_tipo_cuenta_1, tipo_cuenta_1),
        moneda_1              = IFNULL(p_moneda_1, moneda_1),
        cci_1                 = IFNULL(p_cci_1, cci_1),
        banco_2               = IFNULL(p_banco_2, banco_2),
        cuenta_banco_2        = IFNULL(p_cuenta_banco_2, cuenta_banco_2),
        tipo_cuenta_2         = IFNULL(p_tipo_cuenta_2, tipo_cuenta_2),
        moneda_2              = IFNULL(p_moneda_2, moneda_2),
        cci_2                 = IFNULL(p_cci_2, cci_2),
        rubro_negocio         = IFNULL(p_rubro_negocio, rubro_negocio),
        categoria             = IFNULL(p_categoria, categoria),
        calificacion          = IFNULL(p_calificacion, calificacion),
        condicion_pago        = IFNULL(p_condicion_pago, condicion_pago),
        plazo_entrega         = IFNULL(p_plazo_entrega, plazo_entrega),
        descuento_comercial   = IFNULL(p_descuento_comercial, descuento_comercial),
        es_agente_retencion   = IFNULL(p_es_agente_retencion, es_agente_retencion),
        es_buen_contribuyente = IFNULL(p_es_buen_contribuyente, es_buen_contribuyente),
        tiene_certificado_calidad = IFNULL(p_tiene_certificado_calidad, tiene_certificado_calidad),
        certificados_adjuntos = IFNULL(p_certificados_adjuntos, certificados_adjuntos),
        estado                = IFNULL(p_estado, estado),
        motivo_inactivo       = IFNULL(p_motivo_inactivo, motivo_inactivo),
        observaciones         = IFNULL(p_observaciones, observaciones),
        notas_internas        = IFNULL(p_notas_internas, notas_internas),
        actualizado_por       = p_actualizado_por,
        fecha_actualizacion   = NOW()
    WHERE ruc = p_ruc_actual;

    SELECT IFNULL(p_ruc_nuevo, p_ruc_actual) AS ruc, 1 AS resultado, 'Proveedor actualizado' AS mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_ActualizarRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_ActualizarUbicacionMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarUbicacionMarcacion`(
    IN p_id_ubicacion INT,
    IN p_nombre_zona VARCHAR(200),
    IN p_latitud_centro DECIMAL(10, 8),
    IN p_longitud_centro DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_direccion_referencia VARCHAR(500),
    IN p_tipo_zona VARCHAR(50),
    IN p_descripcion TEXT,
    IN p_estado VARCHAR(20),
    OUT p_mensaje VARCHAR(500)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al actualizar la ubicación de marcación';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM TblUbicacionMarcacion WHERE id_ubicacion = p_id_ubicacion) THEN
        SET p_mensaje = 'Ubicación no encontrada';
        ROLLBACK;
    ELSE
        UPDATE TblUbicacionMarcacion SET
            nombre_zona = p_nombre_zona,
            latitud_centro = p_latitud_centro,
            longitud_centro = p_longitud_centro,
            radio_metros = p_radio_metros,
            direccion_referencia = p_direccion_referencia,
            tipo_zona = p_tipo_zona,
            descripcion = p_descripcion,
            estado = p_estado
        WHERE id_ubicacion = p_id_ubicacion;
        
        SET p_mensaje = CONCAT('Ubicación "', p_nombre_zona, '" actualizada exitosamente');
        
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_ActualizarUsuarioCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarUsuarioCompleto`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarUsuarioCompleto`(
    IN p_num_usuario INT,
    IN p_tipo_documento VARCHAR(20),
    IN p_nombres VARCHAR(100),
    IN p_apellido_paterno VARCHAR(100),
    IN p_apellido_materno VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_celular VARCHAR(20),
    IN p_celular_referencia VARCHAR(20),
    IN p_fecha_nacimiento DATE,
    IN p_genero VARCHAR(20),
    IN p_direccion VARCHAR(200),
    IN p_id_distrito INT,
    IN p_id_cargo INT,
    IN p_id_empresa INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_num_documento INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error al actualizar usuario';
    END;
    
    START TRANSACTION;
    
    -- Obtener num_documento del usuario
    SELECT num_documento INTO v_num_documento
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    IF v_num_documento IS NULL THEN
        SET p_mensaje = 'Usuario no encontrado';
        ROLLBACK;
    ELSE
        -- Actualizar TblPersona
        UPDATE TblPersona
        SET 
            tipo_documento = UPPER(p_tipo_documento),
            nombres = UPPER(p_nombres),
            apellido_paterno = UPPER(p_apellido_paterno),
            apellido_materno = UPPER(p_apellido_materno),
            email = UPPER(p_email),
            celular = UPPER(p_celular),
            celular_referencia = UPPER(p_celular_referencia),
            fecha_nacimiento = p_fecha_nacimiento,
            genero = UPPER(p_genero),
            direccion = UPPER(p_direccion),
            id_distrito = p_id_distrito,
            fecha_actualizacion = NOW()
        WHERE num_documento = v_num_documento;
        
        -- Actualizar TblUsuario
        UPDATE TblUsuario
        SET 
            id_cargo = p_id_cargo,
            id_empresa = p_id_empresa,
            fecha_actualizacion = NOW()
        WHERE num_usuario = p_num_usuario;
        
        SET p_mensaje = 'Usuario actualizado exitosamente';
        COMMIT;
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `sp_ActualizarVacacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ActualizarVacacion`(
    IN p_id_vacacion INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_tipo_vacacion VARCHAR(20),
    IN p_observaciones TEXT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_num_documento INT;
    DECLARE v_dias INT DEFAULT 0;
    DECLARE v_saldo_disponible INT DEFAULT 0;
    DECLARE v_dias_anteriores INT DEFAULT 0;
    DECLARE v_anio YEAR;
    
    SELECT estado, num_documento, dias_solicitados
    INTO v_estado, v_num_documento, v_dias_anteriores
    FROM TblVacaciones
    WHERE id_vacacion = p_id_vacacion;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'La solicitud no existe';
        LEAVE proc_label;
    END IF;
    
    IF v_estado != 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('No se puede editar una solicitud en estado: ', v_estado);
        LEAVE proc_label;
    END IF;
    
    IF p_fecha_inicio > p_fecha_fin THEN
        SET p_mensaje = 'La fecha de inicio no puede ser mayor a la fecha fin';
        LEAVE proc_label;
    END IF;
    
    SET v_dias = DATEDIFF(p_fecha_fin, p_fecha_inicio) + 1;
    SET v_anio = YEAR(p_fecha_inicio);
    
    SELECT (dias_pendientes + v_dias_anteriores) INTO v_saldo_disponible
    FROM TblVacacionSaldo
    WHERE num_documento = v_num_documento AND anio = v_anio;
    
    IF v_saldo_disponible < v_dias THEN
        SET p_mensaje = CONCAT('Saldo insuficiente. Disponible: ', v_saldo_disponible, ' dias, Solicitado: ', v_dias, ' dias');
        LEAVE proc_label;
    END IF;
    
    UPDATE TblVacaciones
    SET fecha_inicio = p_fecha_inicio,
        fecha_fin = p_fecha_fin,
        dias_solicitados = v_dias,
        tipo_vacacion = p_tipo_vacacion,
        observaciones = p_observaciones
    WHERE id_vacacion = p_id_vacacion;
    
    SET p_mensaje = CONCAT('Solicitud actualizada. Dias: ', v_dias);
    
END$$

DROP PROCEDURE IF EXISTS `sp_actualizar_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_actualizar_inventario`(
    IN p_id_inventario INT,
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    IN p_tipo_inventario VARCHAR(50),
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_stock_minimo DECIMAL(10,2),
    IN p_stock_maximo DECIMAL(10,2),
    IN p_precio_compra DECIMAL(10,2),
    IN p_id_almacen INT,
    IN p_ubicacion_fisica VARCHAR(100),
    IN p_estado VARCHAR(50),
    IN p_modificado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al actualizar el item';
    END;
    
    START TRANSACTION;
    
    -- Verificar que el item existe
    SELECT COUNT(*) INTO v_existe
    FROM TblInventario
    WHERE id_inventario = p_id_inventario;
    
    IF v_existe = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'El item no existe';
        ROLLBACK;
    ELSE
        -- Validar que el nombre no esté vacío
        IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
            SET p_success = FALSE;
            SET p_message = 'El nombre del item es obligatorio';
            ROLLBACK;
        ELSE
            -- Actualizar el item
            UPDATE TblInventario
            SET nombre = p_nombre,
                descripcion = p_descripcion,
                tipo_inventario = p_tipo_inventario,
                id_categoria = p_id_categoria,
                id_unidad = p_id_unidad,
                stock_minimo = p_stock_minimo,
                stock_maximo = p_stock_maximo,
                precio_compra = p_precio_compra,
                id_almacen = p_id_almacen,
                ubicacion_fisica = p_ubicacion_fisica,
                estado = p_estado,
                fecha_modificacion = NOW(),
                modificado_por = p_modificado_por
            WHERE id_inventario = p_id_inventario;
            
            -- Éxito
            SET p_success = TRUE;
            SET p_message = 'Item actualizado correctamente';
            
            COMMIT;
        END IF;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_ajustar_stock`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ajustar_stock`(
    IN  p_id_inventario        INT,
    IN  p_tipo_movimiento      VARCHAR(20),
    IN  p_cantidad             DECIMAL(10,2),
    IN  p_motivo               TEXT,
    IN  p_documento_referencia VARCHAR(50),
    IN  p_realizado_por        INT,
    OUT p_success              BOOLEAN,
    OUT p_message              VARCHAR(255),
    OUT p_nuevo_stock          DECIMAL(10,2)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_error TEXT;
    DECLARE v_id_mov INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = LEFT(CONCAT('Error al procesar el movimiento: ', COALESCE(v_error, 'desconocido')), 255);
        SET p_nuevo_stock = 0;
    END;

    START TRANSACTION;

    CALL sp_registrar_movimiento_stock(
        p_id_inventario, p_tipo_movimiento, p_cantidad,
        NULL,                       -- almacén del ítem
        'AJUSTE_INVENTARIO', NULL,  -- movimiento manual
        p_motivo,
        IF(NULLIF(TRIM(p_documento_referencia), '') IS NULL, NULL,
           CONCAT('Doc. ref.: ', TRIM(p_documento_referencia))),
        p_realizado_por,
        p_success, p_message, p_nuevo_stock, v_id_mov
    );

    IF p_success THEN
        COMMIT;
    ELSE
        ROLLBACK;
        SET p_nuevo_stock = COALESCE(p_nuevo_stock, 0);
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_AprobarPresupuesto_Progresivo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_AprobarPresupuesto_Progresivo`(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT,
    IN p_id_tipo_documento INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_siguiente_paso INT;
    DECLARE v_max_paso INT;
    DECLARE v_pasos_totales INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    DECLARE v_id_cargo INT;
    
    -- PASO 1: VALIDACIONES BÁSICAS
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no encontrado';
    END IF;
    
    SELECT estado INTO v_estado_actual
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no puede aprobarse. Estado incorrecto.';
    END IF;
    
    -- PASO 2: OBTENER SIGUIENTE PASO PENDIENTE
    SELECT 
        COALESCE(MIN(fc.numero_paso), 1) INTO v_siguiente_paso
    FROM TblFlujoAprobacionCargos fc
    WHERE fc.id_tipo_documento = p_id_tipo_documento
    AND fc.numero_paso > COALESCE(
        (SELECT MAX(numero_paso) 
         FROM TblRegistroAprobacion 
         WHERE id_documento_referencia = p_id_presupuesto 
         AND id_tipo_documento = p_id_tipo_documento 
         AND estado_aprobacion = 'APROBADO'), 
        0
    )
    AND fc.es_requerido = 1
    AND fc.activo = 1;
    
    IF v_siguiente_paso IS NULL THEN
        SELECT MIN(numero_paso) INTO v_siguiente_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1
        AND activo = 1;
    END IF;
    
    IF v_siguiente_paso IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay pasos de aprobación configurados';
    END IF;
    
    -- PASO 3: OBTENER id_cargo del paso actual
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- PASO 4: REGISTRAR LA APROBACIÓN
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso;
    
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento,
            id_documento_referencia,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion
        ) VALUES (
            p_id_tipo_documento,
            p_id_presupuesto,
            v_siguiente_paso,
            v_id_cargo,
            p_num_documento_aprobador,
            'APROBADO',
            NOW()
        );
    ELSE
        UPDATE TblRegistroAprobacion
        SET 
            num_documento_aprobador = p_num_documento_aprobador,
            estado_aprobacion = 'APROBADO',
            fecha_aprobacion = NOW()
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_siguiente_paso;
    END IF;
    
    -- PASO 5: CALCULAR SI ES EL ÚLTIMO PASO (DINÁMICAMENTE)
    -- Obtener el máximo número de paso del flujo
    SELECT MAX(numero_paso) INTO v_max_paso
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND es_requerido = 1
    AND activo = 1;
    
    -- Contar pasos totales y aprobados
    SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND es_requerido = 1
    AND activo = 1;
    
    SELECT COUNT(*) INTO v_pasos_aprobados
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND estado_aprobacion = 'APROBADO';
    
    -- ⭐ CAMBIO CLAVE: Comparar v_siguiente_paso con v_max_paso (NO usar es_final)
    IF v_siguiente_paso = v_max_paso THEN
        -- Es el último paso, verificar si TODOS los pasos están aprobados
        IF v_pasos_totales = v_pasos_aprobados AND v_pasos_totales > 0 THEN
            UPDATE TblPresupuesto
            SET 
                estado = 'APROBADO',
                fecha_actualizacion = NOW()
            WHERE id_presupuesto = p_id_presupuesto;
            
            SET v_mensaje = CONCAT(
                '✅ ¡PRESUPUESTO COMPLETAMENTE APROBADO! ',
                'Todos los ', v_pasos_totales, ' pasos fueron completados.'
            );
        ELSE
            SET v_mensaje = CONCAT(
                '⚠️ Paso ', v_siguiente_paso, ' aprobado. ',
                'Pasos aprobados: ', v_pasos_aprobados, '/', v_pasos_totales
            );
        END IF;
    ELSE
        -- No es el último paso, presupuesto sigue PENDIENTE
        SET v_mensaje = CONCAT(
            '✅ Paso ', v_siguiente_paso, ' aprobado. ',
            'Esperando paso siguiente. ',
            'Progreso: ', v_pasos_aprobados, '/', v_pasos_totales
        );
    END IF;
    
    -- RESPUESTA
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_siguiente_paso AS paso_actual;

END$$

DROP PROCEDURE IF EXISTS `sp_AprobarRequerimiento`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_AprobarRequerimiento`(
    IN p_id_requerimiento INT,
    IN p_num_documento_aprobador INT,
    IN p_comentario TEXT,
    OUT p_aprobacion_completa BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_id_cargo INT;
    DECLARE v_id_registro INT;
    DECLARE v_total_pasos INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_error_msg VARCHAR(500);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('❌ ERROR: ', v_error_msg);
    END;
    
    START TRANSACTION;
    
    -- PASO 1: OBTENER CARGO
    SELECT id_cargo INTO v_id_cargo
    FROM TblUsuario
    WHERE num_documento = p_num_documento_aprobador 
    AND estado = 'Activo'
    LIMIT 1;
    
    IF v_id_cargo IS NULL THEN
        SET p_mensaje = '❌ Usuario no tiene cargo asignado o no está activo';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuario no tiene cargo asignado';
    END IF;
    
    -- PASO 2: VERIFICAR REGISTRO PENDIENTE
    SELECT ra.id_registro INTO v_id_registro
    FROM TblRegistroAprobacion ra
    WHERE ra.id_tipo_documento = 2
      AND ra.id_documento_referencia = p_id_requerimiento
      AND ra.id_cargo_aprobador = v_id_cargo
      AND ra.estado_aprobacion = 'PENDIENTE'
    LIMIT 1;
    
    IF v_id_registro IS NULL THEN
        SET p_mensaje = '❌ No tienes permiso para aprobar este requerimiento';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No tienes permiso para aprobar este requerimiento';
    END IF;
    
    -- PASO 3: ACTUALIZAR A APROBADO
    UPDATE TblRegistroAprobacion 
    SET 
        estado_aprobacion = 'APROBADO',
        num_documento_aprobador = p_num_documento_aprobador,
        comentario = p_comentario,
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;
    
    -- PASO 4: VERIFICAR SI TODOS APROBADOS
    SELECT 
        COUNT(*) as total_pasos,
        SUM(CASE WHEN estado_aprobacion = 'APROBADO' THEN 1 ELSE 0 END) as aprobados
    INTO v_total_pasos, v_pasos_aprobados
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2 
    AND id_documento_referencia = p_id_requerimiento;
    
    -- PASO 5: ACTUALIZAR ESTADO SI COMPLETO
    IF v_total_pasos = v_pasos_aprobados THEN
        UPDATE TblRequerimiento 
        SET 
            estado = 'APROBADO',
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        SET p_aprobacion_completa = TRUE;
        SET p_mensaje = CONCAT(
            '✅ Requerimiento COMPLETAMENTE APROBADO. ',
            'Todos los ', v_total_pasos, ' pasos fueron aprobados.'
        );
    ELSE
        SET p_aprobacion_completa = FALSE;
        SET p_mensaje = CONCAT(
            '✅ Paso aprobado. ',
            'Progreso: ', v_pasos_aprobados, '/', v_total_pasos, ' pasos aprobados.'
        );
    END IF;
    
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_AprobarRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_AprobarRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_AprobarVacacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_AprobarVacacion`(
    IN p_id_vacacion INT,
    IN p_aprobado_por INT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_num_documento INT;
    DECLARE v_dias INT;
    DECLARE v_anio YEAR;
    DECLARE v_saldo_actual INT;
    
    SELECT estado, num_documento, dias_solicitados, YEAR(fecha_inicio)
    INTO v_estado, v_num_documento, v_dias, v_anio
    FROM TblVacaciones
    WHERE id_vacacion = p_id_vacacion;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'La solicitud no existe';
        LEAVE proc_label;
    END IF;
    
    IF v_estado != 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('No se puede aprobar una solicitud en estado: ', v_estado);
        LEAVE proc_label;
    END IF;
    
    SELECT dias_pendientes INTO v_saldo_actual
    FROM TblVacacionSaldo
    WHERE num_documento = v_num_documento AND anio = v_anio;
    
    IF v_saldo_actual < v_dias THEN
        SET p_mensaje = CONCAT('Saldo insuficiente. Disponible: ', v_saldo_actual, ', Requerido: ', v_dias);
        LEAVE proc_label;
    END IF;
    
    UPDATE TblVacaciones
    SET estado = 'APROBADO',
        aprobado_por = p_aprobado_por,
        fecha_aprobacion = NOW()
    WHERE id_vacacion = p_id_vacacion;
    
    UPDATE TblVacacionSaldo
    SET dias_usados = dias_usados + v_dias
    WHERE num_documento = v_num_documento AND anio = v_anio;
    
    SET p_mensaje = CONCAT('Vacacion aprobada. Dias descontados: ', v_dias);
    
END$$

DROP PROCEDURE IF EXISTS `sp_asegurar_seccion_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_asegurar_seccion_inventario`(
    IN p_id_inventario INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_tipo VARCHAR(20) DEFAULT NULL;

    SELECT tipo_inventario INTO v_tipo
    FROM `TblInventario`
    WHERE id_inventario = p_id_inventario;

    CASE v_tipo
        WHEN 'MATERIAL' THEN
            INSERT INTO `TblInventarioMaterial` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'MATERIAL' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioMaterial` WHERE id_inventario = p_id_inventario);
        WHEN 'HERRAMIENTA' THEN
            INSERT INTO `TblInventarioHerramienta` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'HERRAMIENTA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioHerramienta` WHERE id_inventario = p_id_inventario);
        WHEN 'EQUIPO' THEN
            INSERT INTO `TblInventarioEquipo` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'EQUIPO' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioEquipo` WHERE id_inventario = p_id_inventario);
        WHEN 'TECNOLOGIA' THEN
            INSERT INTO `TblInventarioTecnologia` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'TECNOLOGIA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioTecnologia` WHERE id_inventario = p_id_inventario);
        WHEN 'ROPA' THEN
            INSERT INTO `TblInventarioRopa` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'ROPA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioRopa` WHERE id_inventario = p_id_inventario);
        WHEN 'CONSUMIBLE' THEN
            INSERT INTO `TblInventarioConsumible` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'CONSUMIBLE' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioConsumible` WHERE id_inventario = p_id_inventario);
        ELSE
            BEGIN END;
    END CASE;
END$$

DROP PROCEDURE IF EXISTS `sp_asociar_proveedor_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_asociar_proveedor_inventario`(
    IN  p_id_inventario      INT,
    IN  p_ruc_proveedor      VARCHAR(11),
    IN  p_codigo_proveedor   VARCHAR(50),
    IN  p_precio_compra      DECIMAL(10,2),
    IN  p_moneda             VARCHAR(10),
    IN  p_plazo_entrega_dias INT,
    IN  p_es_principal       TINYINT(1),
    IN  p_observaciones      TEXT,
    IN  p_creado_por         VARCHAR(20),
    OUT p_success            TINYINT(1),
    OUT p_message            VARCHAR(255),
    OUT p_id_relacion        INT
)
sp_body: BEGIN
    DECLARE v_existe INT DEFAULT 0;

    -- Validar ítem de inventario
    IF NOT EXISTS (
        SELECT 1 FROM TblInventario
        WHERE id_inventario = p_id_inventario AND estado = 'ACTIVO'
    ) THEN
        SET p_success    = 0;
        SET p_message    = 'El ítem de inventario no existe o está inactivo';
        SET p_id_relacion = 0;
        LEAVE sp_body;
    END IF;

    -- Validar proveedor
    IF NOT EXISTS (
        SELECT 1 FROM TblProveedores
        WHERE ruc = p_ruc_proveedor AND estado != 'ELIMINADO'
    ) THEN
        SET p_success    = 0;
        SET p_message    = 'El proveedor no existe';
        SET p_id_relacion = 0;
        LEAVE sp_body;
    END IF;

    -- Si se marca como principal, quitar flag del anterior
    IF p_es_principal = 1 THEN
        UPDATE TblInventarioProveedor
        SET es_principal = 0
        WHERE id_inventario = p_id_inventario AND es_principal = 1;
    END IF;

    -- ¿Ya existe la relación (activa o inactiva)?
    SELECT COUNT(*) INTO v_existe
    FROM TblInventarioProveedor
    WHERE id_inventario = p_id_inventario AND ruc_proveedor = p_ruc_proveedor;

    IF v_existe > 0 THEN
        -- Reactivar y actualizar
        UPDATE TblInventarioProveedor
        SET codigo_proveedor    = p_codigo_proveedor,
            precio_compra       = p_precio_compra,
            moneda              = IFNULL(p_moneda, 'SOLES'),
            plazo_entrega_dias  = p_plazo_entrega_dias,
            es_principal        = p_es_principal,
            estado              = 'ACTIVO',
            observaciones       = p_observaciones,
            actualizado_por     = p_creado_por,
            fecha_actualizacion = NOW()
        WHERE id_inventario = p_id_inventario
          AND ruc_proveedor = p_ruc_proveedor;

        SELECT id_inventario_proveedor INTO p_id_relacion
        FROM TblInventarioProveedor
        WHERE id_inventario = p_id_inventario AND ruc_proveedor = p_ruc_proveedor;

        SET p_success = 1;
        SET p_message = 'Proveedor actualizado correctamente';
    ELSE
        -- Nueva relación
        INSERT INTO TblInventarioProveedor (
            id_inventario, ruc_proveedor, codigo_proveedor,
            precio_compra, moneda, plazo_entrega_dias,
            es_principal, estado, observaciones, creado_por
        ) VALUES (
            p_id_inventario, p_ruc_proveedor, p_codigo_proveedor,
            p_precio_compra, IFNULL(p_moneda, 'SOLES'), p_plazo_entrega_dias,
            p_es_principal, 'ACTIVO', p_observaciones, p_creado_por
        );

        SET p_id_relacion = LAST_INSERT_ID();
        SET p_success = 1;
        SET p_message = 'Proveedor asociado correctamente';
    END IF;
END sp_body$$

DROP PROCEDURE IF EXISTS `sp_BuscarMateriales`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMateriales`(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        i.id_unidad,
        i.id_categoria,
        COALESCE(c.nombre, 'General') AS categoria,
        COALESCE(u.nombre, 'Unidad') AS unidad_medida,
        COALESCE(u.abreviatura, 'UND') AS unidad_abrev,
        COALESCE(i.precio_compra, 0) AS precio_compra
    FROM `TblInventario` i
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    LEFT JOIN `TblUnidadMedida` u ON i.id_unidad = u.id_unidad
    WHERE i.estado = 'ACTIVO'
      AND (
            p_termino_busqueda = ''
            OR i.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_termino_busqueda, '%')
          )
      AND (
            p_id_categoria = 0
            OR i.id_categoria = p_id_categoria
          )
    ORDER BY i.codigo ASC
    LIMIT 100;
END$$

DROP PROCEDURE IF EXISTS `sp_BuscarMaterialesAutocompletado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMaterialesAutocompletado`(
    IN p_busqueda VARCHAR(200)
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        COALESCE(c.nombre, 'General') AS categoria,
        COALESCE(u.nombre, 'Unidad') AS unidad_medida,
        COALESCE(u.abreviatura, 'UND') AS unidad_abrev,
        i.id_unidad,
        i.estado
    FROM `TblInventario` i
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    LEFT JOIN `TblUnidadMedida` u ON i.id_unidad = u.id_unidad
    WHERE i.estado = 'ACTIVO'
      AND (
            i.nombre LIKE CONCAT('%', p_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_busqueda, '%')
            OR i.descripcion LIKE CONCAT('%', p_busqueda, '%')
          )
    ORDER BY
        CASE
            WHEN i.nombre LIKE CONCAT(p_busqueda, '%') THEN 1
            WHEN i.codigo LIKE CONCAT(p_busqueda, '%') THEN 2
            ELSE 3
        END,
        i.nombre ASC
    LIMIT 50;
END$$

DROP PROCEDURE IF EXISTS `sp_BuscarMaterialPorNombre`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMaterialPorNombre`(
    IN p_nombre VARCHAR(150)
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.id_unidad,
        i.tipo_inventario
    FROM `TblInventario` i
    WHERE i.nombre = p_nombre
      AND i.estado = 'ACTIVO'
      AND i.tipo_inventario NOT IN ('SERVICIO','PARTIDA')
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_BuscarPresupuestosAvanzado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarPresupuestosAvanzado`(
    IN p_numero VARCHAR(50),
    IN p_estado VARCHAR(20),
    IN p_id_proyecto INT,
    IN p_id_obra INT,
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE,
    IN p_nombre_creador VARCHAR(255),
    IN p_monto_desde DECIMAL(12,2),
    IN p_monto_hasta DECIMAL(12,2)
)
BEGIN
    SELECT DISTINCT
        -- CAMPOS DIRECTOS DE TBLPRESUPUESTO
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.id_obra,
        pr.num_documento,
        pr.monto,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.fecha_actualizacion,
        
        -- INFORMACIÓN RELACIONADA DE OBRA
        o.codigo_obra,
        o.nombre as nombre_obra,
        
        -- INFORMACIÓN RELACIONADA DE PROYECTO
        p.codigo_proyecto,
        p.nombre as nombre_proyecto,
        
        -- INFORMACIÓN RELACIONADA DE USUARIO
        u.usuario as usuario_login,
        per.nombres as usuario_nombres,
        per.apellido_paterno as usuario_apellido,
        per.email as usuario_email,
        
        -- NOMBRE COMPLETO DEL USUARIO QUE CREÓ EL PRESUPUESTO
        CONCAT(
            COALESCE(per.nombres, ''),
            ' ',
            COALESCE(per.apellido_paterno, ''),
            ' ',
            COALESCE(per.apellido_materno, '')
        ) as creado_por,
        
        -- NOMBRE COMPLETO DEL USUARIO QUE APROBÓ/RECHAZÓ EL PRESUPUESTO
        CASE 
            WHEN pr.estado IN ('APROBADO', 'RECHAZADO') THEN 
                CONCAT(
                    COALESCE(per_aprobador.nombres, ''),
                    ' ',
                    COALESCE(per_aprobador.apellido_paterno, ''),
                    ' ',
                    COALESCE(per_aprobador.apellido_materno, '')
                )
            ELSE NULL
        END as aprobado_rechazado_por,
        
        -- COMENTARIO DE RECHAZO (si existe)
        CASE 
            WHEN pr.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
            ELSE NULL
        END as comentario_rechazo
        
    FROM TblPresupuesto pr
    
    -- JOINS PARA INFORMACIÓN RELACIONADA
    LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
    LEFT JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
    LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- LEFT JOIN para obtener información del aprobador/rechazador
    LEFT JOIN TblRegistroAprobacion ra ON 
        pr.id_presupuesto = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 1
    
    -- ✅ CORRECCIÓN: Usar ra.num_documento_aprobador en lugar de ra.num_documento
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
    
    -- FILTROS
    WHERE pr.estado != 'ELIMINADO'
        -- Filtro por número de presupuesto (búsqueda parcial)
        AND (p_numero IS NULL OR p_numero = '' OR pr.numero_presupuesto LIKE CONCAT('%', p_numero, '%'))
        
        -- Filtro por estado
        AND (p_estado IS NULL OR p_estado = '' OR pr.estado = p_estado)
        
        -- Filtro por proyecto
        AND (p_id_proyecto IS NULL OR p_id_proyecto = 0 OR o.id_proyecto = p_id_proyecto)
        
        -- Filtro por obra
        AND (p_id_obra IS NULL OR p_id_obra = 0 OR pr.id_obra = p_id_obra)
        
        -- Filtro por rango de fechas (desde)
        AND (p_fecha_desde IS NULL OR DATE(pr.fecha_creacion) >= p_fecha_desde)
        
        -- Filtro por rango de fechas (hasta)
        AND (p_fecha_hasta IS NULL OR DATE(pr.fecha_creacion) <= p_fecha_hasta)
        
        -- Filtro por nombre del creador (búsqueda parcial)
        AND (p_nombre_creador IS NULL OR p_nombre_creador = '' OR 
            CONCAT(
                COALESCE(per.nombres, ''),
                ' ',
                COALESCE(per.apellido_paterno, ''),
                ' ',
                COALESCE(per.apellido_materno, '')
            ) LIKE CONCAT('%', p_nombre_creador, '%'))
        
        -- Filtro por rango de monto (desde)
        AND (p_monto_desde IS NULL OR p_monto_desde = 0 OR pr.monto >= p_monto_desde)
        
        -- Filtro por rango de monto (hasta)
        AND (p_monto_hasta IS NULL OR p_monto_hasta = 0 OR pr.monto <= p_monto_hasta)
    
    -- ORDEN: Por fecha más reciente
    ORDER BY pr.fecha_creacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_BuscarUnidadPorNombre`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarUnidadPorNombre`(
    IN p_nombre VARCHAR(100)
)
BEGIN
    SELECT 
        id_unidad,
        codigo,
        nombre,
        abreviatura
    FROM TblUnidadMedida
    WHERE (
        abreviatura = p_nombre
        OR nombre = p_nombre
        OR nombre LIKE CONCAT('%', p_nombre, '%')
        OR abreviatura LIKE CONCAT('%', p_nombre, '%')
    )
    AND estado = 'ACTIVO'
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_CambiarContrasena`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CambiarContrasena`(
    IN p_num_documento BIGINT,
    IN p_password_hash_actual VARCHAR(255),
    IN p_password_hash_nueva VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_usuario VARCHAR(100);
    
    -- Verificar si existe el usuario con la contraseña actual correcta
    SELECT COUNT(*), MAX(usuario) 
    INTO v_existe, v_usuario
    FROM TblUsuario 
    WHERE num_documento = p_num_documento 
      AND password_hash = p_password_hash_actual
      AND estado IN ('Activo', 'ACTIVO');
    
    -- Si no existe o la contraseña es incorrecta
    IF v_existe = 0 THEN
        SELECT 
            FALSE as success,
            'La contraseña actual es incorrecta' as message;
    ELSE
        -- Actualizar la contraseña
        UPDATE TblUsuario 
        SET password_hash = p_password_hash_nueva
        WHERE num_documento = p_num_documento;
        
        -- Retornar éxito
        SELECT 
            TRUE as success,
            'Contraseña actualizada exitosamente' as message,
            v_usuario as usuario;
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `sp_CompararVersionesPresupuesto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CompararVersionesPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_version1 INT,
    IN p_version2 INT
)
BEGIN
    -- Obtener datos de ambas versiones para comparación
    SELECT 
        v1.numero_version as version1,
        v1.fecha_version as fecha_v1,
        v1.presupuesto_total as total_v1,
        v1.motivo_cambio as motivo_v1,
        v2.numero_version as version2,
        v2.fecha_version as fecha_v2,
        v2.presupuesto_total as total_v2,
        v2.motivo_cambio as motivo_v2,
        (v2.presupuesto_total - v1.presupuesto_total) as diferencia_total,
        ROUND(((v2.presupuesto_total - v1.presupuesto_total) / v1.presupuesto_total) * 100, 2) as porcentaje_cambio
    FROM TblPresupuestoVersionHistorial v1
    CROSS JOIN TblPresupuestoVersionHistorial v2
    WHERE v1.id_presupuesto = p_id_presupuesto 
      AND v1.numero_version = p_version1
      AND v2.id_presupuesto = p_id_presupuesto 
      AND v2.numero_version = p_version2;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearEmpresa`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearEmpresa`(
    IN p_ruc          VARCHAR(11),
    IN p_nombre       VARCHAR(255),
    IN p_latitud      DECIMAL(10,8),
    IN p_longitud     DECIMAL(11,8),
    IN p_radio_metros INT,
    IN p_logo         LONGBLOB
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    -- Evita que el backend reciba 1062 (Duplicate entry) crudo
    SELECT COUNT(*) INTO v_count FROM TblEmpresa WHERE ruc = p_ruc;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una empresa con ese RUC';
    END IF;

    SELECT COUNT(*) INTO v_count FROM TblEmpresa WHERE nombre = p_nombre;
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya existe una empresa con ese nombre';
    END IF;

    -- Sin SELECT de salida: empresa.py lee LAST_INSERT_ID() sin multi=True
    INSERT INTO TblEmpresa (ruc, nombre, latitud, longitud, radio_metros, logo, activa)
    VALUES (p_ruc, p_nombre, p_latitud, p_longitud, p_radio_metros, p_logo, 1);
END$$

DROP PROCEDURE IF EXISTS `sp_CrearMaterialConCodigoAuto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearMaterialConCodigoAuto`(
    IN p_nombre VARCHAR(150),
    IN p_descripcion LONGTEXT,
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_observaciones LONGTEXT,
    OUT p_id_inventario_creado INT,
    OUT p_codigo_generado VARCHAR(50),
    OUT p_resultado INT
)
BEGIN
    DECLARE v_nuevo_codigo VARCHAR(50);
    DECLARE v_id_categoria INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = 0;
        SET p_id_inventario_creado = NULL;
        SET p_codigo_generado = NULL;
    END;

    START TRANSACTION;

    SET v_id_categoria = p_id_categoria;
    IF v_id_categoria IS NULL OR v_id_categoria <= 0 THEN
        SELECT id_categoria INTO v_id_categoria
        FROM `TblCategoriaInventario`
        WHERE codigo = 'MAT-OTROS'
        LIMIT 1;
    END IF;
    IF v_id_categoria IS NULL THEN
        SELECT id_categoria INTO v_id_categoria
        FROM `TblCategoriaInventario`
        WHERE estado = 'ACTIVO'
        ORDER BY id_categoria
        LIMIT 1;
    END IF;

    CALL sp_generar_material('MATERIAL', v_nuevo_codigo);

    INSERT INTO `TblInventario` (
        codigo, nombre, descripcion, id_categoria, tipo_inventario,
        stock_actual, stock_minimo, stock_maximo, id_unidad,
        precio_compra, precio_promedio, estado
    ) VALUES (
        v_nuevo_codigo, p_nombre, p_descripcion, v_id_categoria, 'MATERIAL',
        0, 0, 0, p_id_unidad,
        0, 0, 'ACTIVO'
    );

    SET p_id_inventario_creado = LAST_INSERT_ID();

    CALL sp_asegurar_seccion_inventario(p_id_inventario_creado);

    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearObra`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearObra`(
    IN p_id_proyecto INT,
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    OUT p_id_obra INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe_proyecto INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);
    DECLARE v_codigo_numero INT DEFAULT 1;
    DECLARE v_codigo_obra VARCHAR(50);
    
    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_id_obra = 0;
        SET p_mensaje = CONCAT('Error al crear obra: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que el proyecto existe
    SELECT COUNT(*) INTO v_existe_proyecto
    FROM TblProyecto
    WHERE id_proyecto = p_id_proyecto;
    
    IF v_existe_proyecto = 0 THEN
        SET p_id_obra = 0;
        SET p_mensaje = 'Error: El proyecto especificado no existe';
        ROLLBACK;
    ELSEIF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_id_obra = 0;
        SET p_mensaje = 'Error: El nombre de la obra es obligatorio';
        ROLLBACK;
    ELSE
        -- Obtener el siguiente número de código de obra
        SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_obra, 5) AS UNSIGNED)), 0) + 1 
        INTO v_codigo_numero
        FROM TblObra;
        
        -- Generar código de obra (OBR-001, OBR-002, etc.)
        SET v_codigo_obra = CONCAT('OBR-', LPAD(v_codigo_numero, 3, '0'));
        
        -- Insertar obra (solo campos que existen en TblObra)
        INSERT INTO TblObra (
            id_proyecto,
            codigo_obra,
            nombre,
            descripcion,
            fecha_creacion,
            fecha_actualizacion
        ) VALUES (
            p_id_proyecto,
            v_codigo_obra,
            UPPER(TRIM(p_nombre)),
            UPPER(TRIM(p_descripcion)),
            NOW(),
            NOW()
        );
        
        SET p_id_obra = LAST_INSERT_ID();
        SET p_mensaje = CONCAT('Obra creada exitosamente con código ', v_codigo_obra);
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearPresupuestoCompleto`$$
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

    DECLARE v_id_version_1 INT;
    DECLARE v_id_proyecto INT;
    DECLARE v_id_obra_local INT;
    DECLARE v_nombre_proyecto VARCHAR(255);
    DECLARE v_nombre_obra VARCHAR(255);

    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(CAST(SUBSTRING(numero_presupuesto, 6) AS UNSIGNED)), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM `TblPresupuesto`
    WHERE numero_presupuesto LIKE 'PRES-%';

    SELECT COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) *
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SELECT v_subtotal_base + COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) *
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SET v_sub_total = v_subtotal_base + p_gastos_generales + p_utilidad;

    SET v_igv = ROUND(v_sub_total * 0.18, 2);

    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;

    INSERT INTO `TblPresupuesto` (
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
        fecha_creacion,
        fecha_actualizacion
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
        NOW(),
        NOW()
    );

    SET p_id_presupuesto_created = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
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
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'SERVICIO' THEN 'SERVICIO'
            ELSE 'MATERIAL'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
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
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            ELSE 'SERVICIO'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

    INSERT INTO `TblRegistroAprobacion` (
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
    FROM `TblFlujoAprobacionCargos` fac
    WHERE fac.id_tipo_documento = 1
      AND fac.activo = 1
    ORDER BY fac.numero_paso;

    SELECT
        o.id_proyecto,
        o.id_obra,
        p.nombre,
        o.nombre
    INTO
        v_id_proyecto,
        v_id_obra_local,
        v_nombre_proyecto,
        v_nombre_obra
    FROM `TblObra` o
    LEFT JOIN `TblProyecto` p ON o.id_proyecto = p.id_proyecto
    WHERE o.id_obra = p_id_obra
    LIMIT 1;

    INSERT INTO `TblPresupuestoVersionHistorial` (
        id_presupuesto,
        numero_version,
        fecha_version,
        creado_por,
        motivo_cambio,
        es_version_actual,
        numero_presupuesto,
        id_proyecto,
        id_obra,
        nombre_proyecto,
        nombre_obra,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    ) VALUES (
        p_id_presupuesto_created,
        1,
        NOW(),
        p_num_documento,
        'Versión 1 - Creación inicial del presupuesto',
        1,
        v_numero_presupuesto,
        v_id_proyecto,
        p_id_obra,
        v_nombre_proyecto,
        v_nombre_obra,
        NOW(),
        NULL,
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p_id_presupuesto_created
           AND tipo_item = 'MATERIAL'),
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p_id_presupuesto_created
           AND tipo_item IN ('SERVICIO','PARTIDA')),
        v_subtotal_base,
        p_gastos_generales,
        p_utilidad,
        v_sub_total,
        v_igv,
        p_supervision_obra,
        v_monto_total,
        CASE WHEN v_subtotal_base > 0 THEN ROUND((p_gastos_generales / v_subtotal_base) * 100, 2) ELSE 0 END,
        CASE WHEN v_subtotal_base > 0 THEN ROUND((p_utilidad / v_subtotal_base) * 100, 2) ELSE 0 END,
        CASE WHEN v_sub_total > 0 THEN ROUND((p_supervision_obra / v_sub_total) * 100, 2) ELSE 0 END,
        p_comentarios,
        'PENDIENTE'
    );

    SET v_id_version_1 = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_id_version_1,
        'MATERIAL',
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        pd.cantidad * pd.precio_unitario,
        pd.id_detalle
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto_created
      AND pd.tipo_item = 'MATERIAL';

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_id_version_1,
        pd.tipo_item,
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        pd.cantidad * pd.precio_unitario,
        pd.id_detalle + 10000
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto_created
      AND pd.tipo_item IN ('SERVICIO','PARTIDA');

END$$

DROP PROCEDURE IF EXISTS `sp_CrearProveedor`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearProveedor`(
    IN p_ruc VARCHAR(11),
    IN p_razon_social VARCHAR(255),
    IN p_nombre_comercial VARCHAR(255),
    IN p_tipo_contribuyente VARCHAR(20),
    IN p_telefono VARCHAR(20),
    IN p_telefono_alternativo VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_email_facturacion VARCHAR(100),
    IN p_sitio_web VARCHAR(255),
    IN p_direccion_fiscal TEXT,
    IN p_departamento VARCHAR(100),
    IN p_provincia VARCHAR(100),
    IN p_distrito VARCHAR(100),
    IN p_ubigeo VARCHAR(6),
    IN p_referencia TEXT,
    IN p_contacto_nombre VARCHAR(255),
    IN p_contacto_cargo VARCHAR(100),
    IN p_contacto_telefono VARCHAR(20),
    IN p_contacto_email VARCHAR(100),
    IN p_contacto_dni VARCHAR(8),
    IN p_banco_1 VARCHAR(100),
    IN p_cuenta_banco_1 VARCHAR(50),
    IN p_tipo_cuenta_1 VARCHAR(20),
    IN p_moneda_1 VARCHAR(10),
    IN p_cci_1 VARCHAR(20),
    IN p_banco_2 VARCHAR(100),
    IN p_cuenta_banco_2 VARCHAR(50),
    IN p_tipo_cuenta_2 VARCHAR(20),
    IN p_moneda_2 VARCHAR(10),
    IN p_cci_2 VARCHAR(20),
    IN p_rubro_negocio VARCHAR(255),
    IN p_categoria VARCHAR(20),
    IN p_calificacion VARCHAR(20),
    IN p_condicion_pago VARCHAR(100),
    IN p_plazo_entrega VARCHAR(100),
    IN p_descuento_comercial DECIMAL(5,2),
    IN p_es_agente_retencion TINYINT(1),
    IN p_es_buen_contribuyente TINYINT(1),
    IN p_tiene_certificado_calidad TINYINT(1),
    IN p_certificados_adjuntos TEXT,
    IN p_estado VARCHAR(20),
    IN p_observaciones TEXT,
    IN p_notas_internas TEXT,
    IN p_creado_por VARCHAR(20)
)
BEGIN
    IF EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El RUC ya está registrado';
    END IF;

    INSERT INTO TblProveedores (
        ruc, razon_social, nombre_comercial, tipo_contribuyente, telefono, telefono_alternativo,
        email, email_facturacion, sitio_web, direccion_fiscal, departamento, provincia, distrito,
        ubigeo, referencia, contacto_nombre, contacto_cargo, contacto_telefono, contacto_email,
        contacto_dni, banco_1, cuenta_banco_1, tipo_cuenta_1, moneda_1, cci_1, banco_2,
        cuenta_banco_2, tipo_cuenta_2, moneda_2, cci_2, rubro_negocio, categoria, calificacion,
        condicion_pago, plazo_entrega, descuento_comercial, es_agente_retencion,
        es_buen_contribuyente, tiene_certificado_calidad, certificados_adjuntos, estado,
        observaciones, notas_internas, creado_por
    ) VALUES (
        p_ruc, p_razon_social, p_nombre_comercial, p_tipo_contribuyente, p_telefono, p_telefono_alternativo,
        p_email, p_email_facturacion, p_sitio_web, p_direccion_fiscal, p_departamento, p_provincia, p_distrito,
        p_ubigeo, p_referencia, p_contacto_nombre, p_contacto_cargo, p_contacto_telefono, p_contacto_email,
        p_contacto_dni, p_banco_1, p_cuenta_banco_1, p_tipo_cuenta_1, p_moneda_1, p_cci_1, p_banco_2,
        p_cuenta_banco_2, p_tipo_cuenta_2, p_moneda_2, p_cci_2, p_rubro_negocio, p_categoria, p_calificacion,
        p_condicion_pago, p_plazo_entrega, p_descuento_comercial, p_es_agente_retencion,
        p_es_buen_contribuyente, p_tiene_certificado_calidad, p_certificados_adjuntos, p_estado,
        p_observaciones, p_notas_internas, p_creado_por
    );

    SELECT p_ruc AS ruc, 1 AS resultado, 'Proveedor creado' AS mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearProyecto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearProyecto`(
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    OUT p_id_proyecto INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_error_msg VARCHAR(255);
    DECLARE v_codigo_numero INT DEFAULT 1;
    DECLARE v_codigo_proyecto VARCHAR(50);
    
    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_id_proyecto = 0;
        SET p_mensaje = CONCAT('Error al crear proyecto: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar nombre obligatorio
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_id_proyecto = 0;
        SET p_mensaje = 'Error: El nombre del proyecto es obligatorio';
        ROLLBACK;
    ELSE
        -- Obtener el siguiente número de código de proyecto
        SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_proyecto, 5) AS UNSIGNED)), 0) + 1 
        INTO v_codigo_numero
        FROM TblProyecto;
        
        -- Generar código del proyecto
        SET v_codigo_proyecto = CONCAT('PRY-', LPAD(v_codigo_numero, 3, '0'));
        
        -- Insertar proyecto (solo campos que existen según la estructura real)
        INSERT INTO TblProyecto (
            codigo_proyecto,
            nombre,
            descripcion,
            fecha_creacion,
            fecha_actualizacion
        ) VALUES (
            v_codigo_proyecto,
            UPPER(TRIM(p_nombre)),
            UPPER(TRIM(p_descripcion)),
            NOW(),
            NOW()
        );
        
        SET p_id_proyecto = LAST_INSERT_ID();
        SET p_mensaje = 'Proyecto creado exitosamente';
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearRequerimientoCompleto`(
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

DROP PROCEDURE IF EXISTS `sp_CrearUbicacionMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearUbicacionMarcacion`(
    IN p_num_documento VARCHAR(20),
    IN p_nombre_zona VARCHAR(200),
    IN p_latitud_centro DECIMAL(10, 8),
    IN p_longitud_centro DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_direccion_referencia VARCHAR(500),
    IN p_tipo_zona VARCHAR(50),
    IN p_descripcion TEXT,
    IN p_estado VARCHAR(20),
    IN p_creado_por VARCHAR(20),
    OUT p_id_ubicacion INT,
    OUT p_mensaje VARCHAR(500)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_id_ubicacion = 0;
        SET p_mensaje = 'Error al crear la ubicación de marcación';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_documento = p_num_documento) THEN
        SET p_id_ubicacion = 0;
        SET p_mensaje = 'Usuario no encontrado';
        ROLLBACK;
    ELSE
        -- Insertar ubicación
        INSERT INTO TblUbicacionMarcacion (
            num_documento,
            nombre_zona,
            latitud_centro,
            longitud_centro,
            radio_metros,
            direccion_referencia,
            tipo_zona,
            descripcion,
            estado,
            creado_por,
            fecha_creacion
        ) VALUES (
            p_num_documento,
            p_nombre_zona,
            p_latitud_centro,
            p_longitud_centro,
            p_radio_metros,
            p_direccion_referencia,
            p_tipo_zona,
            p_descripcion,
            p_estado,
            p_creado_por,
            NOW()
        );
        
        SET p_id_ubicacion = LAST_INSERT_ID();
        SET p_mensaje = CONCAT('Ubicación "', p_nombre_zona, '" creada exitosamente');
        
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearUsuarioCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearUsuarioCompleto`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearUsuarioCompleto`(
    IN p_documento_numero VARCHAR(20),
    IN p_tipo_documento VARCHAR(20),
    IN p_nombres VARCHAR(100),
    IN p_apellido_paterno VARCHAR(100),
    IN p_apellido_materno VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_celular VARCHAR(20),
    IN p_celular_referencia VARCHAR(20),
    IN p_fecha_nacimiento DATE,
    IN p_genero VARCHAR(20),
    IN p_direccion VARCHAR(200),
    IN p_id_distrito INT,
    IN p_id_cargo INT,
    IN p_id_empresa INT,
    IN p_lunes_activo BOOLEAN,
    IN p_lunes_entrada TIME,
    IN p_lunes_salida TIME,
    IN p_lunes_entrada2 TIME,
    IN p_lunes_salida2 TIME,
    IN p_martes_activo BOOLEAN,
    IN p_martes_entrada TIME,
    IN p_martes_salida TIME,
    IN p_martes_entrada2 TIME,
    IN p_martes_salida2 TIME,
    IN p_miercoles_activo BOOLEAN,
    IN p_miercoles_entrada TIME,
    IN p_miercoles_salida TIME,
    IN p_miercoles_entrada2 TIME,
    IN p_miercoles_salida2 TIME,
    IN p_jueves_activo BOOLEAN,
    IN p_jueves_entrada TIME,
    IN p_jueves_salida TIME,
    IN p_jueves_entrada2 TIME,
    IN p_jueves_salida2 TIME,
    IN p_viernes_activo BOOLEAN,
    IN p_viernes_entrada TIME,
    IN p_viernes_salida TIME,
    IN p_viernes_entrada2 TIME,
    IN p_viernes_salida2 TIME,
    IN p_sabado_activo BOOLEAN,
    IN p_sabado_entrada TIME,
    IN p_sabado_salida TIME,
    IN p_sabado_entrada2 TIME,
    IN p_sabado_salida2 TIME,
    IN p_domingo_activo BOOLEAN,
    IN p_domingo_entrada TIME,
    IN p_domingo_salida TIME,
    IN p_domingo_entrada2 TIME,
    IN p_domingo_salida2 TIME,
    OUT p_num_usuario INT,
    OUT p_mensaje VARCHAR(255)
)
    READS SQL DATA
BEGIN
    DECLARE v_num_documento INT;
    DECLARE v_usuario VARCHAR(50);
    DECLARE v_contraseña VARCHAR(255);
    DECLARE v_primer_letra_nombre VARCHAR(1);
    DECLARE v_primer_letra_apellido_m VARCHAR(1);
    DECLARE v_contador INT DEFAULT 0;
    
    -- PASO 0: TRIM() a todos los parámetros STRING
    -- Elimina espacios al inicio/final ANTES de procesar
    SET p_documento_numero = TRIM(p_documento_numero);
    SET p_tipo_documento = TRIM(p_tipo_documento);
    SET p_nombres = TRIM(p_nombres);
    SET p_apellido_paterno = TRIM(p_apellido_paterno);
    SET p_apellido_materno = TRIM(COALESCE(p_apellido_materno, ''));
    SET p_email = TRIM(p_email);
    SET p_celular = TRIM(p_celular);
    SET p_celular_referencia = TRIM(COALESCE(p_celular_referencia, ''));
    SET p_genero = TRIM(p_genero);
    SET p_direccion = TRIM(COALESCE(p_direccion, ''));
    
    IF p_documento_numero IS NULL OR p_documento_numero = '' THEN
        SET p_num_usuario = 0;
        SET p_mensaje = 'Documento número es requerido';
    ELSEIF p_nombres IS NULL OR p_nombres = '' THEN
        SET p_num_usuario = 0;
        SET p_mensaje = 'Nombres es requerido';
    ELSEIF p_apellido_paterno IS NULL OR p_apellido_paterno = '' THEN
        SET p_num_usuario = 0;
        SET p_mensaje = 'Apellido paterno es requerido';
    ELSEIF p_email IS NULL OR p_email = '' THEN
        SET p_num_usuario = 0;
        SET p_mensaje = 'Email es requerido';
    ELSEIF p_id_empresa IS NULL OR p_id_empresa = 0 THEN
        SET p_num_usuario = 0;
        SET p_mensaje = 'Empresa es requerida';
    ELSE
        SET v_primer_letra_nombre = UPPER(SUBSTRING(p_nombres, 1, 1));
        SET v_primer_letra_apellido_m = UPPER(SUBSTRING(COALESCE(p_apellido_materno, 'X'), 1, 1));
        SET v_usuario = CONCAT(v_primer_letra_nombre, LOWER(p_apellido_paterno), v_primer_letra_apellido_m);
        SET v_contraseña = SHA2(p_documento_numero, 256);
        
        -- PASO 1: Crear TblPersona
        INSERT INTO TblPersona (
            documento_numero,
            tipo_documento,
            nombres,
            apellido_paterno,
            apellido_materno,
            email,
            celular,
            celular_referencia,
            fecha_nacimiento,
            genero,
            direccion,
            id_distrito,
            estado,
            fecha_creacion
        ) VALUES (
            p_documento_numero,
            UPPER(p_tipo_documento),
            UPPER(p_nombres),
            UPPER(p_apellido_paterno),
            UPPER(p_apellido_materno),
            UPPER(p_email),
            UPPER(p_celular),
            UPPER(p_celular_referencia),
            p_fecha_nacimiento,
            UPPER(p_genero),
            UPPER(p_direccion),
            p_id_distrito,
            'ACTIVO',
            NOW()
        );
        
        SET v_num_documento = LAST_INSERT_ID();
        
        -- PASO 2: Crear TblUsuario
        INSERT INTO TblUsuario (
            num_documento,
            usuario,
            password_hash,
            id_cargo,
            id_empresa,
            estado,
            fecha_creacion
        ) VALUES (
            v_num_documento,
            UPPER(v_usuario),
            v_contraseña,
            p_id_cargo,
            p_id_empresa,
            'ACTIVO',
            NOW()
        );
        
        SET p_num_usuario = LAST_INSERT_ID();
        
        -- PASO 3: Insertar horarios en TblHorarioTrabajo (7 días)
        
        -- LUNES
        IF p_lunes_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'LUNES', p_lunes_entrada, p_lunes_salida, p_lunes_entrada2, p_lunes_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'LUNES', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- MARTES
        IF p_martes_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'MARTES', p_martes_entrada, p_martes_salida, p_martes_entrada2, p_martes_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'MARTES', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- MIÉRCOLES
        IF p_miercoles_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'MIÉRCOLES', p_miercoles_entrada, p_miercoles_salida, p_miercoles_entrada2, p_miercoles_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'MIÉRCOLES', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- JUEVES
        IF p_jueves_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'JUEVES', p_jueves_entrada, p_jueves_salida, p_jueves_entrada2, p_jueves_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'JUEVES', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- VIERNES
        IF p_viernes_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'VIERNES', p_viernes_entrada, p_viernes_salida, p_viernes_entrada2, p_viernes_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'VIERNES', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- SÁBADO
        IF p_sabado_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'SÁBADO', p_sabado_entrada, p_sabado_salida, p_sabado_entrada2, p_sabado_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'SÁBADO', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        -- DOMINGO
        IF p_domingo_activo = 1 THEN
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
            VALUES (v_num_documento, 'DOMINGO', p_domingo_entrada, p_domingo_salida, p_domingo_entrada2, p_domingo_salida2, 1, 'ACTIVO');
        ELSE
            INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
            VALUES (v_num_documento, 'DOMINGO', 0, 'ACTIVO');
        END IF;
        SET v_contador = v_contador + 1;
        
        SET p_mensaje = CONCAT('Usuario creado exitosamente. Usuario: ', UPPER(v_usuario), ' | Horarios: ', v_contador, ' días registrados');
    END IF;

END$$

DROP PROCEDURE IF EXISTS `sp_CrearVacacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearVacacion`(
    IN p_num_documento INT,
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_tipo_vacacion VARCHAR(20),
    IN p_observaciones TEXT,
    IN p_creado_por INT,
    OUT p_id_vacacion INT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_dias INT DEFAULT 0;
    DECLARE v_estado_usuario VARCHAR(20);
    DECLARE v_saldo_disponible INT DEFAULT 0;
    DECLARE v_anio YEAR;
    
    SELECT estado INTO v_estado_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_estado_usuario IS NULL THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = 'El empleado no existe';
        LEAVE proc_label;
    END IF;
    
    IF v_estado_usuario != 'Activo' THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = 'El empleado no esta activo';
        LEAVE proc_label;
    END IF;
    
    IF p_fecha_inicio > p_fecha_fin THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = 'La fecha de inicio no puede ser mayor a la fecha fin';
        LEAVE proc_label;
    END IF;
    
    SET v_dias = DATEDIFF(p_fecha_fin, p_fecha_inicio) + 1;
    
    IF v_dias <= 0 THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = 'El rango de fechas no es valido';
        LEAVE proc_label;
    END IF;
    
    SET v_anio = YEAR(p_fecha_inicio);
    
    INSERT INTO TblVacacionSaldo (num_documento, anio, dias_totales, dias_usados)
    VALUES (p_num_documento, v_anio, 30, 0)
    ON DUPLICATE KEY UPDATE id_saldo = id_saldo;
    
    SELECT dias_pendientes INTO v_saldo_disponible
    FROM TblVacacionSaldo
    WHERE num_documento = p_num_documento AND anio = v_anio;
    
    IF v_saldo_disponible < v_dias THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = CONCAT('Saldo insuficiente. Disponible: ', v_saldo_disponible, ' dias, Solicitado: ', v_dias, ' dias');
        LEAVE proc_label;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM TblVacaciones
        WHERE num_documento = p_num_documento
          AND estado IN ('APROBADO', 'EN_CURSO')
          AND fecha_inicio <= p_fecha_fin
          AND fecha_fin >= p_fecha_inicio
    ) THEN
        SET p_id_vacacion = 0;
        SET p_mensaje = 'Ya existe una vacacion aprobada en ese rango de fechas';
        LEAVE proc_label;
    END IF;
    
    INSERT INTO TblVacaciones (
        num_documento, fecha_inicio, fecha_fin, dias_solicitados,
        tipo_vacacion, estado, observaciones, creado_por
    ) VALUES (
        p_num_documento, p_fecha_inicio, p_fecha_fin, v_dias,
        p_tipo_vacacion, 'PENDIENTE', p_observaciones, p_creado_por
    );
    
    SET p_id_vacacion = LAST_INSERT_ID();
    SET p_mensaje = CONCAT('Solicitud creada. ID: ', p_id_vacacion, ', Dias: ', v_dias);
    
END$$

DROP PROCEDURE IF EXISTS `sp_crear_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_crear_inventario`(
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    IN p_tipo_inventario VARCHAR(50),
    IN p_id_categoria INT,
    IN p_id_subcategoria INT,
    IN p_id_unidad INT,
    IN p_stock_minimo DECIMAL(10,2),
    IN p_stock_maximo DECIMAL(10,2),
    IN p_precio_compra DECIMAL(10,2),
    IN p_id_almacen INT,
    IN p_ubicacion_fisica VARCHAR(100),
    IN p_atributos_json TEXT,
    IN p_creado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255),
    OUT p_id_inventario INT,
    OUT p_codigo VARCHAR(50)
)
BEGIN
    DECLARE v_codigo_generado VARCHAR(50);
    DECLARE v_id_inventario INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al crear el item';
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
    END;

    START TRANSACTION;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_success = FALSE;
        SET p_message = 'El nombre del item es obligatorio';
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
        ROLLBACK;
    ELSE
        CALL sp_generar_material(p_tipo_inventario, v_codigo_generado);

        INSERT INTO TblInventario (
            codigo, nombre, descripcion, id_categoria, id_subcategoria, tipo_inventario,
            stock_actual, stock_minimo, stock_maximo, id_unidad, id_almacen,
            ubicacion_fisica, precio_compra, precio_promedio, estado, fecha_creacion, creado_por
        ) VALUES (
            v_codigo_generado, p_nombre, p_descripcion, p_id_categoria, p_id_subcategoria, p_tipo_inventario,
            0.00, p_stock_minimo, p_stock_maximo, p_id_unidad, p_id_almacen,
            p_ubicacion_fisica, p_precio_compra, p_precio_compra, 'ACTIVO', NOW(), p_creado_por
        );

        SET v_id_inventario = LAST_INSERT_ID();

        CALL sp_asegurar_seccion_inventario(v_id_inventario);

        SET p_success = TRUE;
        SET p_message = CONCAT('Item creado exitosamente con código: ', v_codigo_generado);
        SET p_id_inventario = v_id_inventario;
        SET p_codigo = v_codigo_generado;

        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_desasociar_proveedor_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_desasociar_proveedor_inventario`(
    IN  p_id_inventario_proveedor INT,
    IN  p_usuario                 VARCHAR(20),
    OUT p_success                 TINYINT(1),
    OUT p_message                 VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM TblInventarioProveedor
        WHERE id_inventario_proveedor = p_id_inventario_proveedor
          AND estado = 'ACTIVO'
    ) THEN
        SET p_success = 0;
        SET p_message = 'La relación no existe o ya estaba inactiva';
    ELSE
        UPDATE TblInventarioProveedor
        SET estado              = 'INACTIVO',
            actualizado_por     = p_usuario,
            fecha_actualizacion = NOW()
        WHERE id_inventario_proveedor = p_id_inventario_proveedor;

        SET p_success = 1;
        SET p_message = 'Proveedor desasociado correctamente';
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_EditarMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EditarMarcacion`(
    IN p_id_marcacion INT,
    IN p_nueva_hora TIME,
    IN p_fecha_original DATE,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_num_documento INT;
    DECLARE v_tipo_marcacion VARCHAR(20);
    DECLARE v_nueva_fecha DATETIME;
    DECLARE v_estado_calculado VARCHAR(20);
    DECLARE v_hora_programada TIME;
    
    -- Validar que la marcación existe
    SELECT COUNT(*) INTO v_existe
    FROM TblMarcacion
    WHERE id_marcacion = p_id_marcacion;
    
    IF v_existe = 0 THEN
        SET p_mensaje = 'Marcación no encontrada';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Marcación no encontrada';
    END IF;
    
    -- Obtener datos de la marcación
    SELECT num_documento, tipo_marcacion
    INTO v_num_documento, v_tipo_marcacion
    FROM TblMarcacion
    WHERE id_marcacion = p_id_marcacion;
    
    -- Construir nueva fecha completa
    SET v_nueva_fecha = CONCAT(p_fecha_original, ' ', p_nueva_hora);
    
    -- Calcular estado si es ENTRADA
    SET v_estado_calculado = 'Registrado';
    
    IF v_tipo_marcacion = 'ENTRADA' THEN
        -- Obtener hora programada del usuario
        SELECT h.hora_entrada INTO v_hora_programada
        FROM TblHorarioTrabajo h
        WHERE h.num_documento = v_num_documento
          AND UPPER(h.dia_semana) = CASE DAYOFWEEK(v_nueva_fecha)
              WHEN 1 THEN 'DOMINGO'
              WHEN 2 THEN 'LUNES'
              WHEN 3 THEN 'MARTES'
              WHEN 4 THEN 'MIÉRCOLES'
              WHEN 5 THEN 'JUEVES'
              WHEN 6 THEN 'VIERNES'
              WHEN 7 THEN 'SÁBADO'
          END
          AND h.es_activo = 1
        LIMIT 1;
        
        -- Calcular estado según hora
        IF v_hora_programada IS NOT NULL THEN
            IF p_nueva_hora <= ADDTIME(v_hora_programada, '00:05:00') THEN
                SET v_estado_calculado = 'ASISTIO';
            ELSEIF p_nueva_hora <= ADDTIME(v_hora_programada, '00:30:00') THEN
                SET v_estado_calculado = 'TARDE';
            ELSE
                SET v_estado_calculado = 'ASISTIO +5';
            END IF;
        ELSE
            SET v_estado_calculado = 'ASISTIO';
        END IF;
    END IF;
    
    -- Actualizar la marcación
    UPDATE TblMarcacion
    SET fecha_marcacion = v_nueva_fecha,
        estado = v_estado_calculado,
        fecha_actualizacion = NOW()
    WHERE id_marcacion = p_id_marcacion;
    
    SET p_mensaje = CONCAT('Marcación actualizada. Nuevo estado: ', v_estado_calculado);
    
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarFlujoAprobacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarFlujoAprobacion`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarFlujoAprobacion`(
    IN p_id_flujo_cargo INT,
    IN p_id_tipo_documento INT,
    OUT p_resultado VARCHAR(50),
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_flujo_existe INT DEFAULT 0;
    DECLARE v_numero_paso INT DEFAULT 0;
    DECLARE v_documentos_pendientes INT DEFAULT 0;
    DECLARE v_registros_aprobacion_eliminados INT DEFAULT 0;
    DECLARE v_flujos_en_paso INT DEFAULT 0;
    DECLARE v_nombre_documento VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    
    SELECT COUNT(*) INTO v_flujo_existe
    FROM TblFlujoAprobacionCargos
    WHERE id_flujo_cargo = p_id_flujo_cargo;
    
    IF v_flujo_existe = 0 THEN
        SET p_resultado = 'ERROR';
        SET p_mensaje = 'Flujo no encontrado';
    ELSE
        SELECT numero_paso INTO v_numero_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        IF p_id_tipo_documento = 1 THEN
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblPresupuesto
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 1;
            
            SET v_nombre_documento = 'presupuestos';
            
        ELSEIF p_id_tipo_documento = 2 THEN
            SELECT COUNT(*) INTO v_documentos_pendientes
            FROM TblRequerimiento
            WHERE estado IN ('PENDIENTE', 'RECHAZADO')
            AND id_tipo_documento = 2;
            
            SET v_nombre_documento = 'requerimientos';
        END IF;
        
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND numero_paso = v_numero_paso;
        
        SET v_registros_aprobacion_eliminados = ROW_COUNT();
        
        DELETE FROM TblFlujoAprobacionCargos
        WHERE id_flujo_cargo = p_id_flujo_cargo;
        
        SELECT COUNT(*) INTO v_flujos_en_paso
        FROM TblFlujoAprobacionCargos
        WHERE numero_paso = v_numero_paso
        AND id_tipo_documento = p_id_tipo_documento;
        
        IF v_documentos_pendientes > 0 THEN
            SET p_resultado = 'ADVERTENCIA';
            SET p_mensaje = CONCAT(
                CAST('⚠️ Flujo eliminado. NOTA: Hay ' AS CHAR),
                CAST(v_documentos_pendientes AS CHAR),
                CAST(' ' AS CHAR),
                CAST(v_nombre_documento AS CHAR),
                CAST(' en proceso de aprobación que ya no tendrán este paso en su flujo. Cargos restantes en paso ' AS CHAR),
                CAST(v_numero_paso AS CHAR),
                CAST(': ' AS CHAR),
                CAST(v_flujos_en_paso AS CHAR)
            );
        ELSE
            SET p_resultado = 'OK';
            SET p_mensaje = CONCAT(
                CAST('✅ Flujo eliminado exitosamente. Paso: ' AS CHAR),
                CAST(v_numero_paso AS CHAR),
                CAST('. Tipo: ' AS CHAR),
                CAST(v_nombre_documento AS CHAR),
                CAST('. Registros de aprobación eliminados: ' AS CHAR),
                CAST(v_registros_aprobacion_eliminados AS CHAR),
                CAST('. Cargos restantes en este paso: ' AS CHAR),
                CAST(v_flujos_en_paso AS CHAR)
            );
        END IF;
    END IF;
    
    SELECT p_resultado AS resultado, p_mensaje AS mensaje;

END$$

DROP PROCEDURE IF EXISTS `sp_EliminarPresupuestoCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarPresupuestoCompleto`(
    IN p_id_presupuesto INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' as resultado, 'No se pudo eliminar el presupuesto' as mensaje;
    END;
    
    START TRANSACTION;
    
    -- 1. Eliminar registros de aprobación
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 1
    AND id_documento_referencia = p_id_presupuesto;
    
    -- 2. Eliminar detalles del presupuesto
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- 3. Eliminar presupuesto
    DELETE FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    COMMIT;
    
    SELECT 'SUCCESS' as resultado, 'Presupuesto eliminado correctamente' as mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarProveedor`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarProveedor`(
    IN p_ruc VARCHAR(11),
    IN p_usuario VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc AND estado != 'ELIMINADO') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Proveedor no encontrado o ya eliminado';
    END IF;

    -- Baja lógica: el registro se conserva con estado ELIMINADO
    -- (sp_ListarProveedores y sp_ObtenerProveedorPorRUC lo excluyen).
    UPDATE TblProveedores
    SET estado = 'ELIMINADO',
        actualizado_por = p_usuario,
        fecha_actualizacion = NOW()
    WHERE ruc = p_ruc;

    SELECT p_ruc AS ruc, 1 AS resultado, 'Proveedor eliminado' AS mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarRequerimiento`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarRequerimiento`(
    IN p_id_requerimiento INT,
    OUT p_codigo VARCHAR(50),
    OUT p_detalles_eliminados INT,
    OUT p_aprobaciones_eliminadas INT,
    OUT p_presupuesto_reversado BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(50) DEFAULT '';
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    DECLARE v_cantidad_total DECIMAL(10,2) DEFAULT 0;
    
    -- Inicializar OUT
    SET p_codigo = '';
    SET p_detalles_eliminados = 0;
    SET p_aprobaciones_eliminadas = 0;
    SET p_presupuesto_reversado = 0;
    SET p_mensaje = 'Iniciando...';
    
    -- Obtener datos del requerimiento
    SELECT codigo, id_presupuesto
    INTO v_codigo, v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- Si no existe
    IF v_codigo IS NULL OR v_codigo = '' THEN
        SET p_mensaje = CONCAT('ERROR: Requerimiento ', p_id_requerimiento, ' no encontrado');
        -- NO hacer nada más, salir
    ELSE
        -- Requerimiento existe, proceder
        SET p_codigo = v_codigo;
        
        -- Calcular cantidad si hay presupuesto
        IF v_id_presupuesto IS NOT NULL THEN
            SELECT COALESCE(SUM(cantidad), 0)
            INTO v_cantidad_total
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Reversar presupuesto
            IF v_cantidad_total > 0 THEN
                UPDATE TblPresupuesto
                SET 
                    cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total),
                    cantidad_saldo = cantidad_saldo + v_cantidad_total,
                    monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total),
                    fecha_actualizacion = NOW()
                WHERE id_presupuesto = v_id_presupuesto;
                
                -- Reversar detalles (sin tocar cantidad_saldo que es GENERATED)
                UPDATE TblPresupuestoDetalle pd
                INNER JOIN (
                    SELECT 
                        LOWER(TRIM(descripcion)) as descripcion_key,
                        SUM(cantidad) as total_cantidad
                    FROM TblRequerimientoDetalle
                    WHERE id_requerimiento = p_id_requerimiento
                    GROUP BY LOWER(TRIM(descripcion))
                ) rd ON LOWER(TRIM(pd.descripcion)) = rd.descripcion_key
                SET 
                    pd.cantidad_consumida = GREATEST(0, pd.cantidad_consumida - rd.total_cantidad),
                    pd.fecha_actualizacion = NOW()
                WHERE pd.id_presupuesto = v_id_presupuesto;
                
                SET p_presupuesto_reversado = 1;
            END IF;
        END IF;
        
        -- Eliminar detalles
        DELETE FROM TblRequerimientoDetalle
        WHERE id_requerimiento = p_id_requerimiento;
        SET p_detalles_eliminados = ROW_COUNT();
        
        -- Eliminar aprobaciones
        DELETE FROM TblRegistroAprobacion
        WHERE id_documento_referencia = p_id_requerimiento
        AND id_tipo_documento = 2;
        SET p_aprobaciones_eliminadas = ROW_COUNT();
        
        -- Eliminar requerimiento
        DELETE FROM TblRequerimiento
        WHERE id_requerimiento = p_id_requerimiento;
        
        -- COMMIT para asegurar que se persistan los cambios
        COMMIT;
        
        -- Mensaje de éxito
        SET p_mensaje = CONCAT(
            'OK: Requerimiento ', v_codigo, ' eliminado. ',
            'Detalles: ', p_detalles_eliminados, ', ',
            'Aprobaciones: ', p_aprobaciones_eliminadas, ', ',
            'Presupuesto reversado: ', IF(p_presupuesto_reversado = 1, 'Si', 'No')
        );
    END IF;

END$$

DROP PROCEDURE IF EXISTS `sp_EliminarRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_EliminarRequerimientoCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarRequerimientoCompleto`(
    IN p_id_requerimiento INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' as resultado, 'No se pudo eliminar el requerimiento' as mensaje;
    END;
    
    START TRANSACTION;
    
    -- 1. Eliminar registros de aprobación
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2
    AND id_documento_referencia = p_id_requerimiento;
    
    -- 2. Eliminar detalles del requerimiento
    DELETE FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- 3. Eliminar requerimiento
    DELETE FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    COMMIT;
    
    SELECT 'SUCCESS' as resultado, 'Requerimiento eliminado correctamente' as mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarUbicacionMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarUbicacionMarcacion`(
    IN p_id_ubicacion INT,
    OUT p_mensaje VARCHAR(500)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al eliminar la ubicación de marcación';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    IF NOT EXISTS (SELECT 1 FROM TblUbicacionMarcacion WHERE id_ubicacion = p_id_ubicacion) THEN
        SET p_mensaje = 'Ubicación no encontrada';
        ROLLBACK;
    ELSE
        DELETE FROM TblUbicacionMarcacion WHERE id_ubicacion = p_id_ubicacion;
        SET p_mensaje = 'Ubicación eliminada exitosamente';
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarUsuario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarUsuario`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarUsuario`(
    IN p_num_usuario INT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_num_documento INT;
    DECLARE v_usuario VARCHAR(100);
    DECLARE v_horarios_eliminados INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al eliminar el usuario';
        ROLLBACK;
    END;
    
    -- Validar que el usuario existe y obtener datos
    SELECT num_documento, usuario INTO v_num_documento, v_usuario
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    IF v_num_documento IS NULL THEN
        SET p_mensaje = 'El usuario no existe';
        LEAVE proc_label;
    END IF;
    
    START TRANSACTION;
    
    -- PASO 1: Eliminar horarios de trabajo asociados
    DELETE FROM TblHorarioTrabajo
    WHERE num_documento = v_num_documento;
    
    SET v_horarios_eliminados = ROW_COUNT();
    
    -- PASO 2: Eliminar usuario (TblUsuario)
    DELETE FROM TblUsuario
    WHERE num_usuario = p_num_usuario;
    
    -- PASO 3: Eliminar datos personales (TblPersona)
    DELETE FROM TblPersona
    WHERE num_documento = v_num_documento;
    
    COMMIT;
    
    -- Mensaje de éxito
    SET p_mensaje = CONCAT('Usuario ', v_usuario, ' eliminado exitosamente');
    
END$$

DROP PROCEDURE IF EXISTS `sp_EliminarVacacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarVacacion`(
    IN p_id_vacacion INT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_num_documento INT;
    DECLARE v_dias INT;
    DECLARE v_anio YEAR;
    
    SELECT estado, num_documento, dias_solicitados, YEAR(fecha_inicio)
    INTO v_estado, v_num_documento, v_dias, v_anio
    FROM TblVacaciones
    WHERE id_vacacion = p_id_vacacion;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'La solicitud no existe';
        LEAVE proc_label;
    END IF;
    
    IF v_estado = 'APROBADO' THEN
        UPDATE TblVacacionSaldo
        SET dias_usados = GREATEST(0, dias_usados - v_dias)
        WHERE num_documento = v_num_documento AND anio = v_anio;
    END IF;
    
    DELETE FROM TblVacaciones WHERE id_vacacion = p_id_vacacion;
    
    IF v_estado = 'APROBADO' THEN
        SET p_mensaje = CONCAT('Solicitud eliminada. ', v_dias, ' dias devueltos al saldo');
    ELSE
        SET p_mensaje = 'Solicitud eliminada';
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `sp_ExportarMarcacionDetallada`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ExportarMarcacionDetallada`(
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE
)
    READS SQL DATA
BEGIN
    -- ========================================================================
    -- DESCRIPCIÓN:
    -- Genera un reporte detallado de marcaciones por usuario y fecha
    -- con turnos organizados (Entrada 1, Salida 1, Entrada 2, Salida 2)
    -- ========================================================================
    
    SELECT 
        u.num_documento AS 'Número Documento',
        CONCAT(
            COALESCE(p.nombres, ''), ' ',
            COALESCE(p.apellido_paterno, ''), ' ',
            COALESCE(p.apellido_materno, '')
        ) AS 'Nombres Completos',
        DATE(m.fecha_marcacion) AS 'Fecha',
        
        -- TURNO 1 - MAÑANA
        (SELECT TIME(fecha_marcacion) 
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'ENTRADA'
           AND TIME(m1.fecha_marcacion) < '13:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Entrada 1',
        
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'SALIDA'
           AND TIME(m1.fecha_marcacion) < '14:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Salida 1',
        
        -- TURNO 2 - TARDE
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'ENTRADA'
           AND TIME(m1.fecha_marcacion) >= '13:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Entrada 2',
        
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'SALIDA'
           AND TIME(m1.fecha_marcacion) >= '14:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Salida 2',
        
        -- ESTADO
        CASE
            WHEN EXISTS (
                SELECT 1 FROM TblMarcacion m1
                WHERE m1.num_documento = u.num_documento
                  AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
                  AND m1.tipo_marcacion = 'ENTRADA'
                LIMIT 1
            ) THEN (
                -- Si tiene entrada, usar el estado de la primera entrada
                SELECT m1.estado
                FROM TblMarcacion m1
                WHERE m1.num_documento = u.num_documento
                  AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
                  AND m1.tipo_marcacion = 'ENTRADA'
                ORDER BY m1.fecha_marcacion ASC
                LIMIT 1
            )
            ELSE 'SIN MARCA'
        END AS 'Estado'
        
    FROM TblUsuario u
    
    -- JOIN con TblPersona para obtener nombres
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    
    -- Generar todas las fechas del rango para cada usuario
    CROSS JOIN (
        SELECT DATE(a.fecha) AS fecha_generada
        FROM (
            SELECT DATE_ADD(p_fecha_desde, INTERVAL t.n DAY) AS fecha
            FROM (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL 
                SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL 
                SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL 
                SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL 
                SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL 
                SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL 
                SELECT 24 UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL 
                SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30 UNION ALL SELECT 31 UNION ALL 
                SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL 
                SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39 UNION ALL 
                SELECT 40 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL 
                SELECT 44 UNION ALL SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL 
                SELECT 48 UNION ALL SELECT 49 UNION ALL SELECT 50 UNION ALL SELECT 51 UNION ALL 
                SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL 
                SELECT 56 UNION ALL SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59 UNION ALL 
                SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63
            ) t
        ) a
        WHERE DATE(a.fecha) BETWEEN p_fecha_desde AND p_fecha_hasta
    ) fechas
    
    -- LEFT JOIN con marcaciones (para incluir días sin marcación)
    LEFT JOIN TblMarcacion m ON u.num_documento = m.num_documento
        AND DATE(m.fecha_marcacion) = fechas.fecha_generada
    
    WHERE u.estado = 'ACTIVO'
    
    GROUP BY 
        u.num_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        fechas.fecha_generada
    
    ORDER BY 
        p.apellido_paterno,
        p.apellido_materno,
        p.nombres,
        fechas.fecha_generada;
    
END$$

DROP PROCEDURE IF EXISTS `sp_generar_material`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_generar_material`(
    IN p_tipo_inventario VARCHAR(50),
    OUT p_codigo VARCHAR(50)
)
    READS SQL DATA
BEGIN
    DECLARE v_prefijo VARCHAR(20) DEFAULT NULL;
    DECLARE v_siguiente INT;

    SELECT codigo INTO v_prefijo
    FROM `TblCategoriaInventario`
    WHERE nivel = 1 AND tipo_aplicable = p_tipo_inventario AND estado = 'ACTIVO'
    ORDER BY orden, id_categoria
    LIMIT 1;

    SET v_prefijo = COALESCE(v_prefijo, 'INV');

    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) AS UNSIGNED)), 0) + 1
    INTO v_siguiente
    FROM `TblInventario`
    WHERE codigo LIKE CONCAT(v_prefijo, '-%')
      AND SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) REGEXP '^[0-9]+$';

    SET p_codigo = CONCAT(v_prefijo, '-', LPAD(v_siguiente, GREATEST(3, CHAR_LENGTH(v_siguiente)), '0'));
END$$

DROP PROCEDURE IF EXISTS `sp_GuardarAccesosUsuario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_GuardarAccesosUsuario`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_GuardarAccesosUsuario`(
    IN p_num_documento INT,
    IN p_accesos_json JSON
)
BEGIN
    DECLARE p_error_message VARCHAR(500);
    DECLARE p_acceso_index INT DEFAULT 0;
    DECLARE p_acceso_count INT DEFAULT 0;
    DECLARE p_menu_nombre VARCHAR(100);
    DECLARE p_submenu_nombre VARCHAR(100);
    DECLARE p_id_menu INT;
    DECLARE p_id_submenu INT;
    DECLARE p_inserted_count INT DEFAULT 0;
    DECLARE p_deleted_count INT DEFAULT 0;
    
    -- Manejador de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 
            FALSE as success,
            CONCAT('Error en SP: ', p_error_message) as message,
            0 as deleted_rows,
            0 as inserted_rows;
    END;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- ========================================================================
    -- PASO 1: Validar que el usuario existe
    -- ========================================================================
    
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_documento = p_num_documento) THEN
        SET p_error_message = CONCAT('Usuario con documento ', p_num_documento, ' no existe');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
    END IF;
    
    -- ========================================================================
    -- PASO 2: Validar que el JSON sea válido
    -- ========================================================================
    
    IF p_accesos_json IS NULL OR JSON_TYPE(p_accesos_json) != 'ARRAY' THEN
        SET p_error_message = 'JSON de accesos no válido o vacío';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
    END IF;
    
    SET p_acceso_count = JSON_LENGTH(p_accesos_json);
    
    -- ========================================================================
    -- PASO 3: Eliminar accesos anteriores del usuario
    -- ========================================================================
    
    DELETE FROM TblUsuarioAccesos 
    WHERE num_documento = p_num_documento;
    
    SET p_deleted_count = ROW_COUNT();
    
    -- ========================================================================
    -- PASO 4: Insertar nuevos accesos (iterando el JSON con NOMBRES)
    -- NOTA: SOLO se insertan submenús específicos (NUNCA NULL)
    -- ========================================================================
    
    SET p_acceso_index = 0;
    
    WHILE p_acceso_index < p_acceso_count DO
        -- Extraer nombres del JSON
        SET p_menu_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_accesos_json, CONCAT('$[', p_acceso_index, '].menu_nombre')));
        SET p_submenu_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_accesos_json, CONCAT('$[', p_acceso_index, '].submenu_nombre')));
        
        -- Validar que submenu_nombre NO sea NULL (nueva lógica)
        IF p_submenu_nombre IS NULL OR p_submenu_nombre = 'null' OR p_submenu_nombre = '' THEN
            SET p_error_message = CONCAT('Error: submenu_nombre no puede ser null. Use submenús específicos.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Buscar el ID del menú por nombre
        SELECT id_menu INTO p_id_menu
        FROM TblMenu
        WHERE nombre = p_menu_nombre AND estado = 'ACTIVO'
        LIMIT 1;
        
        IF p_id_menu IS NULL THEN
            SET p_error_message = CONCAT('Menú "', p_menu_nombre, '" no existe o no está activo');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Buscar el ID del submenú por nombre (SIEMPRE debe especificarse)
        SELECT id_submenu INTO p_id_submenu
        FROM TblSubMenu
        WHERE nombre = p_submenu_nombre AND id_menu = p_id_menu AND estado = 'ACTIVO'
        LIMIT 1;
        
        IF p_id_submenu IS NULL THEN
            SET p_error_message = CONCAT('Submenú "', p_submenu_nombre, '" no existe en menú "', p_menu_nombre, '"');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Insertar acceso (SIEMPRE con id_submenu específico, NUNCA NULL)
        INSERT INTO TblUsuarioAccesos (num_documento, id_menu, id_submenu, estado)
        VALUES (p_num_documento, p_id_menu, p_id_submenu, 'ACTIVO')
        ON DUPLICATE KEY UPDATE 
            estado = 'ACTIVO',
            fecha_actualizacion = CURRENT_TIMESTAMP;
        
        SET p_inserted_count = p_inserted_count + 1;
        SET p_acceso_index = p_acceso_index + 1;
    END WHILE;
    
    -- ========================================================================
    -- PASO 5: Confirmar transacción
    -- ========================================================================
    
    COMMIT;
    
    -- ========================================================================
    -- PASO 6: Retornar resultado de éxito
    -- ========================================================================
    
    SELECT 
        TRUE as success,
        CONCAT('Se actualizaron accesos exitosamente: ', p_inserted_count, ' nuevos, ', p_deleted_count, ' eliminados') as message,
        p_deleted_count as deleted_rows,
        p_inserted_count as inserted_rows,
        p_num_documento as usuario_documento;

END$$

DROP PROCEDURE IF EXISTS `sp_GuardarSnapshotAntesDeEditar`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_GuardarSnapshotAntesDeEditar`(
    IN p_id_presupuesto INT,
    IN p_creado_por INT
)
BEGIN
    DECLARE v_siguiente_numero INT;
    DECLARE v_nueva_version_id INT;
    DECLARE v_existe_version INT;

    SELECT COUNT(*) INTO v_existe_version
    FROM `TblPresupuestoVersionHistorial`
    WHERE id_presupuesto = p_id_presupuesto;

    IF v_existe_version = 0 THEN
        SET v_siguiente_numero = 1;
    ELSE
        SELECT COALESCE(MAX(numero_version), 0) + 1
        INTO v_siguiente_numero
        FROM `TblPresupuestoVersionHistorial`
        WHERE id_presupuesto = p_id_presupuesto;
    END IF;

    UPDATE `TblPresupuestoVersionHistorial`
    SET es_version_actual = 0
    WHERE id_presupuesto = p_id_presupuesto;

    INSERT INTO `TblPresupuestoVersionHistorial` (
        id_presupuesto,
        numero_version,
        fecha_version,
        creado_por,
        motivo_cambio,
        es_version_actual,
        numero_presupuesto,
        id_proyecto,
        id_obra,
        nombre_proyecto,
        nombre_obra,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    )
    SELECT
        p.id_presupuesto,
        v_siguiente_numero,
        NOW(),
        p_creado_por,
        CONCAT('Versión ', v_siguiente_numero, ' - Editado por usuario'),
        1,
        p.numero_presupuesto,
        o.id_proyecto,
        p.id_obra,
        pr.nombre,
        o.nombre,
        NOW(),
        NULL,
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p.id_presupuesto
           AND tipo_item = 'MATERIAL'),
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p.id_presupuesto
           AND tipo_item IN ('SERVICIO','PARTIDA')),
        p.monto,
        p.gastos_generales,
        p.utilidad,
        (p.monto + p.gastos_generales + p.utilidad),
        p.igv,
        p.supervision_obra,
        p.monto_total,
        CASE WHEN p.monto > 0 THEN ROUND((p.gastos_generales / p.monto) * 100, 2) ELSE 0 END,
        CASE WHEN p.monto > 0 THEN ROUND((p.utilidad / p.monto) * 100, 2) ELSE 0 END,
        CASE WHEN (p.monto + p.gastos_generales + p.utilidad) > 0
             THEN ROUND((p.supervision_obra / (p.monto + p.gastos_generales + p.utilidad)) * 100, 2)
             ELSE 0 END,
        p.observaciones,
        p.estado
    FROM `TblPresupuesto` p
    LEFT JOIN `TblObra` o ON p.id_obra = o.id_obra
    LEFT JOIN `TblProyecto` pr ON o.id_proyecto = pr.id_proyecto
    WHERE p.id_presupuesto = p_id_presupuesto;

    SET v_nueva_version_id = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_nueva_version_id,
        pd.tipo_item,
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        (pd.cantidad * pd.precio_unitario),
        pd.id_detalle
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto
    ORDER BY pd.id_detalle;

END$$

DROP PROCEDURE IF EXISTS `sp_guardar_entrega_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_guardar_entrega_personal`(
    IN  p_id_personal   VARCHAR(20),
    IN  p_observaciones TEXT,
    IN  p_creado_por    VARCHAR(50),
    OUT p_success       TINYINT(1),
    OUT p_message       VARCHAR(255),
    OUT p_id_entrega    INT,
    OUT p_codigo        VARCHAR(50)
)
sp_body: BEGIN
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_count  INT;

    -- Validar que el personal existe
    IF NOT EXISTS (
        SELECT 1 FROM TblUsuario WHERE num_documento = p_id_personal AND estado = 'Activo'
    ) THEN
        SET p_success = 0;
        SET p_message = 'El personal no existe o está inactivo';
        LEAVE sp_body;
    END IF;

    -- Generar código único VALE-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO v_count FROM TblEntregaPersonal;
    SET v_codigo = CONCAT('VALE-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(v_count, 4, '0'));

    -- Insertar cabecera
    INSERT INTO TblEntregaPersonal (
        codigo_entrega, id_personal, fecha_entrega,
        observaciones, estado, creado_por
    ) VALUES (
        v_codigo, p_id_personal, NOW(),
        p_observaciones, 'ACTIVO', p_creado_por
    );

    SET p_id_entrega = LAST_INSERT_ID();
    SET p_codigo     = v_codigo;
    SET p_success    = 1;
    SET p_message    = 'Entrega creada correctamente';
END sp_body$$

DROP PROCEDURE IF EXISTS `sp_guardar_item`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_guardar_item`(
    IN  p_nombre           VARCHAR(200),
    IN  p_descripcion      TEXT,
    IN  p_tipo_inventario  VARCHAR(20),
    IN  p_id_categoria     INT,
    IN  p_id_unidad        INT,
    IN  p_stock_minimo     DECIMAL(10,2),
    IN  p_stock_maximo     DECIMAL(10,2),
    IN  p_precio_compra    DECIMAL(10,2),
    IN  p_id_almacen       INT,
    IN  p_ubicacion_fisica VARCHAR(100),
    IN  p_ficha            JSON,
    IN  p_stock_inicial    DECIMAL(10,2),
    IN  p_creado_por       INT,
    OUT p_success          BOOLEAN,
    OUT p_message          VARCHAR(255),
    OUT p_id_inventario    INT,
    OUT p_codigo           VARCHAR(50)
)
    MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_error        TEXT;
    DECLARE v_nombre       VARCHAR(200);
    DECLARE v_tipo_cat     VARCHAR(20) DEFAULT NULL;
    DECLARE v_nombre_cat   VARCHAR(100);
    DECLARE v_cat_unidades INT DEFAULT NULL;
    DECLARE v_permitida    INT DEFAULT 0;
    DECLARE v_duplicado    VARCHAR(50) DEFAULT NULL;
    DECLARE v_tabla        VARCHAR(64) DEFAULT NULL;
    DECLARE v_sets         TEXT DEFAULT NULL;
    DECLARE v_codigo       VARCHAR(50);
    DECLARE v_id           INT;
    DECLARE v_bloqueo      INT;
    DECLARE v_min          DECIMAL(10,2);
    DECLARE v_max          DECIMAL(10,2);
    DECLARE v_inicial      DECIMAL(10,2);
    DECLARE v_precio       DECIMAL(10,2);
    DECLARE v_invalido     VARCHAR(255) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = LEFT(CONCAT('No se guardó el ítem: ', COALESCE(v_error, 'error desconocido')), 255);
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
    END;

    SET p_success = FALSE;
    SET p_id_inventario = NULL;
    SET p_codigo = NULL;
    SET v_nombre  = TRIM(p_nombre);
    SET v_min     = COALESCE(p_stock_minimo, 0);
    SET v_max     = COALESCE(p_stock_maximo, 0);
    SET v_inicial = COALESCE(p_stock_inicial, 0);
    SET v_precio  = COALESCE(p_precio_compra, 0);

    -- ------------------------------------------------ Validaciones
    IF v_nombre IS NULL OR v_nombre = '' THEN
        SET p_message = 'El nombre del ítem es obligatorio';
        LEAVE proc;
    END IF;

    SELECT tipo_aplicable, nombre INTO v_tipo_cat, v_nombre_cat
    FROM `TblCategoriaInventario`
    WHERE id_categoria = p_id_categoria AND estado = 'ACTIVO';

    IF v_tipo_cat IS NULL THEN
        SET p_message = 'La categoría no existe o está inactiva';
        LEAVE proc;
    END IF;

    IF v_tipo_cat <> p_tipo_inventario THEN
        SET p_message = CONCAT('La categoría "', v_nombre_cat, '" no corresponde al tipo ', p_tipo_inventario);
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM `TblCategoriaUnidad` WHERE id_categoria = p_id_categoria) THEN
        SET v_cat_unidades = p_id_categoria;
    ELSE
        SELECT id_categoria_padre INTO v_cat_unidades
        FROM `TblCategoriaInventario` WHERE id_categoria = p_id_categoria;
    END IF;

    SELECT COUNT(*) INTO v_permitida
    FROM `TblCategoriaUnidad` cu
    JOIN `TblUnidadMedida` u ON u.id_unidad = cu.id_unidad
    WHERE cu.id_categoria = v_cat_unidades
      AND cu.id_unidad = p_id_unidad
      AND u.estado = 'ACTIVO';

    IF v_permitida = 0 THEN
        SET p_message = CONCAT('La unidad elegida no está permitida para la categoría "', v_nombre_cat, '"');
        LEAVE proc;
    END IF;

    IF v_min < 0 OR v_max < 0 OR v_inicial < 0 OR v_precio < 0 THEN
        SET p_message = 'Stock y precio no pueden ser negativos';
        LEAVE proc;
    END IF;

    IF v_max > 0 AND v_min > v_max THEN
        SET p_message = 'El stock mínimo no puede ser mayor que el stock máximo';
        LEAVE proc;
    END IF;

    IF p_ficha IS NOT NULL AND JSON_TYPE(p_ficha) <> 'OBJECT' THEN
        SET p_message = 'Las especificaciones técnicas deben enviarse como objeto JSON';
        LEAVE proc;
    END IF;

    -- Datos técnicos: se validan contra la estructura real de la sección ANTES
    -- de escribir (no depende del modo estricto ni de la conexión del cliente).
    --   lista (ENUM): el valor debe ser una de sus opciones
    --   número entero / decimal: solo dígitos (y punto decimal), sin negativos
    --   texto: no superar el largo máximo de la columna
    IF p_ficha IS NOT NULL AND JSON_LENGTH(p_ficha) > 0 THEN
        CALL sp_obtener_tabla_seccion(p_tipo_inventario, v_tabla);

        IF v_tabla IS NOT NULL THEN
            SELECT LEFT(CONCAT('Valor no válido en "', COALESCE(m.etiqueta, x.columna), '": ', x.valor,
                          CASE
                            WHEN x.tipo_dato = 'enum' THEN
                              CONCAT(' (opciones: ',
                                     REPLACE(SUBSTRING(x.tipo_columna, 6, CHAR_LENGTH(x.tipo_columna) - 6), '''', ''),
                                     ')')
                            WHEN x.tipo_dato IN ('int','smallint','tinyint','mediumint','bigint') THEN ' (debe ser un número entero)'
                            WHEN x.tipo_dato IN ('decimal','float','double') THEN ' (debe ser un número)'
                            ELSE CONCAT(' (máximo ', x.largo, ' caracteres)')
                          END), 255)
            INTO v_invalido
            FROM (
                SELECT CONVERT(c.COLUMN_NAME USING utf8mb4)  AS columna,
                       CONVERT(c.DATA_TYPE USING utf8mb4)    AS tipo_dato,
                       CONVERT(c.COLUMN_TYPE USING utf8mb4)  AS tipo_columna,
                       c.CHARACTER_MAXIMUM_LENGTH            AS largo,
                       NULLIF(IF(JSON_TYPE(JSON_EXTRACT(p_ficha, CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))) = 'NULL',
                                 NULL,
                                 TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_ficha, CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))))),
                              '') AS valor
                FROM information_schema.COLUMNS c
                WHERE c.TABLE_SCHEMA = DATABASE()
                  AND c.TABLE_NAME = v_tabla
                  AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
                  AND JSON_CONTAINS_PATH(p_ficha, 'one', CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))
            ) x
            LEFT JOIN `TblInventarioCampoSeccion` m
              ON m.tipo_inventario = p_tipo_inventario
             AND m.columna = x.columna COLLATE utf8mb4_unicode_ci
            WHERE x.valor IS NOT NULL
              AND (
                   (x.tipo_dato = 'enum'
                    AND LOCATE(CONCAT('''', x.valor, ''''), x.tipo_columna) = 0)
                OR (x.tipo_dato IN ('int','smallint','tinyint','mediumint','bigint')
                    AND x.valor NOT REGEXP '^[0-9]+$')
                OR (x.tipo_dato IN ('decimal','float','double')
                    AND x.valor NOT REGEXP '^[0-9]+([.][0-9]+)?$')
                OR (x.largo IS NOT NULL AND x.tipo_dato <> 'enum'
                    AND CHAR_LENGTH(x.valor) > x.largo)
              )
            ORDER BY COALESCE(m.orden, 999)
            LIMIT 1;

            IF v_invalido IS NOT NULL THEN
                SET p_message = v_invalido;
                LEAVE proc;
            END IF;
        END IF;
    END IF;

    SELECT codigo INTO v_duplicado
    FROM `TblInventario`
    WHERE estado = 'ACTIVO'
      AND tipo_inventario = p_tipo_inventario
      AND nombre = v_nombre
    LIMIT 1;

    IF v_duplicado IS NOT NULL THEN
        SET p_message = CONCAT('Ya existe un ítem activo con ese nombre: ', v_duplicado);
        LEAVE proc;
    END IF;

    -- ------------------------------------------------ Escritura (todo o nada)
    START TRANSACTION;

    -- Serializa altas del mismo tipo para que dos usuarios no obtengan el mismo código
    SELECT id_categoria INTO v_bloqueo
    FROM `TblCategoriaInventario`
    WHERE nivel = 1 AND tipo_aplicable = p_tipo_inventario
    ORDER BY orden, id_categoria
    LIMIT 1
    FOR UPDATE;

    CALL sp_generar_material(p_tipo_inventario, v_codigo);

    INSERT INTO `TblInventario` (
        codigo, nombre, descripcion, id_categoria, tipo_inventario,
        stock_actual, stock_minimo, stock_maximo, id_unidad, id_almacen,
        ubicacion_fisica, precio_compra, precio_promedio, estado, fecha_creacion, creado_por
    ) VALUES (
        v_codigo, v_nombre, NULLIF(TRIM(p_descripcion), ''), p_id_categoria, p_tipo_inventario,
        0, v_min, v_max, p_id_unidad, p_id_almacen,
        NULLIF(TRIM(p_ubicacion_fisica), ''), v_precio, v_precio, 'ACTIVO', NOW(), p_creado_por
    );

    SET v_id = LAST_INSERT_ID();

    -- 2. Sección del tipo
    CALL sp_asegurar_seccion_inventario(v_id);

    IF p_ficha IS NOT NULL AND JSON_LENGTH(p_ficha) > 0 THEN
        IF v_tabla IS NOT NULL THEN
            SET SESSION group_concat_max_len = 16384;

            SELECT GROUP_CONCAT(
                     CONCAT('`', CONVERT(c.COLUMN_NAME USING utf8mb4), '` = NULLIF(JSON_VALUE(@sp_guardar_item_ficha, ''$."',
                            CONVERT(c.COLUMN_NAME USING utf8mb4), '"''), '''')')
                     ORDER BY c.ORDINAL_POSITION SEPARATOR ', ')
            INTO v_sets
            FROM information_schema.COLUMNS c
            WHERE c.TABLE_SCHEMA = DATABASE()
              AND c.TABLE_NAME = v_tabla
              AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
              AND JSON_CONTAINS_PATH(p_ficha, 'one', CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'));

            IF v_sets IS NOT NULL THEN
                SET @sp_guardar_item_ficha = p_ficha;
                SET @sp_guardar_item_sql = CONCAT('UPDATE `', v_tabla, '` SET ', v_sets,
                                                  ' WHERE id_inventario = ', v_id);
                PREPARE st_ficha FROM @sp_guardar_item_sql;
                EXECUTE st_ficha;
                DEALLOCATE PREPARE st_ficha;
                SET @sp_guardar_item_ficha = NULL;
                SET @sp_guardar_item_sql = NULL;
            END IF;
        END IF;
    END IF;

    -- 3. Stock inicial con su movimiento
    IF v_inicial > 0 THEN
        UPDATE `TblInventario`
        SET stock_actual = v_inicial
        WHERE id_inventario = v_id;

        INSERT INTO `TblMovimientoInventario` (
            codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
            id_almacen_origen, id_almacen_destino, tipo_documento, id_documento_referencia,
            costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
        ) VALUES (
            CONCAT('INI-', v_codigo), v_id, 'ENTRADA', v_inicial,
            NULL, p_id_almacen, 'AJUSTE_INVENTARIO', NULL,
            v_precio, v_inicial * v_precio, 'Stock inicial', NOW(), p_creado_por
        );
    END IF;

    COMMIT;

    SET p_success = TRUE;
    SET p_message = CONCAT('Ítem creado con código ', v_codigo);
    SET p_id_inventario = v_id;
    SET p_codigo = v_codigo;
END$$

DROP PROCEDURE IF EXISTS `sp_horas_laboradas_v2`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_horas_laboradas_v2`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_num_documento INT
)
BEGIN
    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS f
        WHERE p_fecha_inicio <= p_fecha_fin
        UNION ALL
        SELECT f + INTERVAL 1 DAY FROM fechas WHERE f < p_fecha_fin
    ),
    grid AS (
        -- Persona-dia CON horario activo ese dia: genera fila aunque no haya marcas
        SELECT DISTINCT h.num_documento AS gdoc, fe.f AS gf
        FROM TblHorarioTrabajo h
        JOIN fechas fe
          ON UPPER(h.dia_semana) = CASE DAYOFWEEK(fe.f)
                 WHEN 1 THEN 'DOMINGO'
                 WHEN 2 THEN 'LUNES'
                 WHEN 3 THEN 'MARTES'
                 WHEN 4 THEN 'MIÉRCOLES'
                 WHEN 5 THEN 'JUEVES'
                 WHEN 6 THEN 'VIERNES'
                 WHEN 7 THEN 'SÁBADO'
             END
        WHERE h.es_activo = 1
          AND (p_num_documento IS NULL OR h.num_documento = p_num_documento)
        UNION
        -- Persona-dia CON marcas (incluye dias sin horario)
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
          AND (p_num_documento IS NULL OR mm.num_documento = p_num_documento)
    ),
    marcas AS (
        -- Asignacion de cada marca a su turno: IDENTICA a la pantalla
        -- (la ultima ENTRADA que la precede decide el turno segun SU horario)
        SELECT a.num_documento,
               a.fecha_marcacion,
               a.tipo_marcacion,
               a.tipo_ubicacion,
               CASE
                   WHEN a.ult_ent IS NULL
                        THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                   WHEN hh.num_documento IS NULL
                        THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                   WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                   WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                   ELSE 2
               END AS turno
        FROM (
            SELECT mm.*,
                   MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                       OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                             ORDER BY mm.fecha_marcacion, mm.id_marcacion
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
            FROM TblMarcacion mm
            WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
              AND (p_num_documento IS NULL OR mm.num_documento = p_num_documento)
        ) a
        LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
            AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                    WHEN 1 THEN 'DOMINGO'
                    WHEN 2 THEN 'LUNES'
                    WHEN 3 THEN 'MARTES'
                    WHEN 4 THEN 'MIÉRCOLES'
                    WHEN 5 THEN 'JUEVES'
                    WHEN 6 THEN 'VIERNES'
                    WHEN 7 THEN 'SÁBADO'
                END
            AND hh.es_activo = 1
    ),
    base AS (
        -- Pivote por persona-dia: 4 slots (une OFICINA + CAMPO en cada turno)
        -- + horario del dia para el tope de entrada
        SELECT g.gdoc,
               g.gf,
               MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                        THEN TIME(m.fecha_marcacion) END) AS entrada_t1,
               MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1
                        THEN TIME(m.fecha_marcacion) END) AS salida_t1,
               MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                        THEN TIME(m.fecha_marcacion) END) AS entrada_t2,
               MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2
                        THEN TIME(m.fecha_marcacion) END) AS salida_t2,
               MAX(h.hora_entrada)  AS horario_entrada,
               MAX(h.hora_entrada2) AS horario_entrada2
        FROM grid g
        LEFT JOIN marcas m ON m.num_documento = g.gdoc
                          AND DATE(m.fecha_marcacion) = g.gf
        LEFT JOIN TblHorarioTrabajo h ON h.num_documento = g.gdoc
            AND UPPER(h.dia_semana) = CASE DAYOFWEEK(g.gf)
                    WHEN 1 THEN 'DOMINGO'
                    WHEN 2 THEN 'LUNES'
                    WHEN 3 THEN 'MARTES'
                    WHEN 4 THEN 'MIÉRCOLES'
                    WHEN 5 THEN 'JUEVES'
                    WHEN 6 THEN 'VIERNES'
                    WHEN 7 THEN 'SÁBADO'
                END
            AND h.es_activo = 1
        GROUP BY g.gdoc, g.gf
    ),
    calculo AS (
        -- Minutos efectivos por turno:
        --   * par completo obligatorio (entrada y salida del turno)
        --   * tope de entrada: GREATEST(marca, horario); sin horario -> libre
        --   * salida sin tope
        --   * GREATEST(0, ...) contra negativos
        SELECT b.*,
               ( CASE
                    WHEN b.entrada_t1 IS NOT NULL AND b.salida_t1 IS NOT NULL THEN
                        GREATEST(0, ROUND((
                            TIME_TO_SEC(b.salida_t1) - TIME_TO_SEC(
                                CASE WHEN b.horario_entrada IS NOT NULL
                                     THEN GREATEST(b.entrada_t1, b.horario_entrada)
                                     ELSE b.entrada_t1 END
                            )) / 60))
                    ELSE 0
                 END
               + CASE
                    WHEN b.entrada_t2 IS NOT NULL AND b.salida_t2 IS NOT NULL THEN
                        GREATEST(0, ROUND((
                            TIME_TO_SEC(b.salida_t2) - TIME_TO_SEC(
                                CASE WHEN b.horario_entrada2 IS NOT NULL
                                     THEN GREATEST(b.entrada_t2, b.horario_entrada2)
                                     ELSE b.entrada_t2 END
                            )) / 60))
                    ELSE 0
                 END
               ) AS m_calc
        FROM base b
    )
    SELECT
        p.num_documento,
        p.documento_numero AS dni,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        e.nombre AS empresa,
        c.nombre AS cargo,
        cal.gf AS fecha,
        DAYNAME(cal.gf) AS dia,
        cal.entrada_t1,
        cal.salida_t1,
        cal.entrada_t2,
        cal.salida_t2,
        NULLIF(cal.m_calc, 0) AS minutos_totales,
        CASE WHEN NULLIF(cal.m_calc, 0) IS NULL THEN '-'
             ELSE CONCAT(LPAD(FLOOR(cal.m_calc / 60), 2, '0'), ':',
                         LPAD(cal.m_calc % 60, 2, '0'))
        END AS horas_laboradas
    FROM calculo cal
    INNER JOIN TblPersona p ON p.num_documento = cal.gdoc
    INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo  c ON u.id_cargo = c.id_cargo
    ORDER BY p.apellido_paterno, p.apellido_materno, p.nombres, cal.gf;
END$$

DROP PROCEDURE IF EXISTS `sp_InicializarVersionPresupuesto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_InicializarVersionPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_creado_por INT
)
BEGIN
    DECLARE v_existe INT;
    
    -- Verificar si ya tiene versiones
    SELECT COUNT(*) INTO v_existe
    FROM TblPresupuestoVersionHistorial
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_existe = 0 THEN
        -- Crear versión 1 inicial
        CALL sp_CrearNuevaVersionPresupuesto(
            p_id_presupuesto,
            p_creado_por,
            'Versión inicial'
        );
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_kardex_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_kardex_personal`(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    -- 1. Ficha del trabajador
    SELECT
        p.documento_numero                                                          AS documento,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                             AS nombre_completo,
        COALESCE(c.nombre, 'Sin Cargo')                                             AS cargo,
        COALESCE(a.nombre, 'Sin Área')                                              AS area,
        p.email
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c   ON u.id_cargo = c.id_cargo
    LEFT  JOIN TblArea a    ON c.id_area  = a.id_area
    WHERE u.num_documento = p_id_personal
    LIMIT 1;

    -- 2. Historial de materiales
    SELECT
        ep.fecha_entrega,
        ep.codigo_entrega,
        i.nombre                AS material,
        i.codigo                AS codigo_material,
        epd.serie,
        epd.cantidad,
        u2.abreviatura          AS unidad,
        epd.estado_bien,
        ep.estado               AS estado_asignacion,
        epd.observaciones
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i               ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u2            ON i.id_unidad = u2.id_unidad
    WHERE ep.id_personal = p_id_personal
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_ListarProveedores`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ListarProveedores`()
BEGIN
    SELECT 
        p.ruc,
        p.razon_social,
        p.nombre_comercial,
        p.tipo_contribuyente,
        p.telefono,
        p.telefono_alternativo,
        p.email,
        p.email_facturacion,
        p.sitio_web,
        p.direccion_fiscal,
        p.departamento,
        p.provincia,
        p.distrito,
        p.ubigeo,
        p.referencia,
        p.contacto_nombre,
        p.contacto_cargo,
        p.contacto_telefono,
        p.contacto_email,
        p.contacto_dni,
        p.banco_1,
        p.cuenta_banco_1,
        p.tipo_cuenta_1,
        p.moneda_1,
        p.cci_1,
        p.banco_2,
        p.cuenta_banco_2,
        p.tipo_cuenta_2,
        p.moneda_2,
        p.cci_2,
        p.rubro_negocio,
        p.categoria,
        p.calificacion,
        p.condicion_pago,
        p.plazo_entrega,
        p.descuento_comercial,
        p.es_agente_retencion,
        p.es_buen_contribuyente,
        p.tiene_certificado_calidad,
        p.certificados_adjuntos,
        p.estado,
        p.motivo_inactivo,
        p.observaciones,
        p.notas_internas,
        p.creado_por,
        p.fecha_creacion,
        p.actualizado_por,
        p.fecha_actualizacion,
        CONCAT(IFNULL(per.nombres, ''), ' ', IFNULL(per.apellido_paterno, ''), ' ', IFNULL(per.apellido_materno, '')) as creado_por_nombre,
        CONCAT(IFNULL(per2.nombres, ''), ' ', IFNULL(per2.apellido_paterno, ''), ' ', IFNULL(per2.apellido_materno, '')) as actualizado_por_nombre
    FROM TblProveedores p
    LEFT JOIN TblPersona per ON p.creado_por = per.num_documento
    LEFT JOIN TblPersona per2 ON p.actualizado_por = per2.num_documento
    WHERE p.estado != 'ELIMINADO'
    ORDER BY p.fecha_creacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_campos_seccion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_campos_seccion`(
    IN p_tipo_inventario VARCHAR(20)
)
    READS SQL DATA
BEGIN
    DECLARE v_tabla VARCHAR(64) DEFAULT NULL;

    CALL sp_obtener_tabla_seccion(p_tipo_inventario, v_tabla);

    SELECT CONVERT(c.COLUMN_NAME USING utf8mb4) AS columna,
           COALESCE(m.etiqueta,
                    CONCAT(UPPER(LEFT(c.COLUMN_NAME, 1)),
                           REPLACE(SUBSTRING(c.COLUMN_NAME, 2), '_', ' '))) AS etiqueta,
           m.placeholder,
           CASE
             WHEN c.DATA_TYPE = 'enum' THEN 'select'
             WHEN c.DATA_TYPE IN ('decimal','int','smallint','tinyint','mediumint','bigint','float','double') THEN 'numero'
             WHEN c.DATA_TYPE IN ('date','datetime') THEN 'fecha'
             ELSE 'texto'
           END AS control,
           IF(c.DATA_TYPE = 'enum',
              SUBSTRING(c.COLUMN_TYPE, 6, CHAR_LENGTH(c.COLUMN_TYPE) - 6),
              NULL) AS opciones,
           c.CHARACTER_MAXIMUM_LENGTH AS largo_maximo,
           CASE
             WHEN c.DATA_TYPE IN ('int','smallint','tinyint','mediumint','bigint') THEN 0
             ELSE c.NUMERIC_SCALE
           END AS decimales,
           IF(c.DATA_TYPE IN ('decimal','int','smallint','tinyint','mediumint','bigint','float','double'), 0, NULL) AS minimo,
           COALESCE(m.orden, 1000 + c.ORDINAL_POSITION) AS orden
    FROM information_schema.COLUMNS c
    LEFT JOIN `TblInventarioCampoSeccion` m
      ON m.tipo_inventario = p_tipo_inventario
     AND m.columna = CONVERT(c.COLUMN_NAME USING utf8mb4) COLLATE utf8mb4_unicode_ci
    WHERE c.TABLE_SCHEMA = DATABASE()
      AND c.TABLE_NAME = v_tabla
      AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
      AND COALESCE(m.visible, 1) = 1
    ORDER BY orden;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_categorias_tipo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_categorias_tipo`(
    IN p_tipo_inventario VARCHAR(20)
)
    READS SQL DATA
BEGIN
    SELECT c.id_categoria,
           c.codigo,
           c.nombre,
           c.nivel,
           p.id_categoria AS id_categoria_padre,
           COALESCE(p.nombre, c.nombre) AS grupo,
           c.icono
    FROM `TblCategoriaInventario` c
    LEFT JOIN `TblCategoriaInventario` p ON p.id_categoria = c.id_categoria_padre
    WHERE c.estado = 'ACTIVO'
      AND c.tipo_aplicable = p_tipo_inventario
      AND (c.nivel = 2
           OR NOT EXISTS (SELECT 1 FROM `TblCategoriaInventario` h
                          WHERE h.id_categoria_padre = c.id_categoria AND h.estado = 'ACTIVO'))
    ORDER BY COALESCE(p.orden, c.orden), c.orden, c.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_entrega_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_entrega_personal`(
    IN p_busqueda VARCHAR(100)
)
BEGIN
    SELECT
        u.num_documento                                                        AS id_personal,
        p.documento_numero                                                     AS DOCUMENTO,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                        AS NOMBRE_COMPLETO,
        COALESCE(c.nombre, 'Sin Cargo')                                        AS CARGO,
        COALESCE(a.nombre, 'Sin Área')                                         AS AREA,
        COUNT(DISTINCT ep.id_entrega)                                          AS TOTAL_ENTREGAS,
        COALESCE(SUM(epd.cantidad), 0)                                         AS TOTAL_ITEMS,
        MAX(ep.fecha_entrega)                                                  AS ULTIMA_ENTREGA
    FROM TblUsuario u
    INNER JOIN TblPersona p  ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c    ON u.id_cargo      = c.id_cargo
    LEFT  JOIN TblArea a     ON c.id_area       = a.id_area
    LEFT  JOIN TblEntregaPersonal ep
               ON u.num_documento = ep.id_personal
               AND ep.estado = 'ACTIVO'
    LEFT  JOIN TblEntregaPersonalDetalle epd
               ON ep.id_entrega = epd.id_entrega
    WHERE u.estado = 'Activo'
      AND (
            p_busqueda IS NULL
            OR p_busqueda = ''
            OR p.documento_numero           LIKE CONCAT('%', p_busqueda, '%')
            OR p.nombres                    LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_paterno           LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_materno           LIKE CONCAT('%', p_busqueda, '%')
            OR c.nombre                     LIKE CONCAT('%', p_busqueda, '%')
            OR a.nombre                     LIKE CONCAT('%', p_busqueda, '%')
          )
    GROUP BY u.num_documento, p.documento_numero, p.nombres, p.apellido_paterno,
             p.apellido_materno, c.nombre, a.nombre
    ORDER BY p.apellido_paterno ASC, p.nombres ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_inventario`(
    IN p_busqueda VARCHAR(255),
    IN p_categoria VARCHAR(100),
    IN p_tipo_inventario VARCHAR(50),
    IN p_estado VARCHAR(50)
)
BEGIN
    SELECT 
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        c.nombre AS categoria,
        u.nombre AS unidad_medida,
        u.abreviatura AS unidad_abrev,
        i.stock_actual,
        i.stock_minimo,
        i.stock_maximo,
        i.precio_compra AS precio_unitario,
        i.precio_promedio,
        i.costo_total,
        i.estado,
        i.fecha_actualizacion,
        a.nombre AS almacen,
        a.codigo AS almacen_codigo,
        i.ubicacion_fisica,
        -- Indicador de stock
        CASE 
            WHEN i.stock_actual <= i.stock_minimo THEN 'BAJO'
            WHEN i.stock_actual >= i.stock_maximo * 0.8 THEN 'OPTIMO'
            ELSE 'NORMAL'
        END AS nivel_stock
    FROM TblInventario i
    LEFT JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
    LEFT JOIN TblAlmacen a ON i.id_almacen = a.id_almacen
    WHERE 1=1
        -- Filtro por estado
        AND (p_estado IS NULL OR p_estado = '' OR i.estado = p_estado)
        -- Filtro por tipo
        AND (p_tipo_inventario IS NULL OR p_tipo_inventario = '' OR i.tipo_inventario = p_tipo_inventario)
        -- Filtro por búsqueda (código, nombre o descripción)
        AND (
            p_busqueda IS NULL 
            OR p_busqueda = '' 
            OR i.nombre LIKE CONCAT('%', p_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_busqueda, '%')
            OR i.descripcion LIKE CONCAT('%', p_busqueda, '%')
        )
        -- Filtro por categoría
        AND (p_categoria IS NULL OR p_categoria = '' OR c.nombre = p_categoria)
    ORDER BY i.nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_materiales_de_proveedor`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_materiales_de_proveedor`(
    IN p_ruc_proveedor VARCHAR(11)
)
BEGIN
    SELECT
        ip.id_inventario_proveedor,
        ip.id_inventario,
        ip.ruc_proveedor,
        i.codigo,
        i.nombre,
        i.tipo_inventario,
        i.descripcion,
        c.nombre        AS categoria,
        u.nombre        AS unidad,
        u.abreviatura   AS unidad_abrev,
        i.stock_actual,
        i.estado        AS estado_inventario,
        ip.codigo_proveedor,
        ip.precio_compra,
        ip.moneda,
        ip.plazo_entrega_dias,
        ip.es_principal,
        ip.estado,
        ip.observaciones,
        ip.fecha_creacion
    FROM TblInventarioProveedor ip
    INNER JOIN TblInventario i          ON ip.id_inventario = i.id_inventario
    LEFT  JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
    LEFT  JOIN TblUnidadMedida u        ON i.id_unidad = u.id_unidad
    WHERE ip.ruc_proveedor = p_ruc_proveedor
      AND ip.estado = 'ACTIVO'
      AND i.estado  = 'ACTIVO'
    ORDER BY ip.es_principal DESC, i.nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_proveedores_de_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_proveedores_de_inventario`(
    IN p_id_inventario INT
)
BEGIN
    SELECT
        ip.id_inventario_proveedor,
        ip.id_inventario,
        ip.ruc_proveedor,
        p.razon_social,
        p.nombre_comercial,
        p.telefono,
        p.email,
        p.contacto_nombre,
        p.contacto_telefono,
        p.estado        AS estado_proveedor,
        ip.codigo_proveedor,
        ip.precio_compra,
        ip.moneda,
        ip.plazo_entrega_dias,
        ip.es_principal,
        ip.estado,
        ip.observaciones,
        ip.fecha_creacion
    FROM TblInventarioProveedor ip
    INNER JOIN TblProveedores p ON ip.ruc_proveedor = p.ruc
    WHERE ip.id_inventario = p_id_inventario
      AND ip.estado = 'ACTIVO'
      AND p.estado != 'ELIMINADO'
    ORDER BY ip.es_principal DESC, p.razon_social ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_proveedores_selector`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_proveedores_selector`()
BEGIN
    SELECT
        ruc,
        razon_social,
        nombre_comercial,
        telefono,
        email
    FROM TblProveedores
    WHERE estado = 'ACTIVO'
    ORDER BY razon_social ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_tipos_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_tipos_inventario`(
    IN p_solo_fisicos TINYINT
)
    READS SQL DATA
BEGIN
    SELECT t.*
    FROM (
        SELECT c.tipo_aplicable AS tipo_inventario,
               c.nombre,
               c.codigo         AS prefijo_codigo,
               c.icono,
               c.orden,
               c.id_categoria   AS id_categoria_raiz,
               (SELECT tc.TABLE_NAME
                FROM information_schema.TABLE_CONSTRAINTS tc
                JOIN information_schema.CHECK_CONSTRAINTS cc
                  ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
                WHERE tc.TABLE_SCHEMA = DATABASE()
                  AND tc.CONSTRAINT_TYPE = 'CHECK'
                  AND tc.TABLE_NAME LIKE 'TblInventario%'
                  AND LOCATE('tipo_inventario', CONVERT(cc.CHECK_CLAUSE USING utf8mb4)) > 0
                  AND LOCATE(CONCAT('''', CONVERT(c.tipo_aplicable USING utf8mb4), ''''),
                             REPLACE(CONVERT(cc.CHECK_CLAUSE USING utf8mb4), CHAR(92 USING utf8mb4), '')) > 0
                LIMIT 1) AS tabla_seccion
        FROM `TblCategoriaInventario` c
        WHERE c.nivel = 1
          AND c.estado = 'ACTIVO'
          AND c.tipo_aplicable <> 'TODOS'
    ) t
    WHERE (p_solo_fisicos IS NULL OR p_solo_fisicos = 0 OR t.tabla_seccion IS NOT NULL)
    ORDER BY t.orden, t.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_unidades_categoria`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_unidades_categoria`(
    IN p_id_categoria INT
)
    READS SQL DATA
BEGIN
    DECLARE v_cat INT DEFAULT NULL;

    IF EXISTS (SELECT 1 FROM `TblCategoriaUnidad` WHERE id_categoria = p_id_categoria) THEN
        SET v_cat = p_id_categoria;
    ELSE
        SELECT id_categoria_padre INTO v_cat
        FROM `TblCategoriaInventario` WHERE id_categoria = p_id_categoria;
    END IF;

    SELECT u.id_unidad, u.codigo, u.nombre, u.abreviatura, u.magnitud,
           cu.predeterminada,
           IF(cu.id_categoria = p_id_categoria, 'propia', 'heredada') AS origen
    FROM `TblCategoriaUnidad` cu
    JOIN `TblUnidadMedida` u ON u.id_unidad = cu.id_unidad
    WHERE cu.id_categoria = v_cat
      AND u.estado = 'ACTIVO'
    ORDER BY cu.predeterminada DESC, u.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_MarcarPresupuestoEliminado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_MarcarPresupuestoEliminado`(
    IN p_id_presupuesto INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' as resultado, 'No se pudo cambiar el estado' as mensaje;
    END;
    
    START TRANSACTION;
    
    -- 1. Cambiar estado del presupuesto
    UPDATE TblPresupuesto
    SET estado = 'ELIMINADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- 2. Eliminar registros de aprobación PENDIENTES
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 1
    AND id_documento_referencia = p_id_presupuesto
    AND estado_aprobacion = 'PENDIENTE';
    
    COMMIT;
    
    SELECT 'SUCCESS' as resultado, 'Presupuesto marcado como ELIMINADO' as mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_MarcarRequerimientoEliminado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_MarcarRequerimientoEliminado`(
    IN p_id_requerimiento INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' as resultado, 'No se pudo cambiar el estado' as mensaje;
    END;
    
    START TRANSACTION;
    
    -- 1. Cambiar estado del requerimiento
    UPDATE TblRequerimiento
    SET estado = 'ELIMINADO'
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- 2. Eliminar registros de aprobación PENDIENTES
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2
    AND id_documento_referencia = p_id_requerimiento
    AND estado_aprobacion = 'PENDIENTE';
    
    COMMIT;
    
    SELECT 'SUCCESS' as resultado, 'Requerimiento marcado como ELIMINADO' as mensaje;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerAccesosUsuario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerAccesosUsuario`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerAccesosUsuario`(
    IN p_num_documento INT
)
BEGIN
    SELECT 
        ua.id_usuario_acceso,
        ua.num_documento,
        ua.id_menu,
        m.nombre as menu_nombre,
        m.icono as menu_icono,
        ua.id_submenu,
        sm.nombre as submenu_nombre,
        sm.icono as submenu_icono,
        sm.ruta as submenu_ruta,
        ua.estado,
        ua.fecha_creacion,
        CASE 
            WHEN ua.id_submenu IS NULL THEN 'Menú Completo'
            ELSE 'Submenú Específico'
        END as tipo_acceso
    FROM TblUsuarioAccesos ua
    JOIN TblMenu m ON ua.id_menu = m.id_menu
    LEFT JOIN TblSubMenu sm ON ua.id_submenu = sm.id_submenu AND ua.id_menu = sm.id_menu
    WHERE ua.num_documento = p_num_documento AND ua.estado = 'ACTIVO'
    ORDER BY m.orden, COALESCE(sm.orden, 0);
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerAreas`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerAreas`()
BEGIN          
    SELECT                  
        id_area,                  
        nombre          
    FROM TblArea          
    WHERE estado = 'Activo'          
    ORDER BY nombre; 
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerCargosPorArea`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerCargosPorArea`(
                IN p_id_area INT
            )
BEGIN
                SELECT 
                    id_cargo,
                    nombre,
                    p_id_area AS id_area
                FROM TblCargo
                WHERE id_area = p_id_area
                AND estado = 'Activo'
                ORDER BY nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerCategoriasMaterial`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerCategoriasMaterial`()
BEGIN
    SELECT
        id_categoria,
        codigo,
        nombre,
        tipo_aplicable
    FROM `TblCategoriaInventario`
    WHERE estado = 'ACTIVO'
    ORDER BY nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerDatosEmpleadoMemo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerDatosEmpleadoMemo`(
    IN p_num_documento INT
)
BEGIN
    SELECT 
        p.num_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.tipo_documento,
        p.documento_numero,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', IFNULL(p.apellido_materno, '')) AS nombre_completo,
        u.usuario,
        p.email,
        c.nombre AS cargo,
        a.nombre AS area,
        e.nombre AS empresa
    FROM TblPersona p
    LEFT JOIN TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    WHERE p.num_documento = p_num_documento
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerDetalleDia`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerDetalleDia`(
    IN p_num_documento VARCHAR(20),
    IN p_fecha DATE
)
BEGIN
    -- Obtener información del usuario
    SELECT 
        u.num_documento,
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as nombre_completo,
        p.email
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE u.num_documento = p_num_documento;
    
    -- Obtener todas las marcaciones del día con fotos
    SELECT 
        m.id_marcacion,
        m.tipo_marcacion,
        m.fecha_marcacion,
        TIME(m.fecha_marcacion) as hora,
        m.latitud,
        m.longitud,
        m.precision,
        m.foto_base64,
        m.dispositivo,
        m.observacion,
        m.justificacion
    FROM TblMarcacion m
    WHERE m.num_documento = p_num_documento
        AND DATE(m.fecha_marcacion) = p_fecha
    ORDER BY m.fecha_marcacion ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerDiasDisponibles`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerDiasDisponibles`(
    IN p_num_documento INT,
    IN p_anio YEAR
)
BEGIN
    INSERT INTO TblVacacionSaldo (num_documento, anio, dias_totales, dias_usados)
    VALUES (p_num_documento, p_anio, 30, 0)
    ON DUPLICATE KEY UPDATE id_saldo = id_saldo;
    
    SELECT 
        ts.num_documento,
        ts.anio,
        ts.dias_totales,
        ts.dias_usados,
        ts.dias_pendientes
    FROM TblVacacionSaldo ts
    WHERE ts.num_documento = p_num_documento
      AND ts.anio = p_anio;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerDocumentosPendientesPorCargo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerDocumentosPendientesPorCargo`(
    IN p_id_cargo INT,
    IN p_id_tipo_documento INT
)
    READS SQL DATA
BEGIN
    -- Obtener documentos PENDIENTE para el cargo especificado
    -- IMPORTANTE: Excluye documentos con estado ELIMINADO
    
    SELECT
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        ra.id_documento_referencia AS id_documento,
        ra.numero_paso,
        ra.fecha_asignacion,
        ra.estado_aprobacion,
        tda.icono,
        tda.color
    FROM 
        TblRegistroAprobacion ra
    INNER JOIN 
        TblTipoDocumentoAprobacion tda 
        ON ra.id_tipo_documento = tda.id_tipo_documento
    -- ⭐ NUEVO: JOIN con tablas de documentos para verificar estado
    LEFT JOIN 
        TblPresupuesto p 
        ON ra.id_tipo_documento = 1 AND ra.id_documento_referencia = p.id_presupuesto
    LEFT JOIN 
        TblRequerimiento r 
        ON ra.id_tipo_documento = 2 AND ra.id_documento_referencia = r.id_requerimiento
    WHERE 
        ra.estado_aprobacion = 'PENDIENTE'
        AND ra.id_cargo_aprobador = p_id_cargo
        AND (p_id_tipo_documento IS NULL OR ra.id_tipo_documento = p_id_tipo_documento)
        AND tda.activo = 1
        AND tda.requiere_aprobacion = 1
        -- ⭐ NUEVO: Excluir documentos ELIMINADOS
        AND (
            (ra.id_tipo_documento = 1 AND p.estado <> 'ELIMINADO')  -- Presupuestos
            OR (ra.id_tipo_documento = 2 AND r.estado <> 'ELIMINADO')  -- Requerimientos
            OR (ra.id_tipo_documento NOT IN (1, 2))  -- Otros tipos de documentos
        )
        -- ⭐ NUEVO: Excluir documentos que ya no existen (NULL después del LEFT JOIN)
        AND (
            (ra.id_tipo_documento = 1 AND p.id_presupuesto IS NOT NULL)
            OR (ra.id_tipo_documento = 2 AND r.id_requerimiento IS NOT NULL)
            OR (ra.id_tipo_documento NOT IN (1, 2))
        )
        -- CRÍTICO: Verificar que TODOS los pasos anteriores estén APROBADOS
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    ORDER BY 
        ra.fecha_asignacion DESC,
        ra.id_tipo_documento ASC;

END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerEmpresas`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerEmpresas`()
BEGIN
    SELECT 
        id_empresa,
        nombre
    FROM TblEmpresa
    WHERE activa = 1
    ORDER BY nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerEstadisticasVacaciones`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerEstadisticasVacaciones`(
    IN p_num_documento INT,
    IN p_anio YEAR
)
BEGIN
    DECLARE v_dias_disponibles INT DEFAULT 0;
    DECLARE v_dias_usados INT DEFAULT 0;
    DECLARE v_pendientes INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;
    
    IF p_num_documento IS NOT NULL THEN
        INSERT INTO TblVacacionSaldo (num_documento, anio, dias_totales, dias_usados)
        VALUES (p_num_documento, p_anio, 30, 0)
        ON DUPLICATE KEY UPDATE id_saldo = id_saldo;
        
        SELECT dias_pendientes, dias_usados
        INTO v_dias_disponibles, v_dias_usados
        FROM TblVacacionSaldo
        WHERE num_documento = p_num_documento AND anio = p_anio;
    ELSE
        SELECT IFNULL(SUM(dias_pendientes), 0), IFNULL(SUM(dias_usados), 0)
        INTO v_dias_disponibles, v_dias_usados
        FROM TblVacacionSaldo
        WHERE anio = p_anio;
    END IF;
    
    SELECT 
        COUNT(CASE WHEN estado = 'PENDIENTE' THEN 1 END),
        COUNT(*)
    INTO v_pendientes, v_total
    FROM TblVacaciones
    WHERE (p_num_documento IS NULL OR num_documento = p_num_documento)
      AND YEAR(fecha_inicio) = p_anio;
    
    SELECT 
        v_dias_disponibles AS dias_disponibles,
        v_dias_usados AS dias_usados,
        v_pendientes AS solicitudes_pendientes,
        v_total AS total_solicitudes;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerEstadoMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerEstadoMarcacion`(
    IN p_num_documento VARCHAR(20)
)
BEGIN
    -- Obtener la última marcación del día actual
    SELECT 
        id_marcacion,
        tipo_marcacion,
        fecha_marcacion,
        TIME(fecha_marcacion) as hora
    FROM TblMarcacion
    WHERE num_documento = p_num_documento
        AND DATE(fecha_marcacion) = CURDATE()
    ORDER BY fecha_marcacion DESC
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerHistorialConEstados`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerHistorialConEstados`(
    IN p_num_documento INT,
    IN p_dias INT
)
    READS SQL DATA
BEGIN
    SELECT 
        m.id_marcacion,
        m.num_documento,
        m.tipo_marcacion,
        m.fecha_marcacion,
        TIME(m.fecha_marcacion) as hora_marcacion,
        DATE(m.fecha_marcacion) as fecha,
        CASE DAYNAME(m.fecha_marcacion)
            WHEN 'Monday' THEN 'LUNES'
            WHEN 'Tuesday' THEN 'MARTES'
            WHEN 'Wednesday' THEN 'MIERCOLES'
            WHEN 'Thursday' THEN 'JUEVES'
            WHEN 'Friday' THEN 'VIERNES'
            WHEN 'Saturday' THEN 'SABADO'
            WHEN 'Sunday' THEN 'DOMINGO'
        END as dia_semana,
        h.hora_entrada,
        h.hora_salida,
        h.hora_entrada2,
        h.hora_salida2,
        CASE WHEN TIME(m.fecha_marcacion) < '12:00:00' THEN 1 ELSE 2 END as turno,
        -- Estados: VACACIONES, ASISTIÓ, ASISTIÓ +5, TARDE, SALIDA, SIN HORARIO
        CASE 
            WHEN m.tipo_marcacion = 'ENTRADA'
                 AND EXISTS (
                     SELECT 1 FROM TblVacaciones v
                     WHERE v.num_documento = m.num_documento
                       AND v.estado = 'APROBADO'
                       AND DATE(m.fecha_marcacion) BETWEEN v.fecha_inicio AND v.fecha_fin
                 ) THEN 'VACACIONES'
            WHEN m.tipo_marcacion = 'ENTRADA' THEN
                CASE
                    WHEN h.hora_entrada IS NULL AND h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
                    WHEN TIME(m.fecha_marcacion) < '12:00:00' THEN
                        CASE
                            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
                            WHEN TIME(m.fecha_marcacion) < h.hora_entrada THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) = h.hora_entrada THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) > h.hora_entrada 
                                AND TIME(m.fecha_marcacion) <= ADDTIME(h.hora_entrada, '00:05:00') 
                            THEN 'ASISTIÓ +5'
                            ELSE 'TARDE'
                        END
                    WHEN TIME(m.fecha_marcacion) >= '12:00:00' THEN
                        CASE
                            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
                            WHEN TIME(m.fecha_marcacion) < h.hora_entrada2 THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) = h.hora_entrada2 THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) > h.hora_entrada2 
                                AND TIME(m.fecha_marcacion) <= ADDTIME(h.hora_entrada2, '00:05:00') 
                            THEN 'ASISTIÓ +5'
                            ELSE 'TARDE'
                        END
                    ELSE 'ASISTIÓ'
                END
            WHEN m.tipo_marcacion = 'SALIDA' THEN 'SALIDA'
            ELSE 'ASISTIÓ'
        END as estado_asistencia,
        CASE 
            WHEN m.tipo_marcacion = 'ENTRADA' THEN
                CASE
                    WHEN TIME(m.fecha_marcacion) < '12:00:00' AND h.hora_entrada IS NOT NULL
                    THEN TIMESTAMPDIFF(MINUTE, h.hora_entrada, TIME(m.fecha_marcacion))
                    WHEN TIME(m.fecha_marcacion) >= '12:00:00' AND h.hora_entrada2 IS NOT NULL
                    THEN TIMESTAMPDIFF(MINUTE, h.hora_entrada2, TIME(m.fecha_marcacion))
                    ELSE 0
                END
            ELSE 0
        END as minutos_diferencia,
         m.justificacion
    FROM TblMarcacion m
    LEFT JOIN TblHorarioTrabajo h ON (
        m.num_documento = h.num_documento 
        AND h.dia_semana = CASE DAYNAME(m.fecha_marcacion)
            WHEN 'Monday' THEN 'LUNES'
            WHEN 'Tuesday' THEN 'MARTES'
            WHEN 'Wednesday' THEN 'MIERCOLES'
            WHEN 'Thursday' THEN 'JUEVES'
            WHEN 'Friday' THEN 'VIERNES'
            WHEN 'Saturday' THEN 'SABADO'
            WHEN 'Sunday' THEN 'DOMINGO'
        END
        AND h.es_activo = 1
        AND h.estado = 'ACTIVO'
    )
    WHERE m.num_documento = p_num_documento
        AND DATE(m.fecha_marcacion) >= DATE(NOW() - INTERVAL p_dias DAY)
    ORDER BY m.fecha_marcacion DESC
    LIMIT 100;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerHistorialVersiones`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerHistorialVersiones`(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        vh.id_version,
        vh.numero_version,
        vh.fecha_version,
        vh.motivo_cambio,
        vh.es_version_actual,
        vh.presupuesto_total,
        vh.estado,
        -- Datos del creador
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as creado_por_nombre,
        -- Conteo de partidas
        (SELECT COUNT(*) 
         FROM TblPresupuestoVersionDetalleHistorial 
         WHERE id_version = vh.id_version
        ) as total_partidas
    FROM TblPresupuestoVersionHistorial vh
    LEFT JOIN TblPersona p ON vh.creado_por = p.num_documento
    WHERE vh.id_presupuesto = p_id_presupuesto
    ORDER BY vh.numero_version DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerIdsMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerIdsMarcacion`(
    IN p_documento_numero VARCHAR(20),
    IN p_fecha DATE
)
BEGIN
    DECLARE v_num_documento INT;
    
    SELECT num_documento INTO v_num_documento
    FROM TblPersona
    WHERE documento_numero = p_documento_numero
    LIMIT 1;
    
    IF v_num_documento IS NULL THEN
        SELECT NULL AS id_t1_entrada, NULL AS id_t1_salida, 
               NULL AS id_t2_entrada, NULL AS id_t2_salida,
               NULL AS tipo_ubi_t1_ent, NULL AS tipo_ubi_t1_sal,
               NULL AS tipo_ubi_t2_ent, NULL AS tipo_ubi_t2_sal;
    ELSE
        SELECT 
            -- ===== IDs =====
            (SELECT mt.id_marcacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t1_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t1_salida,
            
            (SELECT mt.id_marcacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t2_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t2_salida,
            
            -- ===== TIPO UBICACION =====
            (SELECT mt.tipo_ubicacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t1_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t1_sal,
            
            (SELECT mt.tipo_ubicacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t2_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
                 SELECT a.*,
                        CASE
                            WHEN a.ult_ent IS NULL
                                 THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.num_documento IS NULL
                                 THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                            WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                            ELSE 2
                        END AS turno
                 FROM (
                     SELECT mm.*,
                            MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                                OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                                      ORDER BY mm.fecha_marcacion, mm.id_marcacion
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
                     FROM TblMarcacion mm
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) a
                 LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
                     AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                         WHEN 1 THEN 'DOMINGO'
                         WHEN 2 THEN 'LUNES'
                         WHEN 3 THEN 'MARTES'
                         WHEN 4 THEN 'MIÉRCOLES'
                         WHEN 5 THEN 'JUEVES'
                         WHEN 6 THEN 'VIERNES'
                         WHEN 7 THEN 'SÁBADO'
                     END
                     AND hh.es_activo = 1
                     AND hh.fecha_vigencia_inicio <= p_fecha
                     AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= p_fecha)
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t2_sal;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerMemosEmpleado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerMemosEmpleado`(
    IN p_num_documento INT
)
BEGIN
    SELECT 
        m.id_memo,
        m.num_documento,
        m.fecha_generacion,
        m.fecha_incidente,
        m.archivo_pdf,
        m.observaciones,
        m.fecha_entrega,
        m.recibido,
        m.fecha_recepcion,
        -- Datos del tipo de memo
        tm.codigo,
        tm.nombre as tipo_memo,
        tm.titulo as titulo_memo,
        -- Datos del empleado
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as nombre_completo,
        p.documento_numero,
        p.email,
        -- Datos de quien generó el memo
        CONCAT(
            COALESCE(pg.nombres, ''),
            ' ',
            COALESCE(pg.apellido_paterno, ''),
            ' ',
            COALESCE(pg.apellido_materno, '')
        ) as generado_por_nombre
    FROM TblMemo m
    INNER JOIN TblTipoMemo tm ON m.id_tipo_memo = tm.id_tipo_memo
    INNER JOIN TblPersona p ON m.num_documento = p.num_documento
    LEFT JOIN TblPersona pg ON m.generado_por = pg.num_documento
    WHERE m.num_documento = p_num_documento
    ORDER BY m.fecha_generacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerObrasPorProyecto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerObrasPorProyecto`(
    IN p_id_proyecto INT
)
BEGIN
    SELECT 
        id_obra,
        id_proyecto,
        nombre,
        codigo_obra,
        descripcion
    FROM TblObra
    WHERE id_proyecto = p_id_proyecto
    ORDER BY codigo_obra, nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerPasosFlujoRequerimiento`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerPasosFlujoRequerimiento`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPasosFlujoRequerimiento`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    
    SELECT 
        fac.numero_paso,
        fac.nombre_paso,
        fac.es_requerido,
        
        -- Estado del paso
        COALESCE(ra.estado_aprobacion, 'PENDIENTE') as estado,
        
        -- Información del aprobador
        CONCAT(
            COALESCE(per.nombres, ''), ' ',
            COALESCE(per.apellido_paterno, ''), ' ',
            COALESCE(per.apellido_materno, '')
        ) as nombre_aprobador,
        
        -- Cargo del aprobador - USAR c.nombre
        c.nombre as nombre_cargo,
        
        -- Fechas
        ra.fecha_aprobacion,
        ra.fecha_asignacion,
        
        -- Comentarios
        ra.comentario
        
    FROM TblFlujoAprobacionCargos fac
    LEFT JOIN TblRegistroAprobacion ra ON 
        fac.numero_paso = ra.numero_paso 
        AND fac.id_cargo = ra.id_cargo_aprobador
        AND ra.id_tipo_documento = 2
        AND ra.id_documento_referencia = p_id_requerimiento
    LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
    LEFT JOIN TblUsuario u ON c.id_cargo = u.id_cargo
    LEFT JOIN TblPersona per ON ra.num_documento_aprobador = per.num_documento
    WHERE fac.id_tipo_documento = 2
      AND fac.activo = 1
      AND fac.es_requerido = 1
    ORDER BY fac.numero_paso ASC;
    
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerPasosRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerPasosRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_ObtenerPersonalVacaciones`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerPersonalVacaciones`(
    IN p_anio INT,
    IN p_estado VARCHAR(20)
)
BEGIN
    SELECT 
        u.num_documento,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', IFNULL(p.apellido_materno, '')) AS nombre_completo,
        a.nombre AS area,
        e.nombre AS empresa,
        v.id_vacacion,
        v.fecha_inicio,
        v.fecha_fin,
        v.dias_solicitados AS dias,
        v.tipo_vacacion AS tipo,
        v.estado,
        v.fecha_creacion AS fecha_solicitud
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblVacaciones v ON u.num_documento = v.num_documento
        AND (p_anio IS NULL OR YEAR(v.fecha_inicio) = p_anio)
        AND (p_estado IS NULL OR p_estado = '' OR v.estado = p_estado)
    WHERE u.estado = 'Activo'
    ORDER BY 
        CASE WHEN v.id_vacacion IS NOT NULL THEN 0 ELSE 1 END,
        p.apellido_paterno, p.apellido_materno, p.nombres;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerPresupuestoPDF`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerPresupuestoPDF`(
    IN p_id_presupuesto INT
)
    READS SQL DATA
BEGIN
    SELECT
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        COALESCE(pr.monto_total, 0) AS monto_total,
        COALESCE(pr.gastos_generales, 0) AS gastos_generales,
        COALESCE(pr.utilidad, 0) AS utilidad,
        COALESCE(pr.igv, 0) AS igv,
        COALESCE(pr.supervision_obra, 0) AS supervision_obra,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.num_documento,
        e.nombre AS nombre_empresa,
        e.logo AS empresa_logo,
        o.id_obra,
        o.nombre AS nombre_obra,
        o.codigo_obra,
        pr.id_obra,
        pry.id_proyecto,
        pry.nombre AS nombre_proyecto,
        pry.codigo_proyecto,
        COALESCE(p.nombres, '') AS usuario_nombres,
        CONCAT(COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) AS usuario_apellido,
        COALESCE(p.email, '') AS usuario_email,
        COALESCE(p.celular, '') AS usuario_celular
    FROM `TblPresupuesto` pr
    LEFT JOIN `TblEmpresa` e ON pr.id_empresa = e.id_empresa
    LEFT JOIN `TblObra` o ON pr.id_obra = o.id_obra
    LEFT JOIN `TblProyecto` pry ON o.id_proyecto = pry.id_proyecto
    LEFT JOIN `TblUsuario` u ON pr.num_documento = u.num_documento
    LEFT JOIN `TblPersona` p ON pr.num_documento = p.num_documento
    WHERE pr.id_presupuesto = p_id_presupuesto;

    SELECT
        d.id_detalle,
        d.id_presupuesto,
        d.id_inventario,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion,
        COALESCE(i.nombre, d.descripcion) AS material_nombre,
        COALESCE(um.nombre, 'und') AS unidad_medida,
        COALESCE(c.nombre, 'General') AS categoria
    FROM `TblPresupuestoDetalle` d
    LEFT JOIN `TblInventario` i ON d.id_inventario = i.id_inventario
    LEFT JOIN `TblUnidadMedida` um ON i.id_unidad = um.id_unidad
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
      AND d.tipo_item IN ('MATERIAL', '')
    ORDER BY d.id_detalle ASC;

    SELECT
        d.id_detalle,
        d.id_presupuesto,
        d.id_inventario,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion AS servicio_nombre,
        d.descripcion,
        d.observaciones AS observaciones_detalle
    FROM `TblPresupuestoDetalle` d
    WHERE d.id_presupuesto = p_id_presupuesto
      AND d.tipo_item IN ('SERVICIO', 'PARTIDA')
    ORDER BY d.id_detalle ASC;

END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerProveedorPorRUC`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerProveedorPorRUC`(IN p_ruc VARCHAR(11))
BEGIN
    SELECT
        p.*,
        CONCAT(IFNULL(per.nombres, ''), ' ', IFNULL(per.apellido_paterno, ''), ' ', IFNULL(per.apellido_materno, '')) AS creado_por_nombre,
        CONCAT(IFNULL(per2.nombres, ' '), ' ', IFNULL(per2.apellido_paterno, ''), ' ', IFNULL(per2.apellido_materno, '')) AS actualizado_por_nombre
    FROM TblProveedores p
    LEFT JOIN TblPersona per ON p.creado_por = per.num_documento
    LEFT JOIN TblPersona per2 ON p.actualizado_por = per2.num_documento
    WHERE p.ruc = p_ruc
      AND p.estado != 'ELIMINADO';
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerProyectos`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerProyectos`()
BEGIN
    SELECT 
        id_proyecto,
        codigo_proyecto,
        nombre,
        descripcion,
        fecha_creacion,
        fecha_actualizacion
    FROM TblProyecto
    ORDER BY fecha_creacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimiento`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerRequerimiento`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    SELECT 
        tr.id_requerimiento,
        tr.num_usuario,
        tr.codigo,
        tr.descripcion,
        tr.cantidad,
        tr.estado,
        tr.observaciones,
        tr.id_presupuesto,
        tr.id_tipo_documento,
        tr.fecha_creacion,
        tr.fecha_actualizacion,
        
        -- ✅ CORRECTO: TblRequerimiento -> TblUsuario -> TblPersona
        TRIM(CONCAT(
            COALESCE(p.nombres, ''), 
            ' ', 
            COALESCE(p.apellido_paterno, ''), 
            ' ', 
            COALESCE(p.apellido_materno, '')
        )) as usuario_completo,
        
        pr.numero_presupuesto
    FROM TblRequerimiento tr
    LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_usuario
    LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
    WHERE tr.id_requerimiento = p_id_requerimiento;

END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientoDetalles`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerRequerimientoDetalles`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    SELECT
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_inventario,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.observaciones,
        rd.fecha_creacion,
        COALESCE(i.nombre, '') AS material_nombre,
        COALESCE(i.codigo, '') AS material_codigo,
        COALESCE(um.nombre, '') AS unidad_nombre,
        COALESCE(um.abreviatura, '') AS unidad_abreviatura
    FROM `TblRequerimientoDetalle` rd
    LEFT JOIN `TblInventario` i ON rd.id_inventario = i.id_inventario
    LEFT JOIN `TblUnidadMedida` um ON i.id_unidad = um.id_unidad
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientosConAprobadores`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerRequerimientosConAprobadores`()
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

DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientosGeneral`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerRequerimientosGeneral`()
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

DROP PROCEDURE IF EXISTS `sp_ObtenerUbicacionesUsuario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerUbicacionesUsuario`(
    IN p_num_documento INT
)
BEGIN
    SELECT 
        id_ubicacion,
        num_documento,
        nombre_zona,
        latitud_centro,
        longitud_centro,
        radio_metros,
        direccion_referencia,
        tipo_zona,
        descripcion,
        estado,
        fecha_creacion,
        fecha_modificacion,
        creado_por
    FROM TblUbicacionMarcacion
    WHERE num_documento = p_num_documento
    ORDER BY estado DESC, nombre_zona ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerUsuarioCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerUsuarioCompleto`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerUsuarioCompleto`(
    IN p_num_usuario INT
)
BEGIN
    DECLARE v_num_documento INT;
    
    SELECT num_documento INTO v_num_documento
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    SELECT 
        u.num_usuario,
        u.num_documento,
        u.usuario,
        u.id_cargo,
        u.id_empresa,
        u.estado as usuario_estado,
        
        p.documento_numero,
        p.tipo_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        p.celular,
        p.celular_referencia,
        p.id_distrito,
        p.fecha_nacimiento,
        p.genero,
        p.direccion,
        
        c.nombre as cargo_nombre,
        e.nombre as empresa_nombre,
        a.nombre as area_nombre,
        d.nombre as distrito_nombre,
        pr.nombre as provincia_nombre,
        dept.nombre as departamento_nombre,
        
        p.estado as persona_estado,
        p.fecha_creacion
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblDistrito d ON p.id_distrito = d.id_distrito
    LEFT JOIN TblProvincia pr ON d.id_provincia = pr.id_provincia
    LEFT JOIN TblDepartamento dept ON pr.id_departamento = dept.id_departamento
    WHERE u.num_usuario = p_num_usuario;
    
    SELECT 
        id_horario,
        num_documento,
        dia_semana,
        hora_entrada,
        hora_salida,
        hora_entrada2,
        hora_salida2,
        es_activo,
        estado,
        observacion,
        fecha_creacion
    FROM TblHorarioTrabajo
    WHERE num_documento = v_num_documento
    ORDER BY 
        CASE dia_semana
            WHEN 'LUNES' THEN 1
            WHEN 'MARTES' THEN 2
            WHEN 'MIÉRCOLES' THEN 3
            WHEN 'JUEVES' THEN 4
            WHEN 'VIERNES' THEN 5
            WHEN 'SÁBADO' THEN 6
            WHEN 'DOMINGO' THEN 7
        END;
    
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerUsuarios`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerUsuarios`()
BEGIN
    SELECT 
        u.num_usuario,
        u.num_documento,
        p.documento_numero,
        p.tipo_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        p.celular,
        p.celular_referencia,
        p.fecha_nacimiento,
        p.genero,
        p.direccion,
        u.usuario,
        c.nombre AS cargo,
        a.nombre AS area,
        u.estado,
        u.intentos_fallidos,
        u.fecha_ultimo_login,
        u.fecha_creacion,
        u.fecha_actualizacion,
        u.id_cargo,
        u.id_empresa,
        e.nombre AS empresa,        -- NUEVO: nombre legible de la empresa
        c.id_area
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa  -- NUEVO: JOIN con empresa
    ORDER BY u.fecha_creacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerUsuariosAccesos`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerUsuariosAccesos`()
BEGIN
    SELECT DISTINCT
        u.num_usuario,
        u.num_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', COALESCE(p.apellido_materno, '')) as nombre_completo,
        u.usuario,
        u.estado,
        c.nombre as cargo_nombre,
        a.id_area,
        a.nombre as area_nombre,
        u.id_empresa,
        e.nombre as empresa_nombre,
        COUNT(DISTINCT ua.id_menu) as total_menus_acceso,
        COUNT(DISTINCT ua.id_submenu) as total_submenus_acceso
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblUsuarioAccesos ua ON u.num_documento = ua.num_documento AND ua.estado = 'ACTIVO' AND ua.id_submenu IS NOT NULL
    WHERE u.estado = 'ACTIVO'
    GROUP BY u.num_usuario, u.num_documento, p.nombres, p.apellido_paterno, p.apellido_materno,
             u.usuario, u.estado, c.nombre, a.id_area, a.nombre, e.nombre, u.id_empresa
    ORDER BY p.nombres, p.apellido_paterno;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerVacaciones`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerVacaciones`(
    IN p_estado VARCHAR(20),
    IN p_anio YEAR,
    IN p_busqueda VARCHAR(100)
)
BEGIN
    SELECT 
        v.id_vacacion,
        v.num_documento,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', IFNULL(p.apellido_materno, '')) AS empleado,
        a.nombre AS area,
        v.fecha_inicio,
        v.fecha_fin,
        v.dias_solicitados AS dias,
        v.tipo_vacacion AS tipo,
        v.estado,
        v.observaciones,
        v.motivo_rechazo,
        v.fecha_creacion AS fecha_solicitud,
        CONCAT(pc.nombres, ' ', pc.apellido_paterno) AS creado_por_nombre,
        v.aprobado_por,
        CONCAT(pa.nombres, ' ', pa.apellido_paterno) AS aprobado_por_nombre,
        v.fecha_aprobacion
    FROM TblVacaciones v
    INNER JOIN TblUsuario u ON v.num_documento = u.num_documento
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblUsuario uc ON v.creado_por = uc.num_documento
    LEFT JOIN TblPersona pc ON uc.num_documento = pc.num_documento
    LEFT JOIN TblUsuario ua ON v.aprobado_por = ua.num_documento
    LEFT JOIN TblPersona pa ON ua.num_documento = pa.num_documento
    WHERE (p_estado IS NULL OR v.estado = p_estado)
      AND (p_anio IS NULL OR YEAR(v.fecha_inicio) = p_anio)
      AND (p_busqueda IS NULL OR p_busqueda = ''
           OR p.nombres LIKE CONCAT('%', p_busqueda, '%')
           OR p.apellido_paterno LIKE CONCAT('%', p_busqueda, '%')
           OR p.apellido_materno LIKE CONCAT('%', p_busqueda, '%'))
    ORDER BY v.fecha_creacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerVersionActual`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerVersionActual`(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        COALESCE(MAX(numero_version), 0) as version_actual,
        (SELECT COUNT(*) 
         FROM TblPresupuestoVersionHistorial 
         WHERE id_presupuesto = p_id_presupuesto
        ) as total_versiones
    FROM TblPresupuestoVersionHistorial
    WHERE id_presupuesto = p_id_presupuesto;
END$$

DROP PROCEDURE IF EXISTS `sp_ObtenerVersionPresupuesto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerVersionPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_numero_version INT
)
BEGIN
    -- Datos principales de la versión
    SELECT 
        vh.*,
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as creado_por_nombre
    FROM TblPresupuestoVersionHistorial vh
    LEFT JOIN TblPersona p ON vh.creado_por = p.num_documento
    WHERE vh.id_presupuesto = p_id_presupuesto 
      AND vh.numero_version = p_numero_version
    LIMIT 1;
    
    -- Detalle de partidas de la versión
    SELECT 
        vdh.*
    FROM TblPresupuestoVersionDetalleHistorial vdh
    INNER JOIN TblPresupuestoVersionHistorial vh ON vdh.id_version = vh.id_version
    WHERE vh.id_presupuesto = p_id_presupuesto 
      AND vh.numero_version = p_numero_version
    ORDER BY vdh.orden;
END$$

DROP PROCEDURE IF EXISTS `sp_obtener_asignados_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_obtener_asignados_personal`(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    SELECT
        epd.id_entrega_detalle,
        epd.id_entrega,
        epd.id_inventario,
        i.codigo,
        i.nombre,
        epd.cantidad,
        epd.serie,
        epd.estado_bien,
        u.abreviatura AS unidad,
        ep.codigo_entrega,
        ep.fecha_entrega
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
    WHERE ep.id_personal = p_id_personal
      AND ep.estado = 'ACTIVO'
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_obtener_tabla_seccion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_obtener_tabla_seccion`(
    IN  p_tipo_inventario VARCHAR(20),
    OUT p_tabla VARCHAR(64)
)
    READS SQL DATA
BEGIN
    SET p_tabla = NULL;
    SELECT tc.TABLE_NAME INTO p_tabla
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.CHECK_CONSTRAINTS cc
      ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    WHERE tc.TABLE_SCHEMA = DATABASE()
      AND tc.CONSTRAINT_TYPE = 'CHECK'
      AND tc.TABLE_NAME LIKE 'TblInventario%'
      AND LOCATE('tipo_inventario', CONVERT(cc.CHECK_CLAUSE USING utf8mb4)) > 0
      AND LOCATE(CONCAT('''', CONVERT(p_tipo_inventario USING utf8mb4), ''''),
                 REPLACE(CONVERT(cc.CHECK_CLAUSE USING utf8mb4), CHAR(92 USING utf8mb4), '')) > 0
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_RechazarPresupuesto_Progresivo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RechazarPresupuesto_Progresivo`(
-- CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RechazarPresupuesto_Progresivo`(
    IN p_id_presupuesto INT,
    IN p_num_documento_rechazador INT,
    IN p_motivo_rechazo VARCHAR(500),
    IN p_id_tipo_documento INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_paso_actual INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_rechazo_existe INT;
    DECLARE v_id_cargo INT;
    
    -- PASO 1: VALIDACIONES BÁSICAS
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto no encontrado';
    END IF;
    
    -- Obtener estado actual
    SELECT estado INTO v_estado_actual
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Verificar que está en estado PENDIENTE o APROBADO (puede ser rechazado en cualquier momento)
    IF v_estado_actual = 'RECHAZADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto ya fue rechazado. No puede rechazarse nuevamente.';
    END IF;
    
    IF v_estado_actual = 'ELIMINADO' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto eliminado. No puede rechazarse.';
    END IF;
    
    -- PASO 2: OBTENER PASO ACTUAL (EL QUE ESTÁ PENDIENTE O ÚLTIMO APROBADO)
    -- Buscar el último paso aprobado
    SELECT MAX(numero_paso) INTO v_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND estado_aprobacion = 'APROBADO';
    
    -- Si no hay ningún paso aprobado, es el Paso 1
    IF v_paso_actual IS NULL THEN
        SET v_paso_actual = 1;
    ELSE
        -- Si hay pasos aprobados, el rechazo es en el siguiente paso
        SET v_paso_actual = v_paso_actual + 1;
        
        -- Verificar que ese siguiente paso existe
        IF NOT EXISTS (
            SELECT 1 FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_paso_actual
        ) THEN
            -- Si no existe siguiente paso, fue rechazado el último paso aprobado
            SET v_paso_actual = (SELECT MAX(numero_paso) 
                                 FROM TblRegistroAprobacion
                                 WHERE id_documento_referencia = p_id_presupuesto
                                 AND id_tipo_documento = p_id_tipo_documento
                                 AND estado_aprobacion = 'APROBADO');
        END IF;
    END IF;
    
    -- Obtener cargo de este paso para auditoría
    SELECT id_cargo INTO v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_paso_actual;
    
    -- PASO 3: REGISTRAR EL RECHAZO EN TblRegistroAprobacion
    -- Verificar si ya existe registro para este paso
    SELECT COUNT(*) INTO v_registro_rechazo_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_paso_actual;
    
    IF v_registro_rechazo_existe = 0 THEN
        -- Crear nuevo registro de rechazo
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento,
            id_documento_referencia,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            comentario,
            fecha_aprobacion
        ) VALUES (
            p_id_tipo_documento,
            p_id_presupuesto,
            v_paso_actual,
            v_id_cargo,
            p_num_documento_rechazador,
            'RECHAZADO',
            p_motivo_rechazo,
            NOW()
        );
    ELSE
        -- Actualizar registro existente
        UPDATE TblRegistroAprobacion
        SET 
            num_documento_aprobador = p_num_documento_rechazador,
            estado_aprobacion = 'RECHAZADO',
            comentario = p_motivo_rechazo,
            fecha_aprobacion = NOW()
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = p_id_tipo_documento
            AND numero_paso = v_paso_actual;
    END IF;
    
    -- PASO 4: CAMBIAR ESTADO DE PRESUPUESTO A RECHAZADO
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 5: ELIMINAR REGISTROS DE PASOS POSTERIORES (CLEANUP)
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso > v_paso_actual
    AND estado_aprobacion = 'PENDIENTE';
    
    -- RESPUESTA AL USUARIO
    SET v_mensaje = CONCAT(
        '❌ Presupuesto RECHAZADO en Paso ', v_paso_actual, '. ',
        'Motivo: ', COALESCE(p_motivo_rechazo, 'Sin especificar'), '. ',
        'El presupuesto vuelve a estado PENDIENTE para re-envío.'
    );
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_paso_actual AS paso_rechazado;

END$$

DROP PROCEDURE IF EXISTS `sp_RechazarRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RechazarRequerimientoAdministrativo`(
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

DROP PROCEDURE IF EXISTS `sp_RechazarVacacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RechazarVacacion`(
    IN p_id_vacacion INT,
    IN p_aprobado_por INT,
    IN p_motivo TEXT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_estado VARCHAR(20);
    
    SELECT estado INTO v_estado
    FROM TblVacaciones
    WHERE id_vacacion = p_id_vacacion;
    
    IF v_estado IS NULL THEN
        SET p_mensaje = 'La solicitud no existe';
        LEAVE proc_label;
    END IF;
    
    IF v_estado != 'PENDIENTE' THEN
        SET p_mensaje = CONCAT('No se puede rechazar una solicitud en estado: ', v_estado);
        LEAVE proc_label;
    END IF;
    
    UPDATE TblVacaciones
    SET estado = 'RECHAZADO',
        aprobado_por = p_aprobado_por,
        fecha_aprobacion = NOW(),
        motivo_rechazo = p_motivo
    WHERE id_vacacion = p_id_vacacion;
    
    SET p_mensaje = 'Vacacion rechazada';
    
END$$

DROP PROCEDURE IF EXISTS `sp_RegistrarMarcacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RegistrarMarcacion`(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_num_usuario INT;
    DECLARE v_ultima_marcacion VARCHAR(20);
    DECLARE v_fecha_hora_actual DATETIME;
    
    -- Inicializar variables
    SET v_fecha_hora_actual = NOW();
    SET p_id_marcacion = 0;
    
    -- Obtener num_usuario desde TblUsuario
    SELECT num_usuario INTO v_num_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    -- Validar que el usuario existe
    IF v_num_usuario IS NULL THEN
        SET p_mensaje = 'Usuario no existe';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Obtener la última marcación del día
    SELECT tipo_marcacion INTO v_ultima_marcacion
    FROM TblMarcacion
    WHERE num_documento = p_num_documento
        AND DATE(fecha_marcacion) = CURDATE()
    ORDER BY fecha_marcacion DESC
    LIMIT 1;
    
    -- Validar secuencia de marcación
    IF p_tipo_marcacion = 'ENTRADA' THEN
        IF v_ultima_marcacion = 'ENTRADA' THEN
            SET p_mensaje = 'Ya tienes una entrada registrada. Debes marcar salida primero.';
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Ya tienes una entrada registrada. Debes marcar salida primero.';
        END IF;
    ELSE -- SALIDA
        IF v_ultima_marcacion IS NULL THEN
            SET p_mensaje = 'No tienes una entrada registrada. Debes marcar entrada primero.';
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'No tienes una entrada registrada. Debes marcar entrada primero.';
        ELSEIF v_ultima_marcacion = 'SALIDA' THEN
            SET p_mensaje = 'Ya tienes una salida registrada. Debes marcar entrada primero.';
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Ya tienes una salida registrada. Debes marcar entrada primero.';
        END IF;
    END IF;
    
    -- Registrar la marcación
    INSERT INTO TblMarcacion (
        num_usuario,
        num_documento,
        tipo_marcacion,
        fecha_marcacion,
        latitud,
        longitud,
        `precision`,
        foto_base64,
        dispositivo,
        observacion,
        estado
    ) VALUES (
        v_num_usuario,
        p_num_documento,
        p_tipo_marcacion,
        v_fecha_hora_actual,
        NULL,  -- latitud (se puede agregar después con GPS)
        NULL,  -- longitud
        NULL,  -- precision
        NULL,  -- foto_base64 (se puede agregar después con cámara)
        'WEB',  -- dispositivo
        NULL,  -- observacion
        'Registrado'  -- estado
    );
    
    SET p_id_marcacion = LAST_INSERT_ID();
    
    IF p_tipo_marcacion = 'ENTRADA' THEN
        SET p_mensaje = CONCAT('Entrada registrada exitosamente a las ', TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s'));
    ELSE
        SET p_mensaje = CONCAT('Salida registrada exitosamente a las ', TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s'));
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `sp_RegistrarMarcacionCompleta`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RegistrarMarcacionCompleta`(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    IN p_latitud DECIMAL(10,8),
    IN p_longitud DECIMAL(11,8),
    IN p_precision DECIMAL(6,2),
    IN p_foto_base64 LONGTEXT,
    IN p_justificacion TEXT,
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_num_usuario INT;
    DECLARE v_ultima_marcacion VARCHAR(20);
    DECLARE v_fecha_hora_actual DATETIME;
    DECLARE v_tiene_ubicaciones INT DEFAULT 0;
    DECLARE v_ubicacion_valida INT DEFAULT 0;
    DECLARE v_nombre_zona VARCHAR(200);
    DECLARE v_distancia_metros DECIMAL(10, 2);
    DECLARE v_radio_permitido INT;
    DECLARE v_estado_calculado VARCHAR(20);
    DECLARE v_hora_entrada TIME;
    DECLARE v_hora_limite_puntual TIME DEFAULT '08:05:00';
    DECLARE v_hora_limite_tarde TIME DEFAULT '08:30:00';
    
    SET v_fecha_hora_actual = NOW();
    SET p_id_marcacion = 0;
    
    -- Validar usuario
    SELECT num_usuario INTO v_num_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_num_usuario IS NULL THEN
        SET p_mensaje = 'Usuario no existe';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar GPS (solo si no hay justificación)
    IF p_justificacion IS NULL OR p_justificacion = '' THEN
        SELECT COUNT(*) INTO v_tiene_ubicaciones
        FROM TblUbicacionMarcacion
        WHERE num_documento = p_num_documento AND estado = 'ACTIVO';
        
        IF v_tiene_ubicaciones > 0 THEN
            SELECT 
                id_ubicacion, nombre_zona, radio_metros,
                (6371000 * ACOS(LEAST(1.0, 
                    COS(RADIANS(p_latitud)) * COS(RADIANS(latitud_centro)) * 
                    COS(RADIANS(longitud_centro) - RADIANS(p_longitud)) + 
                    SIN(RADIANS(p_latitud)) * SIN(RADIANS(latitud_centro))
                ))) AS distancia_metros
            INTO v_ubicacion_valida, v_nombre_zona, v_radio_permitido, v_distancia_metros
            FROM TblUbicacionMarcacion
            WHERE num_documento = p_num_documento AND estado = 'ACTIVO'
            HAVING distancia_metros <= radio_metros
            ORDER BY distancia_metros ASC LIMIT 1;
            
            IF v_ubicacion_valida IS NULL OR v_ubicacion_valida = 0 THEN
                SET p_id_marcacion = 0;
                SET p_mensaje = 'FUERA DE RANGO';
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fuera del rango de marcación permitido';
            END IF;
        END IF;
    END IF;
    
    -- ============================================
    -- CORRECCIÓN: Validar secuencia ENTRADA/SALIDA
    -- ============================================
    SELECT tipo_marcacion INTO v_ultima_marcacion
    FROM TblMarcacion
    WHERE num_documento = p_num_documento
      AND DATE(fecha_marcacion) = DATE(v_fecha_hora_actual)
    ORDER BY fecha_marcacion DESC LIMIT 1;
    
    IF p_tipo_marcacion = 'ENTRADA' THEN
        IF v_ultima_marcacion = 'ENTRADA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una entrada registrada. Debes marcar salida primero.';
        END IF;
    ELSE
        IF v_ultima_marcacion IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes una entrada registrada.';
        ELSEIF v_ultima_marcacion = 'SALIDA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una salida registrada.';
        END IF;
    END IF;
    
    -- Calcular estado
    SET v_estado_calculado = 'Registrado';
    IF p_tipo_marcacion = 'ENTRADA' THEN
        SET v_hora_entrada = TIME(v_fecha_hora_actual);
        IF v_hora_entrada <= v_hora_limite_puntual THEN
            SET v_estado_calculado = 'ASISTIO';
        ELSEIF v_hora_entrada <= v_hora_limite_tarde THEN
            SET v_estado_calculado = 'TARDE';
        ELSE
            SET v_estado_calculado = 'ASISTIO +5';
        END IF;
    END IF;
    
    -- INSERT
    INSERT INTO TblMarcacion (
        num_usuario,
        num_documento,
        tipo_marcacion,
        fecha_marcacion,
        latitud,
        longitud,
        `precision`,
        tipo_ubicacion,
        foto_base64,
        justificacion,
        dispositivo,
        estado
    ) VALUES (
        v_num_usuario,
        p_num_documento,
        p_tipo_marcacion,
        v_fecha_hora_actual,
      p_latitud,
p_longitud,
p_precision,
        IF(p_justificacion IS NOT NULL AND p_justificacion != '', 'CAMPO', 'OFICINA'),
        p_foto_base64,
        p_justificacion,
        'WEB',
        v_estado_calculado
    );
    
    SET p_id_marcacion = LAST_INSERT_ID();
    
    -- Mensaje
    IF p_justificacion IS NOT NULL AND p_justificacion != '' THEN
        SET p_mensaje = CONCAT(p_tipo_marcacion, ' registrada - JUSTIFICADA');
    ELSE
        SET p_mensaje = CONCAT(p_tipo_marcacion, ' registrada OK');
    END IF;
    
END$$

DROP PROCEDURE IF EXISTS `sp_RegistrarMemo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RegistrarMemo`(
    IN p_num_documento INT,
    IN p_codigo_tipo_memo VARCHAR(20),
    IN p_generado_por INT,
    IN p_archivo_pdf VARCHAR(255),
    IN p_observaciones TEXT,
    IN p_fecha_incidente DATE
)
BEGIN
    DECLARE v_id_tipo_memo INT;
    
    -- Obtener el ID del tipo de memo
    SELECT id_tipo_memo INTO v_id_tipo_memo
    FROM TblTipoMemo
    WHERE codigo = p_codigo_tipo_memo
    AND activo = 1
    LIMIT 1;
    
    -- Insertar el registro del memo
    INSERT INTO TblMemo (
        num_documento,
        fecha_incidente,
        id_tipo_memo,
        generado_por,
        archivo_pdf,
        observaciones
    ) VALUES (
        p_num_documento,
        p_fecha_incidente,
        v_id_tipo_memo,
        p_generado_por,
        p_archivo_pdf,
        p_observaciones
    );
    
    -- Retornar el ID del memo generado
    SELECT LAST_INSERT_ID() as id_memo;
END$$

DROP PROCEDURE IF EXISTS `sp_registrar_movimiento_stock`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_registrar_movimiento_stock`(
    IN  p_id_inventario    INT,
    IN  p_tipo_movimiento  VARCHAR(20),
    IN  p_cantidad         DECIMAL(10,2),
    IN  p_id_almacen       INT,
    IN  p_tipo_documento   VARCHAR(30),
    IN  p_id_documento     INT,
    IN  p_motivo           TEXT,
    IN  p_observaciones    TEXT,
    IN  p_realizado_por    INT,
    OUT p_success          BOOLEAN,
    OUT p_message          VARCHAR(255),
    OUT p_nuevo_stock      DECIMAL(10,2),
    OUT p_id_movimiento    INT
)
    MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_stock     DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_nuevo     DECIMAL(10,2);
    DECLARE v_almacen   INT;
    DECLARE v_estado    VARCHAR(20);
    DECLARE v_tipo_inv  VARCHAR(20);
    DECLARE v_nombre    VARCHAR(200);
    DECLARE v_costo     DECIMAL(10,2);
    DECLARE v_prefijo   VARCHAR(5);
    DECLARE v_obs       TEXT;

    SET p_success = FALSE;
    SET p_nuevo_stock = NULL;
    SET p_id_movimiento = NULL;

    IF p_tipo_movimiento NOT IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION') THEN
        SET p_message = 'Tipo de movimiento inválido (ENTRADA, SALIDA, AJUSTE o DEVOLUCION)';
        LEAVE proc;
    END IF;

    IF p_cantidad IS NULL OR p_cantidad < 0
       OR (p_cantidad = 0 AND p_tipo_movimiento <> 'AJUSTE') THEN
        SET p_message = 'La cantidad debe ser mayor que cero';
        LEAVE proc;
    END IF;

    -- Bloquea el ítem hasta que termine la transacción del llamador
    SELECT stock_actual, id_almacen, estado, tipo_inventario, nombre, COALESCE(precio_compra, 0)
    INTO v_stock, v_almacen, v_estado, v_tipo_inv, v_nombre, v_costo
    FROM `TblInventario`
    WHERE id_inventario = p_id_inventario
    FOR UPDATE;

    IF v_nombre IS NULL THEN
        SET p_message = 'Ítem no encontrado';
        LEAVE proc;
    END IF;

    IF v_estado <> 'ACTIVO' THEN
        SET p_message = CONCAT('El ítem "', v_nombre, '" está inactivo');
        LEAVE proc;
    END IF;

    IF v_tipo_inv IN ('SERVICIO', 'PARTIDA') THEN
        SET p_message = 'Los servicios y partidas no manejan stock';
        LEAVE proc;
    END IF;

    SET v_stock = COALESCE(v_stock, 0);
    SET v_almacen = COALESCE(p_id_almacen, v_almacen);

    CASE p_tipo_movimiento
        WHEN 'ENTRADA'    THEN SET v_nuevo = v_stock + p_cantidad; SET v_prefijo = 'ENT';
        WHEN 'DEVOLUCION' THEN SET v_nuevo = v_stock + p_cantidad; SET v_prefijo = 'DEV';
        WHEN 'SALIDA'     THEN SET v_nuevo = v_stock - p_cantidad; SET v_prefijo = 'SAL';
        WHEN 'AJUSTE'     THEN SET v_nuevo = p_cantidad;           SET v_prefijo = 'AJU';
    END CASE;

    IF v_nuevo < 0 THEN
        SET p_message = CONCAT('Stock insuficiente de "', v_nombre, '". Disponible: ', v_stock);
        SET p_nuevo_stock = v_stock;
        LEAVE proc;
    END IF;

    SET v_obs = NULLIF(TRIM(p_observaciones), '');
    IF p_tipo_movimiento = 'AJUSTE' THEN
        SET v_obs = CONCAT_WS(' · ', CONCAT('Stock anterior: ', v_stock), v_obs);
    END IF;

    UPDATE `TblInventario`
    SET stock_actual = v_nuevo,
        fecha_actualizacion = NOW()
    WHERE id_inventario = p_id_inventario;

    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_origen, id_almacen_destino,
        tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, observaciones,
        fecha_movimiento, realizado_por
    ) VALUES (
        NULL, p_id_inventario, p_tipo_movimiento, p_cantidad,
        IF(p_tipo_movimiento = 'SALIDA', v_almacen, NULL),
        IF(p_tipo_movimiento = 'SALIDA', NULL, v_almacen),
        COALESCE(p_tipo_documento, 'AJUSTE_INVENTARIO'), p_id_documento,
        v_costo, p_cantidad * v_costo, NULLIF(TRIM(p_motivo), ''), v_obs,
        NOW(), p_realizado_por
    );

    SET p_id_movimiento = LAST_INSERT_ID();

    -- Código único derivado del ID del movimiento
    UPDATE `TblMovimientoInventario`
    SET codigo_movimiento = CONCAT(v_prefijo, '-', LPAD(p_id_movimiento, GREATEST(6, CHAR_LENGTH(p_id_movimiento)), '0'))
    WHERE id_movimiento = p_id_movimiento;

    SET p_success = TRUE;
    SET p_nuevo_stock = v_nuevo;
    SET p_message = CONCAT('Movimiento registrado correctamente. Nuevo stock: ', v_nuevo);
END$$

DROP PROCEDURE IF EXISTS `sp_ReiniciarFlujoAprobacion`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ReiniciarFlujoAprobacion`(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_documento_existe INT DEFAULT 0;
    DECLARE v_pasos_creados INT DEFAULT 0;
    DECLARE v_paso INT;
    DECLARE v_id_cargo INT;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE cursor_pasos CURSOR FOR
        SELECT numero_paso, id_cargo
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND activo = 1
        AND es_requerido = 1
        ORDER BY numero_paso ASC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- PASO 1: Validar que el documento existe
    IF p_id_tipo_documento = 1 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblPresupuesto WHERE id_presupuesto = p_id_documento;
    ELSEIF p_id_tipo_documento = 2 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblRequerimiento WHERE id_requerimiento = p_id_documento;
    END IF;
    
    IF v_documento_existe = 0 THEN
        SELECT 'ERROR' AS resultado, 'Documento no encontrado' AS mensaje;
    ELSE
        -- PASO 2: Cambiar estado a PENDIENTE
        IF p_id_tipo_documento = 1 THEN
            UPDATE TblPresupuesto
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_presupuesto = p_id_documento;
        ELSEIF p_id_tipo_documento = 2 THEN
            UPDATE TblRequerimiento
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_requerimiento = p_id_documento;
        END IF;
        
        -- PASO 3: Limpiar registros anteriores de aprobación
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND id_documento_referencia = p_id_documento;
        
        -- PASO 4: Crear registros PENDIENTE para TODOS los pasos del flujo
        -- SIN num_documento_aprobador (NULL) para que pueda ser registrado después
        OPEN cursor_pasos;
        
        loop_pasos: LOOP
            FETCH cursor_pasos INTO v_paso, v_id_cargo;
            IF done THEN
                LEAVE loop_pasos;
            END IF;
            
            INSERT INTO TblRegistroAprobacion (
                id_tipo_documento,
                id_documento_referencia,
                numero_paso,
                id_cargo_aprobador,
                num_documento_aprobador,
                estado_aprobacion,
                fecha_asignacion
            ) VALUES (
                p_id_tipo_documento,
                p_id_documento,
                v_paso,
                v_id_cargo,
                NULL,
                'PENDIENTE',
                NOW()
            );
            
            SET v_pasos_creados = v_pasos_creados + 1;
        END LOOP loop_pasos;
        
        CLOSE cursor_pasos;
        
        SELECT 'OK' AS resultado, 
               CONCAT('Flujo reiniciado: ', v_pasos_creados, ' pasos creados') AS mensaje,
               v_pasos_creados AS pasos_creados;
    END IF;

END$$

DROP PROCEDURE IF EXISTS `sp_ReporteMarcacionesTodos`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ReporteMarcacionesTodos`(
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE,
    IN p_num_documento VARCHAR(20)
)
BEGIN
    SELECT 
        m.id_marcacion,
        m.num_documento,
        CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as nombre_completo,
        p.email,
        m.tipo_marcacion,
        m.fecha_marcacion,
        DATE(m.fecha_marcacion) as fecha,
        TIME(m.fecha_marcacion) as hora,
        m.latitud,
        m.longitud,
        m.precision,
        m.dispositivo,
        m.observacion,
        CASE WHEN m.foto_base64 IS NOT NULL AND m.foto_base64 != '' THEN 1 ELSE 0 END as tiene_foto,
         m.justificacion
    FROM TblMarcacion m
    INNER JOIN TblUsuario u ON m.num_documento = u.num_documento
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE 1=1
        AND (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
        AND (p_num_documento IS NULL OR p_num_documento = '' OR m.num_documento = p_num_documento)
    ORDER BY m.fecha_marcacion DESC;
END$$

DROP PROCEDURE IF EXISTS `sp_ReportePresupuestos`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ReportePresupuestos`()
BEGIN
    /*
     * Reporte completo de presupuestos con información de aprobación/rechazo
     * Incluye: fecha_actualizacion antes del número de presupuesto
     */
    
    SELECT 
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.estado,
        pr.monto,
        pr.fecha_actualizacion,
        o.nombre as nombre_obra,
        p.nombre as nombre_proyecto,
        CONCAT(
            COALESCE(per.nombres, ''),
            ' ',
            COALESCE(per.apellido_paterno, ''),
            ' ',
            COALESCE(per.apellido_materno, '')
        ) as creado_por,
        MAX(CONCAT(
            COALESCE(per_aprobador.nombres, ''),
            ' ',
            COALESCE(per_aprobador.apellido_paterno, ''),
            ' ',
            COALESCE(per_aprobador.apellido_materno, '')
        )) as aprobado_rechazado_por,
        MAX(CASE 
            WHEN pr.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
            ELSE NULL
        END) as comentario_rechazo
    FROM TblPresupuesto pr
    LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
    LEFT JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
    LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
    LEFT JOIN TblRegistroAprobacion ra ON 
        pr.id_presupuesto = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 1
        AND ra.estado_aprobacion = 'APROBADO'
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
    WHERE pr.estado != 'ELIMINADO'
    GROUP BY 
        pr.id_presupuesto, 
        pr.numero_presupuesto, 
        pr.estado, 
        pr.monto, 
        pr.fecha_actualizacion, 
        o.nombre, 
        p.nombre,
        per.nombres,
        per.apellido_paterno,
        per.apellido_materno
    ORDER BY pr.fecha_creacion DESC;
    
END$$

DROP PROCEDURE IF EXISTS `sp_reporte_asistencia_automatica`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_reporte_asistencia_automatica`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_num_usuario INT
)
BEGIN
    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS f WHERE p_fecha_inicio <= p_fecha_fin
        UNION ALL
        SELECT f + INTERVAL 1 DAY FROM fechas WHERE f < p_fecha_fin
    ),
    grid AS (
        -- Persona-dia CON horario activo ese dia.
        SELECT DISTINCT h.num_documento AS gdoc, fe.f AS gf
        FROM TblHorarioTrabajo h
        JOIN fechas fe
          ON UPPER(h.dia_semana) = CASE DAYOFWEEK(fe.f)
                 WHEN 1 THEN 'DOMINGO'
                 WHEN 2 THEN 'LUNES'
                 WHEN 3 THEN 'MARTES'
                 WHEN 4 THEN 'MIÉRCOLES'
                 WHEN 5 THEN 'JUEVES'
                 WHEN 6 THEN 'VIERNES'
                 WHEN 7 THEN 'SÁBADO'
             END
        WHERE h.es_activo = 1
          AND h.fecha_vigencia_inicio <= fe.f
          AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= fe.f)
        UNION
        -- Persona-dia CON marcas: conserva filas sin horario.
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    calendario AS (
        SELECT g.gdoc, g.gf,
               h.hora_entrada, h.hora_salida,
               h.hora_entrada2, h.hora_salida2
        FROM grid g
        LEFT JOIN TblHorarioTrabajo h
          ON h.num_documento = g.gdoc
         AND UPPER(h.dia_semana) = CASE DAYOFWEEK(g.gf)
                WHEN 1 THEN 'DOMINGO'
                WHEN 2 THEN 'LUNES'
                WHEN 3 THEN 'MARTES'
                WHEN 4 THEN 'MIÉRCOLES'
                WHEN 5 THEN 'JUEVES'
                WHEN 6 THEN 'VIERNES'
                WHEN 7 THEN 'SÁBADO'
             END
         AND h.es_activo = 1
         AND h.fecha_vigencia_inicio <= g.gf
         AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= g.gf)
    ),
    marcas_base AS (
        SELECT mm.id_marcacion,
               mm.num_documento,
               c.gf,
               TIME(mm.fecha_marcacion) AS hora,
               mm.tipo_marcacion,
               mm.tipo_ubicacion,
               mm.justificacion,
               c.hora_entrada,
               c.hora_salida,
               c.hora_entrada2,
               c.hora_salida2
        FROM TblMarcacion mm
        JOIN calendario c
          ON c.gdoc = mm.num_documento
         AND c.gf = DATE(mm.fecha_marcacion)
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    candidatos AS (
        -- Turno por hora esperada mas cercana del mismo tipo.
        SELECT mb.*,
               CASE
                    WHEN mb.tipo_marcacion = 'ENTRADA' THEN
                        CASE
                            -- Sin horario: se conserva la marca para poder
                            -- mostrar SIN HORARIO; el corte informativo es 14:00.
                            WHEN mb.hora_entrada IS NULL AND mb.hora_entrada2 IS NULL THEN
                                CASE WHEN mb.hora <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN mb.hora_entrada2 IS NULL THEN 1
                            WHEN mb.hora_entrada IS NULL THEN 2
                            WHEN ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_entrada))
                                 <= ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_entrada2)) THEN 1
                            ELSE 2
                        END
                    WHEN mb.tipo_marcacion = 'SALIDA' THEN
                        CASE
                            WHEN mb.hora_salida IS NULL AND mb.hora_salida2 IS NULL THEN
                                CASE WHEN mb.hora <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN mb.hora_salida2 IS NULL THEN 1
                            WHEN mb.hora_salida IS NULL THEN 2
                            WHEN ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_salida))
                                 <= ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_salida2)) THEN 1
                            ELSE 2
                        END
                END AS turno
        FROM marcas_base mb
    ),
    entradas AS (
        SELECT c.num_documento, c.gf, c.turno, c.hora,
               c.tipo_ubicacion, c.justificacion,
               CASE WHEN c.turno = 1 THEN c.hora_entrada
                    ELSE c.hora_entrada2 END AS esperada
        FROM candidatos c
        WHERE c.tipo_marcacion = 'ENTRADA'
          AND c.turno IS NOT NULL
    ),
    salidas AS (
        SELECT c.num_documento, c.gf, c.turno, c.hora,
               c.tipo_ubicacion, c.justificacion,
               CASE WHEN c.turno = 1 THEN c.hora_salida
                    ELSE c.hora_salida2 END AS esperada
        FROM candidatos c
        WHERE c.tipo_marcacion = 'SALIDA'
          AND c.turno IS NOT NULL
    ),
    entradas_rank AS (
        -- Preferimos una entrada dentro de +/-2 h de la esperada.
        -- Si hay varias, primero la que esta en/hacia adelante de
        -- la hora esperada (evita tomar una marca de refrigerio).
        SELECT e.*,
               ROW_NUMBER() OVER (
                   PARTITION BY e.num_documento, e.gf, e.turno
                   ORDER BY
                       CASE WHEN e.esperada IS NULL THEN 1 ELSE 0 END,
                       CASE WHEN e.esperada IS NULL THEN 0
                            WHEN ABS(TIMESTAMPDIFF(SECOND, e.hora, e.esperada)) <= 7200 THEN 0
                            ELSE 1 END,
                       CASE WHEN e.esperada IS NULL THEN 0
                            WHEN e.hora >= e.esperada THEN 0
                            ELSE 1 END,
                       ABS(TIMESTAMPDIFF(SECOND, e.hora, e.esperada)),
                       e.hora ASC
               ) AS rn
        FROM entradas e
    ),
    salidas_rank AS (
        -- Simetrico: preferimos una salida en/hacia atras de la
        -- hora esperada, para no tomar una salida posterior de mas.
        SELECT s.*,
               ROW_NUMBER() OVER (
                   PARTITION BY s.num_documento, s.gf, s.turno
                   ORDER BY
                       CASE WHEN s.esperada IS NULL THEN 1 ELSE 0 END,
                       CASE WHEN s.esperada IS NULL THEN 0
                            WHEN ABS(TIMESTAMPDIFF(SECOND, s.hora, s.esperada)) <= 7200 THEN 0
                            ELSE 1 END,
                       CASE WHEN s.esperada IS NULL THEN 0
                            WHEN s.hora <= s.esperada THEN 0
                            ELSE 1 END,
                       ABS(TIMESTAMPDIFF(SECOND, s.hora, s.esperada)),
                       s.hora DESC
               ) AS rn
        FROM salidas s
    ),
    seleccion AS (
        SELECT c.gdoc, c.gf,
               c.hora_entrada, c.hora_salida,
               c.hora_entrada2, c.hora_salida2,
               e1.hora AS e1, e1.tipo_ubicacion AS e1_ubi, e1.justificacion AS e1_just,
               s1.hora AS s1, s1.tipo_ubicacion AS s1_ubi, s1.justificacion AS s1_just,
               e2.hora AS e2, e2.tipo_ubicacion AS e2_ubi, e2.justificacion AS e2_just,
               s2.hora AS s2, s2.tipo_ubicacion AS s2_ubi, s2.justificacion AS s2_just
        FROM calendario c
        LEFT JOIN entradas_rank e1
          ON e1.num_documento = c.gdoc AND e1.gf = c.gf
         AND e1.turno = 1 AND e1.rn = 1
        LEFT JOIN salidas_rank s1
          ON s1.num_documento = c.gdoc AND s1.gf = c.gf
         AND s1.turno = 1 AND s1.rn = 1
        LEFT JOIN entradas_rank e2
          ON e2.num_documento = c.gdoc AND e2.gf = c.gf
         AND e2.turno = 2 AND e2.rn = 1
        LEFT JOIN salidas_rank s2
          ON s2.num_documento = c.gdoc AND s2.gf = c.gf
         AND s2.turno = 2 AND s2.rn = 1
    ),
    evaluacion AS (
        SELECT sel.*,
               CASE
                   WHEN sel.hora_entrada IS NULL OR sel.hora_salida IS NULL THEN 'SIN HORARIO'
                   WHEN sel.e1 IS NULL AND sel.s1 IS NULL THEN
                       CASE
                           WHEN EXISTS (
                               SELECT 1 FROM TblVacaciones v
                               WHERE v.num_documento = sel.gdoc
                                 AND v.estado = 'APROBADO'
                                 AND sel.gf BETWEEN v.fecha_inicio AND v.fecha_fin
                           ) THEN 'VACACIONES'
                           WHEN TIMESTAMP(sel.gf, sel.hora_salida) >= NOW() THEN '-'
                           ELSE 'FALTÓ'
                       END
                   WHEN sel.e1 IS NULL OR sel.s1 IS NULL THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.e1, sel.s1) <= 0 THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada, sel.e1) > 300 THEN 'TARDANZA'
                   ELSE 'ASISTENCIA'
               END AS estado_t1,
               CASE
                   WHEN sel.hora_entrada2 IS NULL OR sel.hora_salida2 IS NULL THEN 'SIN HORARIO'
                   WHEN sel.e2 IS NULL AND sel.s2 IS NULL THEN
                       CASE
                           WHEN EXISTS (
                               SELECT 1 FROM TblVacaciones v
                               WHERE v.num_documento = sel.gdoc
                                 AND v.estado = 'APROBADO'
                                 AND sel.gf BETWEEN v.fecha_inicio AND v.fecha_fin
                           ) THEN 'VACACIONES'
                           WHEN TIMESTAMP(sel.gf, sel.hora_salida2) >= NOW() THEN '-'
                           ELSE 'FALTÓ'
                       END
                   WHEN sel.e2 IS NULL OR sel.s2 IS NULL THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.e2, sel.s2) <= 0 THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada2, sel.e2) > 300 THEN 'TARDANZA'
                   ELSE 'ASISTENCIA'
               END AS estado_t2
        FROM seleccion sel
    )
    SELECT
        IFNULL(e.nombre, 'Sin Empresa') AS EMPRESA,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS NOMBRES,
        p.documento_numero AS DNI_CE,
        IFNULL(c.nombre, 'Sin Cargo') AS CARGO,
        IFNULL(a.nombre, 'Sin Área') AS AREA,
        IFNULL(
            (SELECT ub2.nombre_zona
             FROM TblUbicacionMarcacion ub2
             WHERE ub2.num_documento = p.num_documento
               AND ub2.estado = 'ACTIVO'
             LIMIT 1),
            'Sin Sede Asignada'
        ) AS SEDE_TRABAJO,
        DAY(ev.gf) AS DIA,
        MONTH(ev.gf) AS MES,
        YEAR(ev.gf) AS ANO,
        ELT(DAYOFWEEK(ev.gf), 'Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado') AS DIA_SEMANA,

        -- OFICINA - T1
        CASE WHEN ev.e1_ubi = 'OFICINA' THEN TIME_FORMAT(ev.e1, '%H:%i:%s') END AS H_ENTRADA_OFI_T1,
        CASE WHEN ev.s1_ubi = 'OFICINA' THEN TIME_FORMAT(ev.s1, '%H:%i:%s') END AS H_SALIDA_OFI_T1,
        -- OFICINA - T2
        CASE WHEN ev.e2_ubi = 'OFICINA' THEN TIME_FORMAT(ev.e2, '%H:%i:%s') END AS H_ENTRADA_OFI_T2,
        CASE WHEN ev.s2_ubi = 'OFICINA' THEN TIME_FORMAT(ev.s2, '%H:%i:%s') END AS H_SALIDA_OFI_T2,
        -- CAMPO - T1
        CASE WHEN ev.e1_ubi = 'CAMPO' THEN TIME_FORMAT(ev.e1, '%H:%i:%s') END AS H_ENTRADA_CMP_T1,
        CASE WHEN ev.s1_ubi = 'CAMPO' THEN TIME_FORMAT(ev.s1, '%H:%i:%s') END AS H_SALIDA_CMP_T1,
        -- CAMPO - T2
        CASE WHEN ev.e2_ubi = 'CAMPO' THEN TIME_FORMAT(ev.e2, '%H:%i:%s') END AS H_ENTRADA_CMP_T2,
        CASE WHEN ev.s2_ubi = 'CAMPO' THEN TIME_FORMAT(ev.s2, '%H:%i:%s') END AS H_SALIDA_CMP_T2,

        -- HORAS T1: solo turno completo, topadas al horario, sin negativos.
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.hora_salida IS NULL THEN '-'
            WHEN ev.e1 IS NULL OR ev.s1 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(
                     SECOND,
                     GREATEST(ev.e1, ev.hora_entrada),
                     LEAST(ev.s1, ev.hora_salida)
                 ) <= 0 THEN '-'
            ELSE CONCAT(
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) DIV 3600, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) MOD 60, 2, '0')
            )
        END AS HORAS_LABORADAS_T1,

        -- HORAS T2
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.hora_salida2 IS NULL THEN '-'
            WHEN ev.e2 IS NULL OR ev.s2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(
                     SECOND,
                     GREATEST(ev.e2, ev.hora_entrada2),
                     LEAST(ev.s2, ev.hora_salida2)
                 ) <= 0 THEN '-'
            ELSE CONCAT(
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) DIV 3600, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) MOD 60, 2, '0')
            )
        END AS HORAS_LABORADAS_T2,

        -- TARDANZA T1 (prorroga 5 min)
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.e1 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) DIV 3600, 2, '0'), ':',
                LPAD(((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T1,

        -- TARDANZA T2
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.e2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) DIV 3600, 2, '0'), ':',
                LPAD(((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T2,

        -- DETALLE OFICINA/CAMPO: un solo estado por turno.
        -- SIN HORARIO solo es informativo: se muestra si el turno tiene
        -- marcas. Un turno que no existe en el horario (ej. sin T2) y
        -- sin marcas queda en '-', no en SIN HORARIO.
        CASE
            WHEN ev.estado_t1 = '-' THEN '-'
            WHEN ev.estado_t1 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'OFICINA'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e1 IS NULL AND ev.s1 IS NULL THEN ev.estado_t1
            WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'OFICINA' THEN ev.estado_t1
            ELSE '-'
        END AS DETALLE_OFI_T1,
        CASE
            WHEN ev.estado_t1 = '-' THEN '-'
            WHEN ev.estado_t1 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'CAMPO'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e1 IS NULL AND ev.s1 IS NULL THEN '-'
            WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'CAMPO' THEN ev.estado_t1
            ELSE '-'
        END AS DETALLE_CMP_T1,
        CASE
            WHEN ev.estado_t2 = '-' THEN '-'
            WHEN ev.estado_t2 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'OFICINA'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e2 IS NULL AND ev.s2 IS NULL THEN ev.estado_t2
            WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'OFICINA' THEN ev.estado_t2
            ELSE '-'
        END AS DETALLE_OFI_T2,
        CASE
            WHEN ev.estado_t2 = '-' THEN '-'
            WHEN ev.estado_t2 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'CAMPO'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e2 IS NULL AND ev.s2 IS NULL THEN '-'
            WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'CAMPO' THEN ev.estado_t2
            ELSE '-'
        END AS DETALLE_CMP_T2,

        -- JUSTIFICACIONES de las marcas elegidas
        ev.e1_just AS JUSTIFICACION_ENT_T1,
        ev.s1_just AS JUSTIFICACION_SAL_T1,
        ev.e2_just AS JUSTIFICACION_ENT_T2,
        ev.s2_just AS JUSTIFICACION_SAL_T2

    FROM evaluacion ev
    INNER JOIN TblPersona p ON p.num_documento = ev.gdoc
    INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    WHERE (p_num_usuario IS NULL OR u.num_usuario = p_num_usuario)
    ORDER BY ev.gf ASC, p.apellido_paterno ASC;
END$$

DROP PROCEDURE IF EXISTS `sp_RestaurarVersionPresupuesto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RestaurarVersionPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_numero_version_a_restaurar INT,
    IN p_creado_por INT,
    IN p_motivo TEXT
)
BEGIN
    DECLARE v_id_version_origen INT;
    DECLARE v_siguiente_numero INT;
    DECLARE v_nueva_version_id INT;
    
    -- Obtener ID de la versión a restaurar
    SELECT id_version INTO v_id_version_origen
    FROM TblPresupuestoVersionHistorial
    WHERE id_presupuesto = p_id_presupuesto 
      AND numero_version = p_numero_version_a_restaurar
    LIMIT 1;
    
    IF v_id_version_origen IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Versión a restaurar no encontrada';
    END IF;
    
    -- Obtener siguiente número de versión
    SELECT COALESCE(MAX(numero_version), 0) + 1 
    INTO v_siguiente_numero
    FROM TblPresupuestoVersionHistorial
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Marcar versiones anteriores como no actuales
    UPDATE TblPresupuestoVersionHistorial
    SET es_version_actual = 0
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Crear nueva versión copiando datos de la versión a restaurar
    INSERT INTO TblPresupuestoVersionHistorial (
        id_presupuesto,
        numero_version,
        fecha_version,
        creado_por,
        motivo_cambio,
        es_version_actual,
        numero_presupuesto,
        id_cliente,
        nombre_cliente,
        proyecto,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    )
    SELECT 
        id_presupuesto,
        v_siguiente_numero,
        NOW(),
        p_creado_por,
        CONCAT('Restaurado desde v', p_numero_version_a_restaurar, ': ', COALESCE(p_motivo, '')),
        1, -- es_version_actual
        numero_presupuesto,
        id_cliente,
        nombre_cliente,
        proyecto,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    FROM TblPresupuestoVersionHistorial
    WHERE id_version = v_id_version_origen;
    
    SET v_nueva_version_id = LAST_INSERT_ID();
    
    -- Copiar detalles de la versión restaurada
    INSERT INTO TblPresupuestoVersionDetalleHistorial (
        id_version,
        tipo_partida,
        id_partida_original,
        descripcion,
        unidad,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT 
        v_nueva_version_id,
        tipo_partida,
        id_partida_original,
        descripcion,
        unidad,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    FROM TblPresupuestoVersionDetalleHistorial
    WHERE id_version = v_id_version_origen;
    
    -- Actualizar TblPresupuesto con los valores restaurados
    UPDATE TblPresupuesto p
    INNER JOIN TblPresupuestoVersionHistorial vh ON p.id_presupuesto = vh.id_presupuesto
    SET 
        p.total_materiales = vh.total_materiales,
        p.total_servicios = vh.total_servicios,
        p.costos_directos = vh.costos_directos,
        p.gastos_generales = vh.gastos_generales,
        p.utilidad = vh.utilidad,
        p.sub_total = vh.sub_total,
        p.igv = vh.igv,
        p.supervision = vh.supervision,
        p.presupuesto_total = vh.presupuesto_total,
        p.porcentaje_gg = vh.porcentaje_gg,
        p.porcentaje_utilidad = vh.porcentaje_utilidad,
        p.porcentaje_supervision = vh.porcentaje_supervision,
        p.observaciones = vh.observaciones
    WHERE vh.id_version = v_nueva_version_id;
    
    -- Retornar información
    SELECT 
        v_nueva_version_id as id_version,
        v_siguiente_numero as numero_version,
        CONCAT('Versión v', p_numero_version_a_restaurar, ' restaurada como v', v_siguiente_numero) as mensaje;
        
END$$

DROP PROCEDURE IF EXISTS `sp_ResumenUsuariosAsistencia`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ResumenUsuariosAsistencia`(
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE
)
BEGIN
    SELECT 
        u.num_documento,
        p.documento_numero,
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as nombre_completo,
        p.email,
        e.nombre AS empresa,                                    -- ★ FALTABA
        COALESCE(COUNT(DISTINCT CASE 
            WHEN m.fecha_marcacion IS NOT NULL
                AND (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
                AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
            THEN DATE(m.fecha_marcacion) 
        END), 0) as dias_asistidos,
        COALESCE(SUM(CASE 
            WHEN m.tipo_marcacion = 'ENTRADA'
                AND (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
                AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
            THEN 1 ELSE 0 
        END), 0) as total_entradas,
        COALESCE(SUM(CASE 
            WHEN m.tipo_marcacion = 'SALIDA'
                AND (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
                AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
            THEN 1 ELSE 0 
        END), 0) as total_salidas,
        MIN(CASE 
            WHEN (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
                AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
            THEN m.fecha_marcacion 
        END) as primera_marcacion,
        MAX(CASE 
            WHEN (p_fecha_desde IS NULL OR DATE(m.fecha_marcacion) >= p_fecha_desde)
                AND (p_fecha_hasta IS NULL OR DATE(m.fecha_marcacion) <= p_fecha_hasta)
            THEN m.fecha_marcacion 
        END) as ultima_marcacion,
        -- Contar memos del empleado
        (SELECT COUNT(*) 
         FROM TblMemo memo 
         WHERE memo.num_documento = u.num_documento
        ) as total_memos
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa      -- ★ FALTABA
    LEFT JOIN TblMarcacion m ON u.num_documento = m.num_documento
    GROUP BY u.num_documento, p.documento_numero, p.nombres,
             p.apellido_paterno, p.apellido_materno, p.email,
             e.nombre
    ORDER BY nombre_completo;
END$$

DROP PROCEDURE IF EXISTS `sp_RQA_ReponerStock`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RQA_ReponerStock`(
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

DROP PROCEDURE IF EXISTS `sp_sincronizar_secciones_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_sincronizar_secciones_inventario`(
    OUT p_creadas INT
)
    MODIFIES SQL DATA
BEGIN
    SET p_creadas = 0;

    INSERT INTO `TblInventarioMaterial` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'MATERIAL' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'MATERIAL'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioMaterial` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioHerramienta` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'HERRAMIENTA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'HERRAMIENTA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioHerramienta` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioEquipo` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'EQUIPO' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'EQUIPO'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioEquipo` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioTecnologia` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'TECNOLOGIA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'TECNOLOGIA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioTecnologia` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioRopa` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'ROPA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'ROPA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioRopa` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioConsumible` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'CONSUMIBLE' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'CONSUMIBLE'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioConsumible` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();
END$$

DROP PROCEDURE IF EXISTS `sp_tardanzas_por_empleado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_tardanzas_por_empleado`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SET @row_num := 0;

    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS f WHERE p_fecha_inicio <= p_fecha_fin
        UNION ALL
        SELECT f + INTERVAL 1 DAY FROM fechas WHERE f < p_fecha_fin
    ),
    grid AS (
        SELECT DISTINCT h.num_documento AS gdoc, fe.f AS gf
        FROM TblHorarioTrabajo h
        JOIN fechas fe
          ON UPPER(h.dia_semana) = CASE DAYOFWEEK(fe.f)
                 WHEN 1 THEN 'DOMINGO'
                 WHEN 2 THEN 'LUNES'
                 WHEN 3 THEN 'MARTES'
                 WHEN 4 THEN 'MIÉRCOLES'
                 WHEN 5 THEN 'JUEVES'
                 WHEN 6 THEN 'VIERNES'
                 WHEN 7 THEN 'SÁBADO'
             END
        WHERE h.es_activo = 1
          AND h.fecha_vigencia_inicio <= fe.f
          AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= fe.f)
        UNION
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    marcas AS (
        SELECT a.*,
               CASE
                    WHEN a.ult_ent IS NULL
                         THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                    WHEN hh.num_documento IS NULL
                         THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                    WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                    WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                    ELSE 2
               END AS turno
        FROM (
            SELECT mm.*,
                   MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                       OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                             ORDER BY mm.fecha_marcacion, mm.id_marcacion
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
            FROM TblMarcacion mm
            WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
        ) a
        LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
            AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                WHEN 1 THEN 'DOMINGO'
                WHEN 2 THEN 'LUNES'
                WHEN 3 THEN 'MARTES'
                WHEN 4 THEN 'MIÉRCOLES'
                WHEN 5 THEN 'JUEVES'
                WHEN 6 THEN 'VIERNES'
                WHEN 7 THEN 'SÁBADO'
            END
            AND hh.es_activo = 1
            AND hh.fecha_vigencia_inicio <= DATE(a.fecha_marcacion)
            AND (hh.fecha_vigencia_fin IS NULL OR hh.fecha_vigencia_fin >= DATE(a.fecha_marcacion))
    ),
    dias AS (
        SELECT
            g.gdoc,
            g.gf,
            -- Segundos de tardanza turno 1 (misma logica y mismo
            -- orden de condiciones que DETALLE_OFI_T1 de v9:
            -- sin marcas / sin ENTRADA OFICINA / sin horario =>
            -- 0; si no, solo cuenta si la diferencia > 300 seg)
            CASE
                WHEN COUNT(CASE WHEN m.turno = 1 THEN 1 END) = 0 THEN 0
                WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                              AND m.tipo_ubicacion = 'OFICINA'
                              THEN TIME(m.fecha_marcacion) END) IS NULL THEN 0
                WHEN h.hora_entrada IS NULL THEN 0
                WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN 0
                ELSE TIMESTAMPDIFF(SECOND, h.hora_entrada,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END))
            END AS seg_t1,
            -- Segundos de tardanza turno 2 (idem DETALLE_OFI_T2)
            CASE
                WHEN COUNT(CASE WHEN m.turno = 2 THEN 1 END) = 0 THEN 0
                WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                              AND m.tipo_ubicacion = 'OFICINA'
                              THEN TIME(m.fecha_marcacion) END) IS NULL THEN 0
                WHEN h.hora_entrada2 IS NULL THEN 0
                WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada2,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN 0
                ELSE TIMESTAMPDIFF(SECOND, h.hora_entrada2,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END))
            END AS seg_t2
        FROM grid g
        LEFT JOIN marcas m ON m.num_documento = g.gdoc
            AND DATE(m.fecha_marcacion) = g.gf
        LEFT JOIN TblHorarioTrabajo h ON h.num_documento = g.gdoc
            AND UPPER(h.dia_semana) = CASE DAYOFWEEK(g.gf)
                WHEN 1 THEN 'DOMINGO'
                WHEN 2 THEN 'LUNES'
                WHEN 3 THEN 'MARTES'
                WHEN 4 THEN 'MIÉRCOLES'
                WHEN 5 THEN 'JUEVES'
                WHEN 6 THEN 'VIERNES'
                WHEN 7 THEN 'SÁBADO'
            END
            AND h.es_activo = 1
            AND h.fecha_vigencia_inicio <= g.gf
            AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= g.gf)
        GROUP BY g.gdoc, g.gf, h.hora_entrada, h.hora_entrada2
    )
    SELECT
        @row_num := @row_num + 1 AS N,
        t.empresa,
        t.dni_ce,
        t.nombres,
        t.cargo,
        t.horario,
        t.total_minutos_tarde,
        CONCAT(
            LPAD(t.total_minutos_tarde DIV 60, 2, '0'), ':',
            LPAD(t.total_minutos_tarde MOD 60, 2, '0')
        ) AS total_horas_tarde,
        t.area,
        t.nombres_dash
    FROM (
        SELECT
            IFNULL(e.nombre, 'Sin Empresa') AS empresa,
            p.documento_numero AS dni_ce,
            CONCAT(p.apellido_paterno, ' ', p.apellido_materno, ', ', p.nombres) AS nombres,
            IFNULL(c.nombre, 'Sin Cargo') AS cargo,
            (SELECT CONCAT(h2.hora_entrada, '-', h2.hora_salida,
                          IF(h2.hora_entrada2 IS NOT NULL,
                             CONCAT(' / ', h2.hora_entrada2, '-', h2.hora_salida2), ''))
             FROM TblHorarioTrabajo h2
             WHERE h2.num_documento = p.num_documento AND h2.es_activo = 1
               AND h2.fecha_vigencia_fin IS NULL
             GROUP BY h2.hora_entrada, h2.hora_salida, h2.hora_entrada2, h2.hora_salida2
             ORDER BY COUNT(*) DESC LIMIT 1) AS horario,
            (SUM(d.seg_t1) + SUM(d.seg_t2)) DIV 60 AS total_minutos_tarde,
            IFNULL(a.nombre, 'Sin Área') AS area,
            CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS nombres_dash
        FROM dias d
        INNER JOIN TblPersona p ON p.num_documento = d.gdoc
        INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
        LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
        LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
        LEFT JOIN TblArea a ON c.id_area = a.id_area
        GROUP BY p.num_documento, e.nombre, p.nombres, p.apellido_paterno,
                 p.apellido_materno, p.documento_numero, c.nombre, a.nombre
        HAVING (SUM(d.seg_t1) + SUM(d.seg_t2)) DIV 60 > 0
        ORDER BY total_minutos_tarde DESC
    ) AS t;
END$$

DROP PROCEDURE IF EXISTS `sp_verificar_kardex`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_verificar_kardex`(
    IN p_solo_diferencias TINYINT
)
    READS SQL DATA
BEGIN
    -- Saldo según kardex = último AJUSTE (o 0) + entradas/devoluciones - salidas
    -- posteriores a ese ajuste. Se compara con stock_actual.
    SELECT k.id_inventario, k.codigo, k.nombre, k.stock_actual, k.saldo_kardex,
           k.stock_actual - k.saldo_kardex AS diferencia, k.movimientos
    FROM (
        SELECT i.id_inventario, i.codigo, i.nombre, i.stock_actual,
               COALESCE(MAX(a.cantidad), 0)
               + COALESCE(SUM(CASE
                                WHEN m.tipo_movimiento IN ('ENTRADA', 'DEVOLUCION') THEN m.cantidad
                                WHEN m.tipo_movimiento = 'SALIDA' THEN -m.cantidad
                                ELSE 0
                              END), 0) AS saldo_kardex,
               (SELECT COUNT(*) FROM `TblMovimientoInventario` x WHERE x.id_inventario = i.id_inventario) AS movimientos
        FROM `TblInventario` i
        LEFT JOIN (
            SELECT id_inventario, cantidad, fecha_movimiento, id_movimiento,
                   ROW_NUMBER() OVER (PARTITION BY id_inventario
                                      ORDER BY fecha_movimiento DESC, id_movimiento DESC) AS rn
            FROM `TblMovimientoInventario`
            WHERE tipo_movimiento = 'AJUSTE'
        ) a ON a.id_inventario = i.id_inventario AND a.rn = 1
        LEFT JOIN `TblMovimientoInventario` m
          ON m.id_inventario = i.id_inventario
         AND m.tipo_movimiento <> 'AJUSTE'
         AND (a.id_movimiento IS NULL
              OR (m.fecha_movimiento, m.id_movimiento) > (a.fecha_movimiento, a.id_movimiento))
        WHERE i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
        GROUP BY i.id_inventario, i.codigo, i.nombre, i.stock_actual
    ) k
    WHERE (p_solo_diferencias IS NULL OR p_solo_diferencias = 0 OR k.stock_actual <> k.saldo_kardex)
      AND (k.stock_actual <> 0 OR k.movimientos > 0 OR p_solo_diferencias = 1)
    ORDER BY k.codigo;
END$$

DROP VIEW IF EXISTS `vw_inventario_consumible`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_consumible` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`k`.`marca` AS `marca`,`k`.`presentacion` AS `presentacion`,`k`.`tamano` AS `tamano`,`k`.`gramaje` AS `gramaje`,`k`.`color` AS `color`,`k`.`unidades_paquete` AS `unidades_paquete`,`k`.`blancura_pct` AS `blancura_pct` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioConsumible` `k` on((`k`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'CONSUMIBLE')$$

DROP VIEW IF EXISTS `vw_inventario_equipo`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_equipo` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`e`.`marca` AS `marca`,`e`.`modelo` AS `modelo`,`e`.`capacidad` AS `capacidad`,`e`.`potencia` AS `potencia`,`e`.`numero_serie` AS `numero_serie`,`e`.`anio_fabricacion` AS `anio_fabricacion`,`e`.`placa` AS `placa`,`e`.`peso_kg` AS `peso_kg`,`e`.`largo_cm` AS `largo_cm`,`e`.`ancho_cm` AS `ancho_cm`,`e`.`alto_cm` AS `alto_cm` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioEquipo` `e` on((`e`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'EQUIPO')$$

DROP VIEW IF EXISTS `vw_inventario_herramienta`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_herramienta` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`h`.`marca` AS `marca`,`h`.`modelo` AS `modelo`,`h`.`tipo_herramienta` AS `tipo_herramienta`,`h`.`potencia` AS `potencia`,`h`.`voltaje` AS `voltaje`,`h`.`numero_serie` AS `numero_serie`,`h`.`peso_kg` AS `peso_kg`,`h`.`largo_cm` AS `largo_cm`,`h`.`ancho_cm` AS `ancho_cm`,`h`.`alto_cm` AS `alto_cm` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioHerramienta` `h` on((`h`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'HERRAMIENTA')$$

DROP VIEW IF EXISTS `vw_inventario_material`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_material` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`m`.`presentacion` AS `presentacion`,`m`.`marca` AS `marca`,`m`.`tipo` AS `tipo`,`m`.`norma` AS `norma`,`m`.`medida` AS `medida`,`m`.`color` AS `color`,`m`.`resistencia` AS `resistencia`,`m`.`lote` AS `lote`,`m`.`peso_unitario_kg` AS `peso_unitario_kg`,`m`.`largo_cm` AS `largo_cm`,`m`.`ancho_cm` AS `ancho_cm`,`m`.`alto_cm` AS `alto_cm` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioMaterial` `m` on((`m`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'MATERIAL')$$

DROP VIEW IF EXISTS `vw_inventario_ropa`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_ropa` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`r`.`talla` AS `talla`,`r`.`color` AS `color`,`r`.`genero` AS `genero`,`r`.`material_tela` AS `material_tela`,`r`.`norma_certificacion` AS `norma_certificacion`,`r`.`tipo_proteccion` AS `tipo_proteccion` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioRopa` `r` on((`r`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'ROPA')$$

DROP VIEW IF EXISTS `vw_inventario_tecnologia`$$
CREATE ALGORITHM=UNDEFINED DEFINER=`kallpasystem`@`%` SQL SECURITY DEFINER VIEW `vw_inventario_tecnologia` AS select `i`.`id_inventario` AS `id_inventario`,`i`.`codigo` AS `codigo`,`i`.`nombre` AS `nombre`,`i`.`descripcion` AS `descripcion`,`i`.`tipo_inventario` AS `tipo_inventario`,`i`.`id_categoria` AS `id_categoria`,`c`.`nombre` AS `categoria`,`i`.`id_unidad` AS `id_unidad`,`u`.`abreviatura` AS `unidad`,`i`.`stock_actual` AS `stock_actual`,`i`.`stock_minimo` AS `stock_minimo`,`i`.`stock_maximo` AS `stock_maximo`,`i`.`id_almacen` AS `id_almacen`,`i`.`ubicacion_fisica` AS `ubicacion_fisica`,`i`.`precio_compra` AS `precio_compra`,`i`.`precio_promedio` AS `precio_promedio`,`i`.`estado` AS `estado`,`t`.`marca` AS `marca`,`t`.`modelo` AS `modelo`,`t`.`procesador` AS `procesador`,`t`.`ram` AS `ram`,`t`.`almacenamiento` AS `almacenamiento`,`t`.`pantalla` AS `pantalla`,`t`.`sistema_operativo` AS `sistema_operativo`,`t`.`numero_serie` AS `numero_serie`,`t`.`garantia_meses` AS `garantia_meses`,`t`.`peso_kg` AS `peso_kg`,`t`.`largo_cm` AS `largo_cm`,`t`.`ancho_cm` AS `ancho_cm`,`t`.`alto_cm` AS `alto_cm` from (((`TblInventario` `i` left join `TblCategoriaInventario` `c` on((`c`.`id_categoria` = `i`.`id_categoria`))) left join `TblUnidadMedida` `u` on((`u`.`id_unidad` = `i`.`id_unidad`))) left join `TblInventarioTecnologia` `t` on((`t`.`id_inventario` = `i`.`id_inventario`))) where (`i`.`tipo_inventario` = 'TECNOLOGIA')$$

DELIMITER ;
