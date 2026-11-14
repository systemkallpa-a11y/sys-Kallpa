-- SPs que tocan inventario, tal como están en la BD
-- Exportado: 2026-11-13T21:16:10

DELIMITER $$

-- ============================================ sp_actualizar_inventario
DROP PROCEDURE IF EXISTS `sp_actualizar_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_actualizar_inventario`(
    IN p_id_inventario INT,
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    IN p_tipo_inventario VARCHAR(50),
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_stock_minimo DECIMAL(10,2),
    IN p_stock_maximo DECIMAL(10,2),
    IN p_precio_compra DECIMAL(10,2),
    IN p_id_almacen INT,
    IN p_ubicacion_fisica VARCHAR(100),
    IN p_estado VARCHAR(50),
    IN p_modificado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_existe INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al actualizar el item';
    END;
    
    START TRANSACTION;
    
    -- Verificar que el item existe
    SELECT COUNT(*) INTO v_existe
    FROM TblInventario
    WHERE id_inventario = p_id_inventario;
    
    IF v_existe = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'El item no existe';
        ROLLBACK;
    ELSE
        -- Validar que el nombre no esté vacío
        IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
            SET p_success = FALSE;
            SET p_message = 'El nombre del item es obligatorio';
            ROLLBACK;
        ELSE
            -- Actualizar el item
            UPDATE TblInventario
            SET nombre = p_nombre,
                descripcion = p_descripcion,
                tipo_inventario = p_tipo_inventario,
                id_categoria = p_id_categoria,
                id_unidad = p_id_unidad,
                stock_minimo = p_stock_minimo,
                stock_maximo = p_stock_maximo,
                precio_compra = p_precio_compra,
                id_almacen = p_id_almacen,
                ubicacion_fisica = p_ubicacion_fisica,
                estado = p_estado,
                fecha_modificacion = NOW(),
                modificado_por = p_modificado_por
            WHERE id_inventario = p_id_inventario;
            
            -- Éxito
            SET p_success = TRUE;
            SET p_message = 'Item actualizado correctamente';
            
            COMMIT;
        END IF;
    END IF;
END$$

-- ============================================ sp_ajustar_stock
DROP PROCEDURE IF EXISTS `sp_ajustar_stock`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ajustar_stock`(
    IN p_id_inventario INT,
    IN p_tipo_movimiento VARCHAR(20),
    IN p_cantidad DECIMAL(10,2),
    IN p_motivo TEXT,
    IN p_documento_referencia VARCHAR(50),
    IN p_realizado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255),
    OUT p_nuevo_stock DECIMAL(10,2)
)
BEGIN
    DECLARE v_stock_actual DECIMAL(10,2);
    DECLARE v_id_almacen INT;
    DECLARE v_nombre_item VARCHAR(200);
    DECLARE v_nuevo_stock DECIMAL(10,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al procesar el movimiento';
        SET p_nuevo_stock = 0;
    END;
    
    START TRANSACTION;
    
    -- Validar que el item existe y obtener datos
    SELECT stock_actual, id_almacen, nombre
    INTO v_stock_actual, v_id_almacen, v_nombre_item
    FROM TblInventario
    WHERE id_inventario = p_id_inventario;
    
    IF v_nombre_item IS NULL THEN
        SET p_success = FALSE;
        SET p_message = 'Item no encontrado';
        SET p_nuevo_stock = 0;
        ROLLBACK;
    ELSE
        -- Calcular nuevo stock según tipo de movimiento
        IF p_tipo_movimiento = 'ENTRADA' THEN
            SET v_nuevo_stock = v_stock_actual + p_cantidad;
            
        ELSEIF p_tipo_movimiento = 'SALIDA' THEN
            -- Validar stock suficiente
            IF p_cantidad > v_stock_actual THEN
                SET p_success = FALSE;
                SET p_message = CONCAT('Stock insuficiente. Disponible: ', v_stock_actual);
                SET p_nuevo_stock = v_stock_actual;
                ROLLBACK;
            ELSE
                SET v_nuevo_stock = v_stock_actual - p_cantidad;
            END IF;
            
        ELSEIF p_tipo_movimiento = 'AJUSTE' THEN
            -- Ajuste es el valor absoluto (corrección de inventario)
            SET v_nuevo_stock = p_cantidad;
            
        ELSE
            SET p_success = FALSE;
            SET p_message = 'Tipo de movimiento inválido';
            SET p_nuevo_stock = v_stock_actual;
            ROLLBACK;
        END IF;
        
        -- Si llegamos aquí, el movimiento es válido
        IF p_success IS NULL THEN
            -- Actualizar stock en TblInventario
            UPDATE TblInventario
            SET stock_actual = v_nuevo_stock,
                fecha_actualizacion = NOW()
            WHERE id_inventario = p_id_inventario;
            
            -- Registrar movimiento en TblMovimientoInventario
            INSERT INTO TblMovimientoInventario (
                codigo_movimiento,
                id_inventario,
                id_almacen_origen,
                tipo_movimiento,
                cantidad,
                motivo,
                observaciones,
                id_documento_referencia,
                costo_unitario,
                costo_total,
                fecha_movimiento,
                realizado_por,
                aprobado_por
            ) VALUES (
                CONCAT(
                    CASE p_tipo_movimiento
                        WHEN 'ENTRADA' THEN 'ENT'
                        WHEN 'SALIDA' THEN 'SAL'
                        WHEN 'AJUSTE' THEN 'AJU'
                    END,
                    '-',
                    DATE_FORMAT(NOW(), '%Y%m%d'),
                    '-',
                    LPAD(p_id_inventario, 5, '0')
                ),
                p_id_inventario,
                v_id_almacen,
                p_tipo_movimiento,
                p_cantidad,
                p_motivo,
                NULL,
                NULL,
                (SELECT precio_compra FROM TblInventario WHERE id_inventario = p_id_inventario),
                p_cantidad * (SELECT precio_compra FROM TblInventario WHERE id_inventario = p_id_inventario),
                NOW(),
                p_realizado_por,
                NULL
            );
            
            -- Éxito
            SET p_success = TRUE;
            SET p_message = CONCAT('Movimiento registrado correctamente. Nuevo stock: ', v_nuevo_stock);
            SET p_nuevo_stock = v_nuevo_stock;
            
            COMMIT;
        END IF;
    END IF;
END$$

-- ============================================ sp_asociar_proveedor_inventario
DROP PROCEDURE IF EXISTS `sp_asociar_proveedor_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_asociar_proveedor_inventario`(
    IN  p_id_inventario      INT,
    IN  p_ruc_proveedor      VARCHAR(11),
    IN  p_codigo_proveedor   VARCHAR(50),
    IN  p_precio_compra      DECIMAL(10,2),
    IN  p_moneda             VARCHAR(10),
    IN  p_plazo_entrega_dias INT,
    IN  p_es_principal       TINYINT(1),
    IN  p_observaciones      TEXT,
    IN  p_creado_por         VARCHAR(20),
    OUT p_success            TINYINT(1),
    OUT p_message            VARCHAR(255),
    OUT p_id_relacion        INT
)
sp_body: BEGIN
    DECLARE v_existe INT DEFAULT 0;

    -- Validar ítem de inventario
    IF NOT EXISTS (
        SELECT 1 FROM TblInventario
        WHERE id_inventario = p_id_inventario AND estado = 'ACTIVO'
    ) THEN
        SET p_success    = 0;
        SET p_message    = 'El ítem de inventario no existe o está inactivo';
        SET p_id_relacion = 0;
        LEAVE sp_body;
    END IF;

    -- Validar proveedor
    IF NOT EXISTS (
        SELECT 1 FROM TblProveedores
        WHERE ruc = p_ruc_proveedor AND estado != 'ELIMINADO'
    ) THEN
        SET p_success    = 0;
        SET p_message    = 'El proveedor no existe';
        SET p_id_relacion = 0;
        LEAVE sp_body;
    END IF;

    -- Si se marca como principal, quitar flag del anterior
    IF p_es_principal = 1 THEN
        UPDATE TblInventarioProveedor
        SET es_principal = 0
        WHERE id_inventario = p_id_inventario AND es_principal = 1;
    END IF;

    -- ¿Ya existe la relación (activa o inactiva)?
    SELECT COUNT(*) INTO v_existe
    FROM TblInventarioProveedor
    WHERE id_inventario = p_id_inventario AND ruc_proveedor = p_ruc_proveedor;

    IF v_existe > 0 THEN
        -- Reactivar y actualizar
        UPDATE TblInventarioProveedor
        SET codigo_proveedor    = p_codigo_proveedor,
            precio_compra       = p_precio_compra,
            moneda              = IFNULL(p_moneda, 'SOLES'),
            plazo_entrega_dias  = p_plazo_entrega_dias,
            es_principal        = p_es_principal,
            estado              = 'ACTIVO',
            observaciones       = p_observaciones,
            actualizado_por     = p_creado_por,
            fecha_actualizacion = NOW()
        WHERE id_inventario = p_id_inventario
          AND ruc_proveedor = p_ruc_proveedor;

        SELECT id_inventario_proveedor INTO p_id_relacion
        FROM TblInventarioProveedor
        WHERE id_inventario = p_id_inventario AND ruc_proveedor = p_ruc_proveedor;

        SET p_success = 1;
        SET p_message = 'Proveedor actualizado correctamente';
    ELSE
        -- Nueva relación
        INSERT INTO TblInventarioProveedor (
            id_inventario, ruc_proveedor, codigo_proveedor,
            precio_compra, moneda, plazo_entrega_dias,
            es_principal, estado, observaciones, creado_por
        ) VALUES (
            p_id_inventario, p_ruc_proveedor, p_codigo_proveedor,
            p_precio_compra, IFNULL(p_moneda, 'SOLES'), p_plazo_entrega_dias,
            p_es_principal, 'ACTIVO', p_observaciones, p_creado_por
        );

        SET p_id_relacion = LAST_INSERT_ID();
        SET p_success = 1;
        SET p_message = 'Proveedor asociado correctamente';
    END IF;
END sp_body$$

-- ============================================ sp_BuscarMateriales
DROP PROCEDURE IF EXISTS `sp_BuscarMateriales`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMateriales`(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        i.id_unidad,
        i.id_categoria,
        COALESCE(c.nombre, 'General') AS categoria,
        COALESCE(u.nombre, 'Unidad') AS unidad_medida,
        COALESCE(u.abreviatura, 'UND') AS unidad_abrev,
        COALESCE(i.precio_compra, 0) AS precio_compra
    FROM `TblInventario` i
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    LEFT JOIN `TblUnidadMedida` u ON i.id_unidad = u.id_unidad
    WHERE i.estado = 'ACTIVO'
      AND (
            p_termino_busqueda = ''
            OR i.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_termino_busqueda, '%')
          )
      AND (
            p_id_categoria = 0
            OR i.id_categoria = p_id_categoria
          )
    ORDER BY i.codigo ASC
    LIMIT 100;
END$$

-- ============================================ sp_BuscarMaterialesAutocompletado
DROP PROCEDURE IF EXISTS `sp_BuscarMaterialesAutocompletado`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMaterialesAutocompletado`(
    IN p_busqueda VARCHAR(200)
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        COALESCE(c.nombre, 'General') AS categoria,
        COALESCE(u.nombre, 'Unidad') AS unidad_medida,
        COALESCE(u.abreviatura, 'UND') AS unidad_abrev,
        i.id_unidad,
        i.estado
    FROM `TblInventario` i
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    LEFT JOIN `TblUnidadMedida` u ON i.id_unidad = u.id_unidad
    WHERE i.estado = 'ACTIVO'
      AND (
            i.nombre LIKE CONCAT('%', p_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_busqueda, '%')
            OR i.descripcion LIKE CONCAT('%', p_busqueda, '%')
          )
    ORDER BY
        CASE
            WHEN i.nombre LIKE CONCAT(p_busqueda, '%') THEN 1
            WHEN i.codigo LIKE CONCAT(p_busqueda, '%') THEN 2
            ELSE 3
        END,
        i.nombre ASC
    LIMIT 50;
END$$

-- ============================================ sp_BuscarMaterialPorNombre
DROP PROCEDURE IF EXISTS `sp_BuscarMaterialPorNombre`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarMaterialPorNombre`(
    IN p_nombre VARCHAR(150)
)
BEGIN
    SELECT
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.id_unidad,
        i.tipo_inventario
    FROM `TblInventario` i
    WHERE i.nombre = p_nombre
      AND i.estado = 'ACTIVO'
      AND i.tipo_inventario NOT IN ('SERVICIO','PARTIDA')
    LIMIT 1;
END$$

-- ============================================ sp_BuscarUnidadPorNombre
DROP PROCEDURE IF EXISTS `sp_BuscarUnidadPorNombre`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_BuscarUnidadPorNombre`(
    IN p_nombre VARCHAR(100)
)
BEGIN
    SELECT 
        id_unidad,
        codigo,
        nombre,
        abreviatura
    FROM TblUnidadMedida
    WHERE (
        abreviatura = p_nombre
        OR nombre = p_nombre
        OR nombre LIKE CONCAT('%', p_nombre, '%')
        OR abreviatura LIKE CONCAT('%', p_nombre, '%')
    )
    AND estado = 'ACTIVO'
    LIMIT 1;
END$$

-- ============================================ sp_CrearMaterialConCodigoAuto
DROP PROCEDURE IF EXISTS `sp_CrearMaterialConCodigoAuto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearMaterialConCodigoAuto`(
    IN p_nombre VARCHAR(150),
    IN p_descripcion LONGTEXT,
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_observaciones LONGTEXT,
    OUT p_id_inventario_creado INT,
    OUT p_codigo_generado VARCHAR(50),
    OUT p_resultado INT
)
BEGIN
    DECLARE v_ultimo_numero INT DEFAULT 0;
    DECLARE v_siguiente_numero INT;
    DECLARE v_nuevo_codigo VARCHAR(50);
    DECLARE v_id_categoria INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = 0;
        SET p_id_inventario_creado = NULL;
        SET p_codigo_generado = NULL;
    END;

    START TRANSACTION;

    SET v_id_categoria = p_id_categoria;
    IF v_id_categoria IS NULL OR v_id_categoria <= 0 THEN
        SELECT id_categoria INTO v_id_categoria
        FROM `TblCategoriaInventario`
        WHERE codigo = 'MAT-OTROS'
        LIMIT 1;
    END IF;
    IF v_id_categoria IS NULL THEN
        SELECT id_categoria INTO v_id_categoria
        FROM `TblCategoriaInventario`
        WHERE estado = 'ACTIVO'
        ORDER BY id_categoria
        LIMIT 1;
    END IF;

    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0)
    INTO v_ultimo_numero
    FROM `TblInventario`
    WHERE codigo LIKE 'MAT-%'
      AND codigo REGEXP '^MAT-[0-9]+$';

    SET v_siguiente_numero = v_ultimo_numero + 1;
    SET v_nuevo_codigo = CONCAT('MAT-', LPAD(v_siguiente_numero, 3, '0'));

    INSERT INTO `TblInventario` (
        codigo,
        nombre,
        descripcion,
        id_categoria,
        tipo_inventario,
        stock_actual,
        stock_minimo,
        stock_maximo,
        id_unidad,
        precio_compra,
        precio_promedio,
        estado
    ) VALUES (
        v_nuevo_codigo,
        p_nombre,
        p_descripcion,
        v_id_categoria,
        'MATERIAL',
        0,
        0,
        0,
        p_id_unidad,
        0,
        0,
        'ACTIVO'
    );

    SET p_id_inventario_creado = LAST_INSERT_ID();
    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;

    COMMIT;
END$$

-- ============================================ sp_CrearPresupuestoCompleto
DROP PROCEDURE IF EXISTS `sp_CrearPresupuestoCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearPresupuestoCompleto`(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),
    IN p_utilidad DECIMAL(12,2),
    IN p_supervision_obra DECIMAL(12,2),
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
BEGIN
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_sub_total DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;

    DECLARE v_id_version_1 INT;
    DECLARE v_id_proyecto INT;
    DECLARE v_id_obra_local INT;
    DECLARE v_nombre_proyecto VARCHAR(255);
    DECLARE v_nombre_obra VARCHAR(255);

    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(CAST(SUBSTRING(numero_presupuesto, 6) AS UNSIGNED)), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM `TblPresupuesto`
    WHERE numero_presupuesto LIKE 'PRES-%';

    SELECT COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) *
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SELECT v_subtotal_base + COALESCE(SUM(
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) *
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2))
    ), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;

    SET v_sub_total = v_subtotal_base + p_gastos_generales + p_utilidad;

    SET v_igv = ROUND(v_sub_total * 0.18, 2);

    SET v_monto_total = v_sub_total + v_igv + p_supervision_obra;

    INSERT INTO `TblPresupuesto` (
        id_empresa,
        numero_presupuesto,
        id_obra,
        num_documento,
        monto,
        monto_total,
        monto_aprobado,
        gastos_generales,
        utilidad,
        igv,
        supervision_obra,
        estado,
        observaciones,
        fecha_creacion,
        fecha_actualizacion
    ) VALUES (
        p_id_empresa,
        v_numero_presupuesto,
        p_id_obra,
        p_num_documento,
        v_subtotal_base,
        v_monto_total,
        0,
        p_gastos_generales,
        p_utilidad,
        v_igv,
        p_supervision_obra,
        'PENDIENTE',
        p_comentarios,
        NOW(),
        NOW()
    );

    SET p_id_presupuesto_created = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto_created,
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'SERVICIO' THEN 'SERVICIO'
            ELSE 'MATERIAL'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;

    INSERT INTO `TblPresupuestoDetalle` (
        id_presupuesto,
        id_inventario,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto_created,
                NULLIF(CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_inventario')) AS UNSIGNED), 0),
        CASE
            WHEN JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')) = 'PARTIDA' THEN 'PARTIDA'
            ELSE 'SERVICIO'
        END,
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
            JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre'))
        ),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;

    INSERT INTO `TblRegistroAprobacion` (
        id_tipo_documento,
        id_documento_referencia,
        numero_paso,
        id_cargo_aprobador,
        estado_aprobacion,
        fecha_asignacion
    )
    SELECT
        fac.id_tipo_documento,
        p_id_presupuesto_created,
        fac.numero_paso,
        fac.id_cargo,
        'PENDIENTE',
        NOW()
    FROM `TblFlujoAprobacionCargos` fac
    WHERE fac.id_tipo_documento = 1
      AND fac.activo = 1
    ORDER BY fac.numero_paso;

    SELECT
        o.id_proyecto,
        o.id_obra,
        p.nombre,
        o.nombre
    INTO
        v_id_proyecto,
        v_id_obra_local,
        v_nombre_proyecto,
        v_nombre_obra
    FROM `TblObra` o
    LEFT JOIN `TblProyecto` p ON o.id_proyecto = p.id_proyecto
    WHERE o.id_obra = p_id_obra
    LIMIT 1;

    INSERT INTO `TblPresupuestoVersionHistorial` (
        id_presupuesto,
        numero_version,
        fecha_version,
        creado_por,
        motivo_cambio,
        es_version_actual,
        numero_presupuesto,
        id_proyecto,
        id_obra,
        nombre_proyecto,
        nombre_obra,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    ) VALUES (
        p_id_presupuesto_created,
        1,
        NOW(),
        p_num_documento,
        'Versión 1 - Creación inicial del presupuesto',
        1,
        v_numero_presupuesto,
        v_id_proyecto,
        p_id_obra,
        v_nombre_proyecto,
        v_nombre_obra,
        NOW(),
        NULL,
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p_id_presupuesto_created
           AND tipo_item = 'MATERIAL'),
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p_id_presupuesto_created
           AND tipo_item IN ('SERVICIO','PARTIDA')),
        v_subtotal_base,
        p_gastos_generales,
        p_utilidad,
        v_sub_total,
        v_igv,
        p_supervision_obra,
        v_monto_total,
        CASE WHEN v_subtotal_base > 0 THEN ROUND((p_gastos_generales / v_subtotal_base) * 100, 2) ELSE 0 END,
        CASE WHEN v_subtotal_base > 0 THEN ROUND((p_utilidad / v_subtotal_base) * 100, 2) ELSE 0 END,
        CASE WHEN v_sub_total > 0 THEN ROUND((p_supervision_obra / v_sub_total) * 100, 2) ELSE 0 END,
        p_comentarios,
        'PENDIENTE'
    );

    SET v_id_version_1 = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_id_version_1,
        'MATERIAL',
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        pd.cantidad * pd.precio_unitario,
        pd.id_detalle
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto_created
      AND pd.tipo_item = 'MATERIAL';

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_id_version_1,
        pd.tipo_item,
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        pd.cantidad * pd.precio_unitario,
        pd.id_detalle + 10000
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto_created
      AND pd.tipo_item IN ('SERVICIO','PARTIDA');

END$$

-- ============================================ sp_CrearRequerimientoAdministrativo
DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoAdministrativo`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearRequerimientoAdministrativo`(
    IN p_num_usuario INT,
    IN p_num_documento INT,
    IN p_fecha_solicitud DATE,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_id_requerimiento INT,
    OUT p_codigo VARCHAR(20)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_id_tipo_documento INT DEFAULT 7;
    DECLARE v_id_req INT;
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_items INT DEFAULT 0;
    DECLARE v_encontrados INT DEFAULT 0;
    DECLARE v_cantidad_total DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_pasos INT DEFAULT 0;
    DECLARE v_msg VARCHAR(500) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;
        RESIGNAL;
    END;

    SET p_id_requerimiento = NULL;
    SET p_codigo = NULL;

    -- ---- Validaciones de entrada -------------------------------------------
    IF p_num_usuario IS NULL OR p_num_usuario <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no válido';
    END IF;

    IF p_descripcion IS NULL OR TRIM(p_descripcion) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La descripción es obligatoria';
    END IF;

    IF p_detalles_json IS NULL OR JSON_VALID(p_detalles_json) = 0 OR JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Debe agregar al menos un material';
    END IF;

    -- Items agrupados por material (si el mismo material viene 2 veces, se suma)
    DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;
    CREATE TEMPORARY TABLE tmp_rqa_items (
        id_inventario INT NULL,
        cantidad DECIMAL(10, 2) NULL,
        KEY (id_inventario)
    );

    INSERT INTO tmp_rqa_items (id_inventario, cantidad)
    SELECT jt.id_inventario, SUM(jt.cantidad)
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_inventario INT PATH '$.id_inventario',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    GROUP BY jt.id_inventario;

    IF EXISTS (SELECT 1 FROM tmp_rqa_items WHERE id_inventario IS NULL OR cantidad IS NULL OR cantidad <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Todos los materiales deben tener una cantidad mayor a 0';
    END IF;

    START TRANSACTION;

    -- ---- Materiales válidos (y bloqueo de sus filas de inventario) ---------
    SELECT COUNT(*) INTO v_items FROM tmp_rqa_items;

    SELECT COUNT(*) INTO v_encontrados
    FROM `TblInventario` i
    INNER JOIN tmp_rqa_items t ON t.id_inventario = i.id_inventario
    WHERE i.estado = 'ACTIVO'
      AND i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
    FOR UPDATE;

    IF v_encontrados < v_items THEN
        SELECT CONCAT('El material con id ', t.id_inventario,
                      ' no existe, está inactivo o no es un material de almacén')
        INTO v_msg
        FROM tmp_rqa_items t
        LEFT JOIN `TblInventario` i
               ON i.id_inventario = t.id_inventario
              AND i.estado = 'ACTIVO'
              AND i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
        WHERE i.id_inventario IS NULL
        LIMIT 1;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- ---- Stock suficiente --------------------------------------------------
    SELECT CONCAT('Stock insuficiente para "', i.nombre, '": disponible ',
                  FORMAT(COALESCE(i.stock_actual, 0), 2), ', solicitado ', FORMAT(t.cantidad, 2))
    INTO v_msg
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario
    WHERE COALESCE(i.stock_actual, 0) < t.cantidad
    LIMIT 1;

    IF v_msg IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- ---- Código RQA-00001 (numeración propia) ------------------------------
    SELECT CONCAT('RQA-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM `TblRequerimiento`
    WHERE codigo LIKE 'RQA-%'
    FOR UPDATE;

    SELECT COALESCE(SUM(cantidad), 0) INTO v_cantidad_total FROM tmp_rqa_items;

    -- ---- Cabecera ----------------------------------------------------------
    INSERT INTO `TblRequerimiento` (
        id_tipo_requerimiento, id_tipo_documento, num_usuario, id_presupuesto,
        codigo, descripcion, cantidad, estado, observaciones, fecha_creacion
    ) VALUES (
        1, v_id_tipo_documento, p_num_usuario, NULL,
        v_codigo, TRIM(p_descripcion), ROUND(v_cantidad_total), 'PENDIENTE',
        COALESCE(p_observaciones, ''),
        TIMESTAMP(COALESCE(p_fecha_solicitud, CURDATE()), CURTIME())
    );

    SET v_id_req = LAST_INSERT_ID();

    -- ---- Detalle -----------------------------------------------------------
    INSERT INTO `TblRequerimientoDetalle` (
        id_requerimiento, id_inventario, tipo_item, descripcion, cantidad, observaciones, fecha_creacion
    )
    SELECT v_id_req, i.id_inventario, 'MATERIAL', i.nombre, t.cantidad, NULL, NOW()
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario;

    -- ---- Movimiento SALIDA (código único por requerimiento + material) ----
    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_origen, tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
    )
    SELECT
        CONCAT('SAL-RQA', LPAD(v_id_req, 6, '0'), '-', LPAD(i.id_inventario, 5, '0')),
        i.id_inventario,
        'SALIDA',
        t.cantidad,
        i.id_almacen,
        'REQUERIMIENTO',
        v_id_req,
        i.precio_compra,
        t.cantidad * COALESCE(i.precio_compra, 0),
        CONCAT('Requerimiento administrativo ', v_codigo),
        NOW(),
        p_num_documento
    FROM tmp_rqa_items t
    INNER JOIN `TblInventario` i ON i.id_inventario = t.id_inventario;

    -- ---- Descontar stock ---------------------------------------------------
    UPDATE `TblInventario` i
    INNER JOIN tmp_rqa_items t ON t.id_inventario = i.id_inventario
    SET i.stock_actual = COALESCE(i.stock_actual, 0) - t.cantidad;

    -- ---- Pasos de aprobación (flujo del tipo 7) ----------------------------
    INSERT INTO `TblRegistroAprobacion` (
        id_tipo_documento, id_documento_referencia, numero_paso,
        id_cargo_aprobador, num_documento_aprobador, estado_aprobacion,
        comentario, fecha_asignacion, fecha_aprobacion
    )
    SELECT v_id_tipo_documento, v_id_req, f.numero_paso, f.id_cargo, NULL, 'PENDIENTE', NULL, NOW(), NULL
    FROM `TblFlujoAprobacionCargos` f
    WHERE f.id_tipo_documento = v_id_tipo_documento
      AND f.activo = 1
      AND f.es_requerido = 1
    ORDER BY f.numero_paso;

    SET v_pasos = ROW_COUNT();

    IF v_pasos = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No hay flujo de aprobación configurado para Requerimiento Administrativo';
    END IF;

    COMMIT;

    DROP TEMPORARY TABLE IF EXISTS tmp_rqa_items;

    SET p_id_requerimiento = v_id_req;
    SET p_codigo = v_codigo;
END$$

-- ============================================ sp_CrearRequerimientoCompleto
DROP PROCEDURE IF EXISTS `sp_CrearRequerimientoCompleto`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_CrearRequerimientoCompleto`(
    IN p_num_usuario INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    IN p_id_presupuesto INT,
    OUT p_id_requerimiento_created INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_cantidad_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE v_id_tipo_documento INT DEFAULT 2;
    DECLARE v_id_tipo_requerimiento INT DEFAULT 2;   -- 2 = Obra
    DECLARE v_numero_paso INT;
    DECLARE v_id_cargo INT;
    DECLARE done INT DEFAULT FALSE;

    DECLARE flujo_cursor CURSOR FOR
        SELECT numero_paso, id_cargo
        FROM `TblFlujoAprobacionCargos`
        WHERE id_tipo_documento = v_id_tipo_documento
          AND activo = 1
          AND es_requerido = 1
        ORDER BY numero_paso;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF p_num_usuario IS NULL OR p_num_usuario <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'num_usuario invalido o nulo';
    END IF;

    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos';
    END IF;

    -- Código generado por la BD: REQ-00001, REQ-00002, ...
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM `TblRequerimiento`
    WHERE codigo LIKE 'REQ-%';

    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;

    -- Si el frontend no envía id_presupuesto, se deduce del primer detalle.
    IF p_id_presupuesto IS NULL THEN
        SELECT COALESCE(pd.id_presupuesto, NULL)
        INTO p_id_presupuesto
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto',
            cantidad DECIMAL(10, 2) PATH '$.cantidad'
        )) jt
        INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle
        LIMIT 1;
    END IF;

    -- Total del requerimiento: suma de las cantidades solicitadas en el formulario.
    SELECT COALESCE(SUM(COALESCE(jt.cantidad, pd.cantidad, 1)), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_detalle INT PATH '$.id_detalle_presupuesto',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle;

    INSERT INTO `TblRequerimiento` (
        codigo, id_tipo_requerimiento, id_tipo_documento, num_usuario, id_presupuesto, descripcion,
        cantidad, estado, observaciones, fecha_creacion
    ) VALUES (
        v_codigo, v_id_tipo_requerimiento, v_id_tipo_documento, p_num_usuario, p_id_presupuesto, p_descripcion,
        COALESCE(v_cantidad_total, 0), 'PENDIENTE', COALESCE(p_observaciones, ''), NOW()
    );

    SET p_id_requerimiento_created = LAST_INSERT_ID();

    -- Detalles: id_inventario + cantidad solicitada por el usuario.
    INSERT INTO `TblRequerimientoDetalle` (
        id_requerimiento,
        id_inventario,
        tipo_item,
        descripcion,
        cantidad,
        observaciones,
        fecha_creacion
    )
    SELECT
        p_id_requerimiento_created,
        pd.id_inventario,
        COALESCE(pd.tipo_item, 'MATERIAL'),
        CASE
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') IN ('SERVICIO','PARTIDA')
                THEN COALESCE(pd.descripcion, 'Servicio o partida sin descripción')
            ELSE COALESCE(i.nombre, pd.descripcion, 'Material sin especificar')
        END,
        COALESCE(jt.cantidad, pd.cantidad, 1),
        NULL,
        NOW()
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
        id_detalle INT PATH '$.id_detalle_presupuesto',
        cantidad DECIMAL(10, 2) PATH '$.cantidad'
    )) jt
    INNER JOIN `TblPresupuestoDetalle` pd ON pd.id_detalle = jt.id_detalle
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario;

    -- Consumo del presupuesto con la cantidad solicitada, no con pd.cantidad.
    UPDATE `TblPresupuestoDetalle` pd
    INNER JOIN (
        SELECT jt.id_detalle, COALESCE(jt.cantidad, pd2.cantidad, 1) AS cantidad_requerida
        FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto',
            cantidad DECIMAL(10, 2) PATH '$.cantidad'
        )) jt
        INNER JOIN `TblPresupuestoDetalle` pd2 ON pd2.id_detalle = jt.id_detalle
    ) req ON pd.id_detalle = req.id_detalle
    SET
        pd.cantidad_consumida = pd.cantidad_consumida + req.cantidad_requerida,
        pd.fecha_actualizacion = NOW()
    WHERE pd.id_presupuesto = p_id_presupuesto;

    UPDATE `TblPresupuesto`
    SET
        cantidad_consumida = cantidad_consumida + v_cantidad_total,
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;

    -- Flujo de aprobación: un registro PENDIENTE por cada paso/cargo configurado.
    OPEN flujo_cursor;

    read_loop: LOOP
        FETCH flujo_cursor INTO v_numero_paso, v_id_cargo;
        IF done THEN LEAVE read_loop; END IF;

        INSERT INTO `TblRegistroAprobacion` (
            id_tipo_documento, id_documento_referencia, numero_paso,
            id_cargo_aprobador, num_documento_aprobador, estado_aprobacion,
            comentario, fecha_asignacion, fecha_aprobacion
        ) VALUES (
            v_id_tipo_documento, p_id_requerimiento_created, v_numero_paso,
            v_id_cargo, NULL, 'PENDIENTE', NULL, NOW(), NULL
        );
    END LOOP;

    CLOSE flujo_cursor;

