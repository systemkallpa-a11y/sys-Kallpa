-- ============================================================================
-- SCRIPT FINAL: Limpiar y Crear SP Correcto
-- DESCRIPCIÓN:
--   1. Eliminar SP anterior (sin importar qué versión esté)
--   2. Crear SOLO UNA versión correcta del SP
--   3. Verificar que funciona
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  LIMPIAR Y CREAR SP CORRECTO                                 ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: ELIMINAR SP ANTERIOR (SIN IMPORTAR VERSIÓN)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Eliminando SP anterior completamente' as paso;

DROP PROCEDURE IF EXISTS sp_ActualizarPresupuestoCompleto;

SELECT '✓ SP anterior eliminado' as resultado;

-- ============================================================================
-- PASO 2: CREAR SP NUEVO (VERSIÓN ÚNICA Y CORRECTA)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Creando SP ÚNICO y CORRECTO' as paso;

DELIMITER $$

CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_total_monto DECIMAL(12,2) DEFAULT 0;
    
    -- Paso 1: Calcular total de materiales
    SELECT COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Paso 2: Sumar servicios
    SELECT v_total_monto + COALESCE(SUM(
        CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12,2)) * 
        CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12,2))
    ), 0)
    INTO v_total_monto
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Paso 3: ACTUALIZAR PRESUPUESTO PRINCIPAL
    UPDATE TblPresupuesto
    SET
        id_empresa = p_id_empresa,
        id_obra = p_id_obra,
        monto = v_total_monto,
        observaciones = p_comentarios,
        estado = 'PENDIENTE',
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Paso 4: LIMPIAR REGISTROS DE APROBACIÓN
    DELETE FROM TblRegistroAprobacion
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Paso 5: ELIMINAR DETALLES VIEJOS
    DELETE FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Paso 6: INSERTAR MATERIALES NUEVOS
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
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- Paso 7: INSERTAR SERVICIOS NUEVOS
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
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12,2)) * 
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12,2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
    
END$$

DELIMITER ;

SELECT '✓ SP sp_ActualizarPresupuestoCompleto creado' as resultado;

-- ============================================================================
-- PASO 3: VERIFICACIÓN
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Verificación final' as paso;

SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
     WHERE ROUTINE_NAME = 'sp_ActualizarPresupuestoCompleto' 
     AND ROUTINE_SCHEMA = DATABASE() 
     AND ROUTINE_TYPE = 'PROCEDURE') > 0,
    '✓ SP EXISTE Y ESTÁ LISTO',
    '✗ ERROR: SP NO SE CREÓ'
) as resultado;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ SP LISTO PARA USAR                            ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'AHORA PUEDES:' as siguiente;
SELECT '  1. Editar un presupuesto en el navegador' as paso1;
SELECT '  2. El estado debe cambiar a PENDIENTE' as paso2;
SELECT '  3. Las aprobaciones deben limpiarse' as paso3;
