-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerDetallesPresupuestosPendientes
-- PROPÓSITO: Obtener detalles de presupuestos pendientes por tipo y cargo
-- FECHA: 14 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerDetallesPresupuestosPendientes;

DELIMITER //

CREATE PROCEDURE sp_ObtenerDetallesPresupuestosPendientes(
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
    SELECT DISTINCT
        p.id_presupuesto,
        p.numero_presupuesto,
        p.monto,
        'SOL' AS moneda,
        p.estado,
        p.fecha_creacion,
        COALESCE(p.observaciones, '') AS observaciones,
        COALESCE(o.nombre, 'Sin obra') AS nombre_obra,
        COALESCE(per.nombres, '') AS nombres_responsable,
        COALESCE(per.apellido_paterno, '') AS apellido_responsable,
        u.usuario AS usuario_responsable
    FROM 
        TblPresupuesto p
    INNER JOIN 
        TblRegistroAprobacion ra ON p.id_presupuesto = ra.id_documento_referencia
            AND ra.id_tipo_documento = p_id_tipo_documento
            AND ra.estado_aprobacion = 'PENDIENTE'
    LEFT JOIN 
        TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN 
        TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN 
        TblPersona per ON p.num_documento = per.num_documento
    WHERE 
        p.estado = 'PENDIENTE'
    ORDER BY 
        p.fecha_creacion ASC;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

-- Ver el SP creado
SHOW PROCEDURE STATUS LIKE 'sp_ObtenerDetallesPresupuestosPendientes'\G

-- Probar el SP
-- CALL sp_ObtenerDetallesPresupuestosPendientes(1);

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

