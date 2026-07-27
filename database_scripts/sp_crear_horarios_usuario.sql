-- ============================================================================
-- STORED PROCEDURE: sp_CrearHorariosUsuario
-- DESCRIPCIÓN: Inserta los horarios de trabajo para un usuario (7 días)
-- PARÁMETROS:
--   - p_num_documento: Número de documento del usuario
--   - p_lunes_activo, p_lunes_entrada, p_lunes_salida
--   - p_martes_activo, p_martes_entrada, p_martes_salida
--   - ... (igual para todos los días)
--   - p_domingo_activo, p_domingo_entrada, p_domingo_salida
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_CrearHorariosUsuario //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_CrearHorariosUsuario(
    IN p_num_documento INT,
    IN p_lunes_activo BOOLEAN,
    IN p_lunes_entrada TIME,
    IN p_lunes_salida TIME,
    IN p_martes_activo BOOLEAN,
    IN p_martes_entrada TIME,
    IN p_martes_salida TIME,
    IN p_miercoles_activo BOOLEAN,
    IN p_miercoles_entrada TIME,
    IN p_miercoles_salida TIME,
    IN p_jueves_activo BOOLEAN,
    IN p_jueves_entrada TIME,
    IN p_jueves_salida TIME,
    IN p_viernes_activo BOOLEAN,
    IN p_viernes_entrada TIME,
    IN p_viernes_salida TIME,
    IN p_sabado_activo BOOLEAN,
    IN p_sabado_entrada TIME,
    IN p_sabado_salida TIME,
    IN p_domingo_activo BOOLEAN,
    IN p_domingo_entrada TIME,
    IN p_domingo_salida TIME,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_contador INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_mensaje = 'Error al crear horarios';
    END;
    
    START TRANSACTION;
    
    -- Eliminar horarios previos si existen
    DELETE FROM TblHorarioTrabajo WHERE num_documento = p_num_documento;
    
    -- Insertar LUNES
    IF p_lunes_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'LUNES', p_lunes_entrada, p_lunes_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'LUNES', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar MARTES
    IF p_martes_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'MARTES', p_martes_entrada, p_martes_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'MARTES', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar MIÉRCOLES
    IF p_miercoles_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'MIÉRCOLES', p_miercoles_entrada, p_miercoles_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'MIÉRCOLES', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar JUEVES
    IF p_jueves_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'JUEVES', p_jueves_entrada, p_jueves_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'JUEVES', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar VIERNES
    IF p_viernes_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'VIERNES', p_viernes_entrada, p_viernes_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'VIERNES', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar SÁBADO
    IF p_sabado_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'SÁBADO', p_sabado_entrada, p_sabado_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'SÁBADO', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    -- Insertar DOMINGO
    IF p_domingo_activo = 1 THEN
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado)
        VALUES (p_num_documento, 'DOMINGO', p_domingo_entrada, p_domingo_salida, 1, 'ACTIVO');
    ELSE
        INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, es_activo, estado)
        VALUES (p_num_documento, 'DOMINGO', 0, 'ACTIVO');
    END IF;
    SET v_contador = v_contador + 1;
    
    SET p_mensaje = CONCAT('Horarios creados exitosamente. ', v_contador, ' días registrados');
    COMMIT;
    
END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN: Ejecutar el SP
-- ============================================================================

-- CALL sp_CrearHorariosUsuario(
--     1,           -- p_num_documento
--     1, '08:30', '19:00',  -- LUNES
--     1, '08:30', '19:00',  -- MARTES
--     1, '08:30', '19:00',  -- MIÉRCOLES
--     1, '08:30', '19:00',  -- JUEVES
--     1, '08:30', '19:00',  -- VIERNES
--     1, '08:30', '13:30',  -- SÁBADO
--     0, NULL, NULL,        -- DOMINGO
--     @p_mensaje
-- );
-- SELECT @p_mensaje as mensaje;

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
