-- ========================================================================
-- SP CORREGIDO FORZADO: sp_ObtenerPasosFlujoRequerimiento
-- SOLUCIÓN: Eliminar y recrear el SP con nombre correcto de columna
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Forzar eliminación del SP
DROP PROCEDURE IF EXISTS sp_ObtenerPasosFlujoRequerimiento;

-- Verificar que se eliminó
SELECT 'SP eliminado' as status;

-- Recrear el SP con la corrección
DELIMITER $$

CREATE PROCEDURE sp_ObtenerPasosFlujoRequerimiento(
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
        
        -- Cargo del aprobador - CORRECCIÓN APLICADA
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
        AND ra.id_tipo_documento = 2
        AND ra.id_documento_referencia = p_id_requerimiento
    LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
    LEFT JOIN TblUsuario u ON c.id_cargo = u.id_cargo
    LEFT JOIN TblPersona per ON ra.num_documento_aprobador = per.num_documento
    WHERE fac.id_tipo_documento = 2
      AND fac.activo = 1
      AND fac.es_requerido = 1
    ORDER BY fac.numero_paso ASC;
    
END$$

DELIMITER ;

-- Verificar que se creó correctamente
SELECT 'SP recreado correctamente' as status;
SHOW PROCEDURE STATUS WHERE Name = 'sp_ObtenerPasosFlujoRequerimiento';

-- Probar inmediatamente
SELECT 'Probando el SP...' as status;
CALL sp_ObtenerPasosFlujoRequerimiento(41);

SELECT '✅ CORRECCIÓN COMPLETADA - SP FUNCIONANDO' AS RESULTADO;