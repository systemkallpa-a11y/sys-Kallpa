-- ============================================================================
-- STORED PROCEDURE: sp_CrearRequerimientoCompleto (CON CONTROL DE PRESUPUESTO)
-- PROPÓSITO: Crear requerimiento vinculado a presupuesto con validación de monto
-- FECHA: 22 de Julio de 2026
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearRequerimientoCompleto(
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
    
    -- Cursor para recorrer flujo de aprobación
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
        
        -- Obtener monto gastado anterior (suma de cantidades de requerimientos anteriores)
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
    -- PASO 6: ACTUALIZAR MONTO GASTADO EN PRESUPUESTO (SI CORRESPONDE)
    -- ========================================================================
    
    IF p_id_presupuesto IS NOT NULL AND p_id_presupuesto > 0 THEN
        UPDATE TblPresupuesto
        SET 
            monto_gastado = (
                SELECT COALESCE(SUM(rd.cantidad), 0)
                FROM TblRequerimiento tr
                INNER JOIN TblRequerimientoDetalle rd ON tr.id_requerimiento = rd.id_requerimiento
                WHERE tr.id_presupuesto = p_id_presupuesto
                AND tr.estado != 'ELIMINADO'
            ),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = p_id_presupuesto;
    END IF;

END$$

DELIMITER ;

-- ============================================================================
-- INFORMACIÓN DEL SP
-- ============================================================================

/*

PARÁMETROS:
  p_num_usuario (INT):              ID del usuario que crea el requerimiento
  p_descripcion (LONGTEXT):         Descripción del requerimiento
  p_observaciones (LONGTEXT):       Observaciones opcionales
  p_detalles_json (JSON):           Array JSON con detalles [{cantidad, nombre/descripcion}, ...]
  p_id_presupuesto (INT):           ID del presupuesto a vincular (NUEVO)
  p_id_requerimiento_created (OUT): ID del requerimiento creado

FLUJO:
  1. Si se proporciona id_presupuesto:
     - Valida que presupuesto existe
     - Calcula monto gastado anterior (suma de cantidades de requerimientos previos)
     - Calcula monto total de detalles nuevo
     - Verifica que no se exceda el monto disponible
     - Si hay exceso: SIGNAL error
  2. Crea código único REQ-XXXXX
  3. Inserta requerimiento con vinculación a presupuesto
  4. Inserta detalles del requerimiento
  5. Crea registros de aprobación según flujo
  6. Actualiza monto_gastado en TblPresupuesto

EJEMPLOS DE USO:

-- Sin presupuesto (requerimiento independiente)
CALL sp_CrearRequerimientoCompleto(
    1,
    'Suministros de oficina',
    'Urgente',
    '[{"nombre":"Tinta azul","cantidad":10}, {"nombre":"Papel blanco","cantidad":5}]',
    NULL,
    @id_req
);
SELECT @id_req;

-- Con presupuesto (validación de monto)
CALL sp_CrearRequerimientoCompleto(
    1,
    'Materiales para proyecto',
    'Destino: Proyecto X',
    '[{"nombre":"Acero","cantidad":50}, {"nombre":"Cemento","cantidad":30}]',
    14,  -- Presupuesto 14 con monto 100
    @id_req
);
SELECT @id_req;

ERRORES POSIBLES:
  - 'Presupuesto no encontrado'
  - 'Monto insuficiente. Disponible: X Solicitado: Y'

CAMBIOS EN BD REQUERIDOS:
  - Agregar columna monto_gastado a TblPresupuesto (si no existe)

*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
