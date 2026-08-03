-- ============================================================================
-- FIX: sp_ObtenerDocumentosPendientesPorCargo
-- ============================================================================
-- Problema: Retorna presupuestos/requerimientos con estado ELIMINADO
-- Solución: Agregar JOIN con TblPresupuesto/TblRequerimiento y filtrar por estado
-- Fecha: 03 Agosto 2026
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerDocumentosPendientesPorCargo;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerDocumentosPendientesPorCargo(
    IN p_id_cargo INT,
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
    -- Obtener documentos PENDIENTE para el cargo especificado
    -- IMPORTANTE: Excluye documentos con estado ELIMINADO
    
    SELECT
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        ra.id_documento_referencia AS id_documento,
        ra.numero_paso,
        ra.fecha_asignacion,
        ra.estado_aprobacion,
        tda.icono,
        tda.color
    FROM 
        TblRegistroAprobacion ra
    INNER JOIN 
        TblTipoDocumentoAprobacion tda 
        ON ra.id_tipo_documento = tda.id_tipo_documento
    -- ⭐ NUEVO: JOIN con tablas de documentos para verificar estado
    LEFT JOIN 
        TblPresupuesto p 
        ON ra.id_tipo_documento = 1 AND ra.id_documento_referencia = p.id_presupuesto
    LEFT JOIN 
        TblRequerimiento r 
        ON ra.id_tipo_documento = 2 AND ra.id_documento_referencia = r.id_requerimiento
    WHERE 
        ra.estado_aprobacion = 'PENDIENTE'
        AND ra.id_cargo_aprobador = p_id_cargo
        AND (p_id_tipo_documento IS NULL OR ra.id_tipo_documento = p_id_tipo_documento)
        AND tda.activo = 1
        AND tda.requiere_aprobacion = 1
        -- ⭐ NUEVO: Excluir documentos ELIMINADOS
        AND (
            (ra.id_tipo_documento = 1 AND p.estado <> 'ELIMINADO')  -- Presupuestos
            OR (ra.id_tipo_documento = 2 AND r.estado <> 'ELIMINADO')  -- Requerimientos
            OR (ra.id_tipo_documento NOT IN (1, 2))  -- Otros tipos de documentos
        )
        -- ⭐ NUEVO: Excluir documentos que ya no existen (NULL después del LEFT JOIN)
        AND (
            (ra.id_tipo_documento = 1 AND p.id_presupuesto IS NOT NULL)
            OR (ra.id_tipo_documento = 2 AND r.id_requerimiento IS NOT NULL)
            OR (ra.id_tipo_documento NOT IN (1, 2))
        )
        -- CRÍTICO: Verificar que TODOS los pasos anteriores estén APROBADOS
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    ORDER BY 
        ra.fecha_asignacion DESC,
        ra.id_tipo_documento ASC;

END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN: Ver documentos que se filtran ahora
-- ============================================================================

-- Ver presupuestos ELIMINADOS que antes salían
SELECT 
    'Presupuestos ELIMINADOS con registros PENDIENTES' as tipo,
    p.numero_presupuesto,
    p.estado,
    ra.numero_paso,
    c.nombre as cargo_aprobador
FROM TblPresupuesto p
INNER JOIN TblRegistroAprobacion ra ON p.id_presupuesto = ra.id_documento_referencia
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 1
AND ra.estado_aprobacion = 'PENDIENTE'
AND p.estado = 'ELIMINADO';

-- Ver requerimientos ELIMINADOS con registros PENDIENTES
SELECT 
    'Requerimientos ELIMINADOS con registros PENDIENTES' as tipo,
    r.codigo,
    r.estado,
    ra.numero_paso,
    c.nombre as cargo_aprobador
FROM TblRequerimiento r
INNER JOIN TblRegistroAprobacion ra ON r.id_requerimiento = ra.id_documento_referencia
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 2
AND ra.estado_aprobacion = 'PENDIENTE'
AND r.estado = 'ELIMINADO';

-- ============================================================================
-- OPCIONAL: Limpiar registros de aprobación para documentos ELIMINADOS
-- ============================================================================

-- Puedes ejecutar esto para eliminar los registros de flujo de presupuestos ELIMINADOS
/*
DELETE ra 
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
WHERE ra.id_tipo_documento = 1
AND p.estado = 'ELIMINADO';

DELETE ra 
FROM TblRegistroAprobacion ra
INNER JOIN TblRequerimiento r ON ra.id_documento_referencia = r.id_requerimiento
WHERE ra.id_tipo_documento = 2
AND r.estado = 'ELIMINADO';
*/

SELECT '✅ SP sp_ObtenerDocumentosPendientesPorCargo actualizado - Excluye ELIMINADOS' AS estado;
