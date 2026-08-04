-- ============================================================================
-- STORED PROCEDURES: GESTIÓN DE PROYECTOS Y OBRAS
-- FECHA: 2026-08-04
-- ACTUALIZADO: Para usar solo campos existentes en las tablas
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DELIMITER $$

-- Eliminar procedimientos existentes
DROP PROCEDURE IF EXISTS sp_CrearProyecto$$
DROP PROCEDURE IF EXISTS sp_CrearObra$$
DROP PROCEDURE IF EXISTS sp_ObtenerProyectos$$
DROP PROCEDURE IF EXISTS sp_ObtenerObrasPorProyecto$$

-- ============================================================================
-- SP: CREAR NUEVO PROYECTO
-- ============================================================================
CREATE PROCEDURE sp_CrearProyecto(
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    OUT p_id_proyecto INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_error_msg VARCHAR(255);
    DECLARE v_codigo_numero INT DEFAULT 1;
    DECLARE v_codigo_proyecto VARCHAR(50);
    
    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_id_proyecto = 0;
        SET p_mensaje = CONCAT('Error al crear proyecto: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar nombre obligatorio
    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_id_proyecto = 0;
        SET p_mensaje = 'Error: El nombre del proyecto es obligatorio';
        ROLLBACK;
    ELSE
        -- Obtener el siguiente número de código de proyecto
        SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_proyecto, 5) AS UNSIGNED)), 0) + 1 
        INTO v_codigo_numero
        FROM TblProyecto;
        
        -- Generar código del proyecto
        SET v_codigo_proyecto = CONCAT('PRY-', LPAD(v_codigo_numero, 3, '0'));
        
        -- Insertar proyecto (solo campos que existen según la estructura real)
        INSERT INTO TblProyecto (
            codigo_proyecto,
            nombre,
            descripcion,
            fecha_creacion,
            fecha_actualizacion
        ) VALUES (
            v_codigo_proyecto,
            TRIM(p_nombre),
            TRIM(p_descripcion),
            NOW(),
            NOW()
        );
        
        SET p_id_proyecto = LAST_INSERT_ID();
        SET p_mensaje = 'Proyecto creado exitosamente';
        COMMIT;
    END IF;
END$$

-- ============================================================================
-- SP: CREAR NUEVA OBRA
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_CrearObra$$
CREATE PROCEDURE sp_CrearObra(
    IN p_id_proyecto INT,
    IN p_nombre VARCHAR(200),
    IN p_descripcion TEXT,
    OUT p_id_obra INT,
    OUT p_mensaje VARCHAR(255)
)
BEGIN
    DECLARE v_existe_proyecto INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);
    DECLARE v_codigo_numero INT DEFAULT 1;
    DECLARE v_codigo_obra VARCHAR(50);
    
    -- Handler para errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_id_obra = 0;
        SET p_mensaje = CONCAT('Error al crear obra: ', v_error_msg);
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- Validar que el proyecto existe
    SELECT COUNT(*) INTO v_existe_proyecto
    FROM TblProyecto
    WHERE id_proyecto = p_id_proyecto;
    
    IF v_existe_proyecto = 0 THEN
        SET p_id_obra = 0;
        SET p_mensaje = 'Error: El proyecto especificado no existe';
        ROLLBACK;
    ELSEIF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SET p_id_obra = 0;
        SET p_mensaje = 'Error: El nombre de la obra es obligatorio';
        ROLLBACK;
    ELSE
        -- Obtener el siguiente número de código de obra
        SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_obra, 5) AS UNSIGNED)), 0) + 1 
        INTO v_codigo_numero
        FROM TblObra;
        
        -- Generar código de obra (OBR-001, OBR-002, etc.)
        SET v_codigo_obra = CONCAT('OBR-', LPAD(v_codigo_numero, 3, '0'));
        
        -- Insertar obra (solo campos que existen en TblObra)
        INSERT INTO TblObra (
            id_proyecto,
            codigo_obra,
            nombre,
            descripcion,
            fecha_creacion,
            fecha_actualizacion
        ) VALUES (
            p_id_proyecto,
            v_codigo_obra,
            TRIM(p_nombre),
            TRIM(p_descripcion),
            NOW(),
            NOW()
        );
        
        SET p_id_obra = LAST_INSERT_ID();
        SET p_mensaje = CONCAT('Obra creada exitosamente con código ', v_codigo_obra);
        COMMIT;
    END IF;
END$$

-- ============================================================================
-- SP: OBTENER TODOS LOS PROYECTOS
-- ============================================================================
CREATE PROCEDURE sp_ObtenerProyectos()
BEGIN
    SELECT 
        id_proyecto,
        codigo_proyecto,
        nombre,
        descripcion,
        fecha_creacion,
        fecha_actualizacion
    FROM TblProyecto
    ORDER BY fecha_creacion DESC;
END$$

-- ============================================================================
-- SP: OBTENER OBRAS POR PROYECTO
-- ============================================================================
CREATE PROCEDURE sp_ObtenerObrasPorProyecto(
    IN p_id_proyecto INT
)
BEGIN
    SELECT 
        id_obra,
        id_proyecto,
        nombre,
        codigo_obra,
        descripcion
    FROM TblObra
    WHERE id_proyecto = p_id_proyecto
    ORDER BY codigo_obra, nombre;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Stored Procedures de Proyectos y Obras creados exitosamente' AS resultado;
SELECT '  - sp_CrearProyecto' AS sp_creado;
SELECT '  - sp_CrearObra' AS sp_creado;
SELECT '  - sp_ObtenerProyectos' AS sp_creado;
SELECT '  - sp_ObtenerObrasPorProyecto' AS sp_creado;
