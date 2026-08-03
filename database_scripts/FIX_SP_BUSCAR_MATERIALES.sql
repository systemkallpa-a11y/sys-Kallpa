-- ==============================================================================
-- FIX: SP sp_BuscarMateriales (Eliminar precio_unitario)
-- ==============================================================================
-- Tu tabla TblMateriales NO tiene la columna precio_unitario
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_BuscarMateriales$$

CREATE PROCEDURE sp_BuscarMateriales(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT 
        m.id_material,
        m.codigo_material,
        m.nombre,
        -- m.precio_unitario,  ❌ ELIMINADO (columna no existe)
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

-- ==============================================================================
-- Probar el SP actualizado
-- ==============================================================================

CALL sp_BuscarMateriales('', 0);

-- Debería mostrar todos los materiales sin error

-- ==============================================================================
-- FIN
-- ==============================================================================
