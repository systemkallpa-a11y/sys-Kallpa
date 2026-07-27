-- Stored Procedure para obtener todos los proyectos
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerProyectos$$

CREATE PROCEDURE sp_ObtenerProyectos()
BEGIN
    SELECT 
        id_proyecto,
        nombre_proyecto
    FROM TblProyecto
    WHERE estado = 1
    ORDER BY nombre_proyecto ASC;
END$$

DELIMITER ;