END$$

-- ============================================ sp_crear_inventario
DROP PROCEDURE IF EXISTS `sp_crear_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_crear_inventario`(
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    IN p_tipo_inventario VARCHAR(50),
    IN p_id_categoria INT,
    IN p_id_subcategoria INT,
    IN p_id_unidad INT,
    IN p_stock_minimo DECIMAL(10,2),
    IN p_stock_maximo DECIMAL(10,2),
    IN p_precio_compra DECIMAL(10,2),
    IN p_id_almacen INT,
    IN p_ubicacion_fisica VARCHAR(100),
    IN p_atributos_json TEXT,
    IN p_creado_por INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255),
    OUT p_id_inventario INT,
    OUT p_codigo VARCHAR(50)
)
BEGIN
    DECLARE v_codigo_generado VARCHAR(50);
    DECLARE v_id_inventario INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'Error al crear el item';
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
    END;
    
    START TRANSACTION;
    
    -- Validar que el nombre no esté vacío
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_success = FALSE;
        SET p_message = 'El nombre del item es obligatorio';
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
        ROLLBACK;
    ELSE
        -- Generar código automático
        CALL sp_generar_material(p_tipo_inventario, v_codigo_generado);
        
        -- Insertar item en TblInventario
        INSERT INTO TblInventario (
            codigo,
            nombre,
            descripcion,
            id_categoria,
            id_subcategoria,
            tipo_inventario,
            stock_actual,
            stock_minimo,
            stock_maximo,
            id_unidad,
            id_almacen,
            ubicacion_fisica,
            precio_compra,
            precio_promedio,
            estado,
            fecha_creacion,
            creado_por
        ) VALUES (
            v_codigo_generado,
            p_nombre,
            p_descripcion,
            p_id_categoria,
            p_id_subcategoria,
            p_tipo_inventario,
            0.00, -- stock inicial en 0
            p_stock_minimo,
            p_stock_maximo,
            p_id_unidad,
            p_id_almacen,
            p_ubicacion_fisica,
            p_precio_compra,
            p_precio_compra, -- precio_promedio = precio_compra inicial
            'ACTIVO',
            NOW(),
            p_creado_por
        );
        
        -- Obtener el ID generado
        SET v_id_inventario = LAST_INSERT_ID();
        
        -- Si hay atributos JSON, procesarlos
        -- Nota: Se espera un JSON como: [{"nombre":"procesador","valor":"Intel i7"},...]
        -- El procesamiento de JSON se hará desde el backend por simplicidad
        
        -- Éxito
        SET p_success = TRUE;
        SET p_message = CONCAT('Item creado exitosamente con código: ', v_codigo_generado);
        SET p_id_inventario = v_id_inventario;
        SET p_codigo = v_codigo_generado;
        
        COMMIT;
    END IF;
