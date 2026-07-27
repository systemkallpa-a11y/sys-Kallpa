-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerRequerimientoCompleto_V2
-- DESCRIPCIÓN: Obtiene datos completos de un requerimiento con todos sus detalles
-- PARÁMETROS:
--   p_id_requerimiento: ID del requerimiento
-- RETORNA: Requerimiento + Detalles + Resumen
-- AUTOR: Sistema Kallpa
-- FECHA: 2026-07-17
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientoCompleto_V2;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimientoCompleto_V2(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    
    -- 1. OBTENER INFORMACIÓN DEL REQUERIMIENTO
    SELECT 
        id_requerimiento,
        codigo,
        descripcion,
        cantidad,
        solicitante,
        estado,
        observaciones,
        fecha_creacion,
        fecha_actualizacion
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    -- 2. OBTENER DETALLES DEL REQUERIMIENTO (Materiales y Servicios)
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.unidad_medida,
        rd.observaciones,
        rd.fecha_creacion,
        rd.fecha_actualizacion,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.id_categoria, 0) as id_categoria,
        COALESCE(cm.nombre, '') as categoria_nombre
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;
    
    -- 3. OBTENER RESUMEN (conteos)
    SELECT 
        COUNT(*) as total_items,
        SUM(CASE WHEN tipo_item = 'MATERIAL' THEN 1 ELSE 0 END) as total_materiales,
        SUM(CASE WHEN tipo_item = 'SERVICIO' THEN 1 ELSE 0 END) as total_servicios
    FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    
END$$

DELIMITER ;

