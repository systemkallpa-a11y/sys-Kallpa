-- =============================================================================
-- PARTE 4b - ACTUALIZA SOLO sp_guardar_item (validación de datos técnicos)
-- Ejecutar COMPLETO en kallpasystem$kallgwkn_kallpa_bd (MySQL Workbench).
-- No toca datos: solo reemplaza el SP. Misma firma que la versión anterior.
-- =============================================================================

-- =============================================================================
-- PARTE 4 / 04 - ALTA ÚNICA DE ÍTEMS: sp_guardar_item
-- -----------------------------------------------------------------------------
-- En UNA transacción (todo o nada):
--   1. TblInventario            datos generales, código PREFIJO-001
--   2. Sección del tipo         TblInventarioRopa / Material / Tecnologia...
--                               con los datos de p_ficha (JSON {"talla":"M"})
--   3. Stock inicial (opcional) stock_actual + movimiento ENTRADA en el kardex
--
-- Validaciones con mensaje claro (antes de escribir nada):
--   nombre obligatorio · categoría activa y del mismo tipo · unidad permitida
--   en la categoría (TblCategoriaUnidad, con herencia del padre) · stock
--   mínimo <= máximo · cantidades no negativas · ficha debe ser un objeto JSON
--   · no repetir el nombre de un ítem activo del mismo tipo.
--
-- La ficha se escribe con SQL dinámico: solo las claves del JSON que existen
-- como columna en la sección (las demás se ignoran). Las columnas salen de
-- information_schema, nunca del texto del usuario.
-- Si algo falla (ej. valor fuera de la lista de 'genero'), el mensaje de
-- MySQL se devuelve en p_message y no queda nada guardado.
-- sp_crear_inventario se mantiene por compatibilidad hasta la Parte 6.
--
-- MODO ESTRICTO: el servidor usa sql_mode = NO_ENGINE_SUBSTITUTION (no
-- estricto: 'NIÑO' en un ENUM o 'abc' en un número se guardarían vacíos/0
-- sin error). MySQL guarda con cada SP el sql_mode con que se creó y lo usa al
-- ejecutarlo (también en su SQL dinámico), así que este SP se crea en modo
-- estricto. Solo afecta a este SP; el resto del sistema no cambia.
-- =============================================================================

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_guardar_item`$$
CREATE PROCEDURE `sp_guardar_item`(
    IN  p_nombre           VARCHAR(200),
    IN  p_descripcion      TEXT,
    IN  p_tipo_inventario  VARCHAR(20),
    IN  p_id_categoria     INT,
    IN  p_id_unidad        INT,
    IN  p_stock_minimo     DECIMAL(10,2),
    IN  p_stock_maximo     DECIMAL(10,2),
    IN  p_precio_compra    DECIMAL(10,2),
    IN  p_id_almacen       INT,
    IN  p_ubicacion_fisica VARCHAR(100),
    IN  p_ficha            JSON,
    IN  p_stock_inicial    DECIMAL(10,2),
    IN  p_creado_por       INT,
    OUT p_success          BOOLEAN,
    OUT p_message          VARCHAR(255),
    OUT p_id_inventario    INT,
    OUT p_codigo           VARCHAR(50)
)
    MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_error        TEXT;
    DECLARE v_nombre       VARCHAR(200);
    DECLARE v_tipo_cat     VARCHAR(20) DEFAULT NULL;
    DECLARE v_nombre_cat   VARCHAR(100);
    DECLARE v_cat_unidades INT DEFAULT NULL;
    DECLARE v_permitida    INT DEFAULT 0;
    DECLARE v_duplicado    VARCHAR(50) DEFAULT NULL;
    DECLARE v_tabla        VARCHAR(64) DEFAULT NULL;
    DECLARE v_sets         TEXT DEFAULT NULL;
    DECLARE v_codigo       VARCHAR(50);
    DECLARE v_id           INT;
    DECLARE v_bloqueo      INT;
    DECLARE v_min          DECIMAL(10,2);
    DECLARE v_max          DECIMAL(10,2);
    DECLARE v_inicial      DECIMAL(10,2);
    DECLARE v_precio       DECIMAL(10,2);
    DECLARE v_invalido     VARCHAR(255) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = LEFT(CONCAT('No se guardó el ítem: ', COALESCE(v_error, 'error desconocido')), 255);
        SET p_id_inventario = NULL;
        SET p_codigo = NULL;
    END;

    SET p_success = FALSE;
    SET p_id_inventario = NULL;
    SET p_codigo = NULL;
    SET v_nombre  = TRIM(p_nombre);
    SET v_min     = COALESCE(p_stock_minimo, 0);
    SET v_max     = COALESCE(p_stock_maximo, 0);
    SET v_inicial = COALESCE(p_stock_inicial, 0);
    SET v_precio  = COALESCE(p_precio_compra, 0);

    -- ------------------------------------------------ Validaciones
    IF v_nombre IS NULL OR v_nombre = '' THEN
        SET p_message = 'El nombre del ítem es obligatorio';
        LEAVE proc;
    END IF;

    SELECT tipo_aplicable, nombre INTO v_tipo_cat, v_nombre_cat
    FROM `TblCategoriaInventario`
    WHERE id_categoria = p_id_categoria AND estado = 'ACTIVO';

    IF v_tipo_cat IS NULL THEN
        SET p_message = 'La categoría no existe o está inactiva';
        LEAVE proc;
    END IF;

    IF v_tipo_cat <> p_tipo_inventario THEN
        SET p_message = CONCAT('La categoría "', v_nombre_cat, '" no corresponde al tipo ', p_tipo_inventario);
        LEAVE proc;
    END IF;

    IF EXISTS (SELECT 1 FROM `TblCategoriaUnidad` WHERE id_categoria = p_id_categoria) THEN
        SET v_cat_unidades = p_id_categoria;
    ELSE
        SELECT id_categoria_padre INTO v_cat_unidades
        FROM `TblCategoriaInventario` WHERE id_categoria = p_id_categoria;
    END IF;

    SELECT COUNT(*) INTO v_permitida
    FROM `TblCategoriaUnidad` cu
    JOIN `TblUnidadMedida` u ON u.id_unidad = cu.id_unidad
    WHERE cu.id_categoria = v_cat_unidades
      AND cu.id_unidad = p_id_unidad
      AND u.estado = 'ACTIVO';

    IF v_permitida = 0 THEN
        SET p_message = CONCAT('La unidad elegida no está permitida para la categoría "', v_nombre_cat, '"');
        LEAVE proc;
    END IF;

    IF v_min < 0 OR v_max < 0 OR v_inicial < 0 OR v_precio < 0 THEN
        SET p_message = 'Stock y precio no pueden ser negativos';
        LEAVE proc;
    END IF;

    IF v_max > 0 AND v_min > v_max THEN
        SET p_message = 'El stock mínimo no puede ser mayor que el stock máximo';
        LEAVE proc;
    END IF;

    IF p_ficha IS NOT NULL AND JSON_TYPE(p_ficha) <> 'OBJECT' THEN
        SET p_message = 'Las especificaciones técnicas deben enviarse como objeto JSON';
        LEAVE proc;
    END IF;

    -- Datos técnicos: se validan contra la estructura real de la sección ANTES
    -- de escribir (no depende del modo estricto ni de la conexión del cliente).
    --   lista (ENUM): el valor debe ser una de sus opciones
    --   número entero / decimal: solo dígitos (y punto decimal), sin negativos
    --   texto: no superar el largo máximo de la columna
    IF p_ficha IS NOT NULL AND JSON_LENGTH(p_ficha) > 0 THEN
        CALL sp_obtener_tabla_seccion(p_tipo_inventario, v_tabla);

        IF v_tabla IS NOT NULL THEN
            SELECT LEFT(CONCAT('Valor no válido en "', COALESCE(m.etiqueta, x.columna), '": ', x.valor,
                          CASE
                            WHEN x.tipo_dato = 'enum' THEN
                              CONCAT(' (opciones: ',
                                     REPLACE(SUBSTRING(x.tipo_columna, 6, CHAR_LENGTH(x.tipo_columna) - 6), '''', ''),
                                     ')')
                            WHEN x.tipo_dato IN ('int','smallint','tinyint','mediumint','bigint') THEN ' (debe ser un número entero)'
                            WHEN x.tipo_dato IN ('decimal','float','double') THEN ' (debe ser un número)'
                            ELSE CONCAT(' (máximo ', x.largo, ' caracteres)')
                          END), 255)
            INTO v_invalido
            FROM (
                SELECT CONVERT(c.COLUMN_NAME USING utf8mb4)  AS columna,
                       CONVERT(c.DATA_TYPE USING utf8mb4)    AS tipo_dato,
                       CONVERT(c.COLUMN_TYPE USING utf8mb4)  AS tipo_columna,
                       c.CHARACTER_MAXIMUM_LENGTH            AS largo,
                       NULLIF(IF(JSON_TYPE(JSON_EXTRACT(p_ficha, CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))) = 'NULL',
                                 NULL,
                                 TRIM(JSON_UNQUOTE(JSON_EXTRACT(p_ficha, CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))))),
                              '') AS valor
                FROM information_schema.COLUMNS c
                WHERE c.TABLE_SCHEMA = DATABASE()
                  AND c.TABLE_NAME = v_tabla
                  AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
                  AND JSON_CONTAINS_PATH(p_ficha, 'one', CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'))
            ) x
            LEFT JOIN `TblInventarioCampoSeccion` m
              ON m.tipo_inventario = p_tipo_inventario
             AND m.columna = x.columna COLLATE utf8mb4_unicode_ci
            WHERE x.valor IS NOT NULL
              AND (
                   (x.tipo_dato = 'enum'
                    AND LOCATE(CONCAT('''', x.valor, ''''), x.tipo_columna) = 0)
                OR (x.tipo_dato IN ('int','smallint','tinyint','mediumint','bigint')
                    AND x.valor NOT REGEXP '^[0-9]+$')
                OR (x.tipo_dato IN ('decimal','float','double')
                    AND x.valor NOT REGEXP '^[0-9]+([.][0-9]+)?$')
                OR (x.largo IS NOT NULL AND x.tipo_dato <> 'enum'
                    AND CHAR_LENGTH(x.valor) > x.largo)
              )
            ORDER BY COALESCE(m.orden, 999)
            LIMIT 1;

            IF v_invalido IS NOT NULL THEN
                SET p_message = v_invalido;
                LEAVE proc;
            END IF;
        END IF;
    END IF;

    SELECT codigo INTO v_duplicado
    FROM `TblInventario`
    WHERE estado = 'ACTIVO'
      AND tipo_inventario = p_tipo_inventario
      AND nombre = v_nombre
    LIMIT 1;

    IF v_duplicado IS NOT NULL THEN
        SET p_message = CONCAT('Ya existe un ítem activo con ese nombre: ', v_duplicado);
        LEAVE proc;
    END IF;

    -- ------------------------------------------------ Escritura (todo o nada)
    START TRANSACTION;

    -- Serializa altas del mismo tipo para que dos usuarios no obtengan el mismo código
    SELECT id_categoria INTO v_bloqueo
    FROM `TblCategoriaInventario`
    WHERE nivel = 1 AND tipo_aplicable = p_tipo_inventario
    ORDER BY orden, id_categoria
    LIMIT 1
    FOR UPDATE;

    CALL sp_generar_material(p_tipo_inventario, v_codigo);

    INSERT INTO `TblInventario` (
        codigo, nombre, descripcion, id_categoria, tipo_inventario,
        stock_actual, stock_minimo, stock_maximo, id_unidad, id_almacen,
        ubicacion_fisica, precio_compra, precio_promedio, estado, fecha_creacion, creado_por
    ) VALUES (
        v_codigo, v_nombre, NULLIF(TRIM(p_descripcion), ''), p_id_categoria, p_tipo_inventario,
        0, v_min, v_max, p_id_unidad, p_id_almacen,
        NULLIF(TRIM(p_ubicacion_fisica), ''), v_precio, v_precio, 'ACTIVO', NOW(), p_creado_por
    );

    SET v_id = LAST_INSERT_ID();

    -- 2. Sección del tipo
    CALL sp_asegurar_seccion_inventario(v_id);

    IF p_ficha IS NOT NULL AND JSON_LENGTH(p_ficha) > 0 THEN
        IF v_tabla IS NOT NULL THEN
            SET SESSION group_concat_max_len = 16384;

            SELECT GROUP_CONCAT(
                     CONCAT('`', CONVERT(c.COLUMN_NAME USING utf8mb4), '` = NULLIF(JSON_VALUE(@sp_guardar_item_ficha, ''$."',
                            CONVERT(c.COLUMN_NAME USING utf8mb4), '"''), '''')')
                     ORDER BY c.ORDINAL_POSITION SEPARATOR ', ')
            INTO v_sets
            FROM information_schema.COLUMNS c
            WHERE c.TABLE_SCHEMA = DATABASE()
              AND c.TABLE_NAME = v_tabla
              AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
              AND JSON_CONTAINS_PATH(p_ficha, 'one', CONCAT('$."', CONVERT(c.COLUMN_NAME USING utf8mb4), '"'));

            IF v_sets IS NOT NULL THEN
                SET @sp_guardar_item_ficha = p_ficha;
                SET @sp_guardar_item_sql = CONCAT('UPDATE `', v_tabla, '` SET ', v_sets,
                                                  ' WHERE id_inventario = ', v_id);
                PREPARE st_ficha FROM @sp_guardar_item_sql;
                EXECUTE st_ficha;
                DEALLOCATE PREPARE st_ficha;
                SET @sp_guardar_item_ficha = NULL;
                SET @sp_guardar_item_sql = NULL;
            END IF;
        END IF;
    END IF;

    -- 3. Stock inicial con su movimiento
    IF v_inicial > 0 THEN
        UPDATE `TblInventario`
        SET stock_actual = v_inicial
        WHERE id_inventario = v_id;

        INSERT INTO `TblMovimientoInventario` (
            codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
            id_almacen_origen, id_almacen_destino, tipo_documento, id_documento_referencia,
            costo_unitario, costo_total, motivo, fecha_movimiento, realizado_por
        ) VALUES (
            CONCAT('INI-', v_codigo), v_id, 'ENTRADA', v_inicial,
            NULL, p_id_almacen, 'AJUSTE_INVENTARIO', NULL,
            v_precio, v_inicial * v_precio, 'Stock inicial', NOW(), p_creado_por
        );
    END IF;

    COMMIT;

    SET p_success = TRUE;
    SET p_message = CONCAT('Ítem creado con código ', v_codigo);
    SET p_id_inventario = v_id;
    SET p_codigo = v_codigo;
END$$

DELIMITER ;
