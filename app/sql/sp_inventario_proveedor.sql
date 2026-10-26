-- ============================================================================
-- MÓDULO: INVENTARIO ↔ PROVEEDORES
-- Tabla intermedia: TblInventarioProveedor
-- Ejecutar en: kallgwkn_kallpa_bd
-- ============================================================================

SET NAMES utf8mb4;
DELIMITER $$

-- ----------------------------------------------------------------------------
-- SP 1: Listar proveedores vinculados a un ítem de inventario
-- Uso: Inventario → botón "Proveedores" de cada ítem
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_listar_proveedores_de_inventario$$
CREATE PROCEDURE sp_listar_proveedores_de_inventario(
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

-- ----------------------------------------------------------------------------
-- SP 2: Listar materiales de inventario vinculados a un proveedor
-- Uso: Proveedores → botón "Ficha de materiales" de cada proveedor
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_listar_materiales_de_proveedor$$
CREATE PROCEDURE sp_listar_materiales_de_proveedor(
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

-- ----------------------------------------------------------------------------
-- SP 3: Asociar un proveedor a un ítem (INSERT o reactivar si ya existía)
-- Uso: modal "Proveedores" en Inventario → "Asociar proveedor"
-- Fix: etiqueta sp_body: en BEGIN para que LEAVE funcione correctamente
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_asociar_proveedor_inventario$$
CREATE PROCEDURE sp_asociar_proveedor_inventario(
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

-- ----------------------------------------------------------------------------
-- SP 4: Desasociar un proveedor de un ítem (soft-delete → INACTIVO)
-- Uso: botón "quitar" dentro del modal de proveedores del ítem
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_desasociar_proveedor_inventario$$
CREATE PROCEDURE sp_desasociar_proveedor_inventario(
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

-- ----------------------------------------------------------------------------
-- SP 5: Listar proveedores activos para el <select> del modal de asociar
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_listar_proveedores_selector$$
CREATE PROCEDURE sp_listar_proveedores_selector()
BEGIN
    SELECT
        ruc,
        razon_social,
        nombre_comercial,
        telefono,
        email
    FROM TblProveedores
    WHERE estado = 'ACTIVO'
    ORDER BY razon_social ASC;
END$$

DELIMITER ;
