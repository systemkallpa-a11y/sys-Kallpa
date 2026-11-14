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
