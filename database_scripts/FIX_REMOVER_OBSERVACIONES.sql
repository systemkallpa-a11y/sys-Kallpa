-- ============================================================================
-- SCRIPT: Remover campo observaciones de TblRequerimientoDetalle
-- DESCRIPCIÓN: Campo no necesario, observaciones van en TblRequerimiento
-- FECHA: 2026-07-16
-- ============================================================================

SELECT 'Iniciando fix para remover observaciones de detalles' as paso;

SET SQL_SAFE_UPDATES = 0;

-- PASO 1: Verificar estructura actual
SELECT 'PASO 1: Estructura actual de TblRequerimientoDetalle:' as paso;
DESCRIBE TblRequerimientoDetalle;

-- PASO 2: Remover la columna observaciones
SELECT 'PASO 2: Removiendo columna observaciones' as paso;

ALTER TABLE TblRequerimientoDetalle 
DROP COLUMN IF EXISTS observaciones;

-- PASO 3: Actualizar SP que crea requerimientos
SELECT 'PASO 3: Actualizando SP sp_CrearRequerimientoCompleto' as paso;

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
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
            WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
            ELSE pd.id_material
        END as id_material,
        COALESCE(pd.tipo_item, 'MATERIAL') as tipo_item,
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

-- PASO 4: Actualizar SP que obtiene detalles
SELECT 'PASO 4: Actualizando SP sp_ObtenerRequerimientoDetalles' as paso;

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientoDetalles;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimientoDetalles(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.unidad_medida,
        m.codigo_material,
        m.nombre as material_nombre,
        m.id_categoria,
        cm.nombre as categoria_nombre,
        rd.fecha_creacion,
        rd.fecha_actualizacion
    FROM TblRequerimientoDetalle rd
    INNER JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.id_detalle;
END$$

DELIMITER ;

SET SQL_SAFE_UPDATES = 1;

-- PASO 5: Verificación final
SELECT 'PASO 5: Verificación final - Estructura de TblRequerimientoDetalle:' as paso;
DESCRIBE TblRequerimientoDetalle;

SELECT '✓ Fix completado - Observaciones removidas' as resultado;
