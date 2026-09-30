-- sp_ObtenerDetalleDia: se agrega m.justificacion al segundo SELECT
-- (el que está aplicado en BD termina en m.observacion, por eso la columna sale vacía)
-- Aplicar en phpMyAdmin:

DROP PROCEDURE IF EXISTS sp_ObtenerDetalleDia;

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerDetalleDia`(
    IN p_num_documento VARCHAR(20),
    IN p_fecha DATE
)
BEGIN
    -- Obtener información del usuario
    SELECT 
        u.num_documento,
        CONCAT(
            COALESCE(p.nombres, ''),
            ' ',
            COALESCE(p.apellido_paterno, ''),
            ' ',
            COALESCE(p.apellido_materno, '')
        ) as nombre_completo,
        p.email
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE u.num_documento = p_num_documento;
    
    -- Obtener todas las marcaciones del día con fotos
    SELECT 
        m.id_marcacion,
        m.tipo_marcacion,
        m.fecha_marcacion,
        TIME(m.fecha_marcacion) as hora,
        m.latitud,
        m.longitud,
        m.precision,
        m.foto_base64,
        m.dispositivo,
        m.observacion,
        m.justificacion
    FROM TblMarcacion m
    WHERE m.num_documento = p_num_documento
        AND DATE(m.fecha_marcacion) = p_fecha
    ORDER BY m.fecha_marcacion ASC;
END
