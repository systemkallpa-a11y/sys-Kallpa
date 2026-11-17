-- ============================================================
-- SP: sp_RegistrarMarcacionCompleta   (v1 - version en produccion al 2026-11-13)
-- ============================================================
-- Registra ENTRADA/SALIDA desde la pantalla de marcacion (foto + GPS).
-- Copia exacta de la BD (verificada el 2026-11-16). Sirve para
-- REVERTIR a la version anterior a la v2.
-- ============================================================

DROP PROCEDURE IF EXISTS `sp_RegistrarMarcacionCompleta`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RegistrarMarcacionCompleta`(
    IN p_num_documento INT,
    IN p_tipo_marcacion VARCHAR(20),
    IN p_latitud DECIMAL(10,8),
    IN p_longitud DECIMAL(11,8),
    IN p_precision DECIMAL(6,2),
    IN p_foto_base64 LONGTEXT,
    IN p_justificacion TEXT,
    OUT p_id_marcacion INT,
    OUT p_mensaje VARCHAR(255)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_num_usuario INT;
    DECLARE v_ultima_marcacion VARCHAR(20);
    DECLARE v_fecha_hora_actual DATETIME;
    DECLARE v_tiene_ubicaciones INT DEFAULT 0;
    DECLARE v_ubicacion_valida INT DEFAULT 0;
    DECLARE v_nombre_zona VARCHAR(200);
    DECLARE v_distancia_metros DECIMAL(10, 2);
    DECLARE v_radio_permitido INT;
    DECLARE v_estado_calculado VARCHAR(20);
    DECLARE v_hora_entrada TIME;
    DECLARE v_hora_limite_puntual TIME DEFAULT '08:05:00';
    DECLARE v_hora_limite_tarde TIME DEFAULT '08:30:00';
    
    SET v_fecha_hora_actual = NOW();
    SET p_id_marcacion = 0;
    
    -- Validar usuario
    SELECT num_usuario INTO v_num_usuario
    FROM TblUsuario
    WHERE num_documento = p_num_documento;
    
    IF v_num_usuario IS NULL THEN
        SET p_mensaje = 'Usuario no existe';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar GPS (solo si no hay justificación)
    IF p_justificacion IS NULL OR p_justificacion = '' THEN
        SELECT COUNT(*) INTO v_tiene_ubicaciones
        FROM TblUbicacionMarcacion
        WHERE num_documento = p_num_documento AND estado = 'ACTIVO';
        
        IF v_tiene_ubicaciones > 0 THEN
            SELECT 
                id_ubicacion, nombre_zona, radio_metros,
                (6371000 * ACOS(LEAST(1.0, 
                    COS(RADIANS(p_latitud)) * COS(RADIANS(latitud_centro)) * 
                    COS(RADIANS(longitud_centro) - RADIANS(p_longitud)) + 
                    SIN(RADIANS(p_latitud)) * SIN(RADIANS(latitud_centro))
                ))) AS distancia_metros
            INTO v_ubicacion_valida, v_nombre_zona, v_radio_permitido, v_distancia_metros
            FROM TblUbicacionMarcacion
            WHERE num_documento = p_num_documento AND estado = 'ACTIVO'
            HAVING distancia_metros <= radio_metros
            ORDER BY distancia_metros ASC LIMIT 1;
            
            IF v_ubicacion_valida IS NULL OR v_ubicacion_valida = 0 THEN
                SET p_id_marcacion = 0;
                SET p_mensaje = 'FUERA DE RANGO';
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fuera del rango de marcación permitido';
            END IF;
        END IF;
    END IF;
    
    -- ============================================
    -- CORRECCIÓN: Validar secuencia ENTRADA/SALIDA
    -- ============================================
    SELECT tipo_marcacion INTO v_ultima_marcacion
    FROM TblMarcacion
    WHERE num_documento = p_num_documento
      AND DATE(fecha_marcacion) = DATE(v_fecha_hora_actual)
    ORDER BY fecha_marcacion DESC LIMIT 1;
    
    IF p_tipo_marcacion = 'ENTRADA' THEN
        IF v_ultima_marcacion = 'ENTRADA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una entrada registrada. Debes marcar salida primero.';
        END IF;
    ELSE
        IF v_ultima_marcacion IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No tienes una entrada registrada.';
        ELSEIF v_ultima_marcacion = 'SALIDA' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya tienes una salida registrada.';
        END IF;
    END IF;
    
    -- Calcular estado
    SET v_estado_calculado = 'Registrado';
    IF p_tipo_marcacion = 'ENTRADA' THEN
        SET v_hora_entrada = TIME(v_fecha_hora_actual);
        IF v_hora_entrada <= v_hora_limite_puntual THEN
            SET v_estado_calculado = 'ASISTIO';
        ELSEIF v_hora_entrada <= v_hora_limite_tarde THEN
            SET v_estado_calculado = 'TARDE';
        ELSE
            SET v_estado_calculado = 'ASISTIO +5';
        END IF;
    END IF;
    
    -- INSERT
    INSERT INTO TblMarcacion (
        num_usuario,
        num_documento,
        tipo_marcacion,
        fecha_marcacion,
        latitud,
        longitud,
        `precision`,
        tipo_ubicacion,
        foto_base64,
        justificacion,
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
        IF(p_justificacion IS NOT NULL AND p_justificacion != '', 'CAMPO', 'OFICINA'),
        p_foto_base64,
        p_justificacion,
        'WEB',
        v_estado_calculado
    );
    
    SET p_id_marcacion = LAST_INSERT_ID();
    
    -- Mensaje
    IF p_justificacion IS NOT NULL AND p_justificacion != '' THEN
        SET p_mensaje = CONCAT(p_tipo_marcacion, ' registrada - JUSTIFICADA');
    ELSE
        SET p_mensaje = CONCAT(p_tipo_marcacion, ' registrada OK');
    END IF;
    
END$$

DELIMITER ;
