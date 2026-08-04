-- ============================================================================
-- STORED PROCEDURE: BÚSQUEDA AVANZADA DE PRESUPUESTOS
-- FECHA: 2026-08-04
-- DESCRIPCIÓN: Búsqueda de presupuestos con filtros múltiples
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_BuscarPresupuestosAvanzado$$

CREATE PROCEDURE sp_BuscarPresupuestosAvanzado(
    IN p_numero VARCHAR(50),
    IN p_estado VARCHAR(20),
    IN p_id_proyecto INT,
    IN p_id_obra INT,
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE,
    IN p_nombre_creador VARCHAR(255),
    IN p_monto_desde DECIMAL(12,2),
    IN p_monto_hasta DECIMAL(12,2)
)
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
        
        -- NOMBRE COMPLETO DEL USUARIO QUE CREÓ EL PRESUPUESTO
        CONCAT(
            COALESCE(per.nombres, ''),
            ' ',
            COALESCE(per.apellido_paterno, ''),
            ' ',
            COALESCE(per.apellido_materno, '')
        ) as creado_por,
        
        -- NOMBRE COMPLETO DEL USUARIO QUE APROBÓ/RECHAZÓ EL PRESUPUESTO
        CASE 
            WHEN pr.estado IN ('APROBADO', 'RECHAZADO') THEN 
                CONCAT(
                    COALESCE(per_aprobador.nombres, ''),
                    ' ',
                    COALESCE(per_aprobador.apellido_paterno, ''),
                    ' ',
                    COALESCE(per_aprobador.apellido_materno, '')
                )
            ELSE NULL
        END as aprobado_rechazado_por,
        
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
    
    -- LEFT JOIN para obtener información del aprobador/rechazador
    LEFT JOIN TblRegistroAprobacion ra ON 
        pr.id_presupuesto = ra.id_documento_referencia 
        AND ra.id_tipo_documento = 1
    
    -- ✅ CORRECCIÓN: Usar ra.num_documento_aprobador en lugar de ra.num_documento
    LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
    
    -- FILTROS
    WHERE pr.estado != 'ELIMINADO'
        -- Filtro por número de presupuesto (búsqueda parcial)
        AND (p_numero IS NULL OR p_numero = '' OR pr.numero_presupuesto LIKE CONCAT('%', p_numero, '%'))
        
        -- Filtro por estado
        AND (p_estado IS NULL OR p_estado = '' OR pr.estado = p_estado)
        
        -- Filtro por proyecto
        AND (p_id_proyecto IS NULL OR p_id_proyecto = 0 OR o.id_proyecto = p_id_proyecto)
        
        -- Filtro por obra
        AND (p_id_obra IS NULL OR p_id_obra = 0 OR pr.id_obra = p_id_obra)
        
        -- Filtro por rango de fechas (desde)
        AND (p_fecha_desde IS NULL OR DATE(pr.fecha_creacion) >= p_fecha_desde)
        
        -- Filtro por rango de fechas (hasta)
        AND (p_fecha_hasta IS NULL OR DATE(pr.fecha_creacion) <= p_fecha_hasta)
        
        -- Filtro por nombre del creador (búsqueda parcial)
        AND (p_nombre_creador IS NULL OR p_nombre_creador = '' OR 
            CONCAT(
                COALESCE(per.nombres, ''),
                ' ',
                COALESCE(per.apellido_paterno, ''),
                ' ',
                COALESCE(per.apellido_materno, '')
            ) LIKE CONCAT('%', p_nombre_creador, '%'))
        
        -- Filtro por rango de monto (desde)
        AND (p_monto_desde IS NULL OR p_monto_desde = 0 OR pr.monto >= p_monto_desde)
        
        -- Filtro por rango de monto (hasta)
        AND (p_monto_hasta IS NULL OR p_monto_hasta = 0 OR pr.monto <= p_monto_hasta)
    
    -- ORDEN: Por fecha más reciente
    ORDER BY pr.fecha_creacion DESC;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'Stored Procedure sp_BuscarPresupuestosAvanzado creado exitosamente' AS resultado;
