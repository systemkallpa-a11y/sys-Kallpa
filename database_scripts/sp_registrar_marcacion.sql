-- STORED PROCEDURE: sp_RegistrarMarcacion
USE kallgwkn_kallpa_bd;
DELIMITER //

DROP PROCEDURE IF EXISTS sp_RegistrarMarcacion //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_RegistrarMarcacion(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_num_usuario INT;
    DECLARE v_existe BOOLEAN;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_id_marcacion = 0;
        SET p_mensaje = 'Error al registrar marcación';
    END;
    
    SELECT COUNT(*) INTO v_existe
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_existe = 0 THEN
        SET p_id_marcacion = 0;
        SET p_mensaje = 'Documento no existe';
    ELSE
        SELECT num_usuario INTO v_num_usuario
        FROM TblUsuario
        WHERE num_documento = p_num_documento
        LIMIT 1;
        
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
    
END //

DELIMITER ;
