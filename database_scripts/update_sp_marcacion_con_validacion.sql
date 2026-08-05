-- ============================================================================
-- SCRIPT: Actualizar sp_RegistrarMarcacionCompleta con Validación de Ubicación GPS
-- FECHA: 05 Agosto 2026
-- DESCRIPCIÓN: Validar que el usuario esté dentro del rango permitido antes de marcar
-- ============================================================================

USE Kallpa;

-- ============================================================================
-- STORED PROCEDURE: Registrar Marcación con Validación de Ubicación GPS
-- ============================================================================

DROP PROCEDURE IF EXISTS `sp_RegistrarMarcacionCompleta`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RegistrarMarcacionCompleta`(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    IN p_latitud DECIMAL(10,8),
    IN p_longitud DECIMAL(11,8),
    IN p_precision DECIMAL(6,2),
    IN p_foto_base64 LONGTEXT,
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_num_usuario INT;
    DECLARE v_ultima_marcacion VARCHAR(20);
    DECLARE v_fecha_hora_actual DATETIME;
    
    -- Variables para validación de ubicación
    DECLARE v_tiene_ubicaciones INT DEFAULT 0;
    DECLARE v_ubicacion_valida INT DEFAULT 0;
    DECLARE v_nombre_zona VARCHAR(200);
    DECLARE v_distancia_metros DECIMAL(10, 2);
    DECLARE v_radio_permitido INT;
    
    -- Usar zona horaria de Perú (UTC-5)
    SET v_fecha_hora_actual = CONVERT_TZ(NOW(), '+00:00', '-05:00');
    SET p_id_marcacion = 0;
    
    -- ========================================================================
    -- PASO 1: VALIDAR QUE EL USUARIO EXISTE
    -- ========================================================================
    
    SELECT num_usuario INTO v_num_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_num_usuario IS NULL THEN
        SET p_mensaje = 'Usuario no existe';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- ========================================================================
    -- PASO 2: VALIDAR UBICACIÓN GPS (SI TIENE UBICACIONES CONFIGURADAS)
    -- ========================================================================
    
    -- Verificar si el usuario tiene ubicaciones configuradas
    SELECT COUNT(*) INTO v_tiene_ubicaciones
    FROM TblUbicacionMarcacion
    WHERE num_documento = p_num_documento
      AND estado = 'ACTIVO';
    
    -- Si tiene ubicaciones configuradas, VALIDAR que esté dentro del rango
    IF v_tiene_ubicaciones > 0 THEN
        
        -- Buscar ubicación dentro del rango usando fórmula Haversine
        SELECT 
            id_ubicacion,
            nombre_zona,
            radio_metros,
            (
                6371000 * ACOS(
                    LEAST(1.0, 
                        COS(RADIANS(p_latitud)) * 
                        COS(RADIANS(latitud_centro)) * 
                        COS(RADIANS(longitud_centro) - RADIANS(p_longitud)) + 
                        SIN(RADIANS(p_latitud)) * 
                        SIN(RADIANS(latitud_centro))
                    )
                )
            ) AS distancia_metros
        INTO 
            v_ubicacion_valida,
            v_nombre_zona,
            v_radio_permitido,
            v_distancia_metros
        FROM TblUbicacionMarcacion
        WHERE num_documento = p_num_documento
          AND estado = 'ACTIVO'
        HAVING distancia_metros <= radio_metros
        ORDER BY distancia_metros ASC
        LIMIT 1;
        
        -- Si no está dentro de ninguna ubicación, RECHAZAR
        IF v_ubicacion_valida IS NULL OR v_ubicacion_valida = 0 THEN
            SET p_id_marcacion = 0;
            SET p_mensaje = '❌ FUERA DE RANGO: Usted está fuera de su rango de marcación. Acérquese a una ubicación autorizada.';
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fuera del rango de marcación permitido';
        END IF;
        
    END IF;
    
    -- ========================================================================
    -- PASO 3: VALIDAR SECUENCIA DE ENTRADA/SALIDA
    -- ========================================================================
    
    -- Obtener última marcación del día (con zona horaria Perú)
    SELECT tipo_marcacion INTO v_ultima_marcacion
    FROM TblMarcacion
    WHERE num_documento = p_num_documento
      AND DATE(CONVERT_TZ(fecha_marcacion, '+00:00', '-05:00')) = DATE(v_fecha_hora_actual)
    ORDER BY fecha_marcacion DESC
    LIMIT 1;
    
    -- Validar secuencia
    IF p_tipo_marcacion = 'ENTRADA' THEN
        IF v_ultima_marcacion = 'ENTRADA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una entrada registrada. Debes marcar salida primero.';
        END IF;
    ELSE
        IF v_ultima_marcacion IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes una entrada registrada. Debes marcar entrada primero.';
        ELSEIF v_ultima_marcacion = 'SALIDA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una salida registrada. Debes marcar entrada primero.';
        END IF;
    END IF;
    
    -- ========================================================================
    -- PASO 4: REGISTRAR LA MARCACIÓN
    -- ========================================================================
    
    INSERT INTO TblMarcacion (
        num_usuario,
        num_documento,
        tipo_marcacion,
        fecha_marcacion,
        latitud,
        longitud,
        `precision`,
        foto_base64,
        dispositivo,
        estado
    ) VALUES (
        v_num_usuario,
        p_num_documento,
        p_tipo_marcacion,
        v_fecha_hora_actual,
        p_latitud,
        p_longitud,
        p_precision,
        p_foto_base64,
        'WEB',
        'Registrado'
    );
    
    SET p_id_marcacion = LAST_INSERT_ID();
    
    -- Mensaje de éxito con información de ubicación
    IF v_tiene_ubicaciones > 0 AND v_ubicacion_valida > 0 THEN
        SET p_mensaje = CONCAT(
            p_tipo_marcacion, 
            ' registrada a las ', 
            TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s'),
            ' en: ',
            v_nombre_zona,
            ' (',
            ROUND(v_distancia_metros, 0),
            'm)'
        );
    ELSE
        SET p_mensaje = CONCAT(
            p_tipo_marcacion, 
            ' registrada exitosamente a las ', 
            TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s')
        );
    END IF;
    
END$$

DELIMITER ;


-- ============================================================================
-- FUNCIÓN AUXILIAR: Calcular Distancia entre dos puntos GPS (Haversine)
-- ============================================================================

DROP FUNCTION IF EXISTS `fn_CalcularDistanciaGPS`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` FUNCTION `fn_CalcularDistanciaGPS`(
    lat1 DECIMAL(10, 8),
    lon1 DECIMAL(11, 8),
    lat2 DECIMAL(10, 8),
    lon2 DECIMAL(11, 8)
)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    DECLARE distancia DECIMAL(10, 2);
    
    -- Fórmula Haversine para calcular distancia en metros
    -- Radio de la Tierra = 6371 km = 6371000 metros
    SET distancia = (
        6371000 * ACOS(
            LEAST(1.0,
                COS(RADIANS(lat1)) * 
                COS(RADIANS(lat2)) * 
                COS(RADIANS(lon2) - RADIANS(lon1)) + 
                SIN(RADIANS(lat1)) * 
                SIN(RADIANS(lat2))
            )
        )
    );
    
    RETURN distancia;
