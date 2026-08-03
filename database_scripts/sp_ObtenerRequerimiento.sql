-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerRequerimiento
-- ============================================================================
-- Propósito: Obtener información completa de un requerimiento incluyendo:
--            - Datos generales del requerimiento
--            - Solicitante (usuario_completo)
--            - Presupuesto asociado
--            - Detalles (items)
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimiento(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    -- Obtener información del requerimiento con solicitante y presupuesto
    SELECT 
        tr.id_requerimiento,
        tr.num_usuario,
        tr.codigo,
        tr.descripcion,
        tr.cantidad,
        tr.estado,
        tr.observaciones,
        tr.id_presupuesto,
        tr.id_tipo_documento,
        tr.fecha_creacion,
        tr.fecha_actualizacion,
        TRIM(CONCAT(
            COALESCE(p.nombres, ''), 
            ' ', 
            COALESCE(p.apellido_paterno, ''), 
            ' ', 
            COALESCE(p.apellido_materno, '')
        )) as usuario_completo,
        pr.numero_presupuesto
    FROM TblRequerimiento tr
    LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
    LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
    WHERE tr.id_requerimiento = p_id_requerimiento;

END$$

DELIMITER ;

-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerRequerimientoDetalles
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientoDetalles;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimientoDetalles(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    -- Obtener detalles del requerimiento con material y unidad
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.observaciones,
        rd.fecha_creacion,
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(um.nombre, '') as unidad_nombre,
        COALESCE(um.abreviatura, '') as unidad_abreviatura
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;

END$$

DELIMITER ;

SELECT '✅ SPs sp_ObtenerRequerimiento y sp_ObtenerRequerimientoDetalles creados' AS estado;

-- ============================================================================
-- PRUEBA
-- ============================================================================
/*
-- Obtener requerimiento 56
CALL sp_ObtenerRequerimiento(56);
CALL sp_ObtenerRequerimientoDetalles(56);
*/
