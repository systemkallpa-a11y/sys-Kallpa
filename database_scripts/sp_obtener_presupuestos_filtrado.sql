-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerPresupuestosFiltrado
-- DESCRIPCIÓN: Obtiene presupuestos con filtros opcionales
--              Permite filtrar por estado, proyecto, obra, fecha, usuario, etc.
-- RETORNA: Result set filtrado
-- PARÁMETROS (TODOS OPCIONALES - NULL = SIN FILTRO):
--   - p_estado: PENDIENTE, APROBADO, RECHAZADO, EJECUTANDO, COMPLETADO, etc.
--   - p_id_proyecto: ID del proyecto a filtrar
--   - p_id_obra: ID de la obra a filtrar
--   - p_num_documento: Número de documento del usuario
--   - p_fecha_desde: Fecha inicial (YYYY-MM-DD)
--   - p_fecha_hasta: Fecha final (YYYY-MM-DD)
--   - p_numero_presupuesto: Búsqueda por número (% para like)
-- FECHA: 10 Julio 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestosFiltrado //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ObtenerPresupuestosFiltrado(
    IN p_estado VARCHAR(50),
    IN p_id_proyecto INT,
    IN p_id_obra INT,
    IN p_num_documento INT,
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE,
    IN p_numero_presupuesto VARCHAR(50)
)
BEGIN
    -- ========================================================================
    -- Obtener presupuestos con filtros dinámicos
    -- ========================================================================
    
    SELECT 
        -- CAMPOS DE PRESUPUESTO
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        pr.estado,
        pr.observaciones,
        pr.fecha_creacion,
        pr.fecha_actualizacion,
        
        -- CAMPOS DE PROYECTO
        p.codigo_proyecto,
        p.nombre as nombre_proyecto,
        
        -- CAMPOS DE OBRA
        o.codigo_obra,
        o.nombre as nombre_obra,
        o.tipo_obra,
        
        -- CAMPOS DE MATERIAL
        m.codigo_material,
        m.nombre as nombre_material,
        m.cantidad_stock,
        
        -- CAMPOS DE UNIDAD
        um.nombre as nombre_unidad,
        
        -- CAMPOS DE CATEGORÍA
        cm.nombre as categoria_material,
        
        -- CAMPOS DE USUARIO
        per.nombres as usuario_nombre,
        per.apellido_paterno,
        CONCAT(per.nombres, ' ', per.apellido_paterno) as usuario_completo,
        per.email as usuario_email,
        
        -- CAMPOS ADICIONALES
        CASE pr.estado
            WHEN 'PENDIENTE' THEN 'Pendiente de aprobación'
            WHEN 'APROBADO' THEN 'Aprobado'
            WHEN 'RECHAZADO' THEN 'Rechazado'
            WHEN 'EJECUTANDO' THEN 'En ejecución'
            WHEN 'COMPLETADO' THEN 'Completado'
            WHEN 'CANCELADO' THEN 'Cancelado'
            ELSE 'Estado desconocido'
        END as estado_descripcion
        
    FROM TblPresupuesto pr
    
    -- JOINS PRINCIPALES
    INNER JOIN TblObra o ON pr.id_obra = o.id_obra
    INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    
    -- JOINS DE MATERIAL
    INNER JOIN TblMateriales m ON pr.id_material = m.id_material
    INNER JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    INNER JOIN TblCategoriaMaterial cm ON m.id_categoria = cm.id_categoria
    
    -- JOINS DE USUARIO
    INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
    INNER JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- FILTROS DINÁMICOS
    WHERE 1=1
        -- Filtro por estado (si se proporciona)
        AND (p_estado IS NULL OR pr.estado = p_estado)
        
        -- Filtro por proyecto (si se proporciona)
        AND (p_id_proyecto IS NULL OR p.id_proyecto = p_id_proyecto)
        
        -- Filtro por obra (si se proporciona)
        AND (p_id_obra IS NULL OR o.id_obra = p_id_obra)
        
        -- Filtro por usuario (si se proporciona)
        AND (p_num_documento IS NULL OR u.num_documento = p_num_documento)
        
        -- Filtro por rango de fechas (si se proporciona)
        AND (p_fecha_desde IS NULL OR DATE(pr.fecha_creacion) >= p_fecha_desde)
        AND (p_fecha_hasta IS NULL OR DATE(pr.fecha_creacion) <= p_fecha_hasta)
        
        -- Filtro por número de presupuesto (búsqueda LIKE si se proporciona)
        AND (p_numero_presupuesto IS NULL OR pr.numero_presupuesto LIKE CONCAT('%', p_numero_presupuesto, '%'))
        
        -- Excluir eliminados
        AND pr.estado != 'ELIMINADO'
    
    -- ORDEN
    ORDER BY 
        pr.fecha_creacion DESC;
        
END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerPresupuestosFiltrado actualizado exitosamente ✓' as resultado;

-- Ejemplos de ejecución
-- CALL sp_ObtenerPresupuestosFiltrado(NULL, NULL, NULL, NULL, NULL, NULL, NULL);
-- CALL sp_ObtenerPresupuestosFiltrado('APROBADO', NULL, NULL, NULL, NULL, NULL, NULL);

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
