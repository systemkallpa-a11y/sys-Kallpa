-- ============================================================================
-- EJECUTAR TODOS LOS SPs DE REQUERIMIENTOS
-- ============================================================================
-- Este script crea/actualiza todos los Stored Procedures relacionados
-- con requerimientos en un solo paso.
--
-- INSTRUCCIONES:
-- 1. Abre MySQL Workbench
-- 2. Conecta a la base de datos: kallpasystem$kallgwkn_kallpa_bd
-- 3. Selecciona TODO este archivo (Ctrl+A)
-- 4. Ejecuta (Ctrl+Shift+Enter)
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ============================================================================
-- 1. SP_OBTENER_REQUERIMIENTO
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerRequerimiento(
    IN p_id_requerimiento INT
)
READS SQL DATA
BEGIN
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
        TRIM(CONCAT(
            COALESCE(p.nombres, ''), 
            ' ', 
            COALESCE(p.apellido_paterno, ''), 
            ' ', 
            COALESCE(p.apellido_materno, '')
        )) as usuario_completo,
        pr.numero_presupuesto
    FROM TblRequerimiento tr
    LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
    LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
    WHERE tr.id_requerimiento = p_id_requerimiento;
END$$

DELIMITER ;

SELECT '✅ sp_ObtenerRequerimiento creado' AS paso1;

-- ============================================================================
-- 2. SP_OBTENER_REQUERIMIENTO_DETALLES
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
        rd.observaciones,
        rd.fecha_creacion,
        COALESCE(m.nombre, '') as material_nombre,
        COALESCE(m.codigo_material, '') as material_codigo,
        COALESCE(um.nombre, '') as unidad_nombre,
        COALESCE(um.abreviatura, '') as unidad_abreviatura
    FROM TblRequerimientoDetalle rd
    LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
    WHERE rd.id_requerimiento = p_id_requerimiento
    ORDER BY rd.tipo_item DESC, rd.id_detalle;
END$$

DELIMITER ;

SELECT '✅ sp_ObtenerRequerimientoDetalles creado' AS paso2;

