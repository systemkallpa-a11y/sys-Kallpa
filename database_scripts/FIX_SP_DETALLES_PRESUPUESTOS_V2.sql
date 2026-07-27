-- ============================================================================
-- FIX: sp_ObtenerDetallesPresupuestosPendientes - Versión 2
-- PROBLEMA: El SP retorna 0 registros porque usa INNER JOIN con TblRegistroAprobacion
--           que podría no tener registros PENDIENTES
-- SOLUCIÓN: Cambiar la lógica para obtener presupuestos PENDIENTES sin depender
--           de que exista un registro previo en TblRegistroAprobacion
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
        COALESCE(CONCAT(per.nombres, ' ', per.apellido_paterno), '') AS nombres_responsable,
        COALESCE(per.apellido_paterno, '') AS apellido_responsable,
        COALESCE(u.usuario, '') AS usuario_responsable
    FROM 
        TblPresupuesto p
    LEFT JOIN 
        TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN 
        TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN 
        TblPersona per ON p.num_documento = per.num_documento
    WHERE 
        p.estado = 'PENDIENTE'
        -- Solo si existen registros de aprobación pendientes O no existen registros
        AND (
            EXISTS (
                SELECT 1 
                FROM TblRegistroAprobacion ra 
                WHERE ra.id_documento_referencia = p.id_presupuesto
                  AND ra.id_tipo_documento = p_id_tipo_documento
                  AND ra.estado_aprobacion = 'PENDIENTE'
            )
            OR NOT EXISTS (
                SELECT 1 
                FROM TblRegistroAprobacion ra 
                WHERE ra.id_documento_referencia = p.id_presupuesto
                  AND ra.id_tipo_documento = p_id_tipo_documento
            )
        )
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
-- NOTA DE IMPLEMENTACIÓN:
-- ============================================================================
-- Este SP ahora obtiene presupuestos PENDIENTES incluso si no tienen 
-- registros de aprobación. Esto es útil para el flujo inicial.
--
-- La lógica es:
-- - Obtener todos los presupuestos con estado = 'PENDIENTE'
-- - Que TENGAN registros de aprobación pendientes (en proceso de aprobación)
-- - O que NO TENGAN ningún registro de aprobación (nuevos presupuestos)
-- ============================================================================
