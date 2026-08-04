-- ============================================================================
-- TABLA: TblUbicacionMarcacion
-- DESCRIPCIÓN: Define RANGOS/ZONAS GPS donde cada usuario está autorizado
--              a registrar marcaciones (geofencing circular)
-- FECHA: 2026-08-04
-- NOTA: Esta tabla define ÁREAS CIRCULARES, no ubicaciones exactas
--       Cada registro define: Centro (lat, lon) + Radio en metros
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- Crear tabla de rangos de ubicación para marcación
CREATE TABLE IF NOT EXISTS TblUbicacionMarcacion (
    id_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    num_documento INT NOT NULL COMMENT 'FK: Usuario autorizado para esta zona',
    
    -- DEFINICIÓN DEL RANGO/ZONA (centro + radio = área circular)
    nombre_zona VARCHAR(100) NOT NULL COMMENT 'Nombre descriptivo (ej: Zona Oficina Central)',
    latitud_centro DECIMAL(10, 8) NOT NULL COMMENT 'Latitud del CENTRO de la zona',
    longitud_centro DECIMAL(11, 8) NOT NULL COMMENT 'Longitud del CENTRO de la zona',
    radio_metros INT NOT NULL DEFAULT 100 COMMENT 'Radio del área circular permitida (en metros)',
    
    -- INFORMACIÓN ADICIONAL
    direccion_referencia VARCHAR(255) NULL COMMENT 'Dirección física de referencia',
    tipo_zona ENUM('OFICINA', 'OBRA', 'PROYECTO', 'CLIENTE', 'OTRO') DEFAULT 'OFICINA',
    descripcion TEXT NULL COMMENT 'Descripción detallada del área',
    
    -- CONTROL
    estado ENUM('ACTIVO', 'INACTIVO') DEFAULT 'ACTIVO',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    creado_por INT NULL COMMENT 'Documento del usuario que creó el registro',
    
    -- ÍNDICES
    INDEX idx_num_documento (num_documento),
    INDEX idx_estado (estado),
    INDEX idx_tipo_zona (tipo_zona),
    INDEX idx_documento_estado (num_documento, estado),
    
    -- FOREIGN KEY
    CONSTRAINT fk_ubicacion_usuario 
        FOREIGN KEY (num_documento) 
        REFERENCES TblUsuario(num_documento) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Define rangos/zonas GPS circulares donde usuarios pueden marcar asistencia';

-- ============================================================================
-- STORED PROCEDURES: GESTIÓN DE UBICACIONES
-- ============================================================================

DELIMITER $$

-- ============================================================================
-- SP: OBTENER UBICACIONES DE UN USUARIO
-- ============================================================================
CREATE PROCEDURE sp_ObtenerUbicacionesUsuario(
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

-- ============================================================================
-- SP: CREAR NUEVA UBICACIÓN
-- ============================================================================
CREATE PROCEDURE sp_CrearUbicacionMarcacion(
    IN p_num_documento INT,
    IN p_nombre_zona VARCHAR(100),
    IN p_latitud_centro DECIMAL(10, 8),
    IN p_longitud_centro DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_direccion_referencia VARCHAR(255),
    IN p_tipo_zona VARCHAR(20),
    IN p_descripcion TEXT,
    IN p_estado VARCHAR(10),
    IN p_creado_por INT,
    OUT p_id_ubicacion INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe_usuario INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);
    
    -- Declarar handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_id_ubicacion = 0;
        SET p_mensaje = CONCAT('Error al crear ubicación: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que el usuario existe
    SELECT COUNT(*) INTO v_existe_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_existe_usuario = 0 THEN
        SET p_id_ubicacion = 0;
        SET p_mensaje = 'Error: El usuario no existe';
        ROLLBACK;
    ELSE
        -- Validar datos obligatorios
        IF p_nombre_zona IS NULL OR TRIM(p_nombre_zona) = '' THEN
            SET p_id_ubicacion = 0;
            SET p_mensaje = 'Error: El nombre de la zona es obligatorio';
            ROLLBACK;
        ELSEIF p_latitud_centro IS NULL OR p_longitud_centro IS NULL THEN
            SET p_id_ubicacion = 0;
            SET p_mensaje = 'Error: Las coordenadas GPS son obligatorias';
            ROLLBACK;
        ELSEIF p_radio_metros IS NULL OR p_radio_metros < 10 OR p_radio_metros > 1000 THEN
            SET p_id_ubicacion = 0;
            SET p_mensaje = 'Error: El radio debe estar entre 10 y 1000 metros';
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
                creado_por
            ) VALUES (
                p_num_documento,
                TRIM(p_nombre_zona),
                p_latitud_centro,
                p_longitud_centro,
                p_radio_metros,
                TRIM(p_direccion_referencia),
                p_tipo_zona,
                TRIM(p_descripcion),
                p_estado,
                p_creado_por
            );
            
            SET p_id_ubicacion = LAST_INSERT_ID();
            SET p_mensaje = 'Ubicación creada exitosamente';
            COMMIT;
        END IF;
    END IF;
END$$

-- ============================================================================
-- SP: ACTUALIZAR UBICACIÓN
-- ============================================================================
CREATE PROCEDURE sp_ActualizarUbicacionMarcacion(
    IN p_id_ubicacion INT,
    IN p_nombre_zona VARCHAR(100),
    IN p_latitud_centro DECIMAL(10, 8),
    IN p_longitud_centro DECIMAL(11, 8),
    IN p_radio_metros INT,
    IN p_direccion_referencia VARCHAR(255),
    IN p_tipo_zona VARCHAR(20),
    IN p_descripcion TEXT,
    IN p_estado VARCHAR(10),
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe_ubicacion INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);
    
    -- Declarar handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('Error al actualizar ubicación: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que la ubicación existe
    SELECT COUNT(*) INTO v_existe_ubicacion
    FROM TblUbicacionMarcacion
    WHERE id_ubicacion = p_id_ubicacion;
    
    IF v_existe_ubicacion = 0 THEN
        SET p_mensaje = 'Error: La ubicación no existe';
        ROLLBACK;
    ELSE
        -- Validar datos obligatorios
        IF p_nombre_zona IS NULL OR TRIM(p_nombre_zona) = '' THEN
            SET p_mensaje = 'Error: El nombre de la zona es obligatorio';
            ROLLBACK;
        ELSEIF p_latitud_centro IS NULL OR p_longitud_centro IS NULL THEN
            SET p_mensaje = 'Error: Las coordenadas GPS son obligatorias';
            ROLLBACK;
        ELSEIF p_radio_metros IS NULL OR p_radio_metros < 10 OR p_radio_metros > 1000 THEN
            SET p_mensaje = 'Error: El radio debe estar entre 10 y 1000 metros';
            ROLLBACK;
        ELSE
            -- Actualizar ubicación
            UPDATE TblUbicacionMarcacion
            SET nombre_zona = TRIM(p_nombre_zona),
                latitud_centro = p_latitud_centro,
                longitud_centro = p_longitud_centro,
                radio_metros = p_radio_metros,
                direccion_referencia = TRIM(p_direccion_referencia),
                tipo_zona = p_tipo_zona,
                descripcion = TRIM(p_descripcion),
                estado = p_estado,
                fecha_modificacion = CURRENT_TIMESTAMP
            WHERE id_ubicacion = p_id_ubicacion;
            
            SET p_mensaje = 'Ubicación actualizada exitosamente';
            COMMIT;
        END IF;
    END IF;
END$$

-- ============================================================================
-- SP: ELIMINAR UBICACIÓN
-- ============================================================================
CREATE PROCEDURE sp_EliminarUbicacionMarcacion(
    IN p_id_ubicacion INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe_ubicacion INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);
    
    -- Declarar handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('Error al eliminar ubicación: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que la ubicación existe
    SELECT COUNT(*) INTO v_existe_ubicacion
    FROM TblUbicacionMarcacion
    WHERE id_ubicacion = p_id_ubicacion;
    
    IF v_existe_ubicacion = 0 THEN
        SET p_mensaje = 'Error: La ubicación no existe';
        ROLLBACK;
    ELSE
        -- Eliminar ubicación
        DELETE FROM TblUbicacionMarcacion
        WHERE id_ubicacion = p_id_ubicacion;
        
        SET p_mensaje = 'Ubicación eliminada exitosamente';
        COMMIT;
    END IF;
END$$

-- ============================================================================
-- SP: VALIDAR UBICACIÓN GPS (Para usar en marcación)
-- ============================================================================
CREATE PROCEDURE sp_ValidarUbicacionGPS(
    IN p_num_documento INT,
    IN p_latitud_actual DECIMAL(10, 8),
    IN p_longitud_actual DECIMAL(11, 8),
    OUT p_es_valida BOOLEAN,
    OUT p_nombre_zona VARCHAR(100),
    OUT p_distancia_metros INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_count_ubicaciones INT DEFAULT 0;
    DECLARE v_latitud_centro DECIMAL(10, 8);
    DECLARE v_longitud_centro DECIMAL(11, 8);
    DECLARE v_radio_permitido INT;
    DECLARE v_distancia DECIMAL(10, 2);
    
    -- Inicializar valores
    SET p_es_valida = FALSE;
    SET p_nombre_zona = NULL;
    SET p_distancia_metros = NULL;
    SET p_mensaje = '';
    
    -- Contar ubicaciones activas del usuario
    SELECT COUNT(*) INTO v_count_ubicaciones
    FROM TblUbicacionMarcacion
    WHERE num_documento = p_num_documento
        AND estado = 'ACTIVO';
    
    -- Si no tiene ubicaciones configuradas, permitir marcación desde cualquier lugar
    IF v_count_ubicaciones = 0 THEN
        SET p_es_valida = TRUE;
        SET p_mensaje = 'Sin restricción de ubicación';
    ELSE
        -- Buscar la ubicación más cercana dentro del radio permitido
        -- Fórmula de Haversine (aproximación para distancias cortas)
        SELECT 
            nombre_zona,
            latitud_centro,
            longitud_centro,
            radio_metros,
            (
                6371000 * ACOS(
                    LEAST(1.0,
                        GREATEST(-1.0,
                            COS(RADIANS(p_latitud_actual)) 
                            * COS(RADIANS(latitud_centro)) 
                            * COS(RADIANS(p_longitud_actual) - RADIANS(longitud_centro)) 
                            + SIN(RADIANS(p_latitud_actual)) 
                            * SIN(RADIANS(latitud_centro))
                        )
                    )
                )
            ) AS distancia
        INTO 
            p_nombre_zona,
            v_latitud_centro,
            v_longitud_centro,
            v_radio_permitido,
            v_distancia
        FROM TblUbicacionMarcacion
        WHERE num_documento = p_num_documento
            AND estado = 'ACTIVO'
        ORDER BY distancia ASC
        LIMIT 1;
        
        SET p_distancia_metros = ROUND(v_distancia);
        
        -- Validar si está dentro del radio permitido
        IF v_distancia <= v_radio_permitido THEN
            SET p_es_valida = TRUE;
            SET p_mensaje = CONCAT('Ubicación válida: ', p_nombre_zona, ' (', p_distancia_metros, 'm)');
        ELSE
            SET p_es_valida = FALSE;
            SET p_mensaje = CONCAT('Fuera de rango. Distancia: ', p_distancia_metros, 'm (permitido: ', v_radio_permitido, 'm)');
        END IF;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Tabla TblUbicacionMarcacion creada exitosamente' AS resultado;
SELECT 'Stored Procedures creados exitosamente' AS resultado;
SELECT '  - sp_ObtenerUbicacionesUsuario' AS sp_creado;
SELECT '  - sp_CrearUbicacionMarcacion' AS sp_creado;
SELECT '  - sp_ActualizarUbicacionMarcacion' AS sp_creado;
SELECT '  - sp_EliminarUbicacionMarcacion' AS sp_creado;
SELECT '  - sp_ValidarUbicacionGPS' AS sp_creado;
