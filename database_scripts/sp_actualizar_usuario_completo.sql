-- STORED PROCEDURE: sp_ActualizarUsuarioCompleto
-- Actualiza todos los datos del usuario (TblPersona + TblUsuario)
USE kallgwkn_kallpa_bd;
DELIMITER //

DROP PROCEDURE IF EXISTS sp_ActualizarUsuarioCompleto //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ActualizarUsuarioCompleto(
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
    
END //

DELIMITER ;
