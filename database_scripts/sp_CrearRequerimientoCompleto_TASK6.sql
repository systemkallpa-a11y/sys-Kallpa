CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearRequerimientoCompleto`(
    IN p_num_usuario INT,
    IN p_descripcion LONGTEXT,
    IN p_observaciones LONGTEXT,
    IN p_detalles_json JSON,
    IN p_id_presupuesto INT,
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
    
    -- Variables para cálculo de presupuesto
    DECLARE v_monto_presupuesto DECIMAL(12,2);
    DECLARE v_monto_total_detalles DECIMAL(12,2);
    DECLARE v_monto_gastado_anterior DECIMAL(12,2);
    DECLARE v_monto_disponible DECIMAL(12,2);
    DECLARE v_presupuesto_existe INT;
    
    -- Cursor para recorrer flujo de aprobación (DEBE IR ANTES DE LOS HANDLERS)
    DECLARE flujo_cursor CURSOR FOR
    SELECT fac.numero_paso,
           fac.id_cargo,
           fac.nombre_paso,
           fac.es_requerido
    FROM TblFlujoAprobacionCargos fac
    WHERE fac.id_tipo_documento = 2
      AND fac.activo = 1
      AND fac.es_requerido = 1
    ORDER BY fac.numero_paso ASC;
    
    -- HANDLERS (DESPUÉS DE CURSORES)
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    
    -- ========================================================================
    -- PASO 1: VALIDACIÓN DE PRESUPUESTO (SI SE PROPORCIONA)
    -- ========================================================================
    IF p_id_presupuesto IS NOT NULL AND p_id_presupuesto > 0 THEN
        -- Verificar que presupuesto existe
        SELECT COUNT(*) INTO v_presupuesto_existe
        FROM TblPresupuesto
        WHERE id_presupuesto = p_id_presupuesto;
        
        IF v_presupuesto_existe = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Presupuesto no encontrado';
        END IF;
        
        -- Obtener monto del presupuesto
        SELECT monto INTO v_monto_presupuesto
        FROM TblPresupuesto
        WHERE id_presupuesto = p_id_presupuesto;
        
        -- Obtener cantidad consumida anterior (suma de cantidades de requerimientos anteriores)
        SELECT COALESCE(SUM(rd.cantidad), 0) INTO v_monto_gastado_anterior
        FROM TblRequerimiento tr
        INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
        WHERE tr.id_presupuesto = p_id_presupuesto
          AND tr.estado != 'ELIMINADO';
        
        -- Calcular monto total de detalles JSON
        SELECT COALESCE(SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2))), 0)
        INTO v_monto_total_detalles
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
        
        -- Verificar que no se exceda el presupuesto
        SET v_monto_disponible = v_monto_presupuesto - v_monto_gastado_anterior;
        IF v_monto_total_detalles > v_monto_disponible THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Monto insuficiente en presupuesto';
        END IF;
    END IF;
    
    -- ========================================================================
    -- PASO 2: CREAR CÓDIGO DE REQUERIMIENTO
    -- ========================================================================
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo_requerimiento
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    IF v_codigo_requerimiento IS NULL THEN
        SET v_codigo_requerimiento = 'REQ-00001';
    END IF;
    
    -- ========================================================================
    -- PASO 3: INSERTAR REQUERIMIENTO
    -- ========================================================================
    INSERT INTO TblRequerimiento (
        num_usuario,
        codigo,
        descripcion,
        cantidad,
        estado,
        observaciones,
        id_presupuesto,
        id_tipo_documento,
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
        p_id_presupuesto,
        2,
        NOW(),
        NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- ========================================================================
    -- PASO 4: INSERTAR DETALLES DEL REQUERIMIENTO
    -- ========================================================================
    IF JSON_LENGTH(p_detalles_json) > 0 THEN
        INSERT INTO TblRequerimientoDetalle (
            id_requerimiento,
            id_material,
            tipo_item,
            descripcion,
            cantidad,
            fecha_creacion
        )
        SELECT
            p_id_requerimiento_created,
            CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')), 0) AS UNSIGNED),
            COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')), 'MATERIAL'),
            COALESCE(
                JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
                JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
                'Sin descripción'
            ),
            CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')), 1) AS DECIMAL(12,2)),
            NOW()
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    END IF;
    
    -- ========================================================================
    -- PASO 5: CREAR REGISTROS DE APROBACIÓN EN FLUJO
    -- ========================================================================
    SELECT id_tipo_documento INTO v_id_tipo_requerimiento
    FROM TblTipoDocumentoAprobacion
    WHERE id_tipo_documento = 2 AND activo = 1
    LIMIT 1;
    
    IF v_id_tipo_requerimiento IS NOT NULL THEN
        SET v_done = 0;
        OPEN flujo_cursor;
        flujo_loop: LOOP
            FETCH flujo_cursor INTO v_numero_paso, v_id_cargo_aprobador, v_nombre_paso, v_es_requerido;
            IF v_done = 1 THEN
                LEAVE flujo_loop;
            END IF;
            
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
    
    -- ========================================================================
    -- PASO 6: ACTUALIZAR CANTIDAD_CONSUMIDA Y CANTIDAD_SALDO EN PRESUPUESTO
    -- ========================================================================
    IF p_id_presupuesto IS NOT NULL AND p_id_presupuesto > 0 THEN
        -- Actualizar cantidad_consumida (suma de todos los requerimientos)
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = (
                SELECT COALESCE(SUM(rd.cantidad), 0)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = p_id_presupuesto
                  AND tr.estado != 'ELIMINADO'
            ),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = p_id_presupuesto;
        
        -- Actualizar cantidad_saldo (monto - cantidad_consumida)
        UPDATE TblPresupuesto
        SET cantidad_saldo = (monto - COALESCE(cantidad_consumida, 0))
        WHERE id_presupuesto = p_id_presupuesto;
        
        -- TAMBIÉN actualizar monto_gastado para compatibilidad con sistema anterior
        UPDATE TblPresupuesto
        SET monto_gastado = cantidad_consumida
        WHERE id_presupuesto = p_id_presupuesto;
    END IF;
    
    -- ========================================================================
    -- PASO 7: ACTUALIZAR CANTIDAD_CONSUMIDA Y CANTIDAD_SALDO EN CADA DETALLE
    -- ========================================================================
    IF p_id_presupuesto IS NOT NULL AND p_id_presupuesto > 0 THEN
        -- Para CADA detalle del presupuesto, calcular cuánto se consumió
        UPDATE TblPresupuestoDetalle pd
        SET 
            cantidad_consumida = (
                SELECT COALESCE(SUM(rd.cantidad), 0)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = p_id_presupuesto
                  AND tr.estado != 'ELIMINADO'
                  AND LOWER(TRIM(rd.descripcion)) = LOWER(TRIM(pd.descripcion))
            ),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = p_id_presupuesto;
        
        -- Actualizar cantidad_saldo
        UPDATE TblPresupuestoDetalle pd
        SET 
            cantidad_saldo = (
                pd.cantidad - COALESCE(pd.cantidad_consumida, 0)
            )
        WHERE id_presupuesto = p_id_presupuesto;
    END IF;
    
END
