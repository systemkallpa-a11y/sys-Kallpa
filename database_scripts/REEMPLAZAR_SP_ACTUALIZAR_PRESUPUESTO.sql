-- ============================================================================
-- SCRIPT: Reemplazar SP ActualizarPresupuestoCompleto
-- DESCRIPCIÓN:
--   Elimina SP antiguo y crea el nuevo con:
--   1. Estado = PENDIENTE
--   2. DELETE de TblRegistroAprobacion
--   3. Reinicio de cantidad_consumida
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  Reemplazar SP: sp_ActualizarPresupuestoCompleto             ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: Eliminar SP antiguo
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Eliminando SP anterior' as paso;

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

SELECT '✓ SP anterior eliminado' as resultado;

-- ============================================================================
-- PASO 2: Crear SP NUEVO CON TODAS LAS CORRECCIONES
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Creando SP nuevo (con estado + aprobaciones)' as paso;

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
    
    -- Validar presupuesto existe
    IF NOT EXISTS (SELECT 1 FROM TblPresupuesto WHERE id_presupuesto = p_id_presupuesto) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Presupuesto no existe';
    END IF;
    
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
    -- PASO A: ACTUALIZAR PRESUPUESTO PRINCIPAL
    -- ========================================================================
    
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        monto = v_total_monto,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',  -- ⭐ ESTADO SIEMPRE PENDIENTE AL EDITAR
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO B: LIMPIAR REGISTROS DE APROBACIÓN
    -- ========================================================================
    
    DELETE FROM TblRegistroAprobacion
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO C: ELIMINAR DETALLES VIEJOS
    -- ========================================================================
    
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- ========================================================================
    -- PASO D: INSERTAR MATERIALES NUEVOS
    -- ========================================================================
    
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
        0,  -- ⭐ cantidad_consumida REINICIA A 0
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- ========================================================================
    -- PASO E: INSERTAR SERVICIOS NUEVOS
    -- ========================================================================
    
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
        0,  -- ⭐ cantidad_consumida REINICIA A 0
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
    
END$$

DELIMITER ;

SELECT '✓ SP sp_ActualizarPresupuestoCompleto recreado' as resultado;

-- ============================================================================
-- PASO 3: VERIFICACIÓN
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Verificación' as paso;

SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
     WHERE ROUTINE_NAME = 'sp_ActualizarPresupuestoCompleto' 
     AND ROUTINE_SCHEMA = DATABASE()) > 0,
    '✓ SP existe y está listo',
    '✗ ERROR: SP no se creó'
) as resultado;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ SP REEMPLAZADO EXITOSAMENTE                   ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CARACTERÍSTICAS DEL SP NUEVO:' as caracteristicas;
SELECT '  ✓ Cambia estado a PENDIENTE al editar' as car1;
SELECT '  ✓ Limpia TblRegistroAprobacion' as car2;
SELECT '  ✓ Reinicia cantidad_consumida a 0' as car3;
SELECT '  ✓ Recrea todos los detalles' as car4;
SELECT '';
SELECT 'PRÓXIMO: Intenta editar presupuesto de nuevo' as proximo;
