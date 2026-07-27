-- STORED PROCEDURE: sp_CrearUsuarioCompleto
-- Crea usuario completo + inserta horarios de trabajo (7 días)
USE kallgwkn_kallpa_bd;
DELIMITER //

DROP PROCEDURE IF EXISTS sp_CrearUsuarioCompleto //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_CrearUsuarioCompleto(
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

END //

DELIMITER ;
