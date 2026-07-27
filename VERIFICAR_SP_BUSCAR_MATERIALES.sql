-- ============================================================================
-- VERIFICAR Y CREAR SP_BUSCAR_MATERIALES
-- ============================================================================

-- Verificar si el SP existe
SELECT 'VERIFICANDO SP EXISTENTE...' AS STATUS;

SELECT 
    ROUTINE_NAME, 
    ROUTINE_TYPE,
    CREATED,
    LAST_ALTERED
FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = 'kallgwkn_kallpa_bd' 
  AND ROUTINE_NAME = 'sp_BuscarMateriales';

-- Crear/Recrear el SP
SELECT 'CREANDO/ACTUALIZANDO SP...' AS STATUS;

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_BuscarMateriales;

DELIMITER $$

CREATE PROCEDURE sp_BuscarMateriales(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT 
        m.id_material,
        m.codigo_material,
        m.nombre,
        m.precio_unitario,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblMateriales m
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE m.estado = 'ACTIVO'
    AND (
        p_termino_busqueda = '' 
        OR m.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
        OR m.codigo_material LIKE CONCAT('%', p_termino_busqueda, '%')
    )
    AND (
        p_id_categoria = 0
        OR m.id_categoria = p_id_categoria
    )
    ORDER BY m.codigo_material ASC;
END$$

DELIMITER ;

-- Verificar creación
SELECT 'VERIFICANDO CREACIÓN...' AS STATUS;

SELECT 
    ROUTINE_NAME, 
    ROUTINE_TYPE,
    CREATED
FROM information_schema.ROUTINES 
WHERE ROUTINE_SCHEMA = 'kallgwkn_kallpa_bd' 
  AND ROUTINE_NAME = 'sp_BuscarMateriales';

-- Test del SP
SELECT 'TESTEANDO SP CON DATOS DE EJEMPLO...' AS STATUS;

CALL sp_BuscarMateriales('acero', 0);

SELECT '✅ SP CREADO Y VERIFICADO CORRECTAMENTE' AS RESULTADO;