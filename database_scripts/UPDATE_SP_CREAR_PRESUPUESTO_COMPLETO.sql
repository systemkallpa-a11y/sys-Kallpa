-- ============================================================================
-- Script: UPDATE_SP_CREAR_PRESUPUESTO_COMPLETO.sql
-- Propósito: Actualizar SP existente con cálculos automáticos de desglose
-- 
-- Cambios:
--   - Agregar cálculos de gastos_generales (10% del total)
--   - Agregar cálculos de utilidad (15% del total)
--   - Agregar cálculos de igv (18% del total)
--   - Agregar cálculos de supervision_obra (5% del total)
--   - Cambiar columna 'monto' a 'monto_total'
--
-- Fecha: 20 Julio 2026
-- ============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoCompleto$$

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE `sp_CrearPresupuestoCompleto`(
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
BEGIN
    DECLARE v_numero_presupuesto VARCHAR(50);
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_gastos_generales DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_utilidad DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_igv DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_supervision_obra DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_monto_total DECIMAL(12, 2) DEFAULT 0;
    
    -- ========================================================================
    -- 1. Generar número de presupuesto automáticamente
    -- ========================================================================
    SELECT CONCAT('PRES-', LPAD(COALESCE(MAX(CAST(SUBSTRING(numero_presupuesto, 6) AS UNSIGNED)), 0) + 1, 3, '0'))
    INTO v_numero_presupuesto
    FROM TblPresupuesto
    WHERE numero_presupuesto LIKE 'PRES-%';
    
    -- ========================================================================
    -- 2. Calcular subtotal base (materiales + servicios)
    -- ========================================================================
    
    -- Calcular total de materiales
    SELECT COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12, 2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12, 2))), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- Sumar servicios
    SELECT v_subtotal_base + COALESCE(SUM(CAST(JSON_EXTRACT(item, '$.cantidad') AS DECIMAL(12, 2)) * CAST(JSON_EXTRACT(item, '$.precio_unitario') AS DECIMAL(12, 2))), 0)
    INTO v_subtotal_base
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
    
    -- ========================================================================
    -- 3. Calcular desglose automático (porcentajes del subtotal base)
    -- ========================================================================
    SET v_gastos_generales = ROUND(v_subtotal_base * 0.10, 2);      -- 10%
    SET v_utilidad = ROUND(v_subtotal_base * 0.15, 2);              -- 15%
    SET v_igv = ROUND(v_subtotal_base * 0.18, 2);                   -- 18%
    SET v_supervision_obra = ROUND(v_subtotal_base * 0.05, 2);      -- 5%
    
    -- Calcular monto total
    SET v_monto_total = v_subtotal_base + v_gastos_generales + v_utilidad + v_igv + v_supervision_obra;
    
    -- ========================================================================
    -- 4. Insertar presupuesto CON desglose calculado automáticamente
    -- ========================================================================
    INSERT INTO TblPresupuesto (
        id_empresa,
        numero_presupuesto,
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
        p_id_empresa,
        v_numero_presupuesto,
        p_id_obra,
        p_num_documento,
        v_monto_total,
        0,
        v_gastos_generales,
        v_utilidad,
        v_igv,
        v_supervision_obra,
        'PENDIENTE',
        p_comentarios,
        NOW()
    );
    
    SET p_id_presupuesto_created = LAST_INSERT_ID();
    
    -- ========================================================================
    -- 5. Insertar materiales
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
        p_id_presupuesto_created,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')) AS UNSIGNED),
        'MATERIAL',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_materiales_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_materiales_json) > 0;
    
    -- ========================================================================
    -- 6. Insertar servicios
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
        p_id_presupuesto_created,
        NULL,
        'SERVICIO',
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)),
        0,
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')) AS DECIMAL(12, 2)) * CAST(JSON_UNQUOTE(JSON_EXTRACT(item, '$.precio_unitario')) AS DECIMAL(12, 2)),
        NOW()
    FROM JSON_TABLE(p_servicios_json, '$[*]' COLUMNS (item JSON PATH '$')) jt
    WHERE JSON_LENGTH(p_servicios_json) > 0;
    
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ SP sp_CrearPresupuestoCompleto ACTUALIZADO CON DESGLOSE AUTOMÁTICO' as resultado;

-- ============================================================================
-- EJEMPLO DE CÁLCULO
-- ============================================================================
/*
EJEMPLO: Presupuesto con Subtotal Base = S/. 10,000

Cálculos automáticos (en el SP):
  Gastos Generales:      10,000 × 0.10 = S/.  1,000 (10%)
  Utilidad:              10,000 × 0.15 = S/.  1,500 (15%)
  IGV:                   10,000 × 0.18 = S/.  1,800 (18%)
  Supervisión de Obra:   10,000 × 0.05 = S/.    500 (5%)
                                          ─────────────
  Total a sumar:                          S/.  4,800

MONTO TOTAL = S/. 10,000 + S/. 4,800 = S/. 14,800

Factor multiplicador: 1.48
*/

-- ============================================================================
-- TABLAS DE REFERENCIA
-- ============================================================================

/*
Porcentajes configurados:
  - Gastos Generales:    10%
  - Utilidad:            15%
  - IGV:                 18%
  - Supervisión Obra:     5%
  ─────────────────────────
  TOTAL INCREMENTO:      48%

Si necesitas cambiar estos porcentajes, modifica los valores en el SP:
  - SET v_gastos_generales = ROUND(v_subtotal_base * 0.XX, 2);
  - SET v_utilidad = ROUND(v_subtotal_base * 0.XX, 2);
  - SET v_igv = ROUND(v_subtotal_base * 0.XX, 2);
  - SET v_supervision_obra = ROUND(v_subtotal_base * 0.XX, 2);
*/

-- ============================================================================
