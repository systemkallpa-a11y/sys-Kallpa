-- ========================================================================
-- SP: sp_ObtenerPasosFlujoRequerimiento
-- Descripción: Obtiene los pasos del flujo de aprobación para un requerimiento
-- Incluye estado de cada paso (PENDIENTE, APROBADO, RECHAZADO)
-- Para mostrar en el componente visual de timeline
-- Autor: Sistema Kallpa - TASK 10 Visual
-- Fecha: 2026-07-22
-- ========================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerPasosFlujoRequerimiento;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPasosFlujoRequerimiento`(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    
    SELECT 
        fac.numero_paso,
        fac.nombre_paso,
        fac.es_requerido,
        
        -- Estado del paso en el registro de aprobación
        COALESCE(ra.estado_aprobacion, 'PENDIENTE') as estado,
        
        -- Información del aprobador
        CONCAT(
            COALESCE(per.nombres, ''), ' ',
            COALESCE(per.apellido_paterno, ''), ' ',
            COALESCE(per.apellido_materno, '')
        ) as nombre_aprobador,
        
        -- Cargo del aprobador (CORREGIDO)
        c.nombre as nombre_cargo,
        
        -- Fechas
        ra.fecha_aprobacion,
        ra.fecha_asignacion,
        
        -- Comentarios
        ra.comentario
        
    FROM TblFlujoAprobacionCargos fac
    LEFT JOIN TblRegistroAprobacion ra ON 
        fac.numero_paso = ra.numero_paso 
        AND fac.id_cargo = ra.id_cargo_aprobador
        AND ra.id_tipo_documento = 2  -- Requerimientos
        AND ra.id_documento_referencia = p_id_requerimiento
    LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
    LEFT JOIN TblUsuario u ON c.id_cargo = u.id_cargo
    LEFT JOIN TblPersona per ON ra.num_documento_aprobador = per.num_documento
    WHERE fac.id_tipo_documento = 2  -- Requerimientos
      AND fac.activo = 1
      AND fac.es_requerido = 1
    ORDER BY fac.numero_paso ASC;
    
END$$

DELIMITER ;

-- ========================================================================
-- VERIFICACIONES
-- ========================================================================
SHOW PROCEDURE STATUS WHERE Name = 'sp_ObtenerPasosFlujoRequerimiento';

-- Ejemplo de uso:
-- CALL sp_ObtenerPasosFlujoRequerimiento(41);

SELECT '✅ SP sp_ObtenerPasosFlujoRequerimiento CREADO CORRECTAMENTE' AS RESULTADO;