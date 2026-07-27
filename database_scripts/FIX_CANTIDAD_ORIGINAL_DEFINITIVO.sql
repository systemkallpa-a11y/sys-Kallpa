-- ============================================================================
-- SCRIPT: FIX - Corregir cantidad_original en SP v3.0
-- DESCRIPCIÓN: 
--   El SP anterior asignaba dos valores a v_cantidad_original
--   Ahora se asigna correctamente a 4 variables diferentes
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  FIX: Corregir cantidad_original - SP v3.0 FINAL             ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: VERIFICAR QUE CANTIDAD_ORIGINAL ESTÁ INICIALIZADA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Inicializar cantidad_original si es necesario' as paso;

SET SQL_SAFE_UPDATES = 0;

UPDATE TblPresupuestoDetalle
SET cantidad_original = COALESCE(cantidad_original, cantidad)
WHERE cantidad_original IS NULL OR cantidad_original = 0;

SET SQL_SAFE_UPDATES = 1;

SELECT 'Cantidad original inicializada' as resultado;

-- ============================================================================
-- PASO 2: RECREAR SP CON CORRECCIÓN (SIN ASIGNACIÓN DUPLICADA)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Recreando SP sp_CrearRequerimientoCompleto (FINAL CORRECCIÓN)' as paso;

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
    DECLARE v_cantidad_actual DECIMAL(10, 2);
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
        
        -- OBTENER DATOS ACTUALES DEL PRESUPUESTO
        -- ⭐ CORRECCIÓN: Asignar correctamente a 4 variables distintas
        SELECT 
            pd.cantidad,                                    -- cantidad actual
            COALESCE(pd.cantidad_original, pd.cantidad),   -- cantidad original (o cantidad si null)
            COALESCE(pd.cantidad_consumida, 0),            -- cantidad consumida
            COALESCE(pd.cantidad_saldo, 0)                 -- saldo actual
        INTO 
            v_cantidad_actual,                -- Variable 1: cantidad actual
            v_cantidad_original,              -- Variable 2: cantidad original
            v_cantidad_consumida_actual,      -- Variable 3: consumida
            v_saldo_anterior                  -- Variable 4: saldo anterior
        FROM TblPresupuestoDetalle pd
        WHERE pd.id_detalle = v_id_detalle;
        
        -- ⭐ CRÍTICO: Usar v_cantidad_original (no v_cantidad_actual) para calcular
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
            v_cantidad_editada,  -- ⭐ CANTIDAD EDITADA
            COALESCE(um.nombre, 'und'),
            NOW()
        FROM TblPresupuestoDetalle pd
        LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0
        LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
        WHERE pd.id_detalle = v_id_detalle;
        
        -- ACTUALIZAR cantidad_consumida Y cantidad_original EN TblPresupuestoDetalle
        -- ⭐ IMPORTANTE: Asegurar que cantidad_original tiene valor
        UPDATE TblPresupuestoDetalle
        SET 
            cantidad_original = COALESCE(cantidad_original, v_cantidad_actual),
            cantidad_consumida = v_nueva_cantidad_consumida,
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

SELECT '✓ SP sp_CrearRequerimientoCompleto FINAL CORREGIDO' as resultado;

-- ============================================================================
-- PASO 3: VERIFICACIÓN
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Verificación' as paso;

SELECT 'Verificar que cantidad_original está con valores:' as verificacion;
SELECT 
    id_detalle,
    descripcion,
    cantidad,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo
FROM TblPresupuestoDetalle
WHERE id_detalle IN (50, 51)  -- Cambia estos números si es necesario
ORDER BY id_detalle;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ CORRECCIÓN APLICADA                           ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS:' as cambios;
SELECT '  ✓ Asignación correcta de variables en SP' as cambio1;
SELECT '  ✓ cantidad_original ahora inicializa correctamente' as cambio2;
SELECT '  ✓ Cálculo de saldo_nuevo usa cantidad_original (no actual)' as cambio3;
SELECT '';
SELECT 'PRÓXIMO: Ejecuta este script COMPLETO en MySQL' as proximo;
