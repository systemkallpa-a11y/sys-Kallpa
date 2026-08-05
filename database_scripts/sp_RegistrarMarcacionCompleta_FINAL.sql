-- ============================================================================
-- STORED PROCEDURE: sp_RegistrarMarcacionCompleta
-- VERSION FINAL con Validación GPS y Cálculo Automático de Estados
-- FECHA: 05 Agosto 2026
-- ============================================================================

USE Kallpa;

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
    
    -- Variables para validación de ubicación GPS
    DECLARE v_tiene_ubicaciones INT DEFAULT 0;
    DECLARE v_ubicacion_valida INT DEFAULT 0;
    DECLARE v_nombre_zona VARCHAR(200);
    DECLARE v_distancia_metros DECIMAL(10, 2);
    DECLARE v_radio_permitido INT;
    
    -- Variables para cálculo automático de estado
    DECLARE v_estado_calculado VARCHAR(20);
    DECLARE v_hora_entrada TIME;
    DECLARE v_hora_limite_puntual TIME DEFAULT '08:05:00';  -- Tolerancia 5 min
    DECLARE v_hora_limite_tarde TIME DEFAULT '08:30:00';    -- Límite tardanza
    
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
    -- PASO 3: VALIDAR SECUENCIA ENTRADA/SALIDA
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
    -- PASO 4: CALCULAR ESTADO AUTOMÁTICO SEGÚN HORA DE ENTRADA
    -- ========================================================================
    
    -- Por defecto, el estado es 'Registrado'
    SET v_estado_calculado = 'Registrado';
    
    -- Si es ENTRADA, calcular el estado según la hora
    IF p_tipo_marcacion = 'ENTRADA' THEN
        SET v_hora_entrada = TIME(v_fecha_hora_actual);
        
        IF v_hora_entrada <= v_hora_limite_puntual THEN
            -- Llegó a tiempo (hasta 08:05:00)
            SET v_estado_calculado = 'ASISTIO';
        ELSEIF v_hora_entrada <= v_hora_limite_tarde THEN
            -- Llegó tarde (08:05:01 - 08:30:00)
            SET v_estado_calculado = 'TARDE';
        ELSE
            -- Llegó muy tarde (después de 08:30:00)
            SET v_estado_calculado = 'ASISTIO +5';
        END IF;
    ELSE
        -- Si es SALIDA, el estado es 'Registrado'
        SET v_estado_calculado = 'Registrado';
    END IF;
    
    -- ========================================================================
    -- PASO 5: REGISTRAR LA MARCACIÓN CON ESTADO CALCULADO
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
        v_estado_calculado  -- ✅ ESTADO CALCULADO AUTOMÁTICAMENTE
    );
    
    SET p_id_marcacion = LAST_INSERT_ID();
    
    -- ========================================================================
    -- PASO 6: MENSAJE DE ÉXITO CON INFORMACIÓN COMPLETA
    -- ========================================================================
    
    IF v_tiene_ubicaciones > 0 AND v_ubicacion_valida > 0 THEN
        -- Con validación de ubicación
        SET p_mensaje = CONCAT(
            p_tipo_marcacion, 
            ' registrada a las ', 
            TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s'),
            ' - Estado: ',
            v_estado_calculado,
            ' en: ',
            v_nombre_zona,
            ' (',
            ROUND(v_distancia_metros, 0),
            'm)'
        );
    ELSE
        -- Sin validación de ubicación
        SET p_mensaje = CONCAT(
            p_tipo_marcacion, 
            ' registrada a las ', 
            TIME_FORMAT(v_fecha_hora_actual, '%H:%i:%s'),
            ' - Estado: ',
            v_estado_calculado
        );
    END IF;
    
END$$

DELIMITER ;


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ sp_RegistrarMarcacionCompleta actualizado correctamente' AS mensaje;
SELECT '✅ Validación GPS: Activa si el usuario tiene ubicaciones configuradas' AS feature_1;
SELECT '✅ Estados automáticos: ASISTIO, TARDE, ASISTIO +5, Registrado' AS feature_2;
SELECT '✅ Mensaje incluye: hora, estado y ubicación (si aplica)' AS feature_3;


-- ============================================================================
-- TABLA DE ESTADOS AUTOMÁTICOS
-- ============================================================================

/*
╔════════════════════════╦══════════════╦═══════════════════════════════════╗
║ HORA DE ENTRADA        ║ ESTADO       ║ DESCRIPCIÓN                       ║
╠════════════════════════╬══════════════╬═══════════════════════════════════╣
║ Hasta 08:05:00         ║ ASISTIO      ║ A tiempo (tolerancia 5 minutos)   ║
║ 08:05:01 - 08:30:00    ║ TARDE        ║ Tarde (entre 5 y 30 minutos)      ║
║ Después de 08:30:00    ║ ASISTIO +5   ║ Muy tarde (más de 30 minutos)     ║
║ SALIDA (cualquier hora)║ Registrado   ║ Salida normal                     ║
╚════════════════════════╩══════════════╩═══════════════════════════════════╝

NOTA: El estado "FALTA" se asigna por un proceso automático (cron/batch)
      al final del día para usuarios que no marcaron entrada.

VALIDACIÓN GPS:
- Si el usuario TIENE ubicaciones configuradas → VALIDA distancia GPS
- Si el usuario NO TIENE ubicaciones → Marca libremente desde cualquier lugar
*/


-- ============================================================================
-- EJEMPLOS DE MENSAJES
-- ============================================================================

/*
EJEMPLOS DE MENSAJES DE ÉXITO:

✅ Con ubicación configurada:
   "ENTRADA registrada a las 08:00:45 - Estado: ASISTIO en: Oficina Central (23m)"
   "ENTRADA registrada a las 08:15:30 - Estado: TARDE en: Obra Villa Verde (87m)"
   "ENTRADA registrada a las 09:10:00 - Estado: ASISTIO +5 en: Cliente ABC (45m)"

✅ Sin ubicación configurada:
   "ENTRADA registrada a las 08:00:45 - Estado: ASISTIO"
   "SALIDA registrada a las 17:30:15 - Estado: Registrado"

❌ Fuera de rango:
   "❌ FUERA DE RANGO: Usted está fuera de su rango de marcación. Acérquese a una ubicación autorizada."
*/
