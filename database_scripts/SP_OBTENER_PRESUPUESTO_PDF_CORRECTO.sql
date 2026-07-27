-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerPresupuestoPDF (VERSIÓN COMPLETA Y CORREGIDA)
-- PROPÓSITO: Obtener TODOS los datos necesarios para generar el PDF del presupuesto
-- FECHA: 20 de Julio de 2026 (Corregido - Incluye DESGLOSE y DETALLES)
-- RETORNA: 3 result sets (Presupuesto + Materiales + Servicios)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoPDF;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerPresupuestoPDF`(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    -- ====================================================================
    -- RESULT SET 1: Información del Presupuesto (CON DESGLOSE COMPLETO)
    -- ====================================================================
    SELECT 
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        COALESCE(pr.monto_total, 0) as monto_total,
        COALESCE(pr.gastos_generales, 0) as gastos_generales,
        COALESCE(pr.utilidad, 0) as utilidad,
        COALESCE(pr.igv, 0) as igv,
        COALESCE(pr.supervision_obra, 0) as supervision_obra,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.num_documento,
        e.nombre as nombre_empresa,
        e.logo as empresa_logo,
        o.id_obra,
        o.nombre as nombre_obra,
        o.codigo_obra,
        pr.id_obra,
        pry.id_proyecto,
        pry.nombre as nombre_proyecto,
        pry.codigo_proyecto,
        COALESCE(p.nombres, '') as usuario_nombres,
        CONCAT(COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as usuario_apellido,
        COALESCE(p.email, '') as usuario_email,
        COALESCE(p.celular, '') as usuario_celular
    FROM TblPresupuesto pr
    LEFT JOIN TblEmpresa e ON pr.id_empresa = e.id_empresa
    LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
    LEFT JOIN TblProyecto pry ON o.id_proyecto = pry.id_proyecto
    LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
    LEFT JOIN TblPersona p ON pr.num_documento = p.num_documento
    WHERE pr.id_presupuesto = p_id_presupuesto;
    
    -- ====================================================================
    -- RESULT SET 2: Detalles de Materiales (TODO LO NECESARIO PARA TABLA)
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.id_material,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion,
        COALESCE(m.nombre, d.descripcion) as material_nombre,
        COALESCE(m.codigo_material, '') as codigo_material,
        COALESCE(um.nombre, 'und') as unidad_medida,
        COALESCE(c.nombre, 'General') as categoria
    FROM TblPresupuestoDetalle d
    LEFT JOIN TblMateriales m ON d.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
    WHERE d.id_presupuesto = p_id_presupuesto
    AND d.tipo_item IN ('MATERIAL', '')
    ORDER BY d.id_detalle ASC;
    
    -- ====================================================================
    -- RESULT SET 3: Detalles de Servicios (TODO LO NECESARIO PARA TABLA)
    -- ====================================================================
    SELECT 
        d.id_detalle,
        d.id_presupuesto,
        d.tipo_item,
        d.cantidad,
        d.precio_unitario,
        d.subtotal,
        d.descripcion as servicio_nombre,
        d.descripcion,
        d.observaciones as observaciones_detalle
    FROM TblPresupuestoDetalle d
    WHERE d.id_presupuesto = p_id_presupuesto
    AND d.tipo_item = 'SERVICIO'
    ORDER BY d.id_detalle ASC;

END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN Y PRUEBA
-- ============================================================================

SELECT '✓ SP sp_ObtenerPresupuestoPDF VERSIÓN COMPLETA creado exitosamente' as resultado;

-- Para probar, descomenta la siguiente línea:
-- CALL sp_ObtenerPresupuestoPDF(21);

-- ============================================================================
-- CAMBIOS EN ESTA VERSIÓN:
-- ============================================================================
--
-- 1. RESULT SET 1 (Presupuesto):
--    ✓ Agregados 5 campos desglose: monto_total, gastos_generales, utilidad, igv, supervision_obra
--    ✓ COALESCE para evitar NULL (retorna 0 si no existen)
--    ✓ Agregada empresa (TblEmpresa)
--    ✓ Agregados nombres de usuario completos
--
-- 2. RESULT SET 2 (Materiales):
--    ✓ Incluye TODAS las columnas necesarias para la tabla
--    ✓ JOIN con TblMateriales para obtener info del material
--    ✓ JOIN con TblUnidadMedida para unidad
--    ✓ JOIN con TblCategoriaMaterial para categoría
--    ✓ COALESCE para evitar NULL en campos opcionales
--
-- 3. RESULT SET 3 (Servicios):
--    ✓ Incluye TODAS las columnas necesarias para la tabla
--    ✓ Solo filtra tipo_item = 'SERVICIO'
--    ✓ Todos los campos accesibles para PDF
--
-- ============================================================================
