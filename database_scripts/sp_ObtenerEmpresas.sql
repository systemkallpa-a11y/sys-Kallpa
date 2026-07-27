-- Stored Procedure para obtener todas las empresas
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_ObtenerEmpresas$$

CREATE PROCEDURE sp_ObtenerEmpresas()
BEGIN
    SELECT 
        id_empresa,
        nombre
    FROM TblEmpresa
    WHERE estado = 1
    ORDER BY nombre ASC;
END$$

DELIMITER ;
