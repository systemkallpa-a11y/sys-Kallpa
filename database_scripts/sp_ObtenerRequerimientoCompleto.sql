-- ========================================================================
-- SP: sp_ObtenerRequerimientoCompleto
-- Descripción: Obtiene datos completos de un requerimiento con sus detalles
-- Incluye información de usuario, presupuesto, materiales y unidades via JOINs
-- Parámetros:
--   p_id_requerimiento: ID del requerimiento a consultar
-- Retorna: 
--   Result Set 1: Datos del requerimiento con usuario y presupuesto
--   Result Set 2: Detalles del requerimiento con materiales y unidades
-- Autor: Sistema Kallpa - TASK 9
-- Fecha: 2026-07-22
-- ========================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimientoCompleto;

DELIMITER $$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_ObtenerRequerimientoCompleto`(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    
    -- Verificar que el requerimiento existe
    SELECT COUNT(*) INTO v_existe
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    
    -- ========================================================================
    -- RESULT SET 1: DATOS DEL REQUERIMIENTO CON USUARIO Y PRESUPUESTO
    -- ========================================================================
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
        -- Usuario completo via JOIN
        CONCAT(
            COALESCE(p.nombres, ''), ' ', 
            COALESCE(p.apellido_paterno, ''), ' ', 
            COALESCE(p.apellido_materno, '')
        ) as usuario_completo,
        -- Presupuesto via JOIN
        pr.numero_presupuesto,
        pr.descripcion as presupuesto_descripcion,
        pr.monto as presupuesto_monto
    FROM TblRequerimiento tr
    LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
    LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
    WHERE tr.id_requerimiento = p_id_requerimiento;
    
    -- ========================================================================
    -- RESULT SET 2: DETALLES DEL REQUERIMIENTO CON MATERIALES Y UNIDADES
    -- ========================================================================
    SELECT 
        rd.id_detalle,
        rd.id_requerimiento,
        rd.id_material,
        rd.tipo_item,
        rd.descripcion,
        rd.cantidad,
        rd.observaciones,
        rd.fecha_creacion,
        rd.fecha_actualizacion,
        -- Material via JOIN
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(m.descripcion, '') as material_descripcion,
        -- Unidad via JOIN (TblMateriales → TblUnidadMedida)
        COALESCE(um.nombre, '') as unidad_nombre,
        COALESCE(um.abreviatura, '') as unidad_abreviatura,
        COALESCE(um.codigo, '') as unidad_codigo,
        -- Categoría via JOIN
        COALESCE(mc.nombre, 'General') as categoria_nombre
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    LEFT JOIN TblCategoriaMaterial mc ON m.id_categoria = mc.id_categoria
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle ASC;
    
END$$

DELIMITER ;

-- ========================================================================
-- VERIFICAR QUE SE CREÓ CORRECTAMENTE
-- ========================================================================
SHOW PROCEDURE STATUS WHERE Name = 'sp_ObtenerRequerimientoCompleto';

-- ========================================================================
-- EJEMPLO DE USO
-- ========================================================================
-- CALL sp_ObtenerRequerimientoCompleto(41);

SELECT '✅ SP sp_ObtenerRequerimientoCompleto CREADO CORRECTAMENTE' AS RESULTADO;