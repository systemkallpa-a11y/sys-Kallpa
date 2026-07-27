-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerPresupuestosReporte
-- DESCRIPCIÓN: Obtiene TODOS los datos de presupuestos para el reporte
--              Incluye información de proyectos, obras, materiales y usuarios
-- RETORNA: Result set con datos completos de presupuestos
-- PARÁMETROS: NINGUNO (trae todos los presupuestos no eliminados)
-- FECHA: 10 Julio 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestosReporte //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ObtenerPresupuestosReporte()
BEGIN
    -- ========================================================================
    -- Obtener TODOS los presupuestos con información completa
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
        
        -- CAMPOS DE UNIDAD DE MEDIDA
        um.nombre as nombre_unidad,
        
        -- CAMPOS DE CATEGORÍA MATERIAL
        cm.nombre as categoria_material,
        
        -- CAMPOS DE USUARIO (desde TblPersona)
        per.nombres as usuario_nombre,
        per.apellido_paterno,
        per.apellido_materno,
        per.email as usuario_email,
        
        -- CAMPOS COMBINADOS (para reporte)
        CONCAT(per.nombres, ' ', per.apellido_paterno) as usuario_completo,
        
        -- ESTADO DESCRIPCIÓN
        CASE pr.estado
            WHEN 'PENDIENTE' THEN 'Pendiente de aprobación'
            WHEN 'APROBADO' THEN 'Aprobado'
            WHEN 'RECHAZADO' THEN 'Rechazado'
            WHEN 'EJECUTANDO' THEN 'En ejecución'
            WHEN 'COMPLETADO' THEN 'Completado'
            WHEN 'CANCELADO' THEN 'Cancelado'
            WHEN 'ELIMINADO' THEN 'Eliminado'
            ELSE 'Estado desconocido'
        END as estado_descripcion
        
    FROM TblPresupuesto pr
    
    -- JOINS PRINCIPALES (presupuesto → obra → proyecto)
    INNER JOIN TblObra o ON pr.id_obra = o.id_obra
    INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
    
    -- JOINS DE MATERIAL
    INNER JOIN TblMateriales m ON pr.id_material = m.id_material
    INNER JOIN TblUnidadMedida um ON m.id_unidad_medida = um.id_unidad_medida
    INNER JOIN TblCategoriaMaterial cm ON m.id_categoria_material = cm.id_categoria_material
    
    -- JOINS DE USUARIO
    INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
    INNER JOIN TblPersona per ON u.num_documento = per.num_documento
    
    -- FILTRO: Excluir eliminados (opcional, comentar para incluir)
    -- WHERE pr.estado != 'ELIMINADO'
    
    -- ORDEN
    ORDER BY 
        pr.fecha_creacion DESC;
        
END //

DELIMITER ;

-- ============================================================================
-- DESCRIPCIÓN DETALLADA DE CAMPOS RETORNADOS
-- ============================================================================

/*

CAMPOS DE PRESUPUESTO:
├─ id_presupuesto (INT): ID único del presupuesto
├─ numero_presupuesto (VARCHAR): Código único ej. PRES-001
├─ monto (DECIMAL): Monto total del presupuesto
├─ estado (VARCHAR): Estado actual (PENDIENTE, APROBADO, etc.)
├─ observaciones (LONGTEXT): Notas adicionales
├─ fecha_creacion (DATETIME): Fecha de registro
└─ fecha_actualizacion (DATETIME): Última actualización

CAMPOS DE PROYECTO:
├─ id_proyecto (INT): ID del proyecto
├─ codigo_proyecto (VARCHAR): Código del proyecto (PRY-001)
├─ nombre_proyecto (VARCHAR): Nombre del proyecto
└─ descripcion_proyecto (LONGTEXT): Descripción

CAMPOS DE OBRA:
├─ id_obra (INT): ID de la obra
├─ codigo_obra (VARCHAR): Código de la obra (OBR-001)
├─ nombre_obra (VARCHAR): Nombre de la obra
├─ descripcion_obra (LONGTEXT): Descripción
├─ tipo_obra (VARCHAR): Tipo (Excavación, Estructura, etc.)
└─ observaciones_obra (LONGTEXT): Notas

CAMPOS DE MATERIAL:
├─ id_material (INT): ID del material
├─ codigo_material (VARCHAR): Código del material
├─ nombre_material (VARCHAR): Nombre del material
├─ descripcion_material (LONGTEXT): Descripción
└─ cantidad_disponible (DECIMAL): Stock disponible

CAMPOS DE UNIDAD DE MEDIDA:
├─ codigo_unidad (VARCHAR): Código (UND, KG, LT, etc.)
└─ nombre_unidad (VARCHAR): Nombre de la unidad

CAMPOS DE CATEGORÍA:
└─ categoria_material (VARCHAR): Categoría (Cemento, Acero, etc.)

CAMPOS DE USUARIO:
├─ num_usuario (INT): ID del usuario
├─ num_documento (INT): Número de documento
├─ usuario_nombre (VARCHAR): Nombres
├─ apellido_paterno (VARCHAR): Apellido paterno
├─ apellido_materno (VARCHAR): Apellido materno
├─ usuario_email (VARCHAR): Email
└─ usuario_celular (VARCHAR): Celular

CAMPOS COMBINADOS:
├─ usuario_completo (VARCHAR): "Juan García López"
├─ estado_descripcion (VARCHAR): Descripción del estado
└─ dias_desde_creacion (INT): Días desde que se creó

*/

-- ============================================================================
-- EJEMPLOS DE USO
-- ============================================================================

/*

-- 1. Obtener todos los presupuestos
CALL sp_ObtenerPresupuestosReporte();

-- 2. Ejemplo en aplicación Python (Flask):
SELECT * FROM (
    SELECT 
        pr.id_presupuesto,
        pr.numero_presupuesto,
        pr.monto,
        pr.estado,
        ...
    FROM (CALL sp_ObtenerPresupuestosReporte())
) AS datos
WHERE estado = 'APROBADO';

-- 3. Exportar a CSV desde MySQLWorkbench:
-- Run SP → Export Result Set → Select Format CSV

*/

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerPresupuestosReporte creado exitosamente ✓' as resultado;

-- Ejecutar SP para verificar
-- CALL sp_ObtenerPresupuestosReporte();

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
