-- ============================================================================
-- PROCEDIMIENTO ALMACENADO: sp_ObtenerNotificacionesPendientes
-- VERSIÓN: 2.0 - CORREGIDO (14 de Julio de 2026)
-- ============================================================================
-- DESCRIPCIÓN: 
--   Obtiene las notificaciones de documentos pendientes de aprobación para 
--   un usuario según su cargo
--
-- CAMBIOS EN V2.0:
--   ✓ Removido filtro "tda.activo = 1" (columna no existe)
--   ✓ Removido filtro "fa.activo = 1" (columna no existe)
--   ✓ Removido filtro "tda.requiere_aprobacion = 1" (columna no existe)
--   ✓ Removido filtro "fa.es_requerido = 1" (columna no existe)
--   ✓ Agregado COALESCE para manejar valores NULL
--   ✓ GROUP BY completado para compatibilidad MySQL 8+
--   ✓ Query simplificada y más performante
--
-- PARÁMETROS:
--   p_id_cargo: ID del cargo del usuario
--
-- RETORNA: 
--   • id_tipo_documento: ID del tipo de documento
--   • nombre_documento: Nombre (ej: "Presupuesto")
--   • icono: Icono Font Awesome (ej: "fa-file-pdf")
--   • color: Color (ej: "blue", "green", "orange")
--   • descripcion_documento: Descripción del documento
--   • cantidad_pendientes: Número de documentos pendientes
--   • numero_paso: Número del paso de aprobación
--   • descripcion_paso: Nombre/descripción del paso
--   • descripcion_detalle: Detalle adicional del paso
--   • documento_mas_antiguo: Fecha del documento más antiguo pendiente
--   • tiempo_pendiente: Tiempo que lleva pendiente
--
-- EJEMPLO DE USO:
--   CALL sp_ObtenerNotificacionesPendientes(22);
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
        COALESCE(tda.icono, 'fa-file') AS icono,
        COALESCE(tda.color, 'blue') AS color,
        COALESCE(tda.descripcion, '') AS descripcion_documento,
        COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
        fa.numero_paso,
        COALESCE(fa.nombre_paso, '') AS descripcion_paso,
        COALESCE(fa.descripcion, '') AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        -- Tabla de tipos de documento (Presupuesto, OT, etc)
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        -- Tabla de flujo de aprobación (qué cargo aprueba cada paso)
        TblFlujoAprobacion fa ON tda.id_tipo_documento = fa.id_tipo_documento
    INNER JOIN 
        -- Tabla de registros de aprobación (documentos pendientes)
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fa.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        -- Filtrar solo para el cargo solicitado
        fa.id_cargo = p_id_cargo
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        tda.descripcion,
        fa.numero_paso,
        fa.nombre_paso,
        fa.descripcion
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBAS DEL PROCEDIMIENTO
-- ============================================================================

-- Verificar que el SP se creó correctamente
-- SHOW PROCEDURE STATUS LIKE 'sp_ObtenerNotificacionesPendientes'\G

-- Prueba básica: obtener notificaciones para cargo 22
-- CALL sp_ObtenerNotificacionesPendientes(22);

-- Prueba con otro cargo
-- CALL sp_ObtenerNotificacionesPendientes(48);

-- ============================================================================
-- QUERIES DE VERIFICACIÓN
-- ============================================================================

-- Ver todos los cargos disponibles
-- SELECT id_cargo, nombre FROM TblCargo ORDER BY nombre;

-- Ver flujos configurados para un cargo
-- SELECT * FROM TblFlujoAprobacion WHERE id_cargo = 22;

-- Ver documentos pendientes
-- SELECT * FROM TblRegistroAprobacion WHERE estado_aprobacion = 'PENDIENTE' LIMIT 10;

-- Ver tipos de documentos
-- SELECT * FROM TblTipoDocumentoAprobacion;

-- ============================================================================
-- FIN DEL PROCEDIMIENTO ALMACENADO
-- ============================================================================