-- ============================================================================
-- 3. SP_ELIMINAR_REQUERIMIENTO
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_EliminarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_EliminarRequerimiento(
    IN p_id_requerimiento INT,
    OUT p_codigo VARCHAR(50),
    OUT p_detalles_eliminados INT,
    OUT p_aprobaciones_eliminadas INT,
    OUT p_presupuesto_reversado BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_requerimiento INT;
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_id_presupuesto INT;
    DECLARE v_cantidad_total DECIMAL(10,2);
    DECLARE v_error_msg VARCHAR(500);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('❌ ERROR: ', v_error_msg);
    END;
    
    START TRANSACTION;
    
    -- PASO 0: VALIDAR EXISTENCIA
    SELECT 
        id_requerimiento,
        codigo,
        id_presupuesto
    INTO 
        v_id_requerimiento,
        v_codigo,
        v_id_presupuesto
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_id_requerimiento IS NULL THEN
        SET p_mensaje = '❌ Requerimiento no encontrado';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Requerimiento no encontrado';
    END IF;
    
    SET p_codigo = v_codigo;
    SET p_presupuesto_reversado = FALSE;
    
    -- PASO 1: CALCULAR CANTIDAD TOTAL
    IF v_id_presupuesto IS NOT NULL THEN
        SELECT COALESCE(SUM(cantidad), 0)
        INTO v_cantidad_total
        FROM TblRequerimientoDetalle
        WHERE id_requerimiento = p_id_requerimiento;
    ELSE
        SET v_cantidad_total = 0;
    END IF;
    
    -- PASO 2: REVERSAR PRESUPUESTO
    IF v_id_presupuesto IS NOT NULL AND v_cantidad_total > 0 THEN
        UPDATE TblPresupuesto
        SET 
            cantidad_consumida = GREATEST(0, cantidad_consumida - v_cantidad_total),
            cantidad_saldo = cantidad_saldo + v_cantidad_total,
            monto_gastado = GREATEST(0, monto_gastado - v_cantidad_total),
            fecha_actualizacion = NOW()
        WHERE id_presupuesto = v_id_presupuesto;
        
        UPDATE TblPresupuestoDetalle pd
        INNER JOIN (
            SELECT 
                LOWER(TRIM(descripcion)) as descripcion_key,
                SUM(cantidad) as total_cantidad
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento
            GROUP BY LOWER(TRIM(descripcion))
        ) rd ON LOWER(TRIM(pd.descripcion)) = rd.descripcion_key
        SET 
            pd.cantidad_consumida = GREATEST(0, pd.cantidad_consumida - rd.total_cantidad),
            pd.cantidad_saldo = pd.cantidad - GREATEST(0, pd.cantidad_consumida - rd.total_cantidad),
            pd.fecha_actualizacion = NOW()
        WHERE pd.id_presupuesto = v_id_presupuesto;
        
        SET p_presupuesto_reversado = TRUE;
    END IF;
    
    -- PASO 3: ELIMINAR DETALLES
    DELETE FROM TblRequerimientoDetalle
    WHERE id_requerimiento = p_id_requerimiento;
    SET p_detalles_eliminados = ROW_COUNT();
    
    -- PASO 4: ELIMINAR APROBACIONES
    DELETE FROM TblRegistroAprobacion
    WHERE id_documento_referencia = p_id_requerimiento
    AND id_tipo_documento = 2;
    SET p_aprobaciones_eliminadas = ROW_COUNT();
    
    -- PASO 5: ELIMINAR REQUERIMIENTO
    DELETE FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    COMMIT;
    
    SET p_mensaje = CONCAT(
        '✅ Requerimiento ', v_codigo, ' eliminado completamente. ',
        'Detalles: ', p_detalles_eliminados, ', ',
        'Aprobaciones: ', p_aprobaciones_eliminadas, ', ',
        'Presupuesto reversado: ', IF(p_presupuesto_reversado, 'Sí', 'No')
    );
END$$

DELIMITER ;

SELECT '✅ sp_EliminarRequerimiento creado' AS paso3;

-- ============================================================================
-- 4. SP_APROBAR_REQUERIMIENTO
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_AprobarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_AprobarRequerimiento(
    IN p_id_requerimiento INT,
    IN p_num_documento_aprobador INT,
    IN p_comentario TEXT,
    OUT p_aprobacion_completa BOOLEAN,
    OUT p_mensaje VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_cargo INT;
    DECLARE v_id_registro INT;
    DECLARE v_total_pasos INT;
    DECLARE v_pasos_aprobados INT;
    DECLARE v_error_msg VARCHAR(500);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        SET p_mensaje = CONCAT('❌ ERROR: ', v_error_msg);
    END;
    
    START TRANSACTION;
    
    -- PASO 1: OBTENER CARGO
    SELECT id_cargo INTO v_id_cargo
    FROM TblUsuario
    WHERE num_documento = p_num_documento_aprobador 
    AND estado = 'Activo'
    LIMIT 1;
    
    IF v_id_cargo IS NULL THEN
        SET p_mensaje = '❌ Usuario no tiene cargo asignado o no está activo';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Usuario no tiene cargo asignado';
    END IF;
    
    -- PASO 2: VERIFICAR REGISTRO PENDIENTE
    SELECT ra.id_registro INTO v_id_registro
    FROM TblRegistroAprobacion ra
    WHERE ra.id_tipo_documento = 2
      AND ra.id_documento_referencia = p_id_requerimiento
      AND ra.id_cargo_aprobador = v_id_cargo
      AND ra.estado_aprobacion = 'PENDIENTE'
    LIMIT 1;
    
    IF v_id_registro IS NULL THEN
        SET p_mensaje = '❌ No tienes permiso para aprobar este requerimiento';
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No tienes permiso para aprobar este requerimiento';
    END IF;
    
    -- PASO 3: ACTUALIZAR A APROBADO
    UPDATE TblRegistroAprobacion 
    SET 
        estado_aprobacion = 'APROBADO',
        num_documento_aprobador = p_num_documento_aprobador,
        comentario = p_comentario,
        fecha_aprobacion = NOW()
    WHERE id_registro = v_id_registro;
    
    -- PASO 4: VERIFICAR SI TODOS APROBADOS
    SELECT 
        COUNT(*) as total_pasos,
        SUM(CASE WHEN estado_aprobacion = 'APROBADO' THEN 1 ELSE 0 END) as aprobados
    INTO v_total_pasos, v_pasos_aprobados
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2 
    AND id_documento_referencia = p_id_requerimiento;
    
    -- PASO 5: ACTUALIZAR ESTADO SI COMPLETO
    IF v_total_pasos = v_pasos_aprobados THEN
        UPDATE TblRequerimiento 
        SET 
            estado = 'APROBADO',
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        SET p_aprobacion_completa = TRUE;
        SET p_mensaje = CONCAT(
            '✅ Requerimiento COMPLETAMENTE APROBADO. ',
            'Todos los ', v_total_pasos, ' pasos fueron aprobados.'
        );
    ELSE
        SET p_aprobacion_completa = FALSE;
        SET p_mensaje = CONCAT(
            '✅ Paso aprobado. ',
            'Progreso: ', v_pasos_aprobados, '/', v_total_pasos, ' pasos aprobados.'
        );
    END IF;
    
    COMMIT;
END$$

DELIMITER ;

SELECT '✅ sp_AprobarRequerimiento creado' AS paso4;

-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================

SELECT '
╔═══════════════════════════════════════════════════════════════════════╗
║                    ✅ TODOS LOS SPs CREADOS                           ║
╚═══════════════════════════════════════════════════════════════════════╝
' AS RESUMEN;

SHOW PROCEDURE STATUS 
WHERE Db = 'kallpasystem$kallgwkn_kallpa_bd'
AND Name IN (
    'sp_ObtenerRequerimiento',
    'sp_ObtenerRequerimientoDetalles',
    'sp_EliminarRequerimiento',
    'sp_AprobarRequerimiento'
);