END$$

DELIMITER ;


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ sp_RegistrarMarcacionCompleta actualizado con validación de ubicación GPS' AS mensaje;
SELECT '✓ fn_CalcularDistanciaGPS creada para cálculo de distancias GPS' AS mensaje;
SELECT '✓ Sistema de marcación ahora valida que el usuario esté dentro del rango' AS nota;
SELECT '⚠️ Si el usuario NO tiene ubicaciones configuradas, puede marcar desde cualquier lugar' AS importante;


-- ============================================================================
-- EJEMPLO DE PRUEBA
-- ============================================================================

/*
-- 1. Probar marcación dentro del rango
CALL sp_RegistrarMarcacionCompleta(
    12345678,             -- num_documento
    'ENTRADA',            -- tipo_marcacion
    -12.04640000,         -- latitud (cercana a ubicación configurada)
    -77.04280000,         -- longitud
    10,                   -- precision
    NULL,                 -- foto_base64
    @id,
    @msg
);
SELECT @id AS id_marcacion, @msg AS mensaje;

-- 2. Probar marcación fuera del rango (debería rechazar)
CALL sp_RegistrarMarcacionCompleta(
    12345678,
    'ENTRADA',
    -12.10000000,         -- latitud lejana
    -77.10000000,         -- longitud lejana
    10,
    NULL,
    @id2,
    @msg2
);
SELECT @id2 AS id_marcacion, @msg2 AS mensaje;

-- 3. Verificar distancia entre dos puntos
SELECT fn_CalcularDistanciaGPS(
    -12.0464, -77.0428,   -- Punto 1 (Centro)
    -12.0465, -77.0429    -- Punto 2 (Muy cercano, ~15 metros)
) AS distancia_metros;

-- 4. Ver ubicaciones de un usuario
SELECT 
    id_ubicacion,
    nombre_zona,
    latitud_centro,
    longitud_centro,
    radio_metros,
    estado
FROM TblUbicacionMarcacion
WHERE num_documento = '12345678';
*/
