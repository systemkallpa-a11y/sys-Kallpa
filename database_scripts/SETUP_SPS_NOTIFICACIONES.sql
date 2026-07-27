-- ============================================================================
-- SETUP: Crear SPs para Notificaciones de Aprobación
-- ============================================================================
-- Este script crea dos Stored Procedures para obtener notificaciones de
-- documentos pendientes de aprobación según el cargo del usuario:
--
-- 1. sp_ObtenerNotificacionesAprobacion - Versión simple
-- 2. sp_ObtenerNotificacionesPendientes - Versión robusta (RECOMENDADA)
--
-- Ejecución: mysql -u usuario -p nombre_bd < SETUP_SPS_NOTIFICACIONES.sql
-- ============================================================================

USE kallpa_db;

-- ============================================================================
-- SP 1: sp_ObtenerNotificacionesAprobacion (Versión Simple)
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerNotificacionesAprobacion //

CREATE PROCEDURE sp_ObtenerNotificacionesAprobacion(
    IN p_id_cargo INT
)
READS SQL DATA
BEGIN
    -- Variable para el resultado
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'ERROR' AS resultado;
    END;

    -- Obtener notificaciones: documentos pendientes por tipo de documento
    SELECT 
        tda.id_tipo_documento,
        tda.nombre AS tipo_documento,
        tda.icono,
        tda.color,
        COUNT(DISTINCT CONCAT(ra.id_tipo_documento, '_', ra.id_documento_referencia)) AS cantidad_pendientes,
        fa.numero_paso AS proximo_paso,
        fa.nombre_paso,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo
    FROM TblTipoDocumentoAprobacion tda
    LEFT JOIN TblFlujoAprobacion fa ON tda.id_tipo_documento = fa.id_tipo_documento 
        AND fa.id_cargo = p_id_cargo 
        AND fa.activo = 1
    LEFT JOIN TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
        AND ra.estado_aprobacion = 'PENDIENTE'
        AND ra.numero_paso = fa.numero_paso
    WHERE tda.activo = 1
    AND tda.requiere_aprobacion = 1
    AND fa.id_flujo_aprobacion IS NOT NULL
    GROUP BY tda.id_tipo_documento, tda.nombre, tda.icono, tda.color, 
             fa.numero_paso, fa.nombre_paso
    HAVING cantidad_pendientes > 0
    ORDER BY cantidad_pendientes DESC, tda.nombre ASC;

END //

DELIMITER ;

-- ============================================================================
-- SP 2: sp_ObtenerNotificacionesPendientes (Versión Robusta) ⭐ RECOMENDADA
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
        fa.numero_paso,
        fa.nombre_paso AS descripcion_paso,
        fa.descripcion AS descripcion_detalle,
        MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
        TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
    FROM 
        -- 1. Traer todos los tipos de documento activos
        TblTipoDocumentoAprobacion tda
    INNER JOIN 
        -- 2. Traer flujos donde este cargo es aprobador
        TblFlujoAprobacion fa ON tda.id_tipo_documento = fa.id_tipo_documento
    INNER JOIN 
        -- 3. Traer registros pendientes de aprobación
        TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
            AND ra.numero_paso = fa.numero_paso 
            AND ra.estado_aprobacion = 'PENDIENTE'
    WHERE 
        -- Condiciones de filtro
        tda.activo = 1
        AND tda.requiere_aprobacion = 1
        AND fa.activo = 1
        AND fa.id_cargo = p_id_cargo
        AND fa.es_requerido = 1
    GROUP BY 
        tda.id_tipo_documento,
        tda.nombre,
        tda.icono,
        tda.color,
        fa.numero_paso,
        fa.nombre_paso
    ORDER BY 
        cantidad_pendientes DESC,
        documento_mas_antiguo ASC;

END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SPs de Notificaciones creados correctamente' AS resultado;

SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME IN ('sp_ObtenerNotificacionesAprobacion', 'sp_ObtenerNotificacionesPendientes')
AND ROUTINE_SCHEMA = DATABASE()
ORDER BY ROUTINE_NAME;

-- ============================================================================
-- PRUEBAS (DESCOMENTA PARA PROBAR)
-- ============================================================================

-- Obtener notificaciones para cargo 48 (Gerente Proyectos)
-- CALL sp_ObtenerNotificacionesPendientes(48);

-- Obtener notificaciones para cargo 54 (Gerente Operaciones)
-- CALL sp_ObtenerNotificacionesPendientes(54);

-- Ver todos los cargos disponibles
-- SELECT id_cargo, nombre FROM TblCargo WHERE activo = 1 ORDER BY nombre;
