-- ========================================================================
-- SP: sp_ObtenerRequerimientosConAprobadores
-- Descripción: Obtiene lista de requerimientos con información de aprobadores
-- MISMA LÓGICA QUE PRESUPUESTOS: aprobado_rechazado_por
-- Retorna: Lista completa con solicitante y aprobado_rechazado_por del flujo
-- Autor: Sistema Kallpa - TASK 10
-- Fecha: 2026-07-22
-- ========================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientosConAprobadores;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientosConAprobadores`()
READS SQL DATA
BEGIN
    
    SELECT 
        -- Datos básicos del requerimiento
        r.id_requerimiento,
        r.codigo,
        r.descripcion,
        r.cantidad,
        r.estado,
        r.fecha_creacion,
        r.fecha_actualizacion,
        
        -- Solicitante (usuario que creó el requerimiento)
        CONCAT(
            COALESCE(per_solicitante.nombres, ''), ' ',
            COALESCE(per_solicitante.apellido_paterno, ''), ' ',
            COALESCE(per_solicitante.apellido_materno, '')
        ) as solicitante,
        
        -- Presupuesto origen (si aplica)
        pr.numero_presupuesto,
        
        -- APROBADO/RECHAZADO POR - MISMA LÓGICA QUE PRESUPUESTOS
        MAX(CONCAT(
            COALESCE(per_aprobador.nombres, ''), ' ',
            COALESCE(per_aprobador.apellido_paterno, ''), ' ',
            COALESCE(per_aprobador.apellido_materno, '')
        )) as aprobado_rechazado_por,
        
        -- Comentario de rechazo (si aplica)
        MAX(CASE 
            WHEN r.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
            ELSE NULL
        END) as comentario_rechazo
        
    FROM TblRequerimiento r
    LEFT JOIN TblUsuario u_solicitante ON r.num_usuario = u_solicitante.num_documento
    LEFT JOIN TblPersona per_solicitante ON u_solicitante.num_documento = per_solicitante.num_documento
    LEFT JOIN TblPresupuesto pr ON r.id_presupuesto = pr.id_presupuesto
    LEFT JOIN TblRegistroAprobacion ra ON 
        r.id_requerimiento = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 2  -- Requerimientos
        AND (ra.estado_aprobacion = 'APROBADO' OR ra.estado_aprobacion = 'RECHAZADO')
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
    WHERE r.estado != 'ELIMINADO'
    GROUP BY r.id_requerimiento
    ORDER BY r.fecha_creacion DESC;
    
END$$

DELIMITER ;

-- ========================================================================
-- VERIFICACIONES
-- ========================================================================
SHOW PROCEDURE STATUS WHERE Name = 'sp_ObtenerRequerimientosConAprobadores';

-- Ejemplo de uso:
-- CALL sp_ObtenerRequerimientosConAprobadores();

SELECT '✅ SP sp_ObtenerRequerimientosConAprobadores CREADO CORRECTAMENTE' AS RESULTADO;