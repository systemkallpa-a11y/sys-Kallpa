-- ==============================================================================
-- STORED PROCEDURE DEBUG: Crear Material con Código Automático
-- ==============================================================================
-- Esta versión incluye mensajes de error detallados
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearMaterialConCodigoAuto_DEBUG$$

CREATE PROCEDURE sp_CrearMaterialConCodigoAuto_DEBUG(
    IN p_nombre VARCHAR(150),
    IN p_descripcion LONGTEXT,
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_precio_unitario DECIMAL(10,2),
    IN p_cantidad_stock INT,
    IN p_cantidad_minima INT,
    IN p_observaciones LONGTEXT,
    OUT p_id_material_creado INT,
    OUT p_codigo_generado VARCHAR(50),
    OUT p_resultado INT,
    OUT p_error_msg VARCHAR(500)
)
BEGIN
    DECLARE v_ultimo_numero INT DEFAULT 0;
    DECLARE v_siguiente_numero INT;
    DECLARE v_nuevo_codigo VARCHAR(50);
    DECLARE v_error_code INT;
    DECLARE v_error_msg TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_code = MYSQL_ERRNO,
            v_error_msg = MESSAGE_TEXT;
        
        ROLLBACK;
        SET p_resultado = 0;
        SET p_id_material_creado = NULL;
        SET p_codigo_generado = NULL;
        SET p_error_msg = CONCAT('Error ', v_error_code, ': ', v_error_msg);
    END;
    
    START TRANSACTION;
    
    -- Obtener el último número
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED)), 0)
    INTO v_ultimo_numero
    FROM TblMateriales
    WHERE codigo_material LIKE 'MAT-%'
      AND codigo_material REGEXP '^MAT-[0-9]+$';
    
    SET v_siguiente_numero = v_ultimo_numero + 1;
    SET v_nuevo_codigo = CONCAT('MAT-', LPAD(v_siguiente_numero, 3, '0'));
    
    -- Intentar INSERT
    INSERT INTO TblMateriales (
        codigo_material,
        nombre,
        descripcion,
        id_categoria,
        id_unidad,
        cantidad_stock,
        cantidad_minima,
        precio_unitario,
        observaciones,
        estado
    ) VALUES (
        v_nuevo_codigo,
        p_nombre,
        p_descripcion,
        p_id_categoria,
        p_id_unidad,
        COALESCE(p_cantidad_stock, 0),
        COALESCE(p_cantidad_minima, 0),
        COALESCE(p_precio_unitario, 0.00),
        p_observaciones,
        'ACTIVO'
    );
    
    SET p_id_material_creado = LAST_INSERT_ID();
    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;
    SET p_error_msg = 'OK';
    
    COMMIT;
    
END$$

DELIMITER ;

-- ==============================================================================
-- PROBAR EL SP DEBUG
-- ==============================================================================

CALL sp_CrearMaterialConCodigoAuto_DEBUG(
    'Casco Blanco Debug',
    'Casco de staff debug',
    25,
    1,
    0.00,
    0,
    0,
    'test',
    @id,
    @codigo,
    @resultado,
    @error
);

SELECT 
    @id as 'ID Creado',
    @codigo as 'Código Generado',
    @resultado as 'Resultado',
    @error as 'Mensaje Error';

-- Si @error tiene mensaje, ahí está el problema
