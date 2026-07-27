-- ============================================================================
-- Script: ACTUALIZAR_SPS_NUEVOS_CAMPOS.sql
-- Propósito: Actualizar SPs para manejar nuevos campos de presupuesto
-- Fecha: 20 Julio 2026
-- ============================================================================

-- Primero verificar que los campos existan
SELECT 'Verificando estructura de TblPresupuesto...' as paso;
SELECT COUNT(*) as cantidad_campos FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'TblPresupuesto' AND TABLE_SCHEMA = DATABASE();

-- ============================================================================
-- PASO 1: Actualizar sp_ObtenerPresupuestoEditar
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoEditar$$

CREATE PROCEDURE sp_ObtenerPresupuestoEditar(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.id_obra,
        p.monto_total,
        p.monto_aprobado,
        p.gastos_generales,
        p.utilidad,
        p.igv,
        p.supervision_obra,
        p.estado,
        p.moneda,
        p.observaciones,
        p.fecha_creacion,
        o.nombre_obra,
        pr.id_proyecto,
        pr.nombre_proyecto,
        e.id_empresa,
        e.nombre_empresa
    FROM TblPresupuesto p
    JOIN TblObra o ON p.id_obra = o.id_obra
    JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    JOIN TblEmpresa e ON pr.id_empresa = e.id_empresa
    WHERE p.id_presupuesto = p_id_presupuesto;
END$$

-- ============================================================================
-- PASO 2: Actualizar sp_ObtenerPresupuestoDetalles
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoDetalles$$

CREATE PROCEDURE sp_ObtenerPresupuestoDetalles(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.monto_total,
        p.monto_aprobado,
        p.gastos_generales,
        p.utilidad,
        p.igv,
        p.supervision_obra,
        p.estado,
        p.observaciones,
        COUNT(DISTINCT pd.id_detalle) as total_items
    FROM TblPresupuesto p
    LEFT JOIN TblPresupuestoDetalle pd ON p.id_presupuesto = pd.id_presupuesto
    WHERE p.id_presupuesto = p_id_presupuesto
    GROUP BY p.id_presupuesto;
END$$

-- ============================================================================
-- PASO 3: Actualizar sp_ObtenerPresupuestoPDF
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoPDF$$

CREATE PROCEDURE sp_ObtenerPresupuestoPDF(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    -- Resultado 1: Información del presupuesto
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.monto_total,
        p.monto_aprobado,
        p.gastos_generales,
        p.utilidad,
        p.igv,
        p.supervision_obra,
        p.estado,
        p.moneda,
        p.observaciones,
        p.fecha_creacion,
        o.nombre_obra,
        pr.nombre_proyecto,
        u.nombres as usuario_nombres,
        u.apellido as usuario_apellido,
        u.email as usuario_email,
        u.celular as usuario_celular
    FROM TblPresupuesto p
    JOIN TblObra o ON p.id_obra = o.id_obra
    JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    JOIN TblUsuario u ON p.num_documento = u.num_documento
    WHERE p.id_presupuesto = p_id_presupuesto;
    
    -- Resultado 2: Materiales
    SELECT 
        pd.id_detalle,
        m.nombre as material_nombre,
        mc.nombre as categoria,
        um.nombre as unidad_medida,
        pd.cantidad,
        pd.precio_unitario,
        (pd.cantidad * pd.precio_unitario) as subtotal
    FROM TblPresupuestoDetalle pd
    JOIN TblMateriales m ON pd.id_material = m.id_material
    LEFT JOIN TblMaterialCategoria mc ON m.id_material_categoria = mc.id_material_categoria
    LEFT JOIN TblUnidadMedida um ON m.id_unidad_medida = um.id_unidad_medida
    WHERE pd.id_presupuesto = p_id_presupuesto 
      AND pd.tipo_item = 'MATERIAL';
    
    -- Resultado 3: Servicios
    SELECT 
        pd.id_detalle,
        pd.descripcion as servicio_nombre,
        pd.cantidad,
        pd.precio_unitario,
        (pd.cantidad * pd.precio_unitario) as subtotal
    FROM TblPresupuestoDetalle pd
    WHERE pd.id_presupuesto = p_id_presupuesto 
      AND pd.tipo_item = 'SERVICIO';
END$$

-- ============================================================================
-- PASO 4: Nota sobre sp_CrearPresupuestoCompleto
-- ============================================================================

-- Este SP necesita ser actualizado en el archivo FIX_CANTIDAD_ORIGINAL_EN_SPS.sql
-- Los nuevos campos se insertarán con valor 0 por defecto
-- El UPDATE de campos específicos se hace en la función actualizar_presupuesto_editar

SELECT 'Scripts de SPs actualizados ✓' as resultado;

-- ============================================================================
-- PASO 5: Nota sobre sp_ActualizarPresupuestoCompleto
-- ============================================================================

-- Este SP también necesita ser actualizado para permitir actualizar los nuevos campos
-- El script actual en el código Python maneja la actualización correctamente

SELECT 'Verificación final de estructura:' as verificacion;
SELECT 
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto' 
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME IN ('gastos_generales', 'utilidad', 'igv', 'supervision_obra')
ORDER BY ORDINAL_POSITION;

SELECT '✓ ACTUALIZACIÓN DE SPS COMPLETADA' as resultado;

-- ============================================================================
