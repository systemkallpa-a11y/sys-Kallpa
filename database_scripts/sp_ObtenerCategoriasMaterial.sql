-- =====================================================
-- SP: Obtener categorías de materiales (YA EXISTE EN BD)
-- Descripción: Devuelve todas las categorías de materiales
-- Este archivo es solo documentación, el SP ya está en la BD
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerCategoriasMaterial$$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE sp_ObtenerCategoriasMaterial()
BEGIN
    SELECT
        id_categoria,
        nombre
    FROM TblCategoriaMaterial
    ORDER BY nombre ASC;
END$$

DELIMITER ;

-- =====================================================
-- NOTAS:
-- - Este SP ya existe en la base de datos
-- - Devuelve todas las categorías sin filtrar por estado
-- - Ordenadas alfabéticamente por nombre
-- =====================================================
