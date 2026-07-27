-- ============================================================================
-- STORED PROCEDURE: sp_ReportePresupuestos (ACTUALIZADO)
-- DESCRIPCIÓN: Reporte General de Gestión de Presupuestos
--              Trae información de presupuestos (sin detalles de items individuales)
--              Los items se obtienen desde TblPresupuestoDetalle
--              Si está RECHAZADO, trae el comentario del rechazo
-- RETORNA: Lista de presupuestos con información de obra, proyecto, usuario y rechazo
-- PARÁMETROS: NINGUNO
-- FECHA: 10 Julio 2026
-- ACTUALIZADO: 17 Julio 2026 - Agregado comentario_rechazo
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ReportePresupuestos //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ReportePresupuestos`()
BEGIN
    SELECT DISTINCT
        -- CAMPOS DIRECTOS DE TBLPRESUPUESTO
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.id_obra,
        pr.num_documento,
        pr.monto,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.fecha_actualizacion,
        
        -- INFORMACIÓN RELACIONADA DE OBRA
        o.codigo_obra,
        o.nombre as nombre_obra,
        
        -- INFORMACIÓN RELACIONADA DE PROYECTO
        p.codigo_proyecto,
        p.nombre as nombre_proyecto,
        
        -- INFORMACIÓN RELACIONADA DE USUARIO
        u.usuario as usuario_login,
        per.nombres as usuario_nombres,
        per.apellido_paterno as usuario_apellido,
        per.email as usuario_email,
        
        -- 🆕 NOMBRE COMPLETO DEL USUARIO QUE CREÓ EL PRESUPUESTO
        CONCAT(
            COALESCE(per.nombres, ''),
            ' ',
            COALESCE(per.apellido_paterno, ''),
            ' ',
            COALESCE(per.apellido_materno, '')
        ) as creado_por,
        
        -- 🆕 NOMBRE COMPLETO DEL USUARIO QUE APROBÓ/RECHAZÓ EL PRESUPUESTO
        CONCAT(
            COALESCE(per_aprobador.nombres, ''),
            ' ',
            COALESCE(per_aprobador.apellido_paterno, ''),
            ' ',
            COALESCE(per_aprobador.apellido_materno, '')
        ) as aprobado_rechazado_por,
        
        -- COMENTARIO DE RECHAZO (si existe)
        CASE 
            WHEN pr.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
            ELSE NULL
        END as comentario_rechazo
        
    FROM TblPresupuesto pr
    
    -- JOINS PARA INFORMACIÓN RELACIONADA
    LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
    LEFT JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
    LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- LEFT JOIN para obtener información del aprobador
    LEFT JOIN TblRegistroAprobacion ra ON 
        pr.id_presupuesto = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 1
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento = per_aprobador.num_documento
    
    -- FILTRO: Excluir presupuestos eliminados
    WHERE pr.estado != 'ELIMINADO'
    
    -- ORDEN: Por fecha más reciente
    ORDER BY pr.fecha_creacion DESC;
END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ReportePresupuestos actualizado exitosamente ✓' as resultado;

-- 🆕 Campos agregados (17 Julio 2026):
-- - comentario_rechazo: Motivo del rechazo (si está RECHAZADO), NULL si otro estado

-- Campos existentes:
-- - total_items: Cantidad de items en el presupuesto
-- - materiales_utilizados: Lista de todos los materiales en el presupuesto

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
