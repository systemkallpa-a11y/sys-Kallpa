-- ============================================================================
-- Script: UPDATE_SP_CON_NUEVOS_CAMPOS.sql
-- Propósito: Actualizar SPs para incluir nuevos campos de desglose
-- Fecha: 20 Julio 2026
-- ============================================================================

DELIMITER $$

-- ============================================================================
-- 1. Actualizar sp_CrearPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoCompleto$$

CREATE PROCEDURE sp_CrearPresupuestoCompleto(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_contador INT;
    DECLARE v_id_presupuesto INT;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_material_count INT;
    DECLARE v_servicio_count INT;
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;
    
    -- Variables para iterate
    DECLARE v_id_material INT;
    DECLARE v_cantidad DECIMAL(10, 2);
    DECLARE v_precio_unitario DECIMAL(12, 2);
    DECLARE v_subtotal DECIMAL(12, 2);
    DECLARE v_descripcion VARCHAR(255);
    
    START TRANSACTION;
    
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al crear presupuesto completo';
        END;
        
        -- 1. Generar número de presupuesto
        SELECT COUNT(*) + 1 INTO v_contador FROM TblPresupuesto;
        SET v_numero_presupuesto = CONCAT('PRES-', LPAD(v_contador, 4, '0'));
        
        -- 2. Insertar presupuesto con campos de desglose inicializados en 0
        INSERT INTO TblPresupuesto (
            numero_presupuesto,
            id_empresa,
            id_obra,
            num_documento,
            monto_total,
            monto_aprobado,
            gastos_generales,
            utilidad,
            igv,
            supervision_obra,
            estado,
            observaciones,
            fecha_creacion
        ) VALUES (
            v_numero_presupuesto,
            p_id_empresa,
            p_id_obra,
            p_num_documento,
            0,
            0,
            0,
            0,
            0,
            0,
            'PENDIENTE',
            p_comentarios,
            NOW()
        );
        
        SET v_id_presupuesto = LAST_INSERT_ID();
        SET p_id_presupuesto_created = v_id_presupuesto;
        
        -- 3. Insertar materiales desde JSON
        SET v_material_count = JSON_LENGTH(p_materiales_json);
        SET v_i = 0;
        
        WHILE v_i < v_material_count DO
            SET v_id_material = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].id_material'));
            SET v_cantidad = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal = v_cantidad * v_precio_unitario;
            
            INSERT INTO TblPresupuestoDetalle (
                id_presupuesto,
                id_material,
                tipo_item,
                cantidad,
                cantidad_original,
                precio_unitario,
                subtotal
            ) VALUES (
                v_id_presupuesto,
                v_id_material,
                'MATERIAL',
                v_cantidad,
                v_cantidad,
                v_precio_unitario,
                v_subtotal
            );
            
            SET v_monto_total = v_monto_total + v_subtotal;
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 4. Insertar servicios desde JSON
        SET v_servicio_count = JSON_LENGTH(p_servicios_json);
        SET v_i = 0;
        
        WHILE v_i < v_servicio_count DO
            SET v_descripcion = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].descripcion'));
            SET v_cantidad = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal = v_cantidad * v_precio_unitario;
            
            INSERT INTO TblPresupuestoDetalle (
                id_presupuesto,
                tipo_item,
                descripcion,
                cantidad,
                cantidad_original,
                precio_unitario,
                subtotal
            ) VALUES (
                v_id_presupuesto,
                'SERVICIO',
                v_descripcion,
                v_cantidad,
                v_cantidad,
                v_precio_unitario,
                v_subtotal
            );
            
            SET v_monto_total = v_monto_total + v_subtotal;
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 5. Actualizar monto total del presupuesto
        UPDATE TblPresupuesto SET monto_total = v_monto_total WHERE id_presupuesto = v_id_presupuesto;
        
        COMMIT;
    END;
END$$

