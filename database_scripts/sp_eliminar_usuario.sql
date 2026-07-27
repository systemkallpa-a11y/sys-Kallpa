-- ============================================================================
-- STORED PROCEDURE: sp_EliminarUsuario
-- DESCRIPCIÓN: Elimina un usuario completamente del sistema:
--   1. Elimina horarios de trabajo (TblHorarioTrabajo)
--   2. Elimina registro de usuario (TblUsuario)
--   3. Elimina datos personales (TblPersona)
-- 
-- PARÁMETROS:
--   - p_num_usuario: ID del usuario a eliminar
--   - p_mensaje (OUT): Mensaje de resultado
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_EliminarUsuario //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_EliminarUsuario(
    IN p_num_usuario INT,
    OUT p_mensaje VARCHAR(255)
)
proc_label: BEGIN
    DECLARE v_num_documento INT;
    DECLARE v_usuario VARCHAR(100);
    DECLARE v_horarios_eliminados INT DEFAULT 0;
    
    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al eliminar el usuario';
        ROLLBACK;
    END;
    
    -- Validar que el usuario existe y obtener datos (num_documento y usuario)
    SELECT num_documento, usuario INTO v_num_documento, v_usuario
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    -- Si no existe, salir con error
    IF v_num_documento IS NULL THEN
        SET p_mensaje = 'El usuario no existe';
        LEAVE proc_label;
    END IF;
    
    -- Iniciar transacción para garantizar consistencia
    START TRANSACTION;
    
    -- PASO 1: Eliminar horarios de trabajo asociados
    -- Esto es crítico porque TblHorarioTrabajo tiene FK a TblPersona
    DELETE FROM TblHorarioTrabajo
    WHERE num_documento = v_num_documento;
    
    SET v_horarios_eliminados = ROW_COUNT();
    
    -- PASO 2: Eliminar usuario (TblUsuario)
    DELETE FROM TblUsuario
    WHERE num_usuario = p_num_usuario;
    
    -- PASO 3: Eliminar datos personales (TblPersona)
    DELETE FROM TblPersona
    WHERE num_documento = v_num_documento;
    
    -- Confirmar transacción
    COMMIT;
    
    -- Mensaje de éxito con detalles de lo eliminado
    SET p_mensaje = CONCAT('Usuario ', v_usuario, ' eliminado exitosamente');
    
END //

DELIMITER ;

-- ============================================================================
-- PRUEBA: Ejecutar el SP
-- ============================================================================
-- CALL sp_EliminarUsuario(5, @p_mensaje);
-- SELECT @p_mensaje as mensaje;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
