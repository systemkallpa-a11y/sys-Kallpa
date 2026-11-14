-- =============================================================================
-- PARTE 4 - EJECUCIÓN MANUAL (une p4_01 .. p4_04 en orden)
-- Ejecutar COMPLETO, de una sola vez, en la BD kallpasystem$kallgwkn_kallpa_bd
-- Requiere un cliente que entienda DELIMITER (MySQL Workbench, consola mysql,
-- phpMyAdmin pestaña SQL). Para revertir: p4_99_revertir.sql
-- =============================================================================


-- ################################################################ p4_01_campos_seccion.sql
-- =============================================================================
-- PARTE 4 / 01 - PRESENTACIÓN DE LOS CAMPOS DE CADA SECCIÓN
-- -----------------------------------------------------------------------------
-- La ESTRUCTURA de cada campo se lee de la BD (information_schema):
--   tipo de dato -> control (texto/número/lista), largo máximo, decimales,
--   opciones de las listas (ENUM).
-- Esta tabla guarda solo la PRESENTACIÓN: etiqueta, texto de ayuda, orden y
-- si se muestra. Si se agrega una columna a una sección y no se registra aquí,
-- igual aparece en el formulario con su nombre formateado ("material_tela" ->
-- "Material tela").
-- Se eligió una tabla en vez de COMMENT de columna para no reescribir la
-- definición de columnas en tablas con datos.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblInventarioCampoSeccion` (
  `tipo_inventario` VARCHAR(20)  NOT NULL,
  `columna`         VARCHAR(64)  NOT NULL,
  `etiqueta`        VARCHAR(100) NOT NULL,
  `placeholder`     VARCHAR(150) NULL,
  `orden`           INT NOT NULL DEFAULT 0,
  `visible`         TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0 = no se muestra en el formulario',
  PRIMARY KEY (`tipo_inventario`, `columna`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Etiqueta, ayuda y orden de los campos de cada sección de inventario';

INSERT INTO `TblInventarioCampoSeccion` (tipo_inventario, columna, etiqueta, placeholder, orden, visible)
VALUES
  -- ROPA
  ('ROPA', 'talla',               'Talla',                 'Ej: M, L, XL, 42',           1, 1),
  ('ROPA', 'color',               'Color',                 'Ej: Azul, Blanco',           2, 1),
  ('ROPA', 'genero',              'Género',                NULL,                         3, 1),
  ('ROPA', 'material_tela',       'Material / Tela',       'Ej: Algodón 100%, Cuero',    4, 1),
  ('ROPA', 'norma_certificacion', 'Norma (EPP)',           'Ej: ANSI Z89.1',             5, 1),
  ('ROPA', 'tipo_proteccion',     'Tipo de protección',    'Ej: Cabeza, Manos, Pies',    6, 1),
  -- MATERIAL
  ('MATERIAL', 'tipo',             'Tipo',                 'Ej: Portland Tipo I, PVC C-7.5', 1, 1),
  ('MATERIAL', 'presentacion',     'Presentación',         'Ej: Bolsa 42.5 kg',          2, 1),
  ('MATERIAL', 'marca',            'Marca',                NULL,                         3, 1),
  ('MATERIAL', 'medida',           'Medida',               'Ej: 1/2", 63 mm',            4, 1),
  ('MATERIAL', 'norma',            'Norma',                'Ej: NTP 334.009',            5, 1),
  ('MATERIAL', 'resistencia',      'Resistencia',          'Ej: f''c=210 kg/cm²',        6, 1),
  ('MATERIAL', 'color',            'Color',                NULL,                         7, 1),
  ('MATERIAL', 'peso_unitario_kg', 'Peso por unidad (kg)', NULL,                         8, 1),
  ('MATERIAL', 'largo_cm',         'Largo (cm)',           NULL,                         9, 1),
  ('MATERIAL', 'ancho_cm',         'Ancho (cm)',           NULL,                        10, 1),
  ('MATERIAL', 'alto_cm',          'Alto (cm)',            NULL,                        11, 1),
  ('MATERIAL', 'lote',             'Lote',                 NULL,                        12, 0),
  -- HERRAMIENTA
  ('HERRAMIENTA', 'tipo_herramienta', 'Tipo de herramienta', NULL,                       1, 1),
  ('HERRAMIENTA', 'marca',            'Marca',               NULL,                       2, 1),
  ('HERRAMIENTA', 'modelo',           'Modelo',              NULL,                       3, 1),
  ('HERRAMIENTA', 'potencia',         'Potencia',            'Ej: 850 W',                4, 1),
  ('HERRAMIENTA', 'voltaje',          'Voltaje',             'Ej: 220 V',                5, 1),
  ('HERRAMIENTA', 'numero_serie',     'Número de serie',     NULL,                       6, 1),
  ('HERRAMIENTA', 'peso_kg',          'Peso (kg)',           NULL,                       7, 1),
  ('HERRAMIENTA', 'largo_cm',         'Largo (cm)',          NULL,                       8, 1),
  ('HERRAMIENTA', 'ancho_cm',         'Ancho (cm)',          NULL,                       9, 1),
  ('HERRAMIENTA', 'alto_cm',          'Alto (cm)',           NULL,                      10, 1),
  -- EQUIPO
  ('EQUIPO', 'marca',            'Marca',              NULL,                  1, 1),
  ('EQUIPO', 'modelo',           'Modelo',             NULL,                  2, 1),
  ('EQUIPO', 'capacidad',        'Capacidad',          'Ej: 9 p3, 1 t',       3, 1),
  ('EQUIPO', 'potencia',         'Potencia',           'Ej: 5 HP',            4, 1),
  ('EQUIPO', 'numero_serie',     'Número de serie',    NULL,                  5, 1),
  ('EQUIPO', 'anio_fabricacion', 'Año de fabricación', NULL,                  6, 1),
  ('EQUIPO', 'placa',            'Placa',              NULL,                  7, 1),
  ('EQUIPO', 'peso_kg',          'Peso (kg)',          NULL,                  8, 1),
  ('EQUIPO', 'largo_cm',         'Largo (cm)',         NULL,                  9, 1),
  ('EQUIPO', 'ancho_cm',         'Ancho (cm)',         NULL,                 10, 1),
  ('EQUIPO', 'alto_cm',          'Alto (cm)',          NULL,                 11, 1),
  -- TECNOLOGIA
  ('TECNOLOGIA', 'marca',             'Marca',             NULL,                    1, 1),
  ('TECNOLOGIA', 'modelo',            'Modelo',            NULL,                    2, 1),
  ('TECNOLOGIA', 'procesador',        'Procesador',        'Ej: Intel Core i7',     3, 1),
  ('TECNOLOGIA', 'ram',               'Memoria RAM',       'Ej: 16GB',              4, 1),
  ('TECNOLOGIA', 'almacenamiento',    'Almacenamiento',    'Ej: 512GB SSD',         5, 1),
  ('TECNOLOGIA', 'pantalla',          'Pantalla',          'Ej: 15.6"',             6, 1),
  ('TECNOLOGIA', 'sistema_operativo', 'Sistema operativo', 'Ej: Windows 11 Pro',    7, 1),
  ('TECNOLOGIA', 'numero_serie',      'Número de serie',   NULL,                    8, 1),
  ('TECNOLOGIA', 'garantia_meses',    'Garantía (meses)',  NULL,                    9, 1),
  ('TECNOLOGIA', 'peso_kg',           'Peso (kg)',         NULL,                   10, 1),
  ('TECNOLOGIA', 'largo_cm',          'Largo (cm)',        NULL,                   11, 1),
  ('TECNOLOGIA', 'ancho_cm',          'Ancho (cm)',        NULL,                   12, 1),
  ('TECNOLOGIA', 'alto_cm',           'Alto (cm)',         NULL,                   13, 1),
  -- CONSUMIBLE
  ('CONSUMIBLE', 'marca',            'Marca',                 NULL,             1, 1),
  ('CONSUMIBLE', 'presentacion',     'Presentación',          'Ej: Caja x 10',  2, 1),
  ('CONSUMIBLE', 'tamano',           'Tamaño',                'Ej: A4, Carta',  3, 1),
  ('CONSUMIBLE', 'gramaje',          'Gramaje (g/m²)',        'Ej: 75',         4, 1),
  ('CONSUMIBLE', 'color',            'Color',                 NULL,             5, 1),
  ('CONSUMIBLE', 'unidades_paquete', 'Unidades por paquete',  NULL,             6, 1),
  ('CONSUMIBLE', 'blancura_pct',     'Blancura (%)',          NULL,             7, 1)
AS n
ON DUPLICATE KEY UPDATE etiqueta = n.etiqueta, placeholder = n.placeholder,
                        orden = n.orden, visible = n.visible;

-- ################################################################ p4_02_sp_lectura.sql
-- =============================================================================
-- PARTE 4 / 02 - SPs DE LECTURA PARA EL FORMULARIO (nada hardcodeado)
-- -----------------------------------------------------------------------------
--  sp_obtener_tabla_seccion(tipo, OUT tabla)
--      Descubre la tabla de sección de un tipo leyendo los CHECK de la BD
--      (ej. TblInventarioRopa tiene CHECK tipo_inventario = 'ROPA').
--  sp_listar_tipos_inventario(solo_fisicos)
--      Tipos = categorías de nivel 1 (nombre, prefijo de código, ícono, orden)
--      + su tabla de sección. solo_fisicos = 1 oculta SERVICIO y PARTIDA.
--  sp_listar_categorias_tipo(tipo)
--      Categorías seleccionables del tipo (subcategorías, agrupadas por padre;
--      si el padre no tiene subcategorías, el propio padre).
--  sp_listar_unidades_categoria(id_categoria)
--      Unidades permitidas (propias o heredadas del padre); la predeterminada
--      primero.
--  sp_listar_campos_seccion(tipo)
--      Campos de la sección: estructura desde information_schema +
--      presentación desde TblInventarioCampoSeccion.
-- PythonAnywhere no permite FUNCIONES (requieren SUPER): todo son SPs.
-- =============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_obtener_tabla_seccion`$$
CREATE PROCEDURE `sp_obtener_tabla_seccion`(
    IN  p_tipo_inventario VARCHAR(20),
    OUT p_tabla VARCHAR(64)
)
    READS SQL DATA