END$$

-- ============================================ sp_desasociar_proveedor_inventario
DROP PROCEDURE IF EXISTS `sp_desasociar_proveedor_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_desasociar_proveedor_inventario`(
    IN  p_id_inventario_proveedor INT,
    IN  p_usuario                 VARCHAR(20),
    OUT p_success                 TINYINT(1),
    OUT p_message                 VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM TblInventarioProveedor
        WHERE id_inventario_proveedor = p_id_inventario_proveedor
          AND estado = 'ACTIVO'
    ) THEN
        SET p_success = 0;
        SET p_message = 'La relación no existe o ya estaba inactiva';
    ELSE
        UPDATE TblInventarioProveedor
        SET estado              = 'INACTIVO',
            actualizado_por     = p_usuario,
            fecha_actualizacion = NOW()
        WHERE id_inventario_proveedor = p_id_inventario_proveedor;

        SET p_success = 1;
        SET p_message = 'Proveedor desasociado correctamente';
    END IF;
END$$

-- ============================================ sp_generar_material
DROP PROCEDURE IF EXISTS `sp_generar_material`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_generar_material`(
    IN p_tipo_inventario VARCHAR(50),
    OUT p_codigo VARCHAR(50)
)
BEGIN
    DECLARE v_prefijo VARCHAR(10);
    DECLARE v_siguiente_numero INT;
    DECLARE v_codigo_generado VARCHAR(50);
    
    -- Definir prefijo según tipo de inventario
    SET v_prefijo = CASE p_tipo_inventario
        WHEN 'MATERIAL' THEN 'MAT'
        WHEN 'HERRAMIENTA' THEN 'HER'
        WHEN 'EQUIPO' THEN 'EQU'
        WHEN 'TECNOLOGIA' THEN 'TEC'
        WHEN 'ROPA' THEN 'ROP'
        WHEN 'CONSUMIBLE' THEN 'OFI'
        ELSE 'INV'
    END;
    
    -- Obtener el siguiente número disponible para ese tipo
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(codigo, LENGTH(v_prefijo) + 2) AS UNSIGNED)
    ), 0) + 1
    INTO v_siguiente_numero
    FROM TblInventario
    WHERE codigo LIKE CONCAT(v_prefijo, '-%')
      AND LENGTH(codigo) >= LENGTH(v_prefijo) + 2
      AND SUBSTRING(codigo, LENGTH(v_prefijo) + 2) REGEXP '^[0-9]+$';
    
    -- Generar código con formato: PREFIJO-00001
    SET v_codigo_generado = CONCAT(v_prefijo, '-', LPAD(v_siguiente_numero, 5, '0'));
    
    -- Retornar el código generado
    SET p_codigo = v_codigo_generado;
END$$

-- ============================================ sp_GuardarSnapshotAntesDeEditar
DROP PROCEDURE IF EXISTS `sp_GuardarSnapshotAntesDeEditar`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_GuardarSnapshotAntesDeEditar`(
    IN p_id_presupuesto INT,
    IN p_creado_por INT
)
BEGIN
    DECLARE v_siguiente_numero INT;
    DECLARE v_nueva_version_id INT;
    DECLARE v_existe_version INT;

    SELECT COUNT(*) INTO v_existe_version
    FROM `TblPresupuestoVersionHistorial`
    WHERE id_presupuesto = p_id_presupuesto;

    IF v_existe_version = 0 THEN
        SET v_siguiente_numero = 1;
    ELSE
        SELECT COALESCE(MAX(numero_version), 0) + 1
        INTO v_siguiente_numero
        FROM `TblPresupuestoVersionHistorial`
        WHERE id_presupuesto = p_id_presupuesto;
    END IF;

    UPDATE `TblPresupuestoVersionHistorial`
    SET es_version_actual = 0
    WHERE id_presupuesto = p_id_presupuesto;

    INSERT INTO `TblPresupuestoVersionHistorial` (
        id_presupuesto,
        numero_version,
        fecha_version,
        creado_por,
        motivo_cambio,
        es_version_actual,
        numero_presupuesto,
        id_proyecto,
        id_obra,
        nombre_proyecto,
        nombre_obra,
        fecha_emision,
        fecha_vigencia,
        total_materiales,
        total_servicios,
        costos_directos,
        gastos_generales,
        utilidad,
        sub_total,
        igv,
        supervision,
        presupuesto_total,
        porcentaje_gg,
        porcentaje_utilidad,
        porcentaje_supervision,
        observaciones,
        estado
    )
    SELECT
        p.id_presupuesto,
        v_siguiente_numero,
        NOW(),
        p_creado_por,
        CONCAT('Versión ', v_siguiente_numero, ' - Editado por usuario'),
        1,
        p.numero_presupuesto,
        o.id_proyecto,
        p.id_obra,
        pr.nombre,
        o.nombre,
        NOW(),
        NULL,
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p.id_presupuesto
           AND tipo_item = 'MATERIAL'),
        (SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
         FROM `TblPresupuestoDetalle`
         WHERE id_presupuesto = p.id_presupuesto
           AND tipo_item IN ('SERVICIO','PARTIDA')),
        p.monto,
        p.gastos_generales,
        p.utilidad,
        (p.monto + p.gastos_generales + p.utilidad),
        p.igv,
        p.supervision_obra,
        p.monto_total,
        CASE WHEN p.monto > 0 THEN ROUND((p.gastos_generales / p.monto) * 100, 2) ELSE 0 END,
        CASE WHEN p.monto > 0 THEN ROUND((p.utilidad / p.monto) * 100, 2) ELSE 0 END,
        CASE WHEN (p.monto + p.gastos_generales + p.utilidad) > 0
             THEN ROUND((p.supervision_obra / (p.monto + p.gastos_generales + p.utilidad)) * 100, 2)
             ELSE 0 END,
        p.observaciones,
        p.estado
    FROM `TblPresupuesto` p
    LEFT JOIN `TblObra` o ON p.id_obra = o.id_obra
    LEFT JOIN `TblProyecto` pr ON o.id_proyecto = pr.id_proyecto
    WHERE p.id_presupuesto = p_id_presupuesto;

    SET v_nueva_version_id = LAST_INSERT_ID();

    INSERT INTO `TblPresupuestoVersionDetalleHistorial` (
        id_version,
        tipo_partida,
        id_inventario,
        id_unidad,
        descripcion,
        cantidad,
        precio_unitario,
        subtotal,
        orden
    )
    SELECT
        v_nueva_version_id,
        pd.tipo_item,
        pd.id_inventario,
        i.id_unidad,
        pd.descripcion,
        pd.cantidad,
        pd.precio_unitario,
        (pd.cantidad * pd.precio_unitario),
        pd.id_detalle
    FROM `TblPresupuestoDetalle` pd
    LEFT JOIN `TblInventario` i ON pd.id_inventario = i.id_inventario
    WHERE pd.id_presupuesto = p_id_presupuesto
    ORDER BY pd.id_detalle;

