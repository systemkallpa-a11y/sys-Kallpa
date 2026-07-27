-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerRequerimientoDetalles
-- DESCRIPCIÓN: Obtiene todos los detalles de un requerimiento específico con datos del material
-- PARÁMETROS:
--   p_id_requerimiento: ID del requerimiento
-- RETORNA: Lista de detalles del requerimiento con información del material
-- AUTOR: Sistema Kallpa
-- FECHA: 2026-07-16
-- ACTUALIZADO: 2026-07-16 - Remover observaciones
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientoDetalles;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimientoDetalles(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.unidad_medida,
        m.codigo_material,
        m.nombre as material_nombre,
        m.id_categoria,
        cm.nombre as categoria_nombre,
        rd.fecha_creacion,
        rd.fecha_actualizacion
    FROM TblRequerimientoDetalle rd
    INNER JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.id_detalle;
END$$

DELIMITER ;
