-- ============================================================================
-- Script: Recrear SP sin SOURCE (compatible con cualquier cliente SQL)
-- Propósito: Eliminar y recrear el SP directamente
-- Fecha: 10 Julio 2026
-- ============================================================================

-- PASO 1: Eliminar el SP si existe
DROP PROCEDURE IF EXISTS sp_obtener_presupuesto_detalle_completo;

SELECT 'SP eliminado' as paso;

-- PASO 2: Recrear el SP
DELIMITER $$

CREATE PROCEDURE sp_obtener_presupuesto_detalle_completo(
    IN p_id_presupuesto INT
)
BEGIN

    -- ========================================================================
    -- PARTE 1: INFORMACIÓN GENERAL DEL PRESUPUESTO
    -- ========================================================================
    
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.id_obra,
        p.num_documento,
        p.monto,
        p.estado,
        p.observaciones,
        p.fecha_creacion,
        p.fecha_actualizacion,
        -- Información relacionada
        COALESCE(pr.nombre, 'N/A') as nombre_proyecto,
        COALESCE(pr.codigo_proyecto, 'N/A') as codigo_proyecto,
        COALESCE(o.nombre, 'N/A') as nombre_obra,
        COALESCE(o.codigo_obra, 'N/A') as codigo_obra,
        COALESCE(per.nombres, 'N/A') as usuario_nombres,
        COALESCE(per.apellido_paterno, 'N/A') as apellido_paterno,
        COALESCE(u.usuario, 'N/A') as usuario,
        COALESCE(per.email, 'N/A') as email
    FROM TblPresupuesto p
    LEFT JOIN TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    LEFT JOIN TblUsuario u ON p.num_documento = u.num_documento
    LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
    WHERE p.id_presupuesto = p_id_presupuesto;

    -- ========================================================================
    -- PARTE 2: ITEMS DEL PRESUPUESTO (DETALLES)
    -- ========================================================================
    
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        COALESCE(m.codigo_material, 'N/A') as codigo_material,
        COALESCE(m.nombre, 'N/A') as material_nombre,
        COALESCE(um.nombre, 'N/A') as unidad_medida,
        COALESCE(c.nombre, 'N/A') as categoria,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        COALESCE(d.observaciones, '') as observaciones,
        d.fecha_creacion
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
    ORDER BY d.id_detalle;

    -- ========================================================================
    -- PARTE 3: RESUMEN Y CÁLCULOS
    -- ========================================================================
    
    SELECT 
        COUNT(d.id_detalle) as cantidad_items,
        COALESCE(SUM(d.cantidad), 0) as cantidad_total,
        COALESCE(SUM(d.subtotal), 0) as monto_total_calculado,
        (SELECT COALESCE(p2.monto, 0) FROM TblPresupuesto p2 WHERE p2.id_presupuesto = p_id_presupuesto) as monto_presupuesto
    FROM TblPresupuestoDetalle d
    WHERE d.id_presupuesto = p_id_presupuesto;

END$$

DELIMITER ;

SELECT '✅ SP sp_obtener_presupuesto_detalle_completo recreado exitosamente' as resultado;
