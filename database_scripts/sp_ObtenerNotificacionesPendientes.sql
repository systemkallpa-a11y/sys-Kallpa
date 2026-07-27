-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerNotificacionesPendientes
-- ============================================================================
-- Descripción: Obtiene las notificaciones de documentos pendientes de 
--              aprobación para un usuario según su cargo
--
-- Parámetros:
--   p_id_cargo: ID del cargo del usuario
--
-- Retorna: 
--   - id_tipo_documento
--   - nombre_documento (ej: Presupuesto)
--   - icono (ej: fa-file-invoice-dollar)
--   - color (ej: blue)
--   - cantidad_pendientes (número de docs pendientes)
--   - numero_paso (paso actual de aprobación)
--   - descripcion_paso
--   - documento_mas_antiguo (fecha del doc más antiguo pendiente)
--
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesPendientes //

CREATE PROCEDURE sp_ObtenerNotificacionesPendientes(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS nombre_documento,
        tda.icono,
        tda.color,
        tda.descripcion AS descripcion_documento,
        COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
        fc.numero_paso,
        fc.nombre_paso AS descripcion_paso,
        fc.descripcion AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        -- 1. Traer todos los tipos de documento activos
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        -- 2. Traer flujos donde este cargo es aprobador
        TblFlujoAprobacionCargos fc ON tda.id_tipo_documento = fc.id_tipo_documento
    INNER JOIN 
        -- 3. Traer registros pendientes de aprobación
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fc.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        -- Condiciones de filtro
        tda.activo = 1
        AND tda.requiere_aprobacion = 1
        AND fc.activo = 1
        AND fc.id_cargo = p_id_cargo
        AND fc.es_requerido = 1
        -- CRÍTICO: Verificar que TODOS los pasos anteriores estén APROBADOS
        -- Si hay algún paso anterior que NO esté APROBADO, excluir este documento
        AND NOT EXISTS (
            SELECT 1 
            FROM TblRegistroAprobacion ra_prev
            WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
              AND ra_prev.id_documento_referencia = ra.id_documento_referencia
              AND ra_prev.numero_paso < ra.numero_paso
              AND ra_prev.estado_aprobacion <> 'APROBADO'
        )
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        fc.numero_paso,
        fc.nombre_paso
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP (COMENTADA)
-- ============================================================================

-- Obtener notificaciones para cargo 48 (Gerente Proyectos)
-- CALL sp_ObtenerNotificacionesPendientes(48);

-- Obtener notificaciones para cargo 54 (Gerente Operaciones)
-- CALL sp_ObtenerNotificacionesPendientes(54);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

-- Ver flujos configurados para un cargo
-- SELECT * FROM TblFlujoAprobacion WHERE id_cargo = 48;

-- Ver documentos pendientes
-- SELECT * FROM TblRegistroAprobacion WHERE estado_aprobacion = 'PENDIENTE' LIMIT 5;

-- ============================================================================
