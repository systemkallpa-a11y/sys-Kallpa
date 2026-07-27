-- ============================================================================
-- STORED PROCEDURE: sp_CrearRequerimientoCompleto
-- DESCRIPCIÓN: Crea un requerimiento con sus detalles en una transacción
-- PARÁMETROS:
--   p_num_usuario: num_usuario del usuario solicitante (FK a TblUsuario)
--   p_descripcion: Descripción general del requerimiento
--   p_observaciones: Observaciones generales
--   p_detalles_json: JSON con array de items {id_detalle_presupuesto, tipo_item}
-- RETORNA: 
--   @p_id_requerimiento_created: ID del requerimiento creado
-- AUTOR: Sistema Kallpa
-- FECHA: 2026-07-16
-- ACTUALIZADO: 2026-07-16 - Remover observaciones de detalles
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
    
    -- Calcular cantidad total de items desde el presupuesto
    SELECT COALESCE(SUM(pd.cantidad), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle;
    
    -- Obtener id_presupuesto del primer item del JSON
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
    
    -- Insertar requerimiento principal
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
    
    -- Insertar detalles del requerimiento desde TblPresupuestoDetalle
    -- NO incluye observaciones (no necesario en detalles)
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
        -- id_material: NULL para servicios, valor para materiales
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
            WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
            ELSE pd.id_material
        END as id_material,
        COALESCE(pd.tipo_item, 'MATERIAL') as tipo_item,
        -- descripcion: según tipo
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN 
                COALESCE(pd.descripcion, 'Servicio sin descripción')
            ELSE 
                COALESCE(m.nombre, pd.descripcion, 'Material sin especificar')
        END as descripcion,
        COALESCE(pd.cantidad, 1) as cantidad,
        COALESCE(um.nombre, 'und') as unidad_medida,
        NOW()
    FROM JSON_TABLE(
        p_detalles_json, 
        '$[*]' 
        COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto'
        )
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad;
    
END$$

DELIMITER ;
