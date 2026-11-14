-- =============================================================================
-- PARTE 4 / 99 - REVERTIR
-- -----------------------------------------------------------------------------
-- Elimina los SPs nuevos y la tabla de presentación de campos, y deja
-- sp_generar_material como quedó en la Parte 2 (prefijos por CASE).
-- =============================================================================

DROP TABLE IF EXISTS `TblInventarioCampoSeccion`;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_guardar_item`$$
DROP PROCEDURE IF EXISTS `sp_listar_campos_seccion`$$
DROP PROCEDURE IF EXISTS `sp_listar_unidades_categoria`$$
DROP PROCEDURE IF EXISTS `sp_listar_categorias_tipo`$$
DROP PROCEDURE IF EXISTS `sp_listar_tipos_inventario`$$
DROP PROCEDURE IF EXISTS `sp_obtener_tabla_seccion`$$

DROP PROCEDURE IF EXISTS `sp_generar_material`$$
CREATE PROCEDURE `sp_generar_material`(
    IN p_tipo_inventario VARCHAR(50),
    OUT p_codigo VARCHAR(50)
)
BEGIN
    DECLARE v_prefijo VARCHAR(10);
    DECLARE v_siguiente INT;
    SET v_prefijo = CASE p_tipo_inventario
        WHEN 'MATERIAL'    THEN 'MAT'
        WHEN 'HERRAMIENTA' THEN 'HER'
        WHEN 'EQUIPO'      THEN 'EQU'
        WHEN 'TECNOLOGIA'  THEN 'TEC'
        WHEN 'ROPA'        THEN 'ROP'
        WHEN 'CONSUMIBLE'  THEN 'OFI'
        WHEN 'SERVICIO'    THEN 'SER'
        WHEN 'PARTIDA'     THEN 'PAR'
        ELSE 'INV'
    END;
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) AS UNSIGNED)), 0) + 1
    INTO v_siguiente
    FROM TblInventario
    WHERE codigo LIKE CONCAT(v_prefijo, '-%')
      AND SUBSTRING(codigo, CHAR_LENGTH(v_prefijo) + 2) REGEXP '^[0-9]+$';
    SET p_codigo = CONCAT(v_prefijo, '-', LPAD(v_siguiente, GREATEST(3, CHAR_LENGTH(v_siguiente)), '0'));
END$$

DELIMITER ;
