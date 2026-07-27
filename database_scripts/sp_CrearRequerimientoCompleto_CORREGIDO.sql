-- ============================================================================
-- STORED PROCEDURE: sp_CrearRequerimientoCompleto (CORREGIDO v3.0)
-- DESCRIPCIÓN: 
--   1. Crea requerimiento con detalles
--   2. Captura CANTIDAD EDITADA del JSON (no cantidad del presupuesto)
--   3. Registra cambios en TblRequerimientoAuditoria
--   4. Actualiza cantidad_consumida en TblPresupuestoDetalle
-- PARÁMETROS:
--   p_num_usuario: num_usuario del usuario solicitante
--   p_descripcion: Descripción del requerimiento
--   p_observaciones: Observaciones generales
--   p_detalles_json: JSON con {id_detalle_presupuesto, cantidad, tipo_item, ...}
-- RETORNA: 
--   p_id_requerimiento_created: ID del requerimiento creado
-- AUTOR: Sistema Kallpa
-- FECHA: 2026-07-16
-- VERSION: 3.0
-- CAMBIOS:
--   - ✓ Captura cantidad_editada del JSON
--   - ✓ Registra auditoría por item
--   - ✓ Actualiza cantidad_consumida en TblPresupuestoDetalle
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearRequerimientoCompleto(
    IN p_num_usuario INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_id_requerimiento_created INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_cantidad_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_id_detalle INT;
    DECLARE v_cantidad_editada DECIMAL(10, 2);
    DECLARE v_cantidad_original DECIMAL(10, 2);
    DECLARE v_cantidad_consumida_actual DECIMAL(10, 2);
    DECLARE v_nueva_cantidad_consumida DECIMAL(10, 2);
    DECLARE v_saldo_anterior DECIMAL(10, 2);
    DECLARE v_saldo_nuevo DECIMAL(10, 2);
    DECLARE v_tipo_item VARCHAR(20);
    DECLARE v_json_length INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Validar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_usuario = p_num_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar que JSON no está vacío
    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos: debe proporcionar al menos un item';
    END IF;
    
    -- Generar código automáticamente
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    -- Si no existe código previo, iniciar en 1
    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;
    
    -- ========================================================================
    -- PASO 1: Calcular cantidad total DESDE EL JSON (cantidades editadas)
    -- ========================================================================
    SELECT COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10, 2))), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- ========================================================================
    -- PASO 2: Obtener id_presupuesto del primer item
    -- ========================================================================
    SELECT COALESCE(pd.id_presupuesto, NULL)
    INTO v_id_presupuesto
    FROM JSON_TABLE(
        p_detalles_json, 
        '$[*]' 
        COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto'
        )
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LIMIT 1;
    
    -- ========================================================================
    -- PASO 3: INSERTAR REQUERIMIENTO PRINCIPAL
    -- ========================================================================
    INSERT INTO TblRequerimiento (
        codigo,
        num_usuario,
        id_presupuesto,
        descripcion,
        cantidad,
        estado,
        observaciones,
        fecha_creacion
    ) VALUES (
        v_codigo,
        p_num_usuario,
        v_id_presupuesto,
        p_descripcion,
        COALESCE(v_cantidad_total, 0),
        'PENDIENTE',
        COALESCE(p_observaciones, ''),
        NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- ========================================================================
    -- PASO 4: PROCESAR CADA ITEM DEL JSON
    -- ========================================================================
    SET v_json_length = JSON_LENGTH(p_detalles_json);
    SET v_idx = 0;
    
    WHILE v_idx < v_json_length DO
        -- Extraer datos del JSON
        SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].id_detalle_presupuesto'));
        SET v_cantidad_editada = CAST(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].cantidad')) AS DECIMAL(10, 2));
        SET v_tipo_item = COALESCE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].tipo_item')), 'MATERIAL');
        
        -- Obtener datos actuales del presupuesto
        SELECT 
            pd.cantidad,
            pd.cantidad_original,
            COALESCE(pd.cantidad_consumida, 0),
            COALESCE(pd.cantidad_saldo, 0)
        INTO 
            v_cantidad_original,
            v_cantidad_original,
            v_cantidad_consumida_actual,
            v_saldo_anterior
        FROM TblPresupuestoDetalle pd
        WHERE pd.id_detalle = v_id_detalle;
        
        -- Calcular nueva cantidad consumida
        SET v_nueva_cantidad_consumida = v_cantidad_consumida_actual + v_cantidad_editada;
        
        -- Calcular saldo nuevo
        SET v_saldo_nuevo = v_cantidad_original - v_nueva_cantidad_consumida;
        
        -- ====================================================================
        -- SUBPASO 4A: INSERTAR DETALLE EN TblRequerimientoDetalle
        -- ====================================================================
        INSERT INTO TblRequerimientoDetalle (
            id_requerimiento,
            id_material,
            tipo_item,
            descripcion,
            cantidad,
            unidad_medida,
            fecha_creacion
        )
        SELECT
            p_id_requerimiento_created,
            CASE 
                WHEN COALESCE(v_tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
                WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
                ELSE pd.id_material
            END as id_material,
            v_tipo_item,
            CASE 
                WHEN v_tipo_item = 'SERVICIO' THEN 
                    COALESCE(pd.descripcion, 'Servicio sin descripción')
                ELSE 
                    COALESCE(m.nombre, pd.descripcion, 'Material sin especificar')
            END as descripcion,
            v_cantidad_editada,  -- ⭐ USAR CANTIDAD EDITADA
            COALESCE(um.nombre, 'und') as unidad_medida,
            NOW()
        FROM TblPresupuestoDetalle pd
        LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0
        LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
        WHERE pd.id_detalle = v_id_detalle;
        
        -- ====================================================================
        -- SUBPASO 4B: ACTUALIZAR cantidad_consumida EN TblPresupuestoDetalle
        -- ====================================================================
        UPDATE TblPresupuestoDetalle
        SET cantidad_consumida = v_nueva_cantidad_consumida
        WHERE id_detalle = v_id_detalle;
        
        -- ====================================================================
        -- SUBPASO 4C: REGISTRAR EN TblRequerimientoAuditoria
        -- ====================================================================
        INSERT INTO TblRequerimientoAuditoria (
            id_presupuesto,
            id_detalle_presupuesto,
            id_requerimiento,
            cantidad_requerida,
            cantidad_anterior_consumida,
            cantidad_nueva_consumida,
            saldo_anterior,
            saldo_nuevo,
            accion,
            num_usuario,
            observaciones,
            fecha_registro
        ) VALUES (
            v_id_presupuesto,
            v_id_detalle,
            p_id_requerimiento_created,
            v_cantidad_editada,  -- ⭐ CANTIDAD SOLICITADA EN ESTE REQUERIMIENTO
            v_cantidad_consumida_actual,  -- Consumo ANTES
            v_nueva_cantidad_consumida,   -- Consumo DESPUÉS
            v_saldo_anterior,             -- Saldo ANTES
            v_saldo_nuevo,                -- Saldo DESPUÉS
            'CREAR',
            p_num_usuario,
            CONCAT('Requerimiento ', v_codigo, ' - Item id_detalle=', v_id_detalle),
            NOW()
        );
        
        SET v_idx = v_idx + 1;
    END WHILE;
    
    -- ========================================================================
    -- PASO 5: CONFIRMACIÓN
    -- ========================================================================
    -- El requerimiento se ha creado con éxito
    
END$$

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP
-- ============================================================================
/*
-- Llamar al SP con datos de prueba:
SET @json = '[
    {
        "id_detalle_presupuesto": 23,
        "nombre": "Cemento Portland",
        "cantidad": 50,
        "tipo_item": "MATERIAL",
        "unidad": "Bolsa"
    },
    {
        "id_detalle_presupuesto": 24,
        "nombre": "Acero",
        "cantidad": 30,
        "tipo_item": "MATERIAL",
        "unidad": "kg"
    }
]';

SET @id_req_created = 0;

CALL sp_CrearRequerimientoCompleto(
    1,  -- p_num_usuario
    'Test de requerimiento con cantidades editadas',
    'Observaciones de prueba',
    @json,
    @id_req_created
);

SELECT @id_req_created as 'ID Requerimiento Creado';

-- Verificar que se registró todo correctamente
SELECT * FROM TblRequerimiento WHERE id_requerimiento = @id_req_created;
SELECT * FROM TblRequerimientoDetalle WHERE id_requerimiento = @id_req_created;
SELECT * FROM TblRequerimientoAuditoria WHERE id_requerimiento = @id_req_created;
SELECT * FROM TblPresupuestoDetalle WHERE id_detalle IN (23, 24);
*/
