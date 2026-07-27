-- ============================================================================
-- STORED PROCEDURE: sp_CrearRequerimientoCompleto (CORREGIDO)
-- ============================================================================
-- Descripción: Crear requerimiento completo con detalles y flujo de aprobación
-- 
-- Cambios respecto a versión anterior:
--   • Actualizado para usar TblFlujoAprobacionCargos en lugar de TblFlujoAprobacion
--   • Ahora obtiene los cargos aprobadores de TblFlujoAprobacionCargos
--
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearRequerimientoCompleto(
    IN p_num_usuario INT,
    IN p_descripcion LONGTEXT,
    IN p_observaciones LONGTEXT,
    IN p_detalles_json JSON,
    OUT p_id_requerimiento_created INT
)
BEGIN
    DECLARE v_codigo_requerimiento VARCHAR(50);
    DECLARE v_id_tipo_requerimiento INT;
    DECLARE v_numero_paso INT;
    DECLARE v_id_cargo_aprobador INT;
    DECLARE v_nombre_paso VARCHAR(150);
    DECLARE v_es_requerido INT;
    DECLARE v_done INT DEFAULT 0;
    
    -- Cursor para iterar sobre los pasos del flujo de aprobación
    DECLARE flujo_cursor CURSOR FOR
        SELECT 
            fac.numero_paso,
            fac.id_cargo,
            fac.nombre_paso,
            fac.es_requerido
        FROM TblFlujoAprobacionCargos fac
        WHERE fac.id_tipo_documento = 2
          AND fac.activo = 1
          AND fac.es_requerido = 1
        ORDER BY fac.numero_paso ASC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    
    -- Generar código del requerimiento
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo_requerimiento
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    IF v_codigo_requerimiento IS NULL THEN
        SET v_codigo_requerimiento = 'REQ-00001';
    END IF;
    
    -- Insertar nuevo requerimiento
    INSERT INTO TblRequerimiento (
        num_usuario,
        codigo,
        descripcion,
        cantidad,
        estado,
        observaciones,
        fecha_creacion,
        fecha_actualizacion
    )
    VALUES (
        p_num_usuario,
        v_codigo_requerimiento,
        p_descripcion,
        COALESCE(JSON_LENGTH(p_detalles_json), 0),
        'PENDIENTE',
        p_observaciones,
        NOW(),
        NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- Insertar detalles del requerimiento si existen
    IF JSON_LENGTH(p_detalles_json) > 0 THEN
        INSERT INTO TblRequerimientoDetalle (
            id_requerimiento,
            descripcion,
            cantidad,
            fecha_creacion
        )
        SELECT
            p_id_requerimiento_created,
            COALESCE(
                JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
                JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion'))
            ),
            CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')), 1) AS DECIMAL(12,2)),
            NOW()
        FROM JSON_TABLE(
            p_detalles_json, 
            '$[*]' COLUMNS (item JSON PATH '$')
        ) jt;
    END IF;
    
    -- Obtener ID del tipo de documento Requerimiento
    SELECT id_tipo_documento 
    INTO v_id_tipo_requerimiento
    FROM TblTipoDocumentoAprobacion
    WHERE id_tipo_documento = 2 AND activo = 1
    LIMIT 1;
    
    -- Crear registros de aprobación para cada paso del flujo
    IF v_id_tipo_requerimiento IS NOT NULL THEN
        SET v_done = 0;
        OPEN flujo_cursor;
        
        flujo_loop: LOOP
            FETCH flujo_cursor INTO v_numero_paso, v_id_cargo_aprobador, v_nombre_paso, v_es_requerido;
            
            IF v_done = 1 THEN
                LEAVE flujo_loop;
            END IF;
            
            -- Insertar registro de aprobación si es requerido y hay cargo asignado
            IF v_es_requerido = 1 AND v_id_cargo_aprobador IS NOT NULL THEN
                INSERT INTO TblRegistroAprobacion (
                    id_tipo_documento,
                    id_documento_referencia,
                    numero_paso,
                    id_cargo_aprobador,
                    estado_aprobacion,
                    comentario,
                    fecha_asignacion
                )
                VALUES (
                    v_id_tipo_requerimiento,
                    p_id_requerimiento_created,
                    v_numero_paso,
                    v_id_cargo_aprobador,
                    'PENDIENTE',
                    '',
                    NOW()
                );
            END IF;
        END LOOP flujo_loop;
        
        CLOSE flujo_cursor;
    END IF;
END$$

DELIMITER ;

-- Verificación
SELECT '✅ SP sp_CrearRequerimientoCompleto actualizado - Usando TblFlujoAprobacionCargos' AS estado;