END$$

-- ============================================ sp_guardar_entrega_personal
DROP PROCEDURE IF EXISTS `sp_guardar_entrega_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_guardar_entrega_personal`(
    IN  p_id_personal   VARCHAR(20),
    IN  p_observaciones TEXT,
    IN  p_creado_por    VARCHAR(50),
    OUT p_success       TINYINT(1),
    OUT p_message       VARCHAR(255),
    OUT p_id_entrega    INT,
    OUT p_codigo        VARCHAR(50)
)
sp_body: BEGIN
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_count  INT;

    -- Validar que el personal existe
    IF NOT EXISTS (
        SELECT 1 FROM TblUsuario WHERE num_documento = p_id_personal AND estado = 'Activo'
    ) THEN
        SET p_success = 0;
        SET p_message = 'El personal no existe o está inactivo';
        LEAVE sp_body;
    END IF;

    -- Generar código único VALE-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO v_count FROM TblEntregaPersonal;
    SET v_codigo = CONCAT('VALE-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(v_count, 4, '0'));

    -- Insertar cabecera
    INSERT INTO TblEntregaPersonal (
        codigo_entrega, id_personal, fecha_entrega,
        observaciones, estado, creado_por
    ) VALUES (
        v_codigo, p_id_personal, NOW(),
        p_observaciones, 'ACTIVO', p_creado_por
    );

    SET p_id_entrega = LAST_INSERT_ID();
    SET p_codigo     = v_codigo;
    SET p_success    = 1;
    SET p_message    = 'Entrega creada correctamente';
END sp_body$$

-- ============================================ sp_kardex_personal
DROP PROCEDURE IF EXISTS `sp_kardex_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_kardex_personal`(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    -- 1. Ficha del trabajador
    SELECT
        p.documento_numero                                                          AS documento,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                             AS nombre_completo,
        COALESCE(c.nombre, 'Sin Cargo')                                             AS cargo,
        COALESCE(a.nombre, 'Sin Área')                                              AS area,
        p.email
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c   ON u.id_cargo = c.id_cargo
    LEFT  JOIN TblArea a    ON c.id_area  = a.id_area
    WHERE u.num_documento = p_id_personal
    LIMIT 1;

    -- 2. Historial de materiales
    SELECT
        ep.fecha_entrega,
        ep.codigo_entrega,
        i.nombre                AS material,
        i.codigo                AS codigo_material,
        epd.serie,
        epd.cantidad,
        u2.abreviatura          AS unidad,
        epd.estado_bien,
        ep.estado               AS estado_asignacion,
        epd.observaciones
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i               ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u2            ON i.id_unidad = u2.id_unidad
    WHERE ep.id_personal = p_id_personal
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

-- ============================================ sp_listar_entrega_personal
DROP PROCEDURE IF EXISTS `sp_listar_entrega_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_entrega_personal`(
    IN p_busqueda VARCHAR(100)
)
BEGIN
    SELECT
        u.num_documento                                                        AS id_personal,
        p.documento_numero                                                     AS DOCUMENTO,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                        AS NOMBRE_COMPLETO,
        COALESCE(c.nombre, 'Sin Cargo')                                        AS CARGO,
        COALESCE(a.nombre, 'Sin Área')                                         AS AREA,
        COUNT(DISTINCT ep.id_entrega)                                          AS TOTAL_ENTREGAS,
        COALESCE(SUM(epd.cantidad), 0)                                         AS TOTAL_ITEMS,
        MAX(ep.fecha_entrega)                                                  AS ULTIMA_ENTREGA
    FROM TblUsuario u
    INNER JOIN TblPersona p  ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c    ON u.id_cargo      = c.id_cargo
    LEFT  JOIN TblArea a     ON c.id_area       = a.id_area
    LEFT  JOIN TblEntregaPersonal ep
               ON u.num_documento = ep.id_personal
               AND ep.estado = 'ACTIVO'
    LEFT  JOIN TblEntregaPersonalDetalle epd
               ON ep.id_entrega = epd.id_entrega
    WHERE u.estado = 'Activo'
      AND (
            p_busqueda IS NULL
            OR p_busqueda = ''
            OR p.documento_numero           LIKE CONCAT('%', p_busqueda, '%')
            OR p.nombres                    LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_paterno           LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_materno           LIKE CONCAT('%', p_busqueda, '%')
            OR c.nombre                     LIKE CONCAT('%', p_busqueda, '%')
            OR a.nombre                     LIKE CONCAT('%', p_busqueda, '%')
          )
    GROUP BY u.num_documento, p.documento_numero, p.nombres, p.apellido_paterno,
             p.apellido_materno, c.nombre, a.nombre
    ORDER BY p.apellido_paterno ASC, p.nombres ASC;
END$$

-- ============================================ sp_listar_inventario
DROP PROCEDURE IF EXISTS `sp_listar_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_inventario`(
    IN p_busqueda VARCHAR(255),
    IN p_categoria VARCHAR(100),
    IN p_tipo_inventario VARCHAR(50),
    IN p_estado VARCHAR(50)
)
BEGIN
    SELECT 
        i.id_inventario,
        i.codigo,
        i.nombre,
        i.descripcion,
        i.tipo_inventario,
        c.nombre AS categoria,
        u.nombre AS unidad_medida,
        u.abreviatura AS unidad_abrev,
        i.stock_actual,
        i.stock_minimo,
        i.stock_maximo,
        i.precio_compra AS precio_unitario,
        i.precio_promedio,
        i.costo_total,
        i.estado,
        i.fecha_actualizacion,
        a.nombre AS almacen,
        a.codigo AS almacen_codigo,
        i.ubicacion_fisica,
        -- Indicador de stock
        CASE 
            WHEN i.stock_actual <= i.stock_minimo THEN 'BAJO'
            WHEN i.stock_actual >= i.stock_maximo * 0.8 THEN 'OPTIMO'
            ELSE 'NORMAL'
        END AS nivel_stock
    FROM TblInventario i
    LEFT JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
    LEFT JOIN TblAlmacen a ON i.id_almacen = a.id_almacen
    WHERE 1=1
        -- Filtro por estado
        AND (p_estado IS NULL OR p_estado = '' OR i.estado = p_estado)
        -- Filtro por tipo
        AND (p_tipo_inventario IS NULL OR p_tipo_inventario = '' OR i.tipo_inventario = p_tipo_inventario)
        -- Filtro por búsqueda (código, nombre o descripción)
        AND (
            p_busqueda IS NULL 
            OR p_busqueda = '' 
            OR i.nombre LIKE CONCAT('%', p_busqueda, '%')
            OR i.codigo LIKE CONCAT('%', p_busqueda, '%')
            OR i.descripcion LIKE CONCAT('%', p_busqueda, '%')
        )
        -- Filtro por categoría
        AND (p_categoria IS NULL OR p_categoria = '' OR c.nombre = p_categoria)
    ORDER BY i.nombre ASC;
END$$

-- ============================================ sp_listar_materiales_de_proveedor
DROP PROCEDURE IF EXISTS `sp_listar_materiales_de_proveedor`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_materiales_de_proveedor`(
    IN p_ruc_proveedor VARCHAR(11)
)
BEGIN
    SELECT
        ip.id_inventario_proveedor,
        ip.id_inventario,
        ip.ruc_proveedor,
        i.codigo,
        i.nombre,
        i.tipo_inventario,
        i.descripcion,
        c.nombre        AS categoria,
        u.nombre        AS unidad,
        u.abreviatura   AS unidad_abrev,
        i.stock_actual,
        i.estado        AS estado_inventario,
        ip.codigo_proveedor,
        ip.precio_compra,
        ip.moneda,
        ip.plazo_entrega_dias,
        ip.es_principal,
        ip.estado,
        ip.observaciones,
        ip.fecha_creacion
    FROM TblInventarioProveedor ip
    INNER JOIN TblInventario i          ON ip.id_inventario = i.id_inventario
    LEFT  JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
    LEFT  JOIN TblUnidadMedida u        ON i.id_unidad = u.id_unidad
    WHERE ip.ruc_proveedor = p_ruc_proveedor
      AND ip.estado = 'ACTIVO'
      AND i.estado  = 'ACTIVO'
    ORDER BY ip.es_principal DESC, i.nombre ASC;
END$$

-- ============================================ sp_listar_proveedores_de_inventario
DROP PROCEDURE IF EXISTS `sp_listar_proveedores_de_inventario`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_listar_proveedores_de_inventario`(
    IN p_id_inventario INT
)
BEGIN
    SELECT
        ip.id_inventario_proveedor,
        ip.id_inventario,
        ip.ruc_proveedor,
        p.razon_social,
        p.nombre_comercial,
        p.telefono,
        p.email,
        p.contacto_nombre,
        p.contacto_telefono,
        p.estado        AS estado_proveedor,
        ip.codigo_proveedor,
        ip.precio_compra,
        ip.moneda,
        ip.plazo_entrega_dias,
        ip.es_principal,
        ip.estado,
        ip.observaciones,
        ip.fecha_creacion
    FROM TblInventarioProveedor ip
    INNER JOIN TblProveedores p ON ip.ruc_proveedor = p.ruc
    WHERE ip.id_inventario = p_id_inventario
      AND ip.estado = 'ACTIVO'
      AND p.estado != 'ELIMINADO'
    ORDER BY ip.es_principal DESC, p.razon_social ASC;
END$$

-- ============================================ sp_ObtenerPresupuestoPDF
DROP PROCEDURE IF EXISTS `sp_ObtenerPresupuestoPDF`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerPresupuestoPDF`(
    IN p_id_presupuesto INT
)
    READS SQL DATA
BEGIN
    SELECT
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        COALESCE(pr.monto_total, 0) AS monto_total,
        COALESCE(pr.gastos_generales, 0) AS gastos_generales,
        COALESCE(pr.utilidad, 0) AS utilidad,
        COALESCE(pr.igv, 0) AS igv,
        COALESCE(pr.supervision_obra, 0) AS supervision_obra,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.num_documento,
        e.nombre AS nombre_empresa,
        e.logo AS empresa_logo,
        o.id_obra,
        o.nombre AS nombre_obra,
        o.codigo_obra,
        pr.id_obra,
        pry.id_proyecto,
        pry.nombre AS nombre_proyecto,
        pry.codigo_proyecto,
        COALESCE(p.nombres, '') AS usuario_nombres,
        CONCAT(COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) AS usuario_apellido,
        COALESCE(p.email, '') AS usuario_email,
        COALESCE(p.celular, '') AS usuario_celular
    FROM `TblPresupuesto` pr
    LEFT JOIN `TblEmpresa` e ON pr.id_empresa = e.id_empresa
    LEFT JOIN `TblObra` o ON pr.id_obra = o.id_obra
    LEFT JOIN `TblProyecto` pry ON o.id_proyecto = pry.id_proyecto
    LEFT JOIN `TblUsuario` u ON pr.num_documento = u.num_documento
    LEFT JOIN `TblPersona` p ON pr.num_documento = p.num_documento
    WHERE pr.id_presupuesto = p_id_presupuesto;

    SELECT
        d.id_detalle,
        d.id_presupuesto,
        d.id_inventario,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion,
        COALESCE(i.nombre, d.descripcion) AS material_nombre,
        COALESCE(um.nombre, 'und') AS unidad_medida,
        COALESCE(c.nombre, 'General') AS categoria
    FROM `TblPresupuestoDetalle` d
    LEFT JOIN `TblInventario` i ON d.id_inventario = i.id_inventario
    LEFT JOIN `TblUnidadMedida` um ON i.id_unidad = um.id_unidad
    LEFT JOIN `TblCategoriaInventario` c ON i.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
      AND d.tipo_item IN ('MATERIAL', '')
    ORDER BY d.id_detalle ASC;

    SELECT
        d.id_detalle,
        d.id_presupuesto,
        d.id_inventario,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion AS servicio_nombre,
        d.descripcion,
        d.observaciones AS observaciones_detalle
    FROM `TblPresupuestoDetalle` d
    WHERE d.id_presupuesto = p_id_presupuesto
      AND d.tipo_item IN ('SERVICIO', 'PARTIDA')
    ORDER BY d.id_detalle ASC;

END$$

-- ============================================ sp_ObtenerRequerimientoDetalles
DROP PROCEDURE IF EXISTS `sp_ObtenerRequerimientoDetalles`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerRequerimientoDetalles`(
    IN p_id_requerimiento INT
)
    READS SQL DATA
BEGIN
    SELECT
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_inventario,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.observaciones,
        rd.fecha_creacion,
        COALESCE(i.nombre, '') AS material_nombre,
        COALESCE(i.codigo, '') AS material_codigo,
        COALESCE(um.nombre, '') AS unidad_nombre,
        COALESCE(um.abreviatura, '') AS unidad_abreviatura
    FROM `TblRequerimientoDetalle` rd
    LEFT JOIN `TblInventario` i ON rd.id_inventario = i.id_inventario
    LEFT JOIN `TblUnidadMedida` um ON i.id_unidad = um.id_unidad
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;
END$$

-- ============================================ sp_obtener_asignados_personal
DROP PROCEDURE IF EXISTS `sp_obtener_asignados_personal`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_obtener_asignados_personal`(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    SELECT
        epd.id_entrega_detalle,
        epd.id_entrega,
        epd.id_inventario,
        i.codigo,
        i.nombre,
        epd.cantidad,
        epd.serie,
        epd.estado_bien,
        u.abreviatura AS unidad,
        ep.codigo_entrega,
        ep.fecha_entrega
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
    WHERE ep.id_personal = p_id_personal
      AND ep.estado = 'ACTIVO'
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

-- ============================================ sp_RQA_ReponerStock
DROP PROCEDURE IF EXISTS `sp_RQA_ReponerStock`$$
CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_RQA_ReponerStock`(
    IN p_id_requerimiento INT,
    IN p_num_documento INT,
    IN p_motivo VARCHAR(300)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_bloqueados INT DEFAULT 0;

    -- Bloquear las filas de inventario involucradas
    SELECT COUNT(*) INTO v_bloqueados
    FROM `TblInventario` i
    INNER JOIN `TblRequerimientoDetalle` d ON d.id_inventario = i.id_inventario
    WHERE d.id_requerimiento = p_id_requerimiento
    FOR UPDATE;

    -- Movimiento DEVOLUCION por material (código único por requerimiento + material)
    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_destino, tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
    )
    SELECT
        CONCAT('DEV-RQA', LPAD(p_id_requerimiento, 6, '0'), '-', LPAD(i.id_inventario, 5, '0')),
        i.id_inventario,
        'DEVOLUCION',
        d.cantidad,
        i.id_almacen,
        'REQUERIMIENTO',
        p_id_requerimiento,
        i.precio_compra,
        d.cantidad * COALESCE(i.precio_compra, 0),
        p_motivo,
        NOW(),
        p_num_documento
    FROM (
        SELECT id_inventario, SUM(cantidad) AS cantidad
        FROM `TblRequerimientoDetalle`
        WHERE id_requerimiento = p_id_requerimiento
          AND id_inventario IS NOT NULL
        GROUP BY id_inventario
    ) d
    INNER JOIN `TblInventario` i ON i.id_inventario = d.id_inventario;

    -- Devolver el stock
    UPDATE `TblInventario` i
    INNER JOIN (
        SELECT id_inventario, SUM(cantidad) AS cantidad
        FROM `TblRequerimientoDetalle`
        WHERE id_requerimiento = p_id_requerimiento
          AND id_inventario IS NOT NULL
        GROUP BY id_inventario
    ) d ON d.id_inventario = i.id_inventario
    SET i.stock_actual = COALESCE(i.stock_actual, 0) + d.cantidad;
END$$

DELIMITER ;
