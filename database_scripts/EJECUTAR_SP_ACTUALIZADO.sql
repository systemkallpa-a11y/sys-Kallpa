-- ==============================================================================
-- EJECUTAR STORED PROCEDURE ACTUALIZADO (Sin campos que no existen)
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ==============================================================================
-- 1. Eliminar el SP anterior (si existe)
-- ==============================================================================
DROP PROCEDURE IF EXISTS sp_CrearMaterialConCodigoAuto;

-- ==============================================================================
-- 2. Crear el SP actualizado
-- ==============================================================================

DELIMITER $$

CREATE PROCEDURE sp_CrearMaterialConCodigoAuto(
    IN p_nombre VARCHAR(150),
    IN p_descripcion LONGTEXT,
    IN p_id_categoria INT,
    IN p_id_unidad INT,
    IN p_observaciones LONGTEXT,
    OUT p_id_material_creado INT,
    OUT p_codigo_generado VARCHAR(50),
    OUT p_resultado INT
)
BEGIN
    DECLARE v_ultimo_numero INT DEFAULT 0;
    DECLARE v_siguiente_numero INT;
    DECLARE v_nuevo_codigo VARCHAR(50);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_resultado = 0;
        SET p_id_material_creado = NULL;
        SET p_codigo_generado = NULL;
    END;
    
    START TRANSACTION;
    
    -- Obtener el último número usado (del código MAT-XXX)
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_material, 5) AS UNSIGNED)), 0)
    INTO v_ultimo_numero
    FROM TblMateriales
    WHERE codigo_material LIKE 'MAT-%'
      AND codigo_material REGEXP '^MAT-[0-9]+$';
    
    -- Calcular el siguiente número
    SET v_siguiente_numero = v_ultimo_numero + 1;
    
    -- Formatear el código con 3 dígitos (MAT-001, MAT-002, etc.)
    SET v_nuevo_codigo = CONCAT('MAT-', LPAD(v_siguiente_numero, 3, '0'));
    
    -- Insertar el nuevo material (SOLO campos que existen en la tabla)
    INSERT INTO TblMateriales (
        codigo_material,
        nombre,
        descripcion,
        id_categoria,
        id_unidad,
        id_proveedor,
        estado,
        observaciones
    ) VALUES (
        v_nuevo_codigo,
        p_nombre,
        p_descripcion,
        p_id_categoria,
        p_id_unidad,
        NULL,
        'ACTIVO',
        p_observaciones
    );
    
    -- Obtener el ID del material creado
    SET p_id_material_creado = LAST_INSERT_ID();
    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;
    
    COMMIT;
    
END$$

DELIMITER ;

-- ==============================================================================
-- 3. Probar el SP actualizado
-- ==============================================================================

CALL sp_CrearMaterialConCodigoAuto(
    'Casco Blanco Final',
    'Casco de staff',
    25,
    1,
    'test',
    @id,
    @codigo,
    @resultado
);

SELECT 
    @id as 'ID Creado',
    @codigo as 'Código Generado',
    @resultado as 'Resultado (1=éxito, 0=error)';

-- ==============================================================================
-- 4. Verificar que se creó el material
-- ==============================================================================

SELECT * FROM TblMateriales WHERE id_material = @id;

-- Debería mostrar el material con código MAT-008

-- ==============================================================================
-- FIN
-- ==============================================================================
