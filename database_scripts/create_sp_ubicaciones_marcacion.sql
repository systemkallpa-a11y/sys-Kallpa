-- ============================================================================
-- SCRIPT: Crear Stored Procedures para Ubicaciones de Marcación
-- FECHA: 05 Agosto 2026
-- DESCRIPCIÓN: Gestión de ubicaciones permitidas para marcación de asistencia
-- ============================================================================

USE Kallpa;

-- ============================================================================
-- 1. STORED PROCEDURE: Crear Ubicación de Marcación
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_CrearUbicacionMarcacion`;

DELIMITER $$

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

DELIMITER ;


-- ============================================================================
-- 2. STORED PROCEDURE: Actualizar Ubicación de Marcación
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_ActualizarUbicacionMarcacion`;

DELIMITER $$

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
    
    -- Verificar que la ubicación existe
    IF NOT EXISTS (SELECT 1 FROM TblUbicacionMarcacion WHERE id_ubicacion = p_id_ubicacion) THEN
        SET p_mensaje = 'Ubicación no encontrada';
        ROLLBACK;
    ELSE
        -- Actualizar ubicación
        UPDATE TblUbicacionMarcacion
        SET
            nombre_zona = p_nombre_zona,
            latitud_centro = p_latitud_centro,
            longitud_centro = p_longitud_centro,
            radio_metros = p_radio_metros,
            direccion_referencia = p_direccion_referencia,
            tipo_zona = p_tipo_zona,
            descripcion = p_descripcion,
            estado = p_estado,
            fecha_actualizacion = NOW()
        WHERE id_ubicacion = p_id_ubicacion;
        
        SET p_mensaje = CONCAT('Ubicación "', p_nombre_zona, '" actualizada exitosamente');
        
        COMMIT;
    END IF;
END$$

DELIMITER ;


-- ============================================================================
-- 3. STORED PROCEDURE: Eliminar Ubicación de Marcación
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_EliminarUbicacionMarcacion`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_EliminarUbicacionMarcacion`(
    IN p_id_ubicacion INT,
    OUT p_mensaje VARCHAR(500)
)
BEGIN
    DECLARE v_nombre_zona VARCHAR(200);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_mensaje = 'Error al eliminar la ubicación de marcación';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Obtener nombre de la ubicación
    SELECT nombre_zona INTO v_nombre_zona
    FROM TblUbicacionMarcacion
    WHERE id_ubicacion = p_id_ubicacion;
    
    IF v_nombre_zona IS NULL THEN
        SET p_mensaje = 'Ubicación no encontrada';
        ROLLBACK;
    ELSE
        -- Eliminar ubicación
        DELETE FROM TblUbicacionMarcacion
        WHERE id_ubicacion = p_id_ubicacion;
        
        SET p_mensaje = CONCAT('Ubicación "', v_nombre_zona, '" eliminada exitosamente');
        
        COMMIT;
    END IF;
END$$

DELIMITER ;


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ sp_CrearUbicacionMarcacion creado correctamente' AS mensaje;
SELECT '✓ sp_ActualizarUbicacionMarcacion creado correctamente' AS mensaje;
SELECT '✓ sp_EliminarUbicacionMarcacion creado correctamente' AS mensaje;
SELECT '✓ Stored procedures de ubicaciones de marcación listos para usar' AS nota;


-- ============================================================================
-- NOTA: Si la tabla TblUbicacionMarcacion no existe, créala con:
-- ============================================================================
/*
CREATE TABLE IF NOT EXISTS `TblUbicacionMarcacion` (
    `id_ubicacion` INT AUTO_INCREMENT PRIMARY KEY,
    `num_documento` VARCHAR(20) NOT NULL,
    `nombre_zona` VARCHAR(200) NOT NULL,
    `latitud_centro` DECIMAL(10, 8) NOT NULL,
    `longitud_centro` DECIMAL(11, 8) NOT NULL,
    `radio_metros` INT NOT NULL DEFAULT 100,
    `direccion_referencia` VARCHAR(500),
    `tipo_zona` VARCHAR(50) DEFAULT 'OFICINA',
    `descripcion` TEXT,
    `estado` VARCHAR(20) DEFAULT 'ACTIVO',
    `creado_por` VARCHAR(20),
    `fecha_creacion` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `fecha_actualizacion` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (num_documento) REFERENCES TblUsuario(num_documento) ON DELETE CASCADE,
    INDEX idx_num_documento (num_documento),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
*/
