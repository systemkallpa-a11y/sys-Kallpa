-- ==============================================================================
-- STORED PROCEDURE: Crear Material con Código Automático
-- ==============================================================================
-- Descripción: Crea un nuevo material generando automáticamente el código
--              en formato MAT-XXX (MAT-001, MAT-002, etc.)
-- Fecha: 01 Agosto 2026
-- ==============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearMaterialConCodigoAuto$$

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
        -- En caso de error, hacer rollback y retornar 0
        ROLLBACK;
        SET p_resultado = 0;
        SET p_id_material_creado = NULL;
        SET p_codigo_generado = NULL;
    END;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- =========================================================================
    -- PASO 1: Generar el siguiente código MAT-XXX
    -- =========================================================================
    
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
    
    -- =========================================================================
    -- PASO 2: Insertar el nuevo material
    -- =========================================================================
    
    INSERT INTO TblMateriales (
        codigo_material,
        nombre,
        descripcion,
        id_categoria,
        id_unidad,
        id_proveedor,
        estado,
        observaciones
        -- fecha_creacion se genera automáticamente (DEFAULT CURRENT_TIMESTAMP)
    ) VALUES (
        v_nuevo_codigo,
        p_nombre,
        p_descripcion,
        p_id_categoria,
        p_id_unidad,
        NULL,  -- id_proveedor (puede asignarse después)
        'ACTIVO',
        p_observaciones
    );
    
    -- Obtener el ID del material creado
    SET p_id_material_creado = LAST_INSERT_ID();
    SET p_codigo_generado = v_nuevo_codigo;
    SET p_resultado = 1;
    
    -- Confirmar transacción
    COMMIT;
    
END$$

DELIMITER ;

-- ==============================================================================
-- FIN STORED PROCEDURE
-- ==============================================================================