-- ============================================================================
-- 2. Actualizar sp_ActualizarPresupuestoCompleto
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto$$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_material_count INT;
    DECLARE v_servicio_count INT;
    DECLARE v_id_material INT;
    DECLARE v_cantidad DECIMAL(10, 2);
    DECLARE v_precio_unitario DECIMAL(12, 2);
    DECLARE v_subtotal DECIMAL(12, 2);
    DECLARE v_descripcion VARCHAR(255);
    
    START TRANSACTION;
    
    BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al actualizar presupuesto completo';
        END;
        
        -- 1. Actualizar encabezado (mantiene campos de desglose sin cambios)
        UPDATE TblPresupuesto 
        SET 
            id_empresa = p_id_empresa,
            id_obra = p_id_obra,
            num_documento = p_num_documento,
            observaciones = p_comentarios,
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = p_id_presupuesto;
        
        -- 2. Eliminar detalles existentes
        DELETE FROM TblPresupuestoDetalle WHERE id_presupuesto = p_id_presupuesto;
        
        -- 3. Insertar nuevos materiales
        SET v_material_count = JSON_LENGTH(p_materiales_json);
        SET v_i = 0;
        
        WHILE v_i < v_material_count DO
            SET v_id_material = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].id_material'));
            SET v_cantidad = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal = v_cantidad * v_precio_unitario;
            
            INSERT INTO TblPresupuestoDetalle (
                id_presupuesto,
                id_material,
                tipo_item,
                cantidad,
                cantidad_original,
                precio_unitario,
                subtotal
            ) VALUES (
                p_id_presupuesto,
                v_id_material,
                'MATERIAL',
                v_cantidad,
                v_cantidad,
                v_precio_unitario,
                v_subtotal
            );
            
            SET v_monto_total = v_monto_total + v_subtotal;
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 4. Insertar nuevos servicios
        SET v_servicio_count = JSON_LENGTH(p_servicios_json);
        SET v_i = 0;
        
        WHILE v_i < v_servicio_count DO
            SET v_descripcion = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].descripcion'));
            SET v_cantidad = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal = v_cantidad * v_precio_unitario;
            
            INSERT INTO TblPresupuestoDetalle (
                id_presupuesto,
                tipo_item,
                descripcion,
                cantidad,
                cantidad_original,
                precio_unitario,
                subtotal
            ) VALUES (
                p_id_presupuesto,
                'SERVICIO',
                v_descripcion,
                v_cantidad,
                v_cantidad,
                v_precio_unitario,
                v_subtotal
            );
            
            SET v_monto_total = v_monto_total + v_subtotal;
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 5. Actualizar monto total (sin alterar campos de desglose)
        UPDATE TblPresupuesto SET monto_total = v_monto_total WHERE id_presupuesto = p_id_presupuesto;
        
        COMMIT;
    END;
END$$

-- ============================================================================
-- 3. Actualizar sp_ObtenerPresupuestoPDF
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoPDF$$

CREATE PROCEDURE sp_ObtenerPresupuestoPDF(
    IN p_id_presupuesto INT
)
READS SQL DATA
BEGIN
    -- Resultado 1: Información del presupuesto con desglose
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
        p.fecha_creacion,
        o.nombre as nombre_obra,
        pr.nombre as nombre_proyecto,
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
        'General' as categoria,
        'und' as unidad_medida,
        pd.cantidad,
        pd.precio_unitario,
        pd.subtotal
    FROM TblPresupuestoDetalle pd
    LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
    WHERE pd.id_presupuesto = p_id_presupuesto 
      AND pd.tipo_item = 'MATERIAL';
    
    -- Resultado 3: Servicios
    SELECT 
        pd.id_detalle,
        pd.descripcion as servicio_nombre,
        pd.cantidad,
        pd.precio_unitario,
        pd.subtotal
    FROM TblPresupuestoDetalle pd
    WHERE pd.id_presupuesto = p_id_presupuesto 
      AND pd.tipo_item = 'SERVICIO';
END$$

-- ============================================================================
-- 4. Actualizar sp_ObtenerPresupuestoEditar
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
        p.id_empresa,
        p.id_obra,
        p.monto_total,
        p.monto_aprobado,
        p.gastos_generales,
        p.utilidad,
        p.igv,
        p.supervision_obra,
        p.estado,
        p.observaciones,
        p.fecha_creacion,
        o.nombre as nombre_obra,
        o.id_proyecto,
        pr.nombre as nombre_proyecto,
        e.nombre as nombre_empresa
    FROM TblPresupuesto p
    LEFT JOIN TblObra o ON p.id_obra = o.id_obra
    LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
    LEFT JOIN TblEmpresa e ON p.id_empresa = e.id_empresa
    WHERE p.id_presupuesto = p_id_presupuesto;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ ACTUALIZACIÓN DE SPS COMPLETADA' as resultado;

-- Listar SPs actualizados
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_NAME IN (
      'sp_CrearPresupuestoCompleto',
      'sp_ActualizarPresupuestoCompleto',
      'sp_ObtenerPresupuestoPDF',
      'sp_ObtenerPresupuestoEditar'
  )
ORDER BY ROUTINE_NAME;

-- ============================================================================
