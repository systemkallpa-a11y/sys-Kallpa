-- ============================================================
-- KALLPA - Stored Procedures del módulo Empresa
-- Base: kallpasystem$kallgwkn_kallpa_bd
-- Fecha creación: 27/09/2026
--
-- Motivo: empresa.py llama a estos 2 SP que no existían en la BD
-- (error 1305 PROCEDURE does not exist -> "Error de conexión" en UI).
--
-- Contratos que respeta el backend (app/routes/empresa.py):
--   CALL sp_CrearEmpresa(ruc, nombre, latitud, longitud, radio_metros, logo)
--     -> empresa.py:230  / logo siempre NULL (lo sube /api/empresa/logo/subir)
--     -> empresa.py:244  lee LAST_INSERT_ID() sin multi=True
--        => el SP NO debe devolver result set
--     -> empresa.py:259  busca 'Ya existe' en el mensaje para devolver 400
--   CALL sp_ActualizarEmpresa(id_empresa, ruc, nombre, latitud, longitud, radio_metros, logo)
--     -> empresa.py:333  logo siempre NULL => significa "no modificar"
-- ============================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearEmpresa$$
CREATE PROCEDURE sp_CrearEmpresa(
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

DROP PROCEDURE IF EXISTS sp_ActualizarEmpresa$$
CREATE PROCEDURE sp_ActualizarEmpresa(
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

DELIMITER ;

-- ============================================================
-- VERIFICACIÓN: debe devolver las 3 rutinas
-- ============================================================
-- SELECT ROUTINE_NAME, ROUTINE_TYPE, CREATED, LAST_ALTERED
-- FROM information_schema.ROUTINES
-- WHERE ROUTINE_SCHEMA = DATABASE()
--   AND ROUTINE_NAME LIKE '%Empresa%'
-- ORDER BY ROUTINE_NAME;
