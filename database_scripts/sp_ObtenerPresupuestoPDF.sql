-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerPresupuestoPDF
-- PROPÓSITO: Obtener todos los datos necesarios para generar el PDF del presupuesto
-- FECHA: 20 de Julio de 2026 (Actualizado para incluir SERVICIOS)
-- PARÁMETROS: p_id_presupuesto INT
-- RETORNA: 3 result sets (Presupuesto + Materiales + Servicios)
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoPDF;

DELIMITER //

CREATE PROCEDURE sp_ObtenerPresupuestoPDF(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    -- ====================================================================
    -- RESULT SET 1: Información del Presupuesto (CON DESGLOSE)
    -- ====================================================================
    SELECT 
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        pr.monto_total,
        pr.gastos_generales,
        pr.utilidad,
        pr.igv,
        pr.supervision_obra,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.num_documento,
        o.nombre as nombre_obra,
        o.codigo_obra,
        p.nombre as nombre_proyecto,
        p.codigo_proyecto,
        per.nombres as usuario_nombres,
        per.apellido_paterno as usuario_apellido,
        per.apellido_materno as usuario_apellido_materno,
        per.email as usuario_email,
        per.celular as usuario_celular
    FROM TblPresupuesto pr
    INNER JOIN TblObra o ON pr.id_obra = o.id_obra
    INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
    INNER JOIN TblPersona per ON u.num_documento = per.num_documento
    WHERE pr.id_presupuesto = p_id_presupuesto;
    
    -- ====================================================================
    -- RESULT SET 2: Detalles de Materiales
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.observaciones as observaciones_detalle,
        m.nombre as material_nombre,
        m.codigo_material,
        um.nombre as unidad_medida,
        c.nombre as categoria,
        d.descripcion
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
    AND (d.tipo_item = 'MATERIAL' OR d.tipo_item IS NULL OR d.tipo_item = '')
    ORDER BY d.id_detalle ASC;
    
    -- ====================================================================
    -- RESULT SET 3: Detalles de Servicios
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion as servicio_nombre,
        d.observaciones as observaciones_detalle
    FROM TblPresupuestoDetalle d
    WHERE d.id_presupuesto = p_id_presupuesto
    AND d.tipo_item = 'SERVICIO'
    ORDER BY d.id_detalle ASC;

END //

DELIMITER ;

-- ============================================================================
-- PRUEBA DEL SP
-- ============================================================================

-- CALL sp_ObtenerPresupuestoPDF(21);
-- CALL sp_ObtenerPresupuestoPDF(1);
-- SELECT * FROM TblPresupuesto LIMIT 1;

SELECT 'Stored Procedure sp_ObtenerPresupuestoPDF creado exitosamente ✓ (Incluye SERVICIOS)' as resultado;

