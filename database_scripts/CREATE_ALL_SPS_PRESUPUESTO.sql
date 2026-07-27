-- ============================================================================
-- STORED PROCEDURES PARA PRESUPUESTOS
-- ============================================================================

-- 1. Obtener todas las empresas
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerEmpresas$$

CREATE PROCEDURE sp_ObtenerEmpresas()
BEGIN
    SELECT 
        id_empresa,
        nombre
    FROM TblEmpresa
    WHERE activa = 1
    ORDER BY nombre ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 2. Obtener todos los proyectos
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerProyectos$$

CREATE PROCEDURE sp_ObtenerProyectos()
BEGIN
    SELECT 
        id_proyecto,
        nombre
    FROM TblProyecto
    ORDER BY nombre ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 3. Obtener obras por proyecto
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerObrasPorProyecto$$

CREATE PROCEDURE sp_ObtenerObrasPorProyecto(
    IN p_id_proyecto INT
)
BEGIN
    SELECT 
        id_obra,
        nombre
    FROM TblObra
    WHERE id_proyecto = p_id_proyecto
    ORDER BY nombre ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 4. Obtener categorías de materiales
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerCategoriasMaterial$$

CREATE PROCEDURE sp_ObtenerCategoriasMaterial()
BEGIN
    SELECT 
        id_categoria,
        nombre
    FROM TblCategoriaMaterial
    ORDER BY nombre ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 5. Buscar materiales por nombre, código y/o categoría
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_BuscarMateriales$$

CREATE PROCEDURE sp_BuscarMateriales(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT 
        m.id_material,
        m.codigo_material,
        m.nombre,
        m.precio_unitario,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblMateriales m
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE m.estado = 'ACTIVO'
    AND (
        p_termino_busqueda = '' 
        OR m.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
        OR m.codigo_material LIKE CONCAT('%', p_termino_busqueda, '%')
    )
    AND (
        p_id_categoria = 0
        OR m.id_categoria = p_id_categoria
    )
    ORDER BY m.codigo_material ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 6. Obtener encabezado de presupuesto para editar
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoEditar$$

CREATE PROCEDURE sp_ObtenerPresupuestoEditar(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.id_empresa,
        e.nombre as nombre_empresa,
        p.id_obra,
        p.num_documento,
        p.monto,
        p.estado,
        p.observaciones,
        o.id_proyecto,
        o.nombre as nombre_obra,
        pr.nombre as nombre_proyecto
    FROM TblPresupuesto p
    LEFT JOIN TblEmpresa e ON p.id_empresa = e.id_empresa
    LEFT JOIN TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    WHERE p.id_presupuesto = p_id_presupuesto;
END$$

DELIMITER ;

-- ============================================================================

-- 7. Obtener detalles del presupuesto (materiales y servicios)
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoDetalles$$

CREATE PROCEDURE sp_ObtenerPresupuestoDetalles(
    IN p_id_presupuesto INT
)
BEGIN
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        d.tipo_item,
        d.descripcion,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        COALESCE(m.nombre, d.descripcion) as nombre_item,
        m.codigo_material,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE d.id_presupuesto = p_id_presupuesto
    ORDER BY d.tipo_item ASC, d.id_detalle ASC;
END$$

DELIMITER ;

-- ============================================================================

-- 8. CREAR PRESUPUESTO CON MATERIALES Y SERVICIOS (NUEVO SP)
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoCompleto$$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearPresupuestoCompleto`(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
BEGIN
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_total_monto DECIMAL(12,2);
    
    -- Generar número de presupuesto automáticamente
    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(CAST(SUBSTRING(numero_presupuesto, 6) AS UNSIGNED)), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM TblPresupuesto
    WHERE numero_presupuesto LIKE 'PRES-%';
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Insertar presupuesto principal
    INSERT INTO TblPresupuesto (
        id_empresa,
        numero_presupuesto,
        id_obra,
        num_documento,
        monto,
        estado,
        observaciones,
        fecha_creacion
    ) VALUES (
        p_id_empresa,
        v_numero_presupuesto,
        p_id_obra,
        COALESCE((SELECT u.num_documento FROM TblUsuario u WHERE u.id_empresa = p_id_empresa LIMIT 1), 0),
        v_total_monto,
        'PENDIENTE',
        p_comentarios,
        NOW()
    );
    
    SET p_id_presupuesto_created = LAST_INSERT_ID();
    
    -- Insertar materiales (CON cantidad_original = cantidad)
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto_created,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')) AS UNSIGNED),
        'MATERIAL',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)), -- cantidad_original = cantidad
        0, -- cantidad_consumida comienza en 0
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- Insertar servicios (CON cantidad_original = cantidad)
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto_created,
        NULL,
        'SERVICIO',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)), -- cantidad_original = cantidad
        0, -- cantidad_consumida comienza en 0
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
END$$

DELIMITER ;

-- ============================================================================

-- 9. ACTUALIZAR PRESUPUESTO COMPLETO (NUEVO SP)
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto$$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2);
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(JSON_EXTRACT(item, '$.cantidad') * JSON_EXTRACT(item, '$.precio_unitario')), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Actualizar presupuesto
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        num_documento = COALESCE((SELECT u.num_documento FROM TblUsuario u WHERE u.id_empresa = p_id_empresa LIMIT 1), 0),
        monto = v_total_monto,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- 🆕 BORRAR REGISTROS DE APROBACIÓN/RECHAZO CUANDO SE EDITA
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_presupuesto
    AND id_tipo_documento = 1;
    
    -- Eliminar detalles viejos
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Insertar materiales nuevos (solo si hay)
    IF JSON_LENGTH(p_materiales_json) > 0 THEN
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            id_material,
            tipo_item,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal,
            fecha_creacion
        )
        SELECT
            p_id_presupuesto,
            NULLIF(JSON_EXTRACT(item, '$.id_material'), JSON_QUOTE('null')),
            'MATERIAL',
            JSON_EXTRACT(item, '$.nombre'),
            CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10,2)),
            CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(10,2)),
            CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10,2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(10,2)),
            NOW()
        FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    END IF;
    
    -- Insertar servicios nuevos (solo si hay)
    IF JSON_LENGTH(p_servicios_json) > 0 THEN
        INSERT INTO TblPresupuestoDetalle (
            id_presupuesto,
            tipo_item,
            descripcion,
            cantidad,
            precio_unitario,
            subtotal,
            fecha_creacion
        )
        SELECT
            p_id_presupuesto,
            'SERVICIO',
            JSON_EXTRACT(item, '$.descripcion'),
            CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10,2)),
            CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(10,2)),
            CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10,2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(10,2)),
            NOW()
        FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- FIN DE STORED PROCEDURES
-- ============================================================================

