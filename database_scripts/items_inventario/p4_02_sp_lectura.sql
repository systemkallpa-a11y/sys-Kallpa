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