BEGIN
    SET p_tabla = NULL;
    SELECT tc.TABLE_NAME INTO p_tabla
    FROM information_schema.TABLE_CONSTRAINTS tc
    JOIN information_schema.CHECK_CONSTRAINTS cc
      ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
    WHERE tc.TABLE_SCHEMA = DATABASE()
      AND tc.CONSTRAINT_TYPE = 'CHECK'
      AND tc.TABLE_NAME LIKE 'TblInventario%'
      AND LOCATE('tipo_inventario', CONVERT(cc.CHECK_CLAUSE USING utf8mb4)) > 0
      AND LOCATE(CONCAT('''', CONVERT(p_tipo_inventario USING utf8mb4), ''''),
                 REPLACE(CONVERT(cc.CHECK_CLAUSE USING utf8mb4), CHAR(92 USING utf8mb4), '')) > 0
    LIMIT 1;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_tipos_inventario`$$
CREATE PROCEDURE `sp_listar_tipos_inventario`(
    IN p_solo_fisicos TINYINT
)
    READS SQL DATA
BEGIN
    SELECT t.*
    FROM (
        SELECT c.tipo_aplicable AS tipo_inventario,
               c.nombre,
               c.codigo         AS prefijo_codigo,
               c.icono,
               c.orden,
               c.id_categoria   AS id_categoria_raiz,
               (SELECT tc.TABLE_NAME
                FROM information_schema.TABLE_CONSTRAINTS tc
                JOIN information_schema.CHECK_CONSTRAINTS cc
                  ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
                WHERE tc.TABLE_SCHEMA = DATABASE()
                  AND tc.CONSTRAINT_TYPE = 'CHECK'
                  AND tc.TABLE_NAME LIKE 'TblInventario%'
                  AND LOCATE('tipo_inventario', CONVERT(cc.CHECK_CLAUSE USING utf8mb4)) > 0
                  AND LOCATE(CONCAT('''', CONVERT(c.tipo_aplicable USING utf8mb4), ''''),
                             REPLACE(CONVERT(cc.CHECK_CLAUSE USING utf8mb4), CHAR(92 USING utf8mb4), '')) > 0
                LIMIT 1) AS tabla_seccion
        FROM `TblCategoriaInventario` c
        WHERE c.nivel = 1
          AND c.estado = 'ACTIVO'
          AND c.tipo_aplicable <> 'TODOS'
    ) t
    WHERE (p_solo_fisicos IS NULL OR p_solo_fisicos = 0 OR t.tabla_seccion IS NOT NULL)
    ORDER BY t.orden, t.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_categorias_tipo`$$
CREATE PROCEDURE `sp_listar_categorias_tipo`(
    IN p_tipo_inventario VARCHAR(20)
)
    READS SQL DATA
BEGIN
    SELECT c.id_categoria,
           c.codigo,
           c.nombre,
           c.nivel,
           p.id_categoria AS id_categoria_padre,
           COALESCE(p.nombre, c.nombre) AS grupo,
           c.icono
    FROM `TblCategoriaInventario` c
    LEFT JOIN `TblCategoriaInventario` p ON p.id_categoria = c.id_categoria_padre
    WHERE c.estado = 'ACTIVO'
      AND c.tipo_aplicable = p_tipo_inventario
      AND (c.nivel = 2
           OR NOT EXISTS (SELECT 1 FROM `TblCategoriaInventario` h
                          WHERE h.id_categoria_padre = c.id_categoria AND h.estado = 'ACTIVO'))
    ORDER BY COALESCE(p.orden, c.orden), c.orden, c.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_unidades_categoria`$$
CREATE PROCEDURE `sp_listar_unidades_categoria`(
    IN p_id_categoria INT
)
    READS SQL DATA
BEGIN
    DECLARE v_cat INT DEFAULT NULL;

    IF EXISTS (SELECT 1 FROM `TblCategoriaUnidad` WHERE id_categoria = p_id_categoria) THEN
        SET v_cat = p_id_categoria;
    ELSE
        SELECT id_categoria_padre INTO v_cat
        FROM `TblCategoriaInventario` WHERE id_categoria = p_id_categoria;
    END IF;

    SELECT u.id_unidad, u.codigo, u.nombre, u.abreviatura, u.magnitud,
           cu.predeterminada,
           IF(cu.id_categoria = p_id_categoria, 'propia', 'heredada') AS origen
    FROM `TblCategoriaUnidad` cu
    JOIN `TblUnidadMedida` u ON u.id_unidad = cu.id_unidad
    WHERE cu.id_categoria = v_cat
      AND u.estado = 'ACTIVO'
    ORDER BY cu.predeterminada DESC, u.nombre;
END$$

DROP PROCEDURE IF EXISTS `sp_listar_campos_seccion`$$
CREATE PROCEDURE `sp_listar_campos_seccion`(
    IN p_tipo_inventario VARCHAR(20)
)
    READS SQL DATA
BEGIN
    DECLARE v_tabla VARCHAR(64) DEFAULT NULL;

    CALL sp_obtener_tabla_seccion(p_tipo_inventario, v_tabla);

    SELECT CONVERT(c.COLUMN_NAME USING utf8mb4) AS columna,
           COALESCE(m.etiqueta,
                    CONCAT(UPPER(LEFT(c.COLUMN_NAME, 1)),
                           REPLACE(SUBSTRING(c.COLUMN_NAME, 2), '_', ' '))) AS etiqueta,
           m.placeholder,
           CASE
             WHEN c.DATA_TYPE = 'enum' THEN 'select'
             WHEN c.DATA_TYPE IN ('decimal','int','smallint','tinyint','mediumint','bigint','float','double') THEN 'numero'
             WHEN c.DATA_TYPE IN ('date','datetime') THEN 'fecha'
             ELSE 'texto'
           END AS control,
           IF(c.DATA_TYPE = 'enum',
              SUBSTRING(c.COLUMN_TYPE, 6, CHAR_LENGTH(c.COLUMN_TYPE) - 6),
              NULL) AS opciones,
           c.CHARACTER_MAXIMUM_LENGTH AS largo_maximo,
           CASE
             WHEN c.DATA_TYPE IN ('int','smallint','tinyint','mediumint','bigint') THEN 0
             ELSE c.NUMERIC_SCALE
           END AS decimales,
           IF(c.DATA_TYPE IN ('decimal','int','smallint','tinyint','mediumint','bigint','float','double'), 0, NULL) AS minimo,
           COALESCE(m.orden, 1000 + c.ORDINAL_POSITION) AS orden
    FROM information_schema.COLUMNS c
    LEFT JOIN `TblInventarioCampoSeccion` m
      ON m.tipo_inventario = p_tipo_inventario
     AND m.columna = CONVERT(c.COLUMN_NAME USING utf8mb4) COLLATE utf8mb4_unicode_ci
    WHERE c.TABLE_SCHEMA = DATABASE()
      AND c.TABLE_NAME = v_tabla
      AND c.COLUMN_NAME NOT IN ('id_inventario', 'tipo_inventario', 'fecha_actualizacion')
      AND COALESCE(m.visible, 1) = 1
    ORDER BY orden;
END$$

DELIMITER ;

-- ################################################################ p4_03_sp_generar_codigo.sql
-- =============================================================================
-- PARTE 4 / 03 - GENERADOR DE CÓDIGO SIN LISTA FIJA
-- -----------------------------------------------------------------------------
-- El prefijo sale de la categoría de nivel 1 del tipo (MAT, HER, EQU, TEC,
-- ROP, OFI, SER, PAR). Si mañana se crea un tipo nuevo con su categoría raíz,
-- el código se genera solo. Sin categoría raíz -> 'INV'.
-- Formato PREFIJO-001: mínimo 3 dígitos, crece sin cortar (MAT-1000).
-- Misma firma: sp_crear_inventario, sp_CrearMaterialConCodigoAuto y
-- sp_guardar_item lo usan sin cambios.
-- =============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_generar_material`$$
CREATE PROCEDURE `sp_generar_material`(
    IN p_tipo_inventario VARCHAR(50),
    OUT p_codigo VARCHAR(50)
)
    READS SQL DATA
BEGIN
    DECLARE v_prefijo VARCHAR(20) DEFAULT NULL;
    DECLARE v_siguiente INT;

    SELECT codigo INTO v_prefijo
    FROM `TblCategoriaInventario`
    WHERE nivel = 1 AND tipo_aplicable = p_tipo_inventario AND estado = 'ACTIVO'
    ORDER BY orden, id_categoria
    LIMIT 1;

    SET v_prefijo = COALESCE(v_prefijo, 'INV');

    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) AS UNSIGNED)), 0) + 1
    INTO v_siguiente
    FROM `TblInventario`
    WHERE codigo LIKE CONCAT(v_prefijo, '-%')
      AND SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) REGEXP '^[0-9]+$';

    SET p_codigo = CONCAT(v_prefijo, '-', LPAD(v_siguiente, GREATEST(3, CHAR_LENGTH(v_siguiente)), '0'));
END$$

DELIMITER ;

-- ################################################################ p4_04_sp_guardar_item.sql
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
