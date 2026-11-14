-- =============================================================================
-- PARTE 3 / 99 - REVERTIR
-- -----------------------------------------------------------------------------
-- Restaura sp_crear_inventario y sp_CrearMaterialConCodigoAuto originales,
-- elimina los SPs de sección, las conversiones por ítem y las filas de sección
-- creadas en la Parte 3 (conserva las que existían antes).
-- La línea agregada en app/routes/inventario.py (actualizar_item) llama a
-- sp_asegurar_seccion_inventario: si se revierte, quitarla también.
-- =============================================================================

DELETE FROM `TblInventarioConversion`;

ALTER TABLE `TblInventarioConversion`
  MODIFY COLUMN `factor` DECIMAL(18,6) NOT NULL
  COMMENT '1 id_unidad = factor en la unidad base del ítem';

DELETE s FROM `TblInventarioMaterial` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioMaterial' AND a.id_inventario = s.id_inventario);
DELETE s FROM `TblInventarioHerramienta` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioHerramienta' AND a.id_inventario = s.id_inventario);
DELETE s FROM `TblInventarioEquipo` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioEquipo' AND a.id_inventario = s.id_inventario);
DELETE s FROM `TblInventarioTecnologia` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioTecnologia' AND a.id_inventario = s.id_inventario);
DELETE s FROM `TblInventarioRopa` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioRopa' AND a.id_inventario = s.id_inventario);
DELETE s FROM `TblInventarioConsumible` s WHERE NOT EXISTS (
  SELECT 1 FROM `aux_p3_secciones_antes` a WHERE a.tabla = 'TblInventarioConsumible' AND a.id_inventario = s.id_inventario);

DROP TABLE IF EXISTS `aux_p3_secciones_antes`;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_crear_inventario`$$
CREATE PROCEDURE `sp_crear_inventario`(
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
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_success = FALSE;
        SET p_message = 'El nombre del item es obligatorio';
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
        ROLLBACK;
    ELSE
        CALL sp_generar_material(p_tipo_inventario, v_codigo_generado);
        INSERT INTO TblInventario (
            codigo, nombre, descripcion, id_categoria, id_subcategoria, tipo_inventario,
            stock_actual, stock_minimo, stock_maximo, id_unidad, id_almacen,
            ubicacion_fisica, precio_compra, precio_promedio, estado, fecha_creacion, creado_por
        ) VALUES (
            v_codigo_generado, p_nombre, p_descripcion, p_id_categoria, p_id_subcategoria, p_tipo_inventario,
            0.00, p_stock_minimo, p_stock_maximo, p_id_unidad, p_id_almacen,
            p_ubicacion_fisica, p_precio_compra, p_precio_compra, 'ACTIVO', NOW(), p_creado_por
        );
        SET v_id_inventario = LAST_INSERT_ID();
        SET p_success = TRUE;
        SET p_message = CONCAT('Item creado exitosamente con código: ', v_codigo_generado);
        SET p_id_inventario = v_id_inventario;
        SET p_codigo = v_codigo_generado;
        COMMIT;
    END IF;
END$$

DROP PROCEDURE IF EXISTS `sp_CrearMaterialConCodigoAuto`$$
CREATE PROCEDURE `sp_CrearMaterialConCodigoAuto`(
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
        FROM `TblCategoriaInventario` WHERE codigo = 'MAT-OTROS' LIMIT 1;
    END IF;
    IF v_id_categoria IS NULL THEN
        SELECT id_categoria INTO v_id_categoria
        FROM `TblCategoriaInventario` WHERE estado = 'ACTIVO' ORDER BY id_categoria LIMIT 1;
    END IF;
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0)
    INTO v_ultimo_numero
    FROM `TblInventario`
    WHERE codigo LIKE 'MAT-%' AND codigo REGEXP '^MAT-[0-9]+$';
    SET v_siguiente_numero = v_ultimo_numero + 1;
    SET v_nuevo_codigo = CONCAT('MAT-', LPAD(v_siguiente_numero, 3, '0'));
    INSERT INTO `TblInventario` (
        codigo, nombre, descripcion, id_categoria, tipo_inventario,
        stock_actual, stock_minimo, stock_maximo, id_unidad,
        precio_compra, precio_promedio, estado
    ) VALUES (
        v_nuevo_codigo, p_nombre, p_descripcion, v_id_categoria, 'MATERIAL',
        0, 0, 0, p_id_unidad, 0, 0, 'ACTIVO'
    );
    SET p_id_inventario_creado = LAST_INSERT_ID();
    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;
    COMMIT;
END$$

DROP PROCEDURE IF EXISTS `sp_sincronizar_secciones_inventario`$$
DROP PROCEDURE IF EXISTS `sp_asegurar_seccion_inventario`$$

DELIMITER ;
