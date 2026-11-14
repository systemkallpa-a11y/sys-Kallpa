-- =============================================================================
-- PARTE 2 / 05 - GENERADOR DE CÓDIGO EN FORMATO CORTO
-- -----------------------------------------------------------------------------
-- sp_generar_material (lo usa sp_crear_inventario) pasa de PREFIJO-00001
-- a PREFIJO-001, con prefijos para SERVICIO (SER) y PARTIDA (PAR).
-- Misma firma: sp_crear_inventario no cambia.
-- Ajuste provisional: en la Parte 4 el prefijo se leerá de la categoría.
-- Original guardado en sp_inventario_actuales_20261113.sql
-- =============================================================================

DELIMITER $$

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

    -- Mínimo 3 dígitos, sin cortar números mayores (1000 -> MAT-1000)
    SET p_codigo = CONCAT(v_prefijo, '-', LPAD(v_siguiente, GREATEST(3, CHAR_LENGTH(v_siguiente)), '0'));
END$$

DELIMITER ;
