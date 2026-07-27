-- ============================================================================
-- STORED PROCEDURE: sp_GuardarAccesosUsuario
-- DESCRIPCIÓN: Guarda/actualiza los accesos de un usuario a menús y submenús
-- 
-- NUEVA LÓGICA (7 Julio 2026):
-- - Solo se guardan SUBMENÚS ESPECÍFICOS (id_submenu IS NOT NULL)
-- - NO se guardan filas con NULL
-- - Si marcas todos los submenús de un menú → Se guardan todos
-- - Si marcas solo algunos → Se guardan solo esos
-- 
-- PARÁMETROS:
-- - p_num_documento: Número de documento del usuario
-- - p_accesos_json: JSON con array de accesos 
--   [{menu_nombre: "RR.HH", submenu_nombre: "Usuario"}, ...]
--   NOTA: submenu_nombre NUNCA es null (siempre es un valor específico)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_GuardarAccesosUsuario //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_GuardarAccesosUsuario(
    IN p_num_documento INT,
    IN p_accesos_json JSON
)
BEGIN
    DECLARE p_error_message VARCHAR(500);
    DECLARE p_acceso_index INT DEFAULT 0;
    DECLARE p_acceso_count INT DEFAULT 0;
    DECLARE p_menu_nombre VARCHAR(100);
    DECLARE p_submenu_nombre VARCHAR(100);
    DECLARE p_id_menu INT;
    DECLARE p_id_submenu INT;
    DECLARE p_inserted_count INT DEFAULT 0;
    DECLARE p_deleted_count INT DEFAULT 0;
    
    -- Manejador de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 
            FALSE as success,
            CONCAT('Error en SP: ', p_error_message) as message,
            0 as deleted_rows,
            0 as inserted_rows;
    END;
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- ========================================================================
    -- PASO 1: Validar que el usuario existe
    -- ========================================================================
    
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_documento = p_num_documento) THEN
        SET p_error_message = CONCAT('Usuario con documento ', p_num_documento, ' no existe');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
    END IF;
    
    -- ========================================================================
    -- PASO 2: Validar que el JSON sea válido
    -- ========================================================================
    
    IF p_accesos_json IS NULL OR JSON_TYPE(p_accesos_json) != 'ARRAY' THEN
        SET p_error_message = 'JSON de accesos no válido o vacío';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
    END IF;
    
    SET p_acceso_count = JSON_LENGTH(p_accesos_json);
    
    -- ========================================================================
    -- PASO 3: Eliminar accesos anteriores del usuario
    -- ========================================================================
    
    DELETE FROM TblUsuarioAccesos 
    WHERE num_documento = p_num_documento;
    
    SET p_deleted_count = ROW_COUNT();
    
    -- ========================================================================
    -- PASO 4: Insertar nuevos accesos (iterando el JSON con NOMBRES)
    -- NOTA: SOLO se insertan submenús específicos (NUNCA NULL)
    -- ========================================================================
    
    SET p_acceso_index = 0;
    
    WHILE p_acceso_index < p_acceso_count DO
        -- Extraer nombres del JSON
        SET p_menu_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_accesos_json, CONCAT('$[', p_acceso_index, '].menu_nombre')));
        SET p_submenu_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_accesos_json, CONCAT('$[', p_acceso_index, '].submenu_nombre')));
        
        -- Validar que submenu_nombre NO sea NULL (nueva lógica)
        IF p_submenu_nombre IS NULL OR p_submenu_nombre = 'null' OR p_submenu_nombre = '' THEN
            SET p_error_message = CONCAT('Error: submenu_nombre no puede ser null. Use submenús específicos.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Buscar el ID del menú por nombre
        SELECT id_menu INTO p_id_menu
        FROM TblMenu
        WHERE nombre = p_menu_nombre AND estado = 'ACTIVO'
        LIMIT 1;
        
        IF p_id_menu IS NULL THEN
            SET p_error_message = CONCAT('Menú "', p_menu_nombre, '" no existe o no está activo');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Buscar el ID del submenú por nombre (SIEMPRE debe especificarse)
        SELECT id_submenu INTO p_id_submenu
        FROM TblSubMenu
        WHERE nombre = p_submenu_nombre AND id_menu = p_id_menu AND estado = 'ACTIVO'
        LIMIT 1;
        
        IF p_id_submenu IS NULL THEN
            SET p_error_message = CONCAT('Submenú "', p_submenu_nombre, '" no existe en menú "', p_menu_nombre, '"');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_error_message;
        END IF;
        
        -- Insertar acceso (SIEMPRE con id_submenu específico, NUNCA NULL)
        INSERT INTO TblUsuarioAccesos (num_documento, id_menu, id_submenu, estado)
        VALUES (p_num_documento, p_id_menu, p_id_submenu, 'ACTIVO')
        ON DUPLICATE KEY UPDATE 
            estado = 'ACTIVO',
            fecha_actualizacion = CURRENT_TIMESTAMP;
        
        SET p_inserted_count = p_inserted_count + 1;
        SET p_acceso_index = p_acceso_index + 1;
    END WHILE;
    
    -- ========================================================================
    -- PASO 5: Confirmar transacción
    -- ========================================================================
    
    COMMIT;
    
    -- ========================================================================
    -- PASO 6: Retornar resultado de éxito
    -- ========================================================================
    
    SELECT 
        TRUE as success,
        CONCAT('Se actualizaron accesos exitosamente: ', p_inserted_count, ' nuevos, ', p_deleted_count, ' eliminados') as message,
        p_deleted_count as deleted_rows,
        p_inserted_count as inserted_rows,
        p_num_documento as usuario_documento;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP: Ejecutar para verificar que funciona
-- ============================================================================

/*

-- Limpiar accesos del usuario 1
DELETE FROM TblUsuarioAccesos WHERE num_documento = 1;

-- Llamar SP con JSON SOLO submenús específicos (NUEVA LÓGICA)
CALL sp_GuardarAccesosUsuario(1, JSON_ARRAY(
    JSON_OBJECT('menu_nombre', 'RR.HH', 'submenu_nombre', 'Usuario'),
    JSON_OBJECT('menu_nombre', 'RR.HH', 'submenu_nombre', 'Marcación'),
    JSON_OBJECT('menu_nombre', 'Configuración', 'submenu_nombre', 'Empresa'),
    JSON_OBJECT('menu_nombre', 'Configuración', 'submenu_nombre', 'Rol y Accesos')
));

-- Verificar que se guardaron
SELECT * FROM TblUsuarioAccesos WHERE num_documento = 1;

*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
