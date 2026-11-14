-- =============================================================================
-- PARTE 3 / 01 - SPs: CADA ÍTEM FÍSICO TIENE SU FILA DE SECCIÓN
-- -----------------------------------------------------------------------------
-- PythonAnywhere no permite triggers (requieren SUPER con binlog activo), así
-- que la regla se aplica con SPs:
--
--  sp_asegurar_seccion_inventario(id)    crea la fila de la sección del tipo
--                                        actual del ítem, si no existe. No abre
--                                        transacción: se suma a la del llamador.
--  sp_sincronizar_secciones_inventario   crea las filas que falten para TODOS
--                                        los ítems físicos (carga inicial y red
--                                        de seguridad; se puede llamar siempre).
--
-- Se modifican los 2 únicos SPs que crean ítems (misma firma):
--  sp_crear_inventario            (Inventario y Dashboard)
--  sp_CrearMaterialConCodigoAuto  (Presupuesto e importación de PDF); además
--                                 usa sp_generar_material para el código
--                                 (antes tenía su propio cálculo con LPAD que
--                                 corta los números desde 1000).
-- Originales en sp_inventario_actuales_20261113.sql
-- =============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_asegurar_seccion_inventario`$$
CREATE PROCEDURE `sp_asegurar_seccion_inventario`(
    IN p_id_inventario INT
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_tipo VARCHAR(20) DEFAULT NULL;

    SELECT tipo_inventario INTO v_tipo
    FROM `TblInventario`
    WHERE id_inventario = p_id_inventario;

    CASE v_tipo
        WHEN 'MATERIAL' THEN
            INSERT INTO `TblInventarioMaterial` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'MATERIAL' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioMaterial` WHERE id_inventario = p_id_inventario);
        WHEN 'HERRAMIENTA' THEN
            INSERT INTO `TblInventarioHerramienta` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'HERRAMIENTA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioHerramienta` WHERE id_inventario = p_id_inventario);
        WHEN 'EQUIPO' THEN
            INSERT INTO `TblInventarioEquipo` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'EQUIPO' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioEquipo` WHERE id_inventario = p_id_inventario);
        WHEN 'TECNOLOGIA' THEN
            INSERT INTO `TblInventarioTecnologia` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'TECNOLOGIA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioTecnologia` WHERE id_inventario = p_id_inventario);
        WHEN 'ROPA' THEN
            INSERT INTO `TblInventarioRopa` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'ROPA' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioRopa` WHERE id_inventario = p_id_inventario);
        WHEN 'CONSUMIBLE' THEN
            INSERT INTO `TblInventarioConsumible` (id_inventario, tipo_inventario)
            SELECT p_id_inventario, 'CONSUMIBLE' FROM DUAL
            WHERE NOT EXISTS (SELECT 1 FROM `TblInventarioConsumible` WHERE id_inventario = p_id_inventario);
        ELSE
            BEGIN END;
    END CASE;
END$$

DROP PROCEDURE IF EXISTS `sp_sincronizar_secciones_inventario`$$
CREATE PROCEDURE `sp_sincronizar_secciones_inventario`(
    OUT p_creadas INT
)
    MODIFIES SQL DATA
BEGIN
    SET p_creadas = 0;

    INSERT INTO `TblInventarioMaterial` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'MATERIAL' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'MATERIAL'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioMaterial` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioHerramienta` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'HERRAMIENTA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'HERRAMIENTA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioHerramienta` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioEquipo` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'EQUIPO' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'EQUIPO'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioEquipo` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioTecnologia` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'TECNOLOGIA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'TECNOLOGIA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioTecnologia` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioRopa` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'ROPA' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'ROPA'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioRopa` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();

    INSERT INTO `TblInventarioConsumible` (id_inventario, tipo_inventario)
    SELECT i.id_inventario, 'CONSUMIBLE' FROM `TblInventario` i
    WHERE i.tipo_inventario = 'CONSUMIBLE'
      AND NOT EXISTS (SELECT 1 FROM `TblInventarioConsumible` s WHERE s.id_inventario = i.id_inventario);
    SET p_creadas = p_creadas + ROW_COUNT();
END$$

-- ------------------------------------------------- sp_crear_inventario
-- Único cambio: CALL sp_asegurar_seccion_inventario antes del COMMIT.
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

        -- Fila de su sección (Ropa, Material, Tecnología...) en la misma transacción
        CALL sp_asegurar_seccion_inventario(v_id_inventario);

        SET p_success = TRUE;
        SET p_message = CONCAT('Item creado exitosamente con código: ', v_codigo_generado);
        SET p_id_inventario = v_id_inventario;
        SET p_codigo = v_codigo_generado;

        COMMIT;
    END IF;
END$$

-- ------------------------------------------------- sp_CrearMaterialConCodigoAuto
-- Cambios: código con sp_generar_material + CALL sp_asegurar_seccion_inventario.
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

    CALL sp_generar_material('MATERIAL', v_nuevo_codigo);

    INSERT INTO `TblInventario` (
        codigo, nombre, descripcion, id_categoria, tipo_inventario,
        stock_actual, stock_minimo, stock_maximo, id_unidad,
        precio_compra, precio_promedio, estado
    ) VALUES (
        v_nuevo_codigo, p_nombre, p_descripcion, v_id_categoria, 'MATERIAL',
        0, 0, 0, p_id_unidad,
        0, 0, 'ACTIVO'
    );

    SET p_id_inventario_creado = LAST_INSERT_ID();

    CALL sp_asegurar_seccion_inventario(p_id_inventario_creado);

    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;

    COMMIT;
END$$

DELIMITER ;
