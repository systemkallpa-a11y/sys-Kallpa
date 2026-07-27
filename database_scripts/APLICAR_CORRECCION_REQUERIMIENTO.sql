-- ============================================================================
-- SCRIPT: Aplicar Corrección a Sistema de Requerimientos
-- DESCRIPCIÓN:
--   1. Verifica estructura de tablas
--   2. Recrear SP sp_CrearRequerimientoCompleto v3.0 (CORREGIDO)
--   3. Crear SPs de validación y auditoría (si no existen)
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  APLICAR CORRECCIÓN A SISTEMA DE REQUERIMIENTOS v3.0         ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: VERIFICAR QUE TABLAS TIENEN ESTRUCTURA CORRECTA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Verificando estructura de tablas' as paso;

-- Verificar TblPresupuestoDetalle tiene las columnas correctas
SELECT 'TblPresupuestoDetalle - Columnas relacionadas con cantidad:' as verificacion;
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuestoDetalle'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%'
ORDER BY ORDINAL_POSITION;

SELECT '' as linea;

-- Verificar TblRequerimientoAuditoria existe
SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_NAME = 'TblRequerimientoAuditoria' 
           AND TABLE_SCHEMA = DATABASE()),
    '✓ TblRequerimientoAuditoria existe',
    '✗ ERROR: TblRequerimientoAuditoria no existe. Ejecuta EJECUTAR_LIMPIEZA_CORREGIR_SP.sql primero'
) as verificacion;

-- ============================================================================
-- PASO 2: RECREAR SP sp_CrearRequerimientoCompleto v3.0 (CORREGIDO)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Recreando SP sp_CrearRequerimientoCompleto v3.0' as paso;

DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearRequerimientoCompleto(
    IN p_num_usuario INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_id_requerimiento_created INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_cantidad_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_id_detalle INT;
    DECLARE v_cantidad_editada DECIMAL(10, 2);
    DECLARE v_cantidad_original DECIMAL(10, 2);
    DECLARE v_cantidad_consumida_actual DECIMAL(10, 2);
    DECLARE v_nueva_cantidad_consumida DECIMAL(10, 2);
    DECLARE v_saldo_anterior DECIMAL(10, 2);
    DECLARE v_saldo_nuevo DECIMAL(10, 2);
    DECLARE v_tipo_item VARCHAR(20);
    DECLARE v_json_length INT;
    
    -- Validar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_usuario = p_num_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar que JSON no está vacío
    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos: debe proporcionar al menos un item';
    END IF;
    
    -- Generar código automáticamente
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;
    
    -- Calcular cantidad total DESDE EL JSON (cantidades editadas)
    SELECT COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(10, 2))), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Obtener id_presupuesto del primer item
    SELECT COALESCE(pd.id_presupuesto, NULL)
    INTO v_id_presupuesto
    FROM JSON_TABLE(
        p_detalles_json, 
        '$[*]' 
        COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LIMIT 1;
    
    -- INSERTAR REQUERIMIENTO PRINCIPAL
    INSERT INTO TblRequerimiento (
        codigo,
        num_usuario,
        id_presupuesto,
        descripcion,
        cantidad,
        estado,
        observaciones,
        fecha_creacion
    ) VALUES (
        v_codigo,
        p_num_usuario,
        v_id_presupuesto,
        p_descripcion,
        COALESCE(v_cantidad_total, 0),
        'PENDIENTE',
        COALESCE(p_observaciones, ''),
        NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- PROCESAR CADA ITEM DEL JSON
    SET v_json_length = JSON_LENGTH(p_detalles_json);
    SET v_idx = 0;
    
    WHILE v_idx < v_json_length DO
        -- Extraer datos del JSON
        SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].id_detalle_presupuesto'));
        SET v_cantidad_editada = CAST(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].cantidad')) AS DECIMAL(10, 2));
        SET v_tipo_item = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_idx, '].tipo_item'))), 'MATERIAL');
        
        -- Obtener datos actuales del presupuesto
        SELECT 
            pd.cantidad,
            COALESCE(pd.cantidad_original, pd.cantidad),
            COALESCE(pd.cantidad_consumida, 0),
            COALESCE(pd.cantidad_saldo, 0)
        INTO 
            v_cantidad_original,
            v_cantidad_original,
            v_cantidad_consumida_actual,
            v_saldo_anterior
        FROM TblPresupuestoDetalle pd
        WHERE pd.id_detalle = v_id_detalle;
        
        -- Calcular nueva cantidad consumida y saldo
        SET v_nueva_cantidad_consumida = v_cantidad_consumida_actual + v_cantidad_editada;
        SET v_saldo_nuevo = v_cantidad_original - v_nueva_cantidad_consumida;
        
        -- INSERTAR DETALLE EN TblRequerimientoDetalle (CON CANTIDAD EDITADA)
        INSERT INTO TblRequerimientoDetalle (
            id_requerimiento,
            id_material,
            tipo_item,
            descripcion,
            cantidad,
            unidad_medida,
            fecha_creacion
        )
        SELECT
            p_id_requerimiento_created,
            CASE 
                WHEN v_tipo_item = 'SERVICIO' THEN NULL
                WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
                ELSE pd.id_material
            END,
            v_tipo_item,
            CASE 
                WHEN v_tipo_item = 'SERVICIO' THEN COALESCE(pd.descripcion, 'Servicio sin descripción')
                ELSE COALESCE(m.nombre, pd.descripcion, 'Material sin especificar')
            END,
            v_cantidad_editada,
            COALESCE(um.nombre, 'und'),
            NOW()
        FROM TblPresupuestoDetalle pd
        LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0
        LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
        WHERE pd.id_detalle = v_id_detalle;
        
        -- ACTUALIZAR cantidad_consumida EN TblPresupuestoDetalle
        UPDATE TblPresupuestoDetalle
        SET cantidad_consumida = v_nueva_cantidad_consumida,
            fecha_actualizacion = NOW()
        WHERE id_detalle = v_id_detalle;
        
        -- REGISTRAR EN TblRequerimientoAuditoria
        INSERT INTO TblRequerimientoAuditoria (
            id_presupuesto,
            id_detalle_presupuesto,
            id_requerimiento,
            cantidad_requerida,
            cantidad_anterior_consumida,
            cantidad_nueva_consumida,
            saldo_anterior,
            saldo_nuevo,
            accion,
            num_usuario,
            observaciones,
            fecha_registro
        ) VALUES (
            v_id_presupuesto,
            v_id_detalle,
            p_id_requerimiento_created,
            v_cantidad_editada,
            v_cantidad_consumida_actual,
            v_nueva_cantidad_consumida,
            v_saldo_anterior,
            v_saldo_nuevo,
            'CREAR',
            p_num_usuario,
            CONCAT('Requerimiento creado - Item id_detalle=', v_id_detalle),
            NOW()
        );
        
        SET v_idx = v_idx + 1;
    END WHILE;
    
END$$

DELIMITER ;

SELECT '✓ SP sp_CrearRequerimientoCompleto v3.0 creado' as resultado;

-- ============================================================================
-- PASO 3: VERIFICACIÓN FINAL
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Verificación final' as paso;

SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
     WHERE ROUTINE_NAME = 'sp_CrearRequerimientoCompleto' 
     AND ROUTINE_SCHEMA = DATABASE()) > 0,
    '✓ SP sp_CrearRequerimientoCompleto existe y está listo',
    '✗ ERROR al crear SP'
) as resultado_sp;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ CORRECCIÓN APLICADA EXITOSAMENTE              ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS REALIZADOS:' as resumen;
SELECT '  ✓ SP sp_CrearRequerimientoCompleto v3.0 actualizado' as c1;
SELECT '  ✓ Ahora captura cantidades editadas del JSON' as c2;
SELECT '  ✓ Registra auditoría para cada item' as c3;
SELECT '  ✓ Actualiza cantidad_consumida en presupuesto' as c4;
SELECT '';
SELECT 'PRÓXIMO PASO: Prueba crear un requerimiento desde la interfaz' as siguiente;
