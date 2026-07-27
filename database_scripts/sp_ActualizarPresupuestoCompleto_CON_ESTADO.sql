-- ============================================================================
-- STORED PROCEDURE: sp_ActualizarPresupuestoCompleto (MEJORADO)
-- DESCRIPCIÓN:
--   Cuando se edita un presupuesto:
--   1. Actualiza datos generales
--   2. Cambia ESTADO a PENDIENTE
--   3. Limpia registros de aprobación (TblRegistroAprobacion)
--   4. Recrea detalles (materiales y servicios)
-- VERSIÓN: 2.0
-- CAMBIOS:
--   ✓ Agregar SET estado = 'PENDIENTE'
--   ✓ DELETE FROM TblRegistroAprobacion donde id_presupuesto
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
BEGIN
    DECLARE v_total_monto DECIMAL(12,2) DEFAULT 0;
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- ========================================================================
    -- PASO 1: ACTUALIZAR PRESUPUESTO (AGREGAR ESTADO Y LIMPIAR APROBACIONES)
    -- ========================================================================
    
    -- Actualizar presupuesto principal
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        monto = v_total_monto,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',  -- ⭐ CAMBIAR A PENDIENTE
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO 2: LIMPIAR REGISTROS DE APROBACIÓN
    -- ========================================================================
    
    -- Eliminar aprobaciones anteriores (reiniciar flujo)
    DELETE FROM TblRegistroAprobacion
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO 3: ACTUALIZAR DETALLES (MATERIALES Y SERVICIOS)
    -- ========================================================================
    
    -- Eliminar detalles viejos
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Insertar materiales nuevos
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')) AS UNSIGNED),
        'MATERIAL',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,  -- ⭐ REINICIAR cantidad_consumida
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- Insertar servicios nuevos
    INSERT INTO TblPresupuestoDetalle (
        id_presupuesto,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        cantidad_original,
        cantidad_consumida,
        precio_unitario,
        subtotal,
        fecha_creacion
    )
    SELECT
        p_id_presupuesto,
        NULL,
        'SERVICIO',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)),
        0,  -- ⭐ REINICIAR cantidad_consumida
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
    
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ SP sp_ActualizarPresupuestoCompleto v2.0 recreado' as resultado;
SELECT '';
SELECT 'CAMBIOS IMPLEMENTADOS:' as cambios;
SELECT '  ✓ Estado = PENDIENTE cuando se edita' as cambio1;
SELECT '  ✓ TblRegistroAprobacion se limpia (flujo reinicia)' as cambio2;
SELECT '  ✓ cantidad_consumida = 0 (resetea requerimientos)' as cambio3;
