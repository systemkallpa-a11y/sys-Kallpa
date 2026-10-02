-- =====================================================
-- SP: Búsqueda dinámica de materiales (YA EXISTE EN BD)
-- Descripción: Busca materiales por nombre/código y categoría
-- Este archivo es solo documentación, el SP ya está en la BD
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_BuscarMateriales$$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE sp_BuscarMateriales(
    IN p_termino_busqueda VARCHAR(255),
    IN p_id_categoria INT
)
BEGIN
    SELECT 
        m.id_material,
        m.codigo_material,
        m.nombre,
        c.nombre as categoria,
        u.nombre as unidad_medida
    FROM TblMateriales m
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
    WHERE m.estado = 'ACTIVO'
      AND (p_termino_busqueda = '' 
           OR m.nombre LIKE CONCAT('%', p_termino_busqueda, '%')
           OR m.codigo_material LIKE CONCAT('%', p_termino_busqueda, '%'))
      AND (p_id_categoria = 0 OR m.id_categoria = p_id_categoria)
    ORDER BY m.codigo_material ASC;
END$$

DELIMITER ;

-- =====================================================
-- NOTAS:
-- - Este SP ya existe en la base de datos
-- - Estructura de TblMateriales:
--   * NO tiene columna precio_unitario
--   * Tiene columna estado (ACTIVO/INACTIVO)
--   * Usa id_unidad en lugar de unidad_medida directa
-- - JOIN con TblCategoriaMaterial (sin 's')
-- - JOIN con TblUnidadMedida para obtener nombre de unidad
-- =====================================================
