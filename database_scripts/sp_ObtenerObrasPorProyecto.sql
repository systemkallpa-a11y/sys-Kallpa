-- Stored Procedure para obtener obras por proyecto
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerObrasPorProyecto$$

CREATE PROCEDURE sp_ObtenerObrasPorProyecto(
    IN p_id_proyecto INT
)
BEGIN
    SELECT 
        id_obra,
        nombre
    FROM TblObra
    WHERE id_proyecto = p_id_proyecto
    AND estado = 1
    ORDER BY nombre ASC;
END$$

DELIMITER ;
