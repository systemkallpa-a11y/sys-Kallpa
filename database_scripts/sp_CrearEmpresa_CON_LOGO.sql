-- =====================================================
-- PROCEDURE: sp_CrearEmpresa
-- PROPOSITO: Crear nueva empresa con validaciones y logo
-- FECHA: 10 Julio 2026
-- ACTUALIZADO: Incluye parámetro logo LONGBLOB
-- =====================================================

DELIMITER $$

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

END$$

DELIMITER ;

-- =====================================================
-- INFORMACIÓN
-- =====================================================
-- Parámetros:
-- - p_ruc: VARCHAR(11) - RUC de 11 dígitos
-- - p_nombre: VARCHAR(255) - Nombre de la empresa
-- - p_latitud: DECIMAL(10,8) - Latitud geográfica
-- - p_longitud: DECIMAL(11,8) - Longitud geográfica
-- - p_radio_metros: INT - Radio de marcación en metros
-- - p_logo: LONGBLOB - Archivo PNG binario del logo (NUEVO)
-- =====================================================
-- Cambios:
-- ✅ Agregado parámetro p_logo LONGBLOB
-- ✅ Actualizado nombre de tabla a TblEmpresa
-- ✅ INSERT ahora incluye campo logo
-- ✅ Mantiene todas las validaciones
-- ✅ DELIMITER agregado correctamente
-- =====================================================
