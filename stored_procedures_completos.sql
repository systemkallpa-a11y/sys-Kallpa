/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.4.12-MariaDB, for Linux (x86_64)
--
-- Host: 127.0.0.1    Database: kallgwkn_kallpa_bd
-- ------------------------------------------------------
-- Server version	11.4.12-MariaDB-cll-lve-log
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Dumping routines for database 'kallgwkn_kallpa_bd'
--
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarEmpresa`(
    IN p_id_empresa INT,
    IN p_ruc VARCHAR(11),
    IN p_nombre VARCHAR(255),
    IN p_latitud DECIMAL(10, 8),
    IN p_longitud DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_logo LONGBLOB
)
BEGIN
    DECLARE v_ruc_existe INT;
    DECLARE v_nombre_existe INT;
    DECLARE v_mensaje VARCHAR(500);

    -- Validar que la empresa existe
    IF NOT EXISTS(SELECT 1 FROM TblEmpresa WHERE id_empresa = p_id_empresa) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La empresa no existe';
    END IF;

    -- Validar que el RUC no esté vacío
    IF p_ruc IS NULL OR p_ruc = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El RUC es requerido';
    END IF;

    -- Validar que el RUC tenga exactamente 11 dígitos
    IF LENGTH(p_ruc) != 11 OR NOT p_ruc REGEXP '^[0-9]{11}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El RUC debe tener exactamente 11 dígitos';
    END IF;

    -- Validar que el nombre no esté vacío
    IF p_nombre IS NULL OR p_nombre = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de la empresa es requerido';
    END IF;

    -- Validar que la latitud esté dentro del rango válido (-90 a 90)
    IF p_latitud < -90 OR p_latitud > 90 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La latitud debe estar entre -90 y 90';
    END IF;

    -- Validar que la longitud esté dentro del rango válido (-180 a 180)
    IF p_longitud < -180 OR p_longitud > 180 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La longitud debe estar entre -180 y 180';
    END IF;

    -- Validar que el radio sea positivo
    IF p_radio_metros <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El radio debe ser mayor a 0 metros';
    END IF;

    -- Verificar si el RUC ya existe (en otra empresa diferente)
    SELECT COUNT(*) INTO v_ruc_existe
    FROM TblEmpresa
    WHERE ruc = p_ruc AND id_empresa != p_id_empresa;
    
    IF v_ruc_existe > 0 THEN
        SET v_mensaje = CONCAT('Ya existe otra empresa con el RUC: ', p_ruc);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;

    -- Verificar si el nombre ya existe (en otra empresa diferente)
    SELECT COUNT(*) INTO v_nombre_existe
    FROM TblEmpresa
    WHERE nombre = p_nombre AND id_empresa != p_id_empresa;
    
    IF v_nombre_existe > 0 THEN
        SET v_mensaje = CONCAT('Ya existe otra empresa con el nombre: ', p_nombre);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;

    -- Actualizar la empresa
    -- Si p_logo es NULL, no se actualiza el logo (mantiene el existente)
    -- Si p_logo tiene valor, reemplaza el logo existente
    IF p_logo IS NOT NULL THEN
        UPDATE TblEmpresa
        SET 
            ruc = p_ruc,
            nombre = p_nombre,
            latitud = p_latitud,
            longitud = p_longitud,
            radio_metros = p_radio_metros,
            logo = p_logo,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_empresa = p_id_empresa;
    ELSE
        UPDATE TblEmpresa
        SET 
            ruc = p_ruc,
            nombre = p_nombre,
            latitud = p_latitud,
            longitud = p_longitud,
            radio_metros = p_radio_metros,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_empresa = p_id_empresa;
    END IF;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarPresupuestoCompleto`(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_utilidad DECIMAL(12,2),            -- ⭐ NUEVO
    IN p_supervision_obra DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2);
    DECLARE v_igv DECIMAL(12,2);
    DECLARE v_monto_total DECIMAL(12,2);

    -- Calcular subtotal (materiales + servicios)
    SELECT COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SELECT v_total_monto + COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    -- IGV automático sobre (subtotal + desglose editable)
    SET v_igv = ROUND((v_total_monto + p_gastos_generales + p_utilidad + p_supervision_obra) * 0.18, 2);
    SET v_monto_total = v_total_monto + p_gastos_generales + p_utilidad + p_supervision_obra + v_igv;

    -- Actualizar presupuesto CON VALORES EDITABLES
    UPDATE TblPresupuesto 
    SET 
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = p_num_documento,
        monto = v_total_monto,
        monto_total = v_monto_total,
        gastos_generales = p_gastos_generales,    -- ⭐ EDITABLE
        utilidad = p_utilidad,                    -- ⭐ EDITABLE
        supervision_obra = p_supervision_obra,    -- ⭐ EDITABLE
        igv = v_igv,                              -- ⭐ AUTOMÁTICO
        observaciones = p_comentarios,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    -- Limpiar flujo de aprobación
    DELETE FROM TblRegistroAprobacion 
    WHERE id_documento_referencia = p_id_presupuesto AND id_tipo_documento = 1;

    -- Eliminar y reinsertar detalles
    DELETE FROM TblPresupuestoDetalle WHERE id_presupuesto = p_id_presupuesto;

    -- Insertar materiales nuevos
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto, id_material, tipo_item, descripcion, cantidad, 
        cantidad_original, cantidad_consumida, precio_unitario, subtotal, fecha_creacion
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
        id_presupuesto, id_material, tipo_item, descripcion, cantidad,
        cantidad_original, cantidad_consumida, precio_unitario, subtotal, fecha_creacion
    )
    SELECT
        p_id_presupuesto, NULL, 'SERVICIO',
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarRequerimiento`(
    IN p_id_requerimiento INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_resultado INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_detalle_index INT DEFAULT 0;
    DECLARE v_total_detalles INT DEFAULT 0;
    DECLARE v_id_detalle INT;
    DECLARE v_desc_detalle VARCHAR(255);
    DECLARE v_cantidad_detalle INT;
    DECLARE v_cantidad_total INT DEFAULT 0;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_id_material INT;
    DECLARE v_tipo_item VARCHAR(20);
    
    -- Verificar que el requerimiento existe
    SELECT COUNT(*)
    INTO v_existe
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no existe';
        SET p_resultado = 0;
    ELSE
        -- ================================================================
        -- PASO 1: OBTENER ESTADO ACTUAL
        -- ================================================================
        SELECT estado INTO v_estado_actual
        FROM TblRequerimiento
        WHERE id_requerimiento = p_id_requerimiento;
        
        -- ================================================================
        -- PASO 2: PROCESAR DETALLES (INSERT y UPDATE)
        -- ================================================================
        IF p_detalles_json IS NOT NULL AND p_detalles_json != '[]' THEN
            -- Procesar cada detalle del JSON
            SET v_detalle_index = 0;
            SET v_total_detalles = JSON_LENGTH(p_detalles_json);
            
            WHILE v_detalle_index < v_total_detalles DO
                -- Extraer datos del detalle
                SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].id_detalle'));
                SET v_desc_detalle = JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].descripcion')));
                SET v_cantidad_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].cantidad'));
                SET v_tipo_item = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].tipo_item'))), 'MATERIAL');
                SET v_id_material = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].id_material'));
                
                -- Acumular cantidad total
                SET v_cantidad_total = v_cantidad_total + COALESCE(v_cantidad_detalle, 0);
                
                -- ========================================================
                -- LÓGICA: Si ID es negativo → INSERT, si es positivo → UPDATE
                -- ========================================================
                IF v_id_detalle < 0 THEN
                    -- INSERTAR nuevo item (viene desde presupuesto en edición)
                    INSERT INTO TblRequerimientoDetalle (
                        id_requerimiento,
                        id_material,
                        descripcion,
                        cantidad,
                        tipo_item,
                        fecha_creacion,
                        fecha_actualizacion
                    ) VALUES (
                        p_id_requerimiento,
                        v_id_material,
                        v_desc_detalle,
                        v_cantidad_detalle,
                        v_tipo_item,
                        NOW(),
                        NOW()
                    );
                ELSE
                    -- ACTUALIZAR item existente
                    UPDATE TblRequerimientoDetalle
                    SET descripcion = v_desc_detalle,
                        cantidad = v_cantidad_detalle,
                        fecha_actualizacion = NOW()
                    WHERE id_detalle = v_id_detalle
                    AND id_requerimiento = p_id_requerimiento;
                END IF;
                
                SET v_detalle_index = v_detalle_index + 1;
            END WHILE;
        ELSE
            -- Si no hay JSON, calcular suma de cantidades actuales
            SELECT COALESCE(SUM(cantidad), 0)
            INTO v_cantidad_total
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
        END IF;
        
        -- ================================================================
        -- PASO 3: ACTUALIZAR DATOS DEL REQUERIMIENTO
        -- ================================================================
        UPDATE TblRequerimiento
        SET descripcion = p_descripcion,
            observaciones = p_observaciones,
            cantidad = v_cantidad_total,
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        -- ================================================================
        -- PASO 4: MANEJAR CAMBIO DE ESTADO
        -- ================================================================
        -- Si está RECHAZADO → Cambiar a PENDIENTE automáticamente
        IF v_estado_actual = 'RECHAZADO' THEN
            UPDATE TblRequerimiento
            SET estado = 'PENDIENTE',
                fecha_actualizacion = NOW()
            WHERE id_requerimiento = p_id_requerimiento;
        END IF;
        
        -- ================================================================
        -- RETORNAR RESULTADO (éxito)
        -- ================================================================
        SET p_resultado = 1;
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarUsuario`(
    IN p_num_usuario INT,
    IN p_nombres VARCHAR(100),
    IN p_apellido_paterno VARCHAR(100),
    IN p_apellido_materno VARCHAR(100),
    IN p_email VARCHAR(120),
    IN p_telefono VARCHAR(20),
    IN p_celular VARCHAR(20),
    IN p_usuario VARCHAR(100),
    IN p_password_hash VARCHAR(255),
    IN p_rol VARCHAR(50),
    IN p_id_cargo INT,
    IN p_estado VARCHAR(20),
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_num_documento INT;
    DECLARE v_usuario_existente INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al actualizar el usuario';
        ROLLBACK;
    END;
    
    -- Validar que el usuario existe
    SELECT num_documento INTO v_num_documento
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    IF v_num_documento IS NULL THEN
        SET p_mensaje = 'El usuario no existe';
        LEAVE proc_label;
    END IF;
    
    -- Validar que el nuevo usuario no exista (si se está cambiando)
    IF p_usuario IS NOT NULL AND p_usuario != '' THEN
        SELECT COUNT(*) INTO v_usuario_existente
        FROM TblUsuario
        WHERE usuario = p_usuario
        AND num_usuario != p_num_usuario;
        
        IF v_usuario_existente > 0 THEN
            SET p_mensaje = CONCAT('El usuario ', p_usuario, ' ya existe');
            LEAVE proc_label;
        END IF;
    END IF;
    
    START TRANSACTION;
    
    -- Actualizar TblPersona
    UPDATE TblPersona
    SET
        nombres = COALESCE(p_nombres, nombres),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        email = COALESCE(p_email, email),
        telefono = COALESCE(p_telefono, telefono),
        celular = COALESCE(p_celular, celular)
    WHERE num_documento = v_num_documento;
    
    -- Actualizar TblUsuario
    UPDATE TblUsuario
    SET
        usuario = COALESCE(p_usuario, usuario),
        password_hash = COALESCE(p_password_hash, password_hash),
        rol = COALESCE(p_rol, rol),
        id_cargo = COALESCE(p_id_cargo, id_cargo),
        estado = COALESCE(p_estado, estado)
    WHERE num_usuario = p_num_usuario;
    
    SET p_mensaje = 'Usuario actualizado exitosamente';
    
    COMMIT;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ActualizarUsuarioCompleto`(
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
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_AprobarPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    
    -- Verificar que el presupuesto existe
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
    
    -- Verificar que está en estado PENDIENTE o RECHAZADO (permite re-envío)
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE o RECHAZADO. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- PASO 1: Actualizar estado del presupuesto a APROBADO
    UPDATE TblPresupuesto
    SET 
        estado = 'APROBADO'
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 2: Registrar en TblRegistroAprobacion
    -- Verificar si existe registro en TblRegistroAprobacion
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Si NO existe registro, crear uno nuevo con estado APROBADO
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_documento_referencia,
            id_tipo_documento,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            1,                                      -- Paso por defecto: 1
            NULL,                                   -- Cargo (no requerido para presupuesto simple)
            p_num_documento_aprobador,              -- Usuario que aprueba
            'APROBADO',                             -- Estado: APROBADO
            NOW()                                   -- Fecha actual
        );
        
        SET v_mensaje = CONCAT('✅ Presupuesto ', p_id_presupuesto, ' APROBADO. Estado actualizado en TblPresupuesto. Registro nuevo creado en TblRegistroAprobacion');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'APROBADO',
            num_documento_aprobador = p_num_documento_aprobador,      -- Registrar documento del aprobador
            fecha_aprobacion = NOW()                        -- Registrar fecha de aprobación
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = 1;
        
        SET v_mensaje = CONCAT('✅ Presupuesto ', p_id_presupuesto, ' APROBADO. Estado actualizado en TblPresupuesto. Registro actualizado en TblRegistroAprobacion');
    END IF;
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_AprobarPresupuesto_Progresivo`(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT,
    IN p_id_tipo_documento INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_siguiente_paso INT;
    DECLARE v_es_final TINYINT;
    DECLARE v_pasos_totales INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    DECLARE v_id_cargo INT;
    
    -- PASO 1: VALIDACIONES BÁSICAS
    -- Verificar que el presupuesto existe
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
    
    -- Verificar que está en estado PENDIENTE o RECHAZADO
    IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Presupuesto en estado APROBADO o ELIMINADO. No puede aprobarse.';
    END IF;
    
    -- PASO 2: OBTENER SIGUIENTE PASO PENDIENTE (usando TblFlujoAprobacionCargos)
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
    
    -- Si no hay siguiente paso, buscar el primero
    IF v_siguiente_paso IS NULL THEN
        SELECT MIN(numero_paso) INTO v_siguiente_paso
        FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = p_id_tipo_documento
        AND es_requerido = 1
        AND activo = 1;
    END IF;
    
    IF v_siguiente_paso IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No hay pasos de aprobación configurados para este tipo de documento';
    END IF;
    
    -- PASO 3: OBTENER INFORMACIÓN DEL PASO ACTUAL
    SELECT 
        es_final,
        id_cargo INTO v_es_final, v_id_cargo
    FROM TblFlujoAprobacionCargos
    WHERE id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso
    AND es_requerido = 1
    AND activo = 1
    LIMIT 1;
    
    -- PASO 4: REGISTRAR LA APROBACIÓN EN TblRegistroAprobacion
    -- Verificar si ya existe registro para este paso
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = p_id_tipo_documento
    AND numero_paso = v_siguiente_paso;
    
    IF v_registro_aprobacion_existe = 0 THEN
        -- Crear nuevo registro
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
        -- Actualizar registro existente
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
    
    -- PASO 5: VERIFICAR SI ES EL ÚLTIMO PASO
    IF v_es_final = 1 THEN
        -- Es el último paso, verificar si TODOS los pasos están aprobados
        
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
        
        -- Si todos los pasos están aprobados, cambiar estado de presupuesto
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
        
        SET v_mensaje = CONCAT(
            '✅ Paso ', v_siguiente_paso, ' aprobado. ',
            'Esperando paso siguiente. ',
            'Progreso: ', v_pasos_aprobados, '/', v_pasos_totales
        );
    END IF;
    
    -- RESPUESTA AL USUARIO
    SELECT 'OK' AS resultado, v_mensaje AS mensaje, v_siguiente_paso AS paso_actual;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_AutenticarUsuarioKallpa`(
    IN p_usuario VARCHAR(100),
    IN p_password_hash VARCHAR(255),
    OUT p_autenticado INT,
    OUT p_num_usuario INT,
    OUT p_num_documento INT,
    OUT p_nombres VARCHAR(100),
    OUT p_apellido_paterno VARCHAR(100),
    OUT p_apellido_materno VARCHAR(100),
    OUT p_email VARCHAR(120),
    OUT p_cargo VARCHAR(100),
    OUT p_area VARCHAR(100),
    OUT p_rol VARCHAR(50),
    OUT p_estado VARCHAR(20),
    OUT p_ultima_marcacion DATETIME,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE p_password_actual VARCHAR(255);
    DECLARE p_estado_usuario VARCHAR(20);
    
    SET p_autenticado = 0;
    SET p_ultima_marcacion = NULL;
    
    SELECT 
        u.num_usuario,
        u.num_documento,
        u.password_hash,
        u.estado,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        u.cargo,
        u.area,
        u.rol
    INTO
        p_num_usuario,
        p_num_documento,
        p_password_actual,
        p_estado_usuario,
        p_nombres,
        p_apellido_paterno,
        p_apellido_materno,
        p_email,
        p_cargo,
        p_area,
        p_rol
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE u.usuario = p_usuario
    LIMIT 1;
    
    IF p_num_usuario IS NULL THEN
        SET p_autenticado = 0;
        SET p_mensaje = 'Usuario no encontrado';
    ELSEIF p_estado_usuario = 'Bloqueado' THEN
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Usuario bloqueado. Contacte al administrador';
    ELSEIF p_estado_usuario = 'Inactivo' THEN
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Usuario inactivo';
    ELSEIF p_password_actual = p_password_hash THEN
        SET p_autenticado = 1;
        SET p_estado = 'Activo';
        SET p_mensaje = 'Autenticación exitosa';
        
        UPDATE TblUsuario 
        SET 
            intentos_fallidos = 0,
            fecha_ultimo_login = NOW()
        WHERE num_usuario = p_num_usuario;
        
        INSERT INTO TblLoginIntento (num_usuario, usuario, resultado)
        VALUES (p_num_usuario, p_usuario, 'Exitoso');
        
    ELSE
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Contraseña incorrecta';
        
        UPDATE TblUsuario 
        SET intentos_fallidos = intentos_fallidos + 1
        WHERE num_usuario = p_num_usuario;
        
        UPDATE TblUsuario 
        SET estado = 'Bloqueado'
        WHERE num_usuario = p_num_usuario 
        AND intentos_fallidos >= 5;
        
        INSERT INTO TblLoginIntento (num_usuario, usuario, resultado, razon)
        VALUES (p_num_usuario, p_usuario, 'Fallido', 'Contraseña incorrecta');
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_BuscarMateriales`(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT 
        m.id_material,
        m.codigo_material,
        m.nombre,
        m.precio_unitario,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblMateriales m
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE m.estado = 'ACTIVO'
    AND (
        p_termino_busqueda = '' 
        OR m.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
        OR m.codigo_material LIKE CONCAT('%', p_termino_busqueda, '%')
    )
    AND (
        p_id_categoria = 0
        OR m.id_categoria = p_id_categoria
    )
    ORDER BY m.codigo_material ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_BuscarPresupuestosAvanzado`(
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
            WHEN pr.estado IN ('APROBADO', 'RECHAZADO') THEN CONCAT(
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
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento = per_aprobador.num_documento
    
    -- FILTROS
    WHERE pr.estado != 'ELIMINADO'
    
    -- Filtro por número de presupuesto (búsqueda parcial)
    AND (
        p_numero IS NULL 
        OR p_numero = '' 
        OR pr.numero_presupuesto LIKE CONCAT('%', p_numero, '%')
    )
    
    -- Filtro por estado
    AND (
        p_estado IS NULL 
        OR p_estado = '' 
        OR pr.estado = p_estado
    )
    
    -- Filtro por proyecto
    AND (
        p_id_proyecto IS NULL 
        OR p_id_proyecto = 0 
        OR o.id_proyecto = p_id_proyecto
    )
    
    -- Filtro por obra
    AND (
        p_id_obra IS NULL 
        OR p_id_obra = 0 
        OR pr.id_obra = p_id_obra
    )
    
    -- Filtro por rango de fechas (desde)
    AND (
        p_fecha_desde IS NULL 
        OR DATE(pr.fecha_creacion) >= p_fecha_desde
    )
    
    -- Filtro por rango de fechas (hasta)
    AND (
        p_fecha_hasta IS NULL 
        OR DATE(pr.fecha_creacion) <= p_fecha_hasta
    )
    
    -- Filtro por nombre del creador (búsqueda parcial)
    AND (
        p_nombre_creador IS NULL 
        OR p_nombre_creador = '' 
        OR CONCAT(
            COALESCE(per.nombres, ''),
            ' ',
            COALESCE(per.apellido_paterno, ''),
            ' ',
            COALESCE(per.apellido_materno, '')
        ) LIKE CONCAT('%', p_nombre_creador, '%')
    )
    
    -- Filtro por rango de monto (desde)
    AND (
        p_monto_desde IS NULL 
        OR p_monto_desde = 0 
        OR pr.monto >= p_monto_desde
    )
    
    -- Filtro por rango de monto (hasta)
    AND (
        p_monto_hasta IS NULL 
        OR p_monto_hasta = 0 
        OR pr.monto <= p_monto_hasta
    )
    
    -- ORDEN: Por fecha más reciente
    ORDER BY pr.fecha_creacion DESC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearEmpresa`(
    IN p_ruc VARCHAR(11),
    IN p_nombre VARCHAR(255),
    IN p_latitud DECIMAL(10, 8),
    IN p_longitud DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_logo LONGBLOB
)
BEGIN
    DECLARE v_empresa_existe INT;
    DECLARE v_ruc_existe INT;
    DECLARE v_mensaje VARCHAR(500);

    -- Validar que el RUC no esté vacío
    IF p_ruc IS NULL OR p_ruc = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El RUC es requerido';
    END IF;

    -- Validar que el RUC tenga exactamente 11 dígitos
    IF LENGTH(p_ruc) != 11 OR NOT p_ruc REGEXP '^[0-9]{11}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El RUC debe tener exactamente 11 dígitos';
    END IF;

    -- Validar que el nombre no esté vacío
    IF p_nombre IS NULL OR p_nombre = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de la empresa es requerido';
    END IF;

    -- Validar que la latitud esté dentro del rango válido (-90 a 90)
    IF p_latitud < -90 OR p_latitud > 90 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La latitud debe estar entre -90 y 90';
    END IF;

    -- Validar que la longitud esté dentro del rango válido (-180 a 180)
    IF p_longitud < -180 OR p_longitud > 180 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La longitud debe estar entre -180 y 180';
    END IF;

    -- Validar que el radio sea positivo
    IF p_radio_metros <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El radio debe ser mayor a 0 metros';
    END IF;

    -- Verificar si el RUC ya existe
    SELECT COUNT(*) INTO v_ruc_existe
    FROM TblEmpresa
    WHERE ruc = p_ruc;
    
    IF v_ruc_existe > 0 THEN
        SET v_mensaje = CONCAT('Ya existe una empresa con el RUC: ', p_ruc);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;

    -- Verificar si la empresa con ese nombre ya existe
    SELECT COUNT(*) INTO v_empresa_existe
    FROM TblEmpresa
    WHERE nombre = p_nombre;
    
    IF v_empresa_existe > 0 THEN
        SET v_mensaje = CONCAT('Ya existe una empresa con el nombre: ', p_nombre);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;

    -- Insertar la nueva empresa CON LOGO
    INSERT INTO TblEmpresa (ruc, nombre, latitud, longitud, radio_metros, activa, logo)
    VALUES (p_ruc, p_nombre, p_latitud, p_longitud, p_radio_metros, 1, p_logo);

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearMaterial`(
    IN p_nombre VARCHAR(255),
    IN p_id_categoria INT,
    IN p_codigo_unidad VARCHAR(10),
    IN p_descripcion TEXT,
    OUT p_id_material_creado INT,
    OUT p_codigo_generado VARCHAR(20),
    OUT p_mensaje VARCHAR(500)
)
BEGIN
    DECLARE v_ultimo_codigo VARCHAR(20);
    DECLARE v_numero_actual INT;
    DECLARE v_nuevo_numero INT;
    DECLARE v_nuevo_codigo VARCHAR(20);
    DECLARE v_existe_nombre INT DEFAULT 0;
    DECLARE v_id_unidad INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
            p_mensaje = MESSAGE_TEXT;
        SET p_id_material_creado = NULL;
        SET p_codigo_generado = NULL;
    END;

    START TRANSACTION;

    -- Inicializar variables de salida
    SET p_id_material_creado = NULL;
    SET p_codigo_generado = NULL;
    SET p_mensaje = '';

    -- Validar que el nombre no exista
    SELECT COUNT(*) INTO v_existe_nombre 
    FROM TblMateriales 
    WHERE LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre)) 
    AND estado != 'ELIMINADO';

    IF v_existe_nombre > 0 THEN
        SET p_mensaje = CONCAT('Ya existe un material con el nombre "', p_nombre, '"');
        ROLLBACK;
    ELSE
        -- Buscar el ID de la unidad de medida
        SELECT id_unidad INTO v_id_unidad
        FROM TblUnidadMedida 
        WHERE codigo = p_codigo_unidad AND estado = 'ACTIVO';

        IF v_id_unidad IS NULL THEN
            SET p_mensaje = CONCAT('Unidad de medida "', p_codigo_unidad, '" no encontrada');
            ROLLBACK;
        ELSE
            -- Obtener el último código numérico
            SELECT codigo_material INTO v_ultimo_codigo
            FROM TblMateriales 
            WHERE codigo_material REGEXP '^MAT-[0-9]+$'
            ORDER BY CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED) DESC
            LIMIT 1;

            -- Si no hay códigos previos, empezar desde 001
            IF v_ultimo_codigo IS NULL THEN
                SET v_nuevo_numero = 1;
            ELSE
                -- Extraer el número del código (MAT-001 -> 001 -> 1)
                SET v_numero_actual = CAST(SUBSTRING(v_ultimo_codigo, 5) AS UNSIGNED);
                SET v_nuevo_numero = v_numero_actual + 1;
            END IF;

            -- Generar el nuevo código con formato MAT-XXX
            SET v_nuevo_codigo = CONCAT('MAT-', LPAD(v_nuevo_numero, 3, '0'));

            -- Insertar el nuevo material
            INSERT INTO TblMateriales (
                nombre,
                codigo_material,
                descripcion,
                id_categoria,
                id_unidad,
                cantidad_stock,
                cantidad_minima,
                precio_unitario,
                estado,
                fecha_creacion
            ) VALUES (
                TRIM(p_nombre),
                v_nuevo_codigo,
                TRIM(COALESCE(p_descripcion, '')),
                p_id_categoria,
                v_id_unidad,
                0, -- cantidad_stock inicial
                1, -- cantidad_minima por defecto
                0.00, -- precio_unitario inicial
                'ACTIVO',
                NOW()
            );

            -- Obtener el ID del material creado
            SET p_id_material_creado = LAST_INSERT_ID();
            SET p_codigo_generado = v_nuevo_codigo;
            SET p_mensaje = CONCAT('Material "', p_nombre, '" creado exitosamente con código "', v_nuevo_codigo, '"');

            COMMIT;
        END IF;
    END IF;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearRequerimientoCompleto`(
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
        FROM TblFlujoAprobacionCargos 
        WHERE id_tipo_documento = v_id_tipo_documento 
        AND activo = 1 
        AND es_requerido = 1
        ORDER BY numero_paso;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Validar usuario
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_usuario = p_num_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar JSON
    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos';
    END IF;
    
    -- Generar código
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;
    
    -- Calcular cantidad
    SELECT COALESCE(SUM(pd.cantidad), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle;
    
    -- Obtener presupuesto si no se proporciona
    IF p_id_presupuesto IS NULL THEN
        SELECT COALESCE(pd.id_presupuesto, NULL)
        INTO p_id_presupuesto
        FROM JSON_TABLE(
            p_detalles_json, 
            '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')
        ) jt
        INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
        LIMIT 1;
    END IF;
    
    -- Insertar requerimiento principal
    INSERT INTO TblRequerimiento (
        codigo, num_usuario, id_presupuesto, descripcion, cantidad, estado,
        observaciones, fecha_creacion
    ) VALUES (
        v_codigo, p_num_usuario, p_id_presupuesto, p_descripcion,
        COALESCE(v_cantidad_total, 0), 'PENDIENTE',
        COALESCE(p_observaciones, ''), NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- ========================================================================
    -- INSERTAR DETALLES - CAMPOS REALES (sin unidad_medida)
    -- ========================================================================
    INSERT INTO TblRequerimientoDetalle (
        id_requerimiento, id_material, tipo_item, descripcion,
        cantidad, observaciones, fecha_creacion
    )
    SELECT
        p_id_requerimiento_created,
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
            WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
            ELSE pd.id_material
        END,
        COALESCE(pd.tipo_item, 'MATERIAL'),
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN 
                COALESCE(pd.descripcion, 'Servicio sin descripción')
            ELSE 
                COALESCE(m.nombre, pd.descripcion, 'Material sin especificar')
        END,
        COALESCE(pd.cantidad, 1),
        NULL,
        NOW()
    FROM JSON_TABLE(
        p_detalles_json, '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0;
    
    -- ========================================================================
    -- CREAR REGISTROS DE APROBACIÓN PARA CADA PASO DEL FLUJO
    -- ========================================================================
    OPEN flujo_cursor;
    read_loop: LOOP
        FETCH flujo_cursor INTO v_numero_paso, v_id_cargo;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        INSERT INTO TblRegistroAprobacion (
            id_tipo_documento, id_documento_referencia, numero_paso,
            id_cargo_aprobador, num_documento_aprobador, estado_aprobacion,
            comentario, fecha_asignacion, fecha_aprobacion
        ) VALUES (
            v_id_tipo_documento, p_id_requerimiento_created, v_numero_paso,
            v_id_cargo, NULL, 'PENDIENTE', NULL, NOW(), NULL
        );
    END LOOP;
    CLOSE flujo_cursor;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearUsuarioCompleto`(
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarEmpresa`(
    IN p_id INT
)
BEGIN
    DECLARE v_empresa_existe INT;
    DECLARE v_usuarios_asociados INT;
    DECLARE v_mensaje VARCHAR(500);
    
    -- Validar que la empresa existe
    SELECT COUNT(*) INTO v_empresa_existe
    FROM tblEmpresa
    WHERE id = p_id;
    
    IF v_empresa_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La empresa no existe';
    END IF;
    
    -- Verificar si hay usuarios asociados
    SELECT COUNT(*) INTO v_usuarios_asociados
    FROM TblUsuario
    WHERE id_empresa = p_id;
    
    IF v_usuarios_asociados > 0 THEN
        SET v_mensaje = CONCAT('No se puede eliminar. Hay ', v_usuarios_asociados, ' usuario(s) asociado(s) a esta empresa');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- Eliminar la empresa
    DELETE FROM tblEmpresa
    WHERE id = p_id;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarFlujoAprobacion`(
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarRequerimientoCompleto`(
            IN p_id_requerimiento INT,
            OUT p_resultado VARCHAR(20),
            OUT p_mensaje VARCHAR(255),
            OUT p_detalles_eliminados INT,
            OUT p_aprobaciones_eliminadas INT
        )
sp_main: BEGIN
            DECLARE v_id_presupuesto INT;
            DECLARE v_cantidad_total_requerimiento DECIMAL(12,2);
            DECLARE v_timestamp DATETIME DEFAULT NOW();
            
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                SET p_resultado = 'ERROR';
                SET p_mensaje = 'Error ejecutando procedimiento';
                ROLLBACK;
            END;
            
            SET p_detalles_eliminados = 0;
            SET p_aprobaciones_eliminadas = 0;
            
            IF NOT EXISTS (SELECT 1 FROM TblRequerimiento WHERE id_requerimiento = p_id_requerimiento) THEN
                SET p_resultado = 'ERROR';
                SET p_mensaje = 'Requerimiento no encontrado';
                LEAVE sp_main;
            END IF;
            
            -- Obtener datos del requerimiento
            SELECT 
                id_presupuesto,
                COALESCE((SELECT COALESCE(SUM(cantidad), 0) FROM TblRequerimientoDetalle WHERE id_requerimiento = p_id_requerimiento), 0)
            INTO v_id_presupuesto, v_cantidad_total_requerimiento
            FROM TblRequerimiento
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Contar detalles antes de eliminar
            SELECT COUNT(*) INTO p_detalles_eliminados
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Eliminar detalles
            DELETE FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Contar aprobaciones antes de eliminar
            SELECT COUNT(*) INTO p_aprobaciones_eliminadas
            FROM TblRegistroAprobacion
            WHERE id_documento_referencia = p_id_requerimiento
              AND id_tipo_documento = 2;
            
            -- Eliminar aprobaciones
            DELETE FROM TblRegistroAprobacion
            WHERE id_documento_referencia = p_id_requerimiento
              AND id_tipo_documento = 2;
            
            -- Eliminar requerimiento
            DELETE FROM TblRequerimiento
            WHERE id_requerimiento = p_id_requerimiento;
            
            -- Reversar cambios en presupuesto
            IF v_id_presupuesto IS NOT NULL AND v_id_presupuesto > 0 THEN
                UPDATE TblPresupuesto
                SET 
                    cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total_requerimiento),
                    cantidad_saldo = cantidad_saldo + v_cantidad_total_requerimiento,
                    monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total_requerimiento),
                    fecha_actualizacion = NOW()
                WHERE id_presupuesto = v_id_presupuesto;
                
                UPDATE TblPresupuestoDetalle pd
                SET 
                    pd.cantidad_consumida = 0,
                    pd.cantidad_saldo = pd.cantidad
                WHERE pd.id_presupuesto = v_id_presupuesto;
            END IF;
            
            SET p_resultado = 'OK';
            SET p_mensaje = 'Requerimiento eliminado completamente';
            
        END sp_main
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_EliminarUsuario`(
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
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_GuardarAccesosUsuario`(
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_LoginMarcacionKallpa`(
    IN p_usuario VARCHAR(100),
    IN p_password_hash VARCHAR(255),
    OUT p_autenticado INT,
    OUT p_num_usuario INT,
    OUT p_num_documento INT,
    OUT p_nombres VARCHAR(100),
    OUT p_apellido_paterno VARCHAR(100),
    OUT p_apellido_materno VARCHAR(100),
    OUT p_email VARCHAR(120),
    OUT p_cargo VARCHAR(100),
    OUT p_area VARCHAR(100),
    OUT p_rol VARCHAR(50),
    OUT p_estado VARCHAR(20),
    OUT p_ultima_marcacion DATETIME,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE p_password_actual VARCHAR(255);
    DECLARE p_intento INT;
    DECLARE p_estado_usuario VARCHAR(20);
    
    SET p_autenticado = 0;
    
    -- Buscar usuario
    SELECT 
        u.num_usuario,
        u.num_documento,
        u.password_hash,
        u.intentos_fallidos,
        u.estado,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        u.cargo,
        u.area,
        u.rol
    INTO
        p_num_usuario,
        p_num_documento,
        p_password_actual,
        p_intento,
        p_estado_usuario,
        p_nombres,
        p_apellido_paterno,
        p_apellido_materno,
        p_email,
        p_cargo,
        p_area,
        p_rol
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE u.usuario = p_usuario
    LIMIT 1;
    
    -- Si no encontró usuario
    IF p_num_usuario IS NULL THEN
        SET p_autenticado = 0;
        SET p_mensaje = 'Usuario no encontrado';
    -- Si usuario está bloqueado
    ELSEIF p_estado_usuario = 'Bloqueado' THEN
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Usuario bloqueado. Contacte al administrador';
    -- Si usuario está inactivo
    ELSEIF p_estado_usuario = 'Inactivo' THEN
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Usuario inactivo';
    -- Usuario existe y está activo - validar contraseña
    ELSEIF p_password_actual = p_password_hash THEN
        -- Contraseña correcta
        SET p_autenticado = 1;
        SET p_estado = 'Activo';
        SET p_mensaje = 'Autenticación exitosa';
        
        -- Resetear intentos fallidos
        UPDATE TblUsuario 
        SET 
            intentos_fallidos = 0,
            fecha_ultimo_login = NOW()
        WHERE num_usuario = p_num_usuario;
        
        -- Registrar intento exitoso
        INSERT INTO TblLoginIntento (num_usuario, usuario, resultado)
        VALUES (p_num_usuario, p_usuario, 'Exitoso');
        
        -- Obtener última marcación
        SELECT MAX(CONCAT(m.fecha_marcacion, ' ', m.hora_marcacion)) 
        INTO p_ultima_marcacion
        FROM TblMarcacion m
        WHERE m.num_usuario = p_num_usuario;
        
    ELSE
        -- Contraseña incorrecta
        SET p_autenticado = 0;
        SET p_estado = p_estado_usuario;
        SET p_mensaje = 'Contraseña incorrecta';
        
        -- Incrementar intentos fallidos
        UPDATE TblUsuario 
        SET intentos_fallidos = intentos_fallidos + 1
        WHERE num_usuario = p_num_usuario;
        
        -- Bloquear si hay 5+ intentos fallidos
        UPDATE TblUsuario 
        SET estado = 'Bloqueado'
        WHERE num_usuario = p_num_usuario 
        AND intentos_fallidos >= 5;
        
        -- Registrar intento fallido
        INSERT INTO TblLoginIntento (num_usuario, usuario, resultado, razon)
        VALUES (p_num_usuario, p_usuario, 'Fallido', 'Contraseña incorrecta');
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerAccesosUsuario`(
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
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerAreas`()
BEGIN
    SELECT 
        id_area,
        nombre
    FROM TblArea
    WHERE estado = 'Activo'
    ORDER BY nombre;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerCargosPorArea`(
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
            END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerCategoriasMaterial`()
BEGIN
    SELECT 
        id_categoria,
        nombre
    FROM TblCategoriaMaterial
    ORDER BY nombre ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerDetalleDocumentoPorCargo`(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT,
    IN p_id_cargo INT
)
    READS SQL DATA
BEGIN
    -- Validar que el cargo tiene acceso a este documento
    -- mediante TblRegistroAprobacion con estado PENDIENTE
    
    DECLARE v_tiene_acceso INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_tiene_acceso
    FROM TblRegistroAprobacion ra
    INNER JOIN TblFlujoAprobacionCargos fac
        ON fac.id_tipo_documento = ra.id_tipo_documento
        AND fac.numero_paso = ra.numero_paso
        AND fac.id_cargo = p_id_cargo
    WHERE ra.id_tipo_documento = p_id_tipo_documento
        AND ra.id_documento_referencia = p_id_documento
        AND ra.estado_aprobacion = 'PENDIENTE'
        AND fac.activo = 1
        AND fac.es_requerido = 1;
    
    IF v_tiene_acceso = 0 THEN
        SELECT 'ERROR' AS resultado, 'Acceso denegado' AS mensaje;
    ELSE
        -- Retornar información base del documento + paso actual
        SELECT 
            tda.id_tipo_documento,
            tda.nombre AS nombre_documento,
            ra.id_documento_referencia AS id_documento,
            ra.numero_paso,
            ra.fecha_asignacion,
            fac.nombre_paso,
            fac.descripcion AS descripcion_paso
        FROM TblRegistroAprobacion ra
        INNER JOIN TblTipoDocumentoAprobacion tda
            ON tda.id_tipo_documento = ra.id_tipo_documento
        INNER JOIN TblFlujoAprobacionCargos fac
            ON fac.id_tipo_documento = ra.id_tipo_documento
            AND fac.numero_paso = ra.numero_paso
        WHERE ra.id_tipo_documento = p_id_tipo_documento
            AND ra.id_documento_referencia = p_id_documento
            AND ra.estado_aprobacion = 'PENDIENTE'
        LIMIT 1;
    END IF;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerDetallesPresupuestosPendientes`(
    IN p_id_tipo_documento INT
)
    READS SQL DATA
BEGIN
    SELECT DISTINCT
        p.id_presupuesto,
        p.numero_presupuesto,
        p.monto,
        'SOL' AS moneda,
        p.estado,
        p.fecha_creacion,
        COALESCE(p.observaciones, '') AS observaciones,
        COALESCE(o.nombre, 'Sin obra') AS nombre_obra,
        COALESCE(CONCAT(per.nombres, ' ', per.apellido_paterno), '') AS nombres_responsable,
        COALESCE(per.apellido_paterno, '') AS apellido_responsable,
        COALESCE(u.usuario, '') AS usuario_responsable
    FROM 
        TblPresupuesto p
    LEFT JOIN 
        TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN 
        TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN 
        TblPersona per ON p.num_documento = per.num_documento
    WHERE 
        p.estado = 'PENDIENTE'
        -- Solo si existen registros de aprobación pendientes O no existen registros
        AND (
            EXISTS (
                SELECT 1 
                FROM TblRegistroAprobacion ra 
                WHERE ra.id_documento_referencia = p.id_presupuesto
                  AND ra.id_tipo_documento = p_id_tipo_documento
                  AND ra.estado_aprobacion = 'PENDIENTE'
            )
            OR NOT EXISTS (
                SELECT 1 
                FROM TblRegistroAprobacion ra 
                WHERE ra.id_documento_referencia = p.id_presupuesto
                  AND ra.id_tipo_documento = p_id_tipo_documento
            )
        )
    ORDER BY 
        p.fecha_creacion ASC;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerDocumentosPendientesPorCargo`(
    IN p_id_cargo INT,
    IN p_id_tipo_documento INT
)
    READS SQL DATA
BEGIN
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
    WHERE 
        ra.estado_aprobacion = 'PENDIENTE'
        AND ra.id_cargo_aprobador = p_id_cargo
        AND (p_id_tipo_documento IS NULL OR ra.id_tipo_documento = p_id_tipo_documento)
        AND tda.activo = 1
        AND tda.requiere_aprobacion = 1
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
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerEmpresaPorId`(
    IN p_id INT
)
BEGIN
    SELECT 
        id,
        ruc,
        nombre,
        latitud,
        longitud,
        radio_metros,
        activa,
        fecha_creacion,
        fecha_actualizacion
    FROM tblEmpresa
    WHERE id = p_id
    LIMIT 1;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerEmpresas`()
BEGIN
    SELECT 
        id_empresa,
        nombre
    FROM TblEmpresa
    WHERE activa = 1
    ORDER BY nombre ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerHistorialAprobacion`(
        IN p_id_tipo_documento INT,
        IN p_id_documento_referencia INT
    )
    READS SQL DATA
BEGIN
        SELECT 
            ra.id_registro,
            ra.id_tipo_documento,
            ra.id_documento_referencia,
            ra.numero_paso,
            c.nombre AS cargo_aprobador,
            p.nombre AS nombre_aprobador,
            p.apellidos AS apellidos_aprobador,
            ra.estado_aprobacion,
            ra.comentario,
            ra.fecha_asignacion,
            ra.fecha_aprobacion,
            CASE 
                WHEN ra.estado_aprobacion = 'APROBADO' THEN 'Aprobado'
                WHEN ra.estado_aprobacion = 'RECHAZADO' THEN 'Rechazado'
                ELSE 'Pendiente'
            END AS estado_texto
        FROM TblRegistroAprobacion ra
        LEFT JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
        LEFT JOIN TblPersona p ON ra.num_documento_aprobador = p.num_documento
        WHERE ra.id_tipo_documento = p_id_tipo_documento
          AND ra.id_documento_referencia = p_id_documento_referencia
        ORDER BY ra.numero_paso ASC, ra.fecha_aprobacion ASC;
    END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerInfoUsuarioKallpa`(
    IN p_num_documento INT
)
BEGIN
    -- Obtener información del usuario con cargo y área desde TblCargo
    SELECT 
        u.num_usuario,
        u.num_documento,
        u.usuario,
        u.rol,
        u.estado,
        u.fecha_ultimo_login,
        CONCAT(
            COALESCE(p.nombres, ''),
            CASE WHEN p.nombres IS NOT NULL AND p.apellido_paterno IS NOT NULL THEN ' ' ELSE '' END,
            COALESCE(p.apellido_paterno, ''),
            CASE WHEN (p.nombres IS NOT NULL OR p.apellido_paterno IS NOT NULL) AND p.apellido_materno IS NOT NULL THEN ' ' ELSE '' END,
            COALESCE(p.apellido_materno, '')
        ) AS nombre_completo,
        p.documento_numero,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        p.celular,
        p.direccion,
        u.id_cargo,
        c.nombre AS cargo,
        c.id_area,
        a.nombre AS area
    FROM TblUsuario u
    LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    WHERE u.num_documento = p_num_documento
    LIMIT 1;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerNotificacionesAprobacion`(
    IN p_id_cargo INT
)
    READS SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR' AS resultado;
    END;

    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS tipo_documento,
        tda.icono,
        tda.color,
        COUNT(DISTINCT CONCAT(ra.id_tipo_documento, '_', ra.id_documento_referencia)) AS cantidad_pendientes,
        fa.numero_paso AS proximo_paso,
        fa.nombre_paso,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo
    FROM TblTipoDocumentoAprobacion tda
    LEFT JOIN TblFlujoAprobacionCargos fa ON tda.id_tipo_documento = fa.id_tipo_documento 
        AND fa.id_cargo = p_id_cargo 
        AND fa.activo = 1
    LEFT JOIN TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
        AND ra.estado_aprobacion = 'PENDIENTE'
        AND ra.numero_paso = fa.numero_paso
    WHERE tda.activo = 1
    AND tda.requiere_aprobacion = 1
    AND fa.id_flujo_cargo IS NOT NULL
    GROUP BY tda.id_tipo_documento, tda.nombre, tda.icono, tda.color, 
             fa.numero_paso, fa.nombre_paso
    HAVING cantidad_pendientes > 0
    ORDER BY cantidad_pendientes DESC, tda.nombre ASC;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerNotificacionesPendientes`(
    IN p_id_cargo INT
)
    READS SQL DATA
BEGIN
    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        tda.icono,
        tda.color,
        tda.descripcion AS descripcion_documento,
        COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
        fc.numero_paso,
        fc.nombre_paso AS descripcion_paso,
        fc.descripcion AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        TblFlujoAprobacionCargos fc ON tda.id_tipo_documento = fc.id_tipo_documento
    INNER JOIN 
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fc.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        tda.activo = 1
        AND tda.requiere_aprobacion = 1
        AND fc.activo = 1
        AND fc.id_cargo = p_id_cargo
        AND fc.es_requerido = 1
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        fc.numero_paso,
        fc.nombre_paso
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerObrasPorProyecto`(
    IN p_id_proyecto INT
)
BEGIN
    SELECT 
        id_obra,
        nombre
    FROM TblObra
    WHERE id_proyecto = p_id_proyecto
    ORDER BY nombre ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPasosFlujoRequerimiento`(
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
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestoDetalles`(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        d.tipo_item,
        d.descripcion,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        COALESCE(m.nombre, d.descripcion) as nombre_item,
        m.codigo_material,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE d.id_presupuesto = p_id_presupuesto
    ORDER BY d.tipo_item ASC, d.id_detalle ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestoEditar`(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.id_empresa,
        e.nombre as nombre_empresa,
        p.id_obra,
        p.num_documento,
        p.monto,
        p.estado,
        p.observaciones,
        o.id_proyecto,
        o.nombre as nombre_obra,
        pr.nombre as nombre_proyecto
    FROM TblPresupuesto p
    LEFT JOIN TblEmpresa e ON p.id_empresa = e.id_empresa
    LEFT JOIN TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    WHERE p.id_presupuesto = p_id_presupuesto;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestoPDF`(
    IN p_id_presupuesto INT
)
    READS SQL DATA
BEGIN
    -- ====================================================================
    -- RESULT SET 1: Información del Presupuesto (CON DESGLOSE COMPLETO)
    -- ====================================================================
    SELECT 
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        COALESCE(pr.monto_total, 0) as monto_total,
        COALESCE(pr.gastos_generales, 0) as gastos_generales,
        COALESCE(pr.utilidad, 0) as utilidad,
        COALESCE(pr.igv, 0) as igv,
        COALESCE(pr.supervision_obra, 0) as supervision_obra,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.num_documento,
        e.nombre as nombre_empresa,
        e.logo as empresa_logo,
        o.id_obra,
        o.nombre as nombre_obra,
        o.codigo_obra,
        pr.id_obra,
        pry.id_proyecto,
        pry.nombre as nombre_proyecto,
        pry.codigo_proyecto,
        COALESCE(p.nombres, '') as usuario_nombres,
        CONCAT(COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as usuario_apellido,
        COALESCE(p.email, '') as usuario_email,
        COALESCE(p.celular, '') as usuario_celular
    FROM TblPresupuesto pr
    LEFT JOIN TblEmpresa e ON pr.id_empresa = e.id_empresa
    LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
    LEFT JOIN TblProyecto pry ON o.id_proyecto = pry.id_proyecto
    LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
    LEFT JOIN TblPersona p ON pr.num_documento = p.num_documento
    WHERE pr.id_presupuesto = p_id_presupuesto;
    
    -- ====================================================================
    -- RESULT SET 2: Detalles de Materiales (TODO LO NECESARIO PARA TABLA)
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion,
        COALESCE(m.nombre, d.descripcion) as material_nombre,
        COALESCE(m.codigo_material, '') as codigo_material,
        COALESCE(um.nombre, 'und') as unidad_medida,
        COALESCE(c.nombre, 'General') as categoria
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
    AND d.tipo_item IN ('MATERIAL', '')
    ORDER BY d.id_detalle ASC;
    
    -- ====================================================================
    -- RESULT SET 3: Detalles de Servicios (TODO LO NECESARIO PARA TABLA)
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion as servicio_nombre,
        d.descripcion,
        d.observaciones as observaciones_detalle
    FROM TblPresupuestoDetalle d
    WHERE d.id_presupuesto = p_id_presupuesto
    AND d.tipo_item = 'SERVICIO'
    ORDER BY d.id_detalle ASC;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestoRequerimiento`()
    READS SQL DATA
BEGIN
    SELECT DISTINCT
        r.id_requerimiento,
        r.codigo,
        r.descripcion,
        r.cantidad,
        r.estado,
        r.observaciones,
        r.fecha_creacion,
        r.fecha_actualizacion,
        r.id_presupuesto,
        u.num_usuario,
        u.usuario as usuario_nombre,
        p.nombres as solicitante_nombres,
        p.apellido_paterno as solicitante_apellido,
        CONCAT(p.nombres, ' ', p.apellido_paterno) as solicitante
    FROM TblRequerimiento r
    INNER JOIN TblUsuario u ON r.num_usuario = u.num_usuario
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE r.estado != 'ELIMINADO'
    ORDER BY r.fecha_creacion DESC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestosFiltrado`(
    IN p_estado VARCHAR(50),
    IN p_id_proyecto INT,
    IN p_id_obra INT,
    IN p_num_documento INT,
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE,
    IN p_numero_presupuesto VARCHAR(50)
)
BEGIN
    -- ========================================================================
    -- Obtener presupuestos con filtros dinámicos
    -- ========================================================================
    
    SELECT 
        -- CAMPOS DE PRESUPUESTO
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.fecha_actualizacion,
        
        -- CAMPOS DE PROYECTO
        p.id_proyecto,
        p.codigo_proyecto,
        p.nombre as nombre_proyecto,
        
        -- CAMPOS DE OBRA
        o.id_obra,
        o.codigo_obra,
        o.nombre as nombre_obra,
        o.tipo_obra,
        
        -- CAMPOS DE MATERIAL
        m.id_material,
        m.codigo_material,
        m.nombre as nombre_material,
        
        -- CAMPOS DE UNIDAD
        um.nombre as nombre_unidad,
        
        -- CAMPOS DE CATEGORÍA
        cm.nombre as categoria_material,
        
        -- CAMPOS DE USUARIO
        u.num_usuario,
        u.num_documento,
        per.nombres as usuario_nombre,
        per.apellido_paterno,
        CONCAT(per.nombres, ' ', per.apellido_paterno) as usuario_completo,
        per.email as usuario_email,
        
        -- CAMPOS ADICIONALES
        CASE pr.estado
            WHEN 'PENDIENTE' THEN 'Pendiente de aprobación'
            WHEN 'APROBADO' THEN 'Aprobado'
            WHEN 'RECHAZADO' THEN 'Rechazado'
            WHEN 'EJECUTANDO' THEN 'En ejecución'
            WHEN 'COMPLETADO' THEN 'Completado'
            WHEN 'CANCELADO' THEN 'Cancelado'
            ELSE 'Estado desconocido'
        END as estado_descripcion,
        
        DATEDIFF(CURDATE(), DATE(pr.fecha_creacion)) as dias_desde_creacion
        
    FROM TblPresupuesto pr
    
    -- JOINS PRINCIPALES
    INNER JOIN TblObra o ON pr.id_obra = o.id_obra
    INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    
    -- JOINS DE MATERIAL
    INNER JOIN TblMateriales m ON pr.id_material = m.id_material
    INNER JOIN TblUnidadMedida um ON m.id_unidad_medida = um.id_unidad_medida
    INNER JOIN TblCategoriaMaterial cm ON m.id_categoria_material = cm.id_categoria_material
    
    -- JOINS DE USUARIO
    INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
    INNER JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- FILTROS DINÁMICOS
    WHERE 1=1
        -- Filtro por estado (si se proporciona)
        AND (p_estado IS NULL OR pr.estado = p_estado)
        
        -- Filtro por proyecto (si se proporciona)
        AND (p_id_proyecto IS NULL OR p.id_proyecto = p_id_proyecto)
        
        -- Filtro por obra (si se proporciona)
        AND (p_id_obra IS NULL OR o.id_obra = p_id_obra)
        
        -- Filtro por usuario (si se proporciona)
        AND (p_num_documento IS NULL OR u.num_documento = p_num_documento)
        
        -- Filtro por rango de fechas (si se proporciona)
        AND (p_fecha_desde IS NULL OR DATE(pr.fecha_creacion) >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR DATE(pr.fecha_creacion) <= p_fecha_hasta)
        
        -- Filtro por número de presupuesto (búsqueda LIKE si se proporciona)
        AND (p_numero_presupuesto IS NULL OR pr.numero_presupuesto LIKE CONCAT('%', p_numero_presupuesto, '%'))
        
        -- Excluir eliminados
        AND pr.estado != 'ELIMINADO'
    
    -- ORDEN
    ORDER BY 
        pr.fecha_creacion DESC,
        p.codigo_proyecto ASC,
        o.codigo_obra ASC;
        
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestosReporte`()
BEGIN
    -- ========================================================================
    -- Obtener TODOS los presupuestos con información completa
    -- ========================================================================
    
    SELECT 
        -- CAMPOS DE PRESUPUESTO
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.fecha_actualizacion,
        
        -- CAMPOS DE PROYECTO
        p.id_proyecto,
        p.codigo_proyecto,
        p.nombre as nombre_proyecto,
        p.descripcion as descripcion_proyecto,
        
        -- CAMPOS DE OBRA
        o.id_obra,
        o.codigo_obra,
        o.nombre as nombre_obra,
        o.descripcion as descripcion_obra,
        o.tipo_obra,
        o.observaciones as observaciones_obra,
        
        -- CAMPOS DE MATERIAL
        m.id_material,
        m.codigo_material,
        m.nombre as nombre_material,
        m.descripcion as descripcion_material,
        m.cantidad_disponible,
        
        -- CAMPOS DE UNIDAD DE MEDIDA
        um.codigo_unidad,
        um.nombre as nombre_unidad,
        
        -- CAMPOS DE CATEGORÍA MATERIAL
        cm.nombre as categoria_material,
        
        -- CAMPOS DE USUARIO (desde TblPersona)
        u.num_usuario,
        u.num_documento,
        per.nombres as usuario_nombre,
        per.apellido_paterno,
        per.apellido_materno,
        per.email as usuario_email,
        per.celular as usuario_celular,
        
        -- CAMPOS COMBINADOS (para reporte)
        CONCAT(per.nombres, ' ', per.apellido_paterno) as usuario_completo,
        
        -- ESTADO DESCRIPCIÓN
        CASE pr.estado
            WHEN 'PENDIENTE' THEN 'Pendiente de aprobación'
            WHEN 'APROBADO' THEN 'Aprobado'
            WHEN 'RECHAZADO' THEN 'Rechazado'
            WHEN 'EJECUTANDO' THEN 'En ejecución'
            WHEN 'COMPLETADO' THEN 'Completado'
            WHEN 'CANCELADO' THEN 'Cancelado'
            WHEN 'ELIMINADO' THEN 'Eliminado'
            ELSE 'Estado desconocido'
        END as estado_descripcion,
        
        -- CAMPO PARA DÍAS DESDE CREACIÓN
        DATEDIFF(CURDATE(), DATE(pr.fecha_creacion)) as dias_desde_creacion
        
    FROM TblPresupuesto pr
    
    -- JOINS PRINCIPALES (presupuesto → obra → proyecto)
    INNER JOIN TblObra o ON pr.id_obra = o.id_obra
    INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    
    -- JOINS DE MATERIAL
    INNER JOIN TblMateriales m ON pr.id_material = m.id_material
    INNER JOIN TblUnidadMedida um ON m.id_unidad_medida = um.id_unidad_medida
    INNER JOIN TblCategoriaMaterial cm ON m.id_categoria_material = cm.id_categoria_material
    
    -- JOINS DE USUARIO
    INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
    INNER JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- FILTRO: Excluir eliminados (opcional, comentar para incluir)
    -- WHERE pr.estado != 'ELIMINADO'
    
    -- ORDEN
    ORDER BY 
        pr.fecha_creacion DESC,
        p.codigo_proyecto ASC,
        o.codigo_obra ASC,
        pr.numero_presupuesto ASC;
        
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerProximoPasoAprobacion`(
        IN p_id_tipo_documento INT,
        IN p_id_documento_referencia INT
    )
    READS SQL DATA
BEGIN
        SELECT 
            fa.id_flujo_aprobacion,
            fa.numero_paso,
            fa.id_cargo,
            c.nombre AS nombre_cargo,
            fa.nombre_paso,
            fa.descripcion,
            fa.es_final,
            fa.es_requerido,
            fa.permite_rechazo
        FROM TblFlujoAprobacion fa
        JOIN TblCargo c ON fa.id_cargo = c.id_cargo
        WHERE fa.id_tipo_documento = p_id_tipo_documento
          AND fa.activo = 1
          AND fa.numero_paso > (
              SELECT COALESCE(MAX(numero_paso), 0)
              FROM TblRegistroAprobacion
              WHERE id_tipo_documento = p_id_tipo_documento
                AND id_documento_referencia = p_id_documento_referencia
                AND estado_aprobacion = 'APROBADO'
          )
        ORDER BY fa.numero_paso ASC
        LIMIT 1;
    END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerProximoPasoConCargos`(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT
)
    COMMENT 'Obtiene el próximo paso de aprobación con TODOS los cargos que pueden aprobar'
BEGIN
    DECLARE v_paso_actual INT DEFAULT 0;
    DECLARE v_proximo_paso INT;
    
    -- Obtener último paso aprobado
    SELECT IFNULL(MAX(numero_paso), 0) INTO v_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = p_id_tipo_documento
    AND id_documento_referencia = p_id_documento
    AND estado_aprobacion = 'APROBADO';
    
    SET v_proximo_paso = v_paso_actual + 1;
    
    -- Retornar información del próximo paso con todos los cargos
    SELECT 
        fa.id_flujo_aprobacion,
        fa.numero_paso,
        fa.nombre_paso,
        fa.descripcion,
        fa.es_final,
        fa.es_requerido,
        fa.permite_rechazo,
        fa.id_tipo_documento,
        COUNT(DISTINCT c.id_cargo) as cantidad_opciones,
        GROUP_CONCAT(
            JSON_OBJECT(
                'id_cargo', c.id_cargo,
                'nombre_cargo', c.nombre,
                'descripcion', c.descripcion,
                'id_area', c.id_area,
                'orden', fc.orden_visualizacion
            )
            ORDER BY fc.orden_visualizacion
        ) as cargos_aprobadores_json
    
    FROM TblFlujoAprobacion fa
    JOIN TblFlujoAprobacionCargos fc 
        ON fa.id_flujo_aprobacion = fc.id_flujo_aprobacion AND fc.activo = 1
    JOIN TblCargo c 
        ON fc.id_cargo = c.id_cargo
    
    WHERE fa.id_tipo_documento = p_id_tipo_documento
    AND fa.numero_paso = v_proximo_paso
    AND fa.activo = 1
    
    GROUP BY fa.id_flujo_aprobacion;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerProyectos`()
BEGIN
    SELECT 
        id_proyecto,
        nombre
    FROM TblProyecto
    ORDER BY nombre ASC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientoCompleto`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    
    -- Verificar que el requerimiento existe
    SELECT COUNT(*) INTO v_existe
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    
    -- ========================================================================
    -- RESULT SET 1: DATOS DEL REQUERIMIENTO CON USUARIO Y PRESUPUESTO
    -- ========================================================================
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
        -- Usuario completo via JOIN
        CONCAT(
            COALESCE(p.nombres, ''), ' ', 
            COALESCE(p.apellido_paterno, ''), ' ', 
            COALESCE(p.apellido_materno, '')
        ) as usuario_completo,
        -- Presupuesto via JOIN
        pr.numero_presupuesto,
        pr.descripcion as presupuesto_descripcion,
        pr.monto as presupuesto_monto
    FROM TblRequerimiento tr
    LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
    LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
    WHERE tr.id_requerimiento = p_id_requerimiento;
    
    -- ========================================================================
    -- RESULT SET 2: DETALLES DEL REQUERIMIENTO CON MATERIALES Y UNIDADES
    -- ========================================================================
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.observaciones,
        rd.fecha_creacion,
        rd.fecha_actualizacion,
        -- Material via JOIN
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(m.descripcion, '') as material_descripcion,
        -- Unidad via JOIN (TblMateriales → TblUnidadMedida)
        COALESCE(um.nombre, '') as unidad_nombre,
        COALESCE(um.abreviatura, '') as unidad_abreviatura,
        COALESCE(um.codigo, '') as unidad_codigo,
        -- Categoría via JOIN
        COALESCE(mc.nombre, 'General') as categoria_nombre
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial mc ON m.id_categoria = mc.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle ASC;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientoCompleto_V2`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    DECLARE v_count INT;
    
    -- 1. OBTENER INFORMACIÓN DEL REQUERIMIENTO
    SELECT 
        id_requerimiento,
        codigo,
        descripcion,
        cantidad,
        solicitante,
        estado,
        observaciones,
        fecha_creacion,
        fecha_actualizacion
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- 2. OBTENER DETALLES DEL REQUERIMIENTO (Materiales y Servicios)
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.unidad_medida,
        rd.observaciones,
        rd.fecha_creacion,
        rd.fecha_actualizacion,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.id_categoria, 0) as id_categoria,
        COALESCE(cm.nombre, '') as categoria_nombre
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;
    
    -- 3. OBTENER RESUMEN (conteos)
    SELECT 
        COUNT(*) as total_items,
        SUM(CASE WHEN tipo_item = 'MATERIAL' THEN 1 ELSE 0 END) as total_materiales,
        SUM(CASE WHEN tipo_item = 'SERVICIO' THEN 1 ELSE 0 END) as total_servicios
    FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientoDetalles`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.unidad_medida,
        m.codigo_material,
        m.nombre as material_nombre,
        m.id_categoria,
        cm.nombre as categoria_nombre,
        rd.fecha_creacion,
        rd.fecha_actualizacion
    FROM TblRequerimientoDetalle rd
    INNER JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.id_detalle;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientosAprobados`()
BEGIN
    SELECT 
        tr.id_requerimiento,
        tr.codigo,
        tr.descripcion,
        tr.estado,
        tr.fecha_creacion,
        tr.observaciones,
        CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, '')) as solicitante,
        (SELECT COUNT(*) FROM TblRequerimientoDetalle WHERE id_requerimiento = tr.id_requerimiento) as cantidad_items
    FROM TblRequerimiento tr
    LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
    LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE tr.estado = 'APROBADO'
    ORDER BY tr.fecha_creacion DESC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientosConAprobadores`()
    READS SQL DATA
BEGIN
    
    SELECT 
        -- Datos básicos del requerimiento
        r.id_requerimiento,
        r.codigo,
        r.descripcion,
        r.cantidad,
        r.estado,
        r.fecha_creacion,
        r.fecha_actualizacion,
        
        -- Solicitante (usuario que creó el requerimiento)
        CONCAT(
            COALESCE(per_solicitante.nombres, ''), ' ',
            COALESCE(per_solicitante.apellido_paterno, ''), ' ',
            COALESCE(per_solicitante.apellido_materno, '')
        ) as solicitante,
        
        -- Presupuesto origen (si aplica)
        pr.numero_presupuesto,
        
        -- APROBADO/RECHAZADO POR - MISMA LÓGICA QUE PRESUPUESTOS
        MAX(CONCAT(
            COALESCE(per_aprobador.nombres, ''), ' ',
            COALESCE(per_aprobador.apellido_paterno, ''), ' ',
            COALESCE(per_aprobador.apellido_materno, '')
        )) as aprobado_rechazado_por,
        
        -- Comentario de rechazo (si aplica)
        MAX(CASE 
            WHEN r.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
            ELSE NULL
        END) as comentario_rechazo
        
    FROM TblRequerimiento r
    LEFT JOIN TblUsuario u_solicitante ON r.num_usuario = u_solicitante.num_documento
    LEFT JOIN TblPersona per_solicitante ON u_solicitante.num_documento = per_solicitante.num_documento
    LEFT JOIN TblPresupuesto pr ON r.id_presupuesto = pr.id_presupuesto
    LEFT JOIN TblRegistroAprobacion ra ON 
        r.id_requerimiento = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 2  -- Requerimientos
        AND (ra.estado_aprobacion = 'APROBADO' OR ra.estado_aprobacion = 'RECHAZADO')
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
    WHERE r.estado != 'ELIMINADO'
    GROUP BY r.id_requerimiento
    ORDER BY r.fecha_creacion DESC;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerUsuarioCompleto`(
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
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerUsuarios`()
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
        c.nombre as cargo,
        a.nombre as area,
        u.estado,
        u.intentos_fallidos,
        u.fecha_ultimo_login,
        u.fecha_creacion,
        u.fecha_actualizacion,
        u.id_cargo,
        u.id_empresa,
        c.id_area
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    ORDER BY u.fecha_creacion DESC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerUsuariosAccesos`()
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
        e.nombre as empresa_nombre,
        COUNT(DISTINCT ua.id_menu) as total_menus_acceso,
        COUNT(DISTINCT ua.id_submenu) as total_submenus_acceso
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblUsuarioAccesos ua ON u.num_documento = ua.num_documento AND ua.estado = 'ACTIVO' AND ua.id_submenu IS NOT NULL
    WHERE u.estado = 'ACTIVO'
    GROUP BY u.num_usuario, u.num_documento, p.nombres, p.apellido_paterno, p.apellido_materno, u.usuario, u.estado, c.nombre, e.nombre
    ORDER BY p.nombres, p.apellido_paterno;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_obtener_presupuesto_detalle_completo`(
    IN p_id_presupuesto INT
)
BEGIN

    -- ========================================================================
    -- PARTE 1: INFORMACIÓN GENERAL DEL PRESUPUESTO
    -- ========================================================================
    
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.id_obra,
        p.num_documento,
        p.monto,
        p.estado,
        p.observaciones,
        p.fecha_creacion,
        p.fecha_actualizacion,
        -- Información relacionada
        COALESCE(pr.nombre, 'N/A') as nombre_proyecto,
        COALESCE(pr.codigo_proyecto, 'N/A') as codigo_proyecto,
        COALESCE(o.nombre, 'N/A') as nombre_obra,
        COALESCE(o.codigo_obra, 'N/A') as codigo_obra,
        COALESCE(per.nombres, 'N/A') as usuario_nombres,
        COALESCE(per.apellido_paterno, 'N/A') as apellido_paterno,
        COALESCE(u.usuario, 'N/A') as usuario,
        COALESCE(per.email, 'N/A') as email
    FROM TblPresupuesto p
    LEFT JOIN TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    LEFT JOIN TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
    WHERE p.id_presupuesto = p_id_presupuesto;

    -- ========================================================================
    -- PARTE 2: ITEMS DEL PRESUPUESTO (DETALLES)
    -- ========================================================================
    
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        COALESCE(m.codigo_material, 'N/A') as codigo_material,
        COALESCE(m.nombre, 'N/A') as material_nombre,
        COALESCE(um.nombre, 'N/A') as unidad_medida,
        COALESCE(c.nombre, 'N/A') as categoria,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        COALESCE(d.observaciones, '') as observaciones,
        d.fecha_creacion
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
    ORDER BY d.id_detalle;

    -- ========================================================================
    -- PARTE 3: RESUMEN Y CÁLCULOS
    -- ========================================================================
    
    SELECT 
        COUNT(d.id_detalle) as cantidad_items,
        COALESCE(SUM(d.cantidad), 0) as cantidad_total,
        COALESCE(SUM(d.subtotal), 0) as monto_total_calculado,
        (SELECT COALESCE(p2.monto, 0) FROM TblPresupuesto p2 WHERE p2.id_presupuesto = p_id_presupuesto) as monto_presupuesto
    FROM TblPresupuestoDetalle d
    WHERE d.id_presupuesto = p_id_presupuesto;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RechazarPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_num_documento_rechazador INT,
    IN p_motivo_rechazo VARCHAR(500)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_presupuesto_existe INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_mensaje VARCHAR(500);
    DECLARE v_registro_aprobacion_existe INT;
    
    -- Verificar que el presupuesto existe
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
    
    -- Verificar que está en estado PENDIENTE o APROBADO (permite cambio)
    IF v_estado_actual NOT IN ('PENDIENTE', 'APROBADO') THEN
        SET v_mensaje = CONCAT('Presupuesto no está en estado PENDIENTE o APROBADO. Estado actual: ', v_estado_actual);
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = v_mensaje;
    END IF;
    
    -- PASO 1: Actualizar estado del presupuesto a RECHAZADO
    UPDATE TblPresupuesto
    SET 
        estado = 'RECHAZADO'
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- PASO 2: Registrar en TblRegistroAprobacion
    -- Verificar si existe registro en TblRegistroAprobacion
    SELECT COUNT(*) INTO v_registro_aprobacion_existe
    FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Si NO existe registro, crear uno nuevo con estado RECHAZADO
    IF v_registro_aprobacion_existe = 0 THEN
        INSERT INTO TblRegistroAprobacion (
            id_documento_referencia,
            id_tipo_documento,
            numero_paso,
            id_cargo_aprobador,
            num_documento_aprobador,
            estado_aprobacion,
            fecha_aprobacion,
            comentario
        ) VALUES (
            p_id_presupuesto,
            1,                                      -- Tipo documento: Presupuesto
            1,                                      -- Paso por defecto: 1
            NULL,                                   -- Cargo (no requerido para presupuesto simple)
            p_num_documento_rechazador,             -- Usuario que rechaza
            'RECHAZADO',                            -- Estado: RECHAZADO
            NOW(),                                  -- Fecha actual
            p_motivo_rechazo                        -- Motivo del rechazo
        );
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' rechazado correctamente (Nuevo registro creado)');
    ELSE
        -- Si SÍ existe, actualizar el registro existente
        UPDATE TblRegistroAprobacion
        SET 
            estado_aprobacion = 'RECHAZADO',
            num_documento_aprobador = p_num_documento_rechazador,      -- Registrar documento del rechazador
            fecha_aprobacion = NOW(),                        -- Registrar fecha de rechazo
            comentario = p_motivo_rechazo                    -- Registrar motivo del rechazo
        WHERE 
            id_documento_referencia = p_id_presupuesto
            AND id_tipo_documento = 1;
        
        SET v_mensaje = CONCAT('Presupuesto ', p_id_presupuesto, ' rechazado correctamente (Registro actualizado)');
    END IF;
    
    SELECT 'OK' AS resultado, v_mensaje AS mensaje;

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RechazarPresupuesto_Progresivo`(
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RechazarRequerimiento`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    IN p_comentario LONGTEXT,
    OUT p_success BOOLEAN,
    OUT p_mensaje VARCHAR(255)
)
    MODIFIES SQL DATA
sp_proc: BEGIN
    DECLARE v_id_cargo INT;
    DECLARE v_id_registro INT;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_numero_paso INT;
    
    -- Inicializar valores por defecto
    SET p_success = FALSE;
    SET p_mensaje = 'Error desconocido';
    
    -- ========================================================================
    -- VALIDACIÓN 1: Verificar que el usuario existe y tiene cargo
    -- ========================================================================
    SELECT tc.id_cargo INTO v_id_cargo
    FROM TblCargo tc
    INNER JOIN TblUsuario tu ON tc.id_cargo = tu.id_cargo
    WHERE tu.num_documento = p_num_documento AND tu.estado = 'Activo'
    LIMIT 1;
    
    IF v_id_cargo IS NULL THEN
        SET p_success = FALSE;
        SET p_mensaje = 'Usuario no tiene cargo asignado';
        SELECT p_success as success, p_mensaje as mensaje;
        LEAVE sp_proc;
    END IF;
    
    -- ========================================================================
    -- VALIDACIÓN 2: Verificar estado actual del requerimiento
    -- ========================================================================
    SELECT estado INTO v_estado_actual
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_estado_actual IS NULL THEN
        SET p_success = FALSE;
        SET p_mensaje = 'Requerimiento no existe';
        SELECT p_success as success, p_mensaje as mensaje;
        LEAVE sp_proc;
    END IF;
    
    IF v_estado_actual NOT IN ('PENDIENTE', 'EN_PROCESO') THEN
        SET p_success = FALSE;
        SET p_mensaje = CONCAT('No se puede rechazar un requerimiento en estado: ', v_estado_actual);
        SELECT p_success as success, p_mensaje as mensaje;
        LEAVE sp_proc;
    END IF;
    
    -- ========================================================================
    -- VALIDACIÓN 3: Verificar que el usuario tiene un registro PENDIENTE
    -- ========================================================================
    SELECT 
        ra.id_registro,
        ra.numero_paso
    INTO v_id_registro, v_numero_paso
    FROM TblRegistroAprobacion ra
    WHERE ra.id_tipo_documento = 2 
      AND ra.id_documento_referencia = p_id_requerimiento
      AND ra.id_cargo_aprobador = v_id_cargo
      AND ra.estado_aprobacion = 'PENDIENTE'
    LIMIT 1;
    
    IF v_id_registro IS NULL THEN
        SET p_success = FALSE;
        SET p_mensaje = 'No tienes un registro pendiente para aprobar/rechazar este requerimiento';
        SELECT p_success as success, p_mensaje as mensaje;
        LEAVE sp_proc;
    END IF;
    
    -- ========================================================================
    -- ACCIÓN 1: Actualizar registro de aprobación a RECHAZADO
    -- ========================================================================
    UPDATE TblRegistroAprobacion 
    SET 
        estado_aprobacion = 'RECHAZADO',
        num_documento_aprobador = p_num_documento,
        comentario = p_comentario,
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;
    
    IF ROW_COUNT() = 0 THEN
        SET p_success = FALSE;
        SET p_mensaje = 'Error al actualizar registro de aprobación';
        SELECT p_success as success, p_mensaje as mensaje;
        LEAVE sp_proc;
    END IF;
    
    -- ========================================================================
    -- ACCIÓN 2: Cambiar estado del requerimiento a RECHAZADO
    -- ========================================================================
    UPDATE TblRequerimiento 
    SET 
        estado = 'RECHAZADO',
        fecha_actualizacion = NOW()
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- ========================================================================
    -- ACCIÓN 3: Actualizar todos los demás registros de este requerimiento a CANCELADO
    -- (Los otros pasos no se procesarán ya que fue rechazado en este paso)
    -- ========================================================================
    UPDATE TblRegistroAprobacion
    SET 
        estado_aprobacion = 'CANCELADO',
        comentario = CONCAT('Requerimiento rechazado en paso ', v_numero_paso)
    WHERE id_tipo_documento = 2
      AND id_documento_referencia = p_id_requerimiento
      AND numero_paso > v_numero_paso
      AND estado_aprobacion = 'PENDIENTE';
    
    -- ========================================================================
    -- RETORNAR RESULTADO
    -- ========================================================================
    SET p_success = TRUE;
    SET p_mensaje = 'Requerimiento rechazado exitosamente';
    
    SELECT p_success as success, p_mensaje as mensaje;
    
END sp_proc
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RegistrarAprobacion`(
        IN p_id_tipo_documento INT,
        IN p_id_documento_referencia INT,
        IN p_numero_paso INT,
        IN p_id_cargo_aprobador INT,
        IN p_num_documento_aprobador INT,
        IN p_estado_aprobacion VARCHAR(20),
        IN p_comentario TEXT
    )
    MODIFIES SQL DATA
BEGIN
        DECLARE v_id_registro INT;
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
            p_id_documento_referencia,
            p_numero_paso,
            p_id_cargo_aprobador,
            p_num_documento_aprobador,
            p_estado_aprobacion,
            p_comentario,
            CURRENT_TIMESTAMP
        );
        SET v_id_registro = LAST_INSERT_ID();
        SELECT v_id_registro AS id_registro;
    END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RegistrarAuditoriaRequerimiento`(
    IN p_id_presupuesto INT,
    IN p_id_requerimiento INT,
    IN p_cantidad_requerida INT,
    IN p_accion VARCHAR(20),
    IN p_num_usuario INT,
    OUT p_result INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_cantidad_consumida_anterior INT;
    DECLARE v_saldo_anterior INT;
    DECLARE v_saldo_nuevo INT;
    
    SELECT cantidad_consumida, cantidad_saldo
    INTO v_cantidad_consumida_anterior, v_saldo_anterior
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF p_accion = 'CREAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior - p_cantidad_requerida;
    ELSEIF p_accion = 'CANCELAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior + p_cantidad_requerida;
    ELSE
        SET v_saldo_nuevo = v_saldo_anterior;
    END IF;
    
    INSERT INTO TblRequerimientoAuditoria (
        id_presupuesto,
        id_requerimiento,
        cantidad_requerida,
        cantidad_anterior_consumida,
        cantidad_nueva_consumida,
        saldo_anterior,
        saldo_nuevo,
        accion,
        num_usuario,
        fecha_registro
    ) VALUES (
        p_id_presupuesto,
        p_id_requerimiento,
        p_cantidad_requerida,
        v_cantidad_consumida_anterior,
        CASE 
            WHEN p_accion = 'CREAR' THEN v_cantidad_consumida_anterior + p_cantidad_requerida
            WHEN p_accion = 'CANCELAR' THEN v_cantidad_consumida_anterior - p_cantidad_requerida
            ELSE v_cantidad_consumida_anterior
        END,
        v_saldo_anterior,
        v_saldo_nuevo,
        p_accion,
        p_num_usuario,
        NOW()
    );
    
    SET p_result = 1;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_RegistrarMarcacion`(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_num_usuario INT;
    
    -- ========================================================================
    -- PASO 1: Validar que el documento existe en TblUsuario y obtener num_usuario
    -- ========================================================================
    
    SELECT num_usuario INTO v_num_usuario FROM TblUsuario 
    WHERE num_documento = p_num_documento LIMIT 1;
    
    IF v_num_usuario IS NULL THEN
        SET p_id_marcacion = 0;
        SET p_mensaje = 'Usuario no encontrado';
    ELSE
        -- ====================================================================
        -- PASO 2: Insertar marcación en TblMarcacion con NOW() (datetime)
        -- ====================================================================
        
        INSERT INTO TblMarcacion (
            num_usuario,
            num_documento,
            tipo_marcacion,
            fecha_marcacion,
            estado
        ) VALUES (
            v_num_usuario,
            p_num_documento,
            p_tipo_marcacion,
            NOW(),
            'Registrado'
        );
        
        SET p_id_marcacion = LAST_INSERT_ID();
        SET p_mensaje = CONCAT(p_tipo_marcacion, ' registrada exitosamente');
        
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ReiniciarFlujoAprobacion`(
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
    
    IF p_id_tipo_documento = 1 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblPresupuesto WHERE id_presupuesto = p_id_documento;
    ELSEIF p_id_tipo_documento = 2 THEN
        SELECT COUNT(*) INTO v_documento_existe FROM TblRequerimiento WHERE id_requerimiento = p_id_documento;
    END IF;
    
    IF v_documento_existe = 0 THEN
        SELECT 'ERROR' AS resultado, 'Documento no encontrado' AS mensaje;
    ELSE
        IF p_id_tipo_documento = 1 THEN
            UPDATE TblPresupuesto
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_presupuesto = p_id_documento;
        ELSEIF p_id_tipo_documento = 2 THEN
            UPDATE TblRequerimiento
            SET estado = 'PENDIENTE', fecha_actualizacion = NOW()
            WHERE id_requerimiento = p_id_documento;
        END IF;
        
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
        AND id_documento_referencia = p_id_documento;
        
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

END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ReportePresupuestos`()
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
        
        -- 🆕 NOMBRE COMPLETO DEL USUARIO QUE APROBÓ/RECHAZÓ EL PRESUPUESTO
        -- Se muestra si el estado es APROBADO O RECHAZADO (cualquiera de los dos)
        CASE 
            WHEN pr.estado IN ('APROBADO', 'RECHAZADO') THEN CONCAT(
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
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento = per_aprobador.num_documento
    
    -- FILTRO: Excluir presupuestos eliminados
    WHERE pr.estado != 'ELIMINADO'
    
    -- ORDEN: Por fecha más reciente
    ORDER BY pr.fecha_creacion DESC;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ValidarCargoAprobador`(
    IN p_id_tipo_documento INT,
    IN p_numero_paso INT,
    IN p_id_cargo INT,
    OUT p_es_valido BOOLEAN
)
    COMMENT 'Valida si un cargo está autorizado para aprobar en un paso específico'
BEGIN
    SELECT 
        CASE 
            WHEN COUNT(*) > 0 THEN TRUE
            ELSE FALSE
        END INTO p_es_valido
    FROM TblFlujoAprobacionCargos fc
    JOIN TblFlujoAprobacion fa 
        ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
    WHERE fa.id_tipo_documento = p_id_tipo_documento
    AND fa.numero_paso = p_numero_paso
    AND fc.id_cargo = p_id_cargo
    AND fc.activo = 1
    AND fa.activo = 1;
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ValidarSaldoPresupuesto`(
    IN p_id_presupuesto INT,
    IN p_cantidad_requerida INT,
    OUT p_saldo_disponible INT,
    OUT p_permitido BOOLEAN,
    OUT p_mensaje VARCHAR(255)
)
    READS SQL DATA
BEGIN
    DECLARE v_cantidad_original INT;
    DECLARE v_cantidad_consumida INT;
    
    SELECT cantidad_original, cantidad_consumida
    INTO v_cantidad_original, v_cantidad_consumida
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_cantidad_original IS NULL THEN
        SET p_permitido = FALSE;
        SET p_saldo_disponible = 0;
        SET p_mensaje = 'Presupuesto no existe';
    ELSE
        SET p_saldo_disponible = v_cantidad_original - v_cantidad_consumida;
        
        IF p_saldo_disponible >= p_cantidad_requerida THEN
            SET p_permitido = TRUE;
            SET p_mensaje = CONCAT('Saldo suficiente. Disponible: ', p_saldo_disponible, ' und, Requerido: ', p_cantidad_requerida, ' und');
        ELSE
            SET p_permitido = FALSE;
            SET p_mensaje = CONCAT('SALDO INSUFICIENTE. Disponible: ', p_saldo_disponible, ' und, Requerido: ', p_cantidad_requerida, ' und');
        END IF;
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_VerificarDocumentoAprobado`(
        IN p_id_tipo_documento INT,
        IN p_id_documento_referencia INT
    )
    READS SQL DATA
BEGIN
        DECLARE v_total_pasos INT;
        DECLARE v_pasos_aprobados INT;
        DECLARE v_rechazado INT;
        SELECT COUNT(*) INTO v_total_pasos
        FROM TblFlujoAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
          AND es_requerido = 1
          AND activo = 1;
        SELECT COUNT(*) INTO v_rechazado
        FROM TblRegistroAprobacion
        WHERE id_tipo_documento = p_id_tipo_documento
          AND id_documento_referencia = p_id_documento_referencia
          AND estado_aprobacion = 'RECHAZADO';
        IF v_rechazado > 0 THEN
            SELECT -1 AS estado;
        ELSE
            SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_aprobados
            FROM TblRegistroAprobacion
            WHERE id_tipo_documento = p_id_tipo_documento
              AND id_documento_referencia = p_id_documento_referencia
              AND estado_aprobacion = 'APROBADO';
            IF v_pasos_aprobados >= v_total_pasos THEN
                SELECT 1 AS estado;
            ELSE
                SELECT 0 AS estado;
            END IF;
        END IF;
    END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_general_ci */ ;
DELIMITER ;;
CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_VerificarEstadoMarcacionHoy`(
    IN p_num_usuario INT,
    OUT p_tiene_entrada INT,
    OUT p_tiene_salida INT,
    OUT p_hora_entrada TIME,
    OUT p_hora_salida TIME,
    OUT p_estado_marcacion VARCHAR(50)
)
BEGIN
    DECLARE p_fecha_hoy DATE;
    SET p_fecha_hoy = CURDATE();
    
    -- Verificar entrada
    SELECT COUNT(*) INTO p_tiene_entrada
    FROM TblMarcacion
    WHERE num_usuario = p_num_usuario 
    AND fecha_marcacion = p_fecha_hoy 
    AND tipo_marcacion = 'Entrada'
    LIMIT 1;
    
    -- Verificar salida
    SELECT COUNT(*) INTO p_tiene_salida
    FROM TblMarcacion
    WHERE num_usuario = p_num_usuario 
    AND fecha_marcacion = p_fecha_hoy 
    AND tipo_marcacion = 'Salida'
    LIMIT 1;
    
    -- Obtener hora de entrada
    SELECT hora_marcacion INTO p_hora_entrada
    FROM TblMarcacion
    WHERE num_usuario = p_num_usuario 
    AND fecha_marcacion = p_fecha_hoy 
    AND tipo_marcacion = 'Entrada'
    LIMIT 1;
    
    -- Obtener hora de salida
    SELECT hora_marcacion INTO p_hora_salida
    FROM TblMarcacion
    WHERE num_usuario = p_num_usuario 
    AND fecha_marcacion = p_fecha_hoy 
    AND tipo_marcacion = 'Salida'
    LIMIT 1;
    
    -- Determinar estado
    IF p_tiene_entrada = 1 AND p_tiene_salida = 1 THEN
        SET p_estado_marcacion = 'Completo';
    ELSEIF p_tiene_entrada = 1 THEN
        SET p_estado_marcacion = 'En Jornada';
    ELSE
        SET p_estado_marcacion = 'Pendiente';
    END IF;
    
END
;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-07-31 16:50:45
