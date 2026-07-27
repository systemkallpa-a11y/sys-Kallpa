-- ============================================================================
-- Script: SP_CREAR_PRESUPUESTO_CON_DESGLOSE_AUTOMATICO.sql
-- Propósito: Crear SP que guarde presupuesto con desglose automático
-- 
-- Cálculos automáticos:
--   - gastos_generales = 10% del subtotal base
--   - utilidad = 15% del subtotal base
--   - igv = 18% del subtotal base
--   - supervision_obra = 5% del subtotal base
--
-- Fórmula:
--   monto_total = subtotal_base + (subtotal_base * 0.10 + 0.15 + 0.18 + 0.05)
--   monto_total = subtotal_base * 1.48
--
-- Fecha: 20 Julio 2026
-- ============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_CrearPresupuestoConDesgloseAutomatico$$

CREATE PROCEDURE sp_CrearPresupuestoConDesgloseAutomatico(
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
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_gastos_generales DECIMAL(12, 2);
    DECLARE v_utilidad DECIMAL(12, 2);
    DECLARE v_igv DECIMAL(12, 2);
    DECLARE v_supervision_obra DECIMAL(12, 2);
    DECLARE v_monto_total DECIMAL(12, 2);
    
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
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al crear presupuesto con desglose automático';
        END;
        
        -- 1. Generar número de presupuesto
        SELECT COUNT(*) + 1 INTO v_contador FROM TblPresupuesto;
        SET v_numero_presupuesto = CONCAT('PRES-', LPAD(v_contador, 4, '0'));
        
        -- 2. Calcular subtotal base primero (antes de insertar)
        SET v_material_count = JSON_LENGTH(p_materiales_json);
        SET v_i = 0;
        
        -- Sumar materiales
        WHILE v_i < v_material_count DO
            SET v_cantidad = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_materiales_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal_base = v_subtotal_base + (v_cantidad * v_precio_unitario);
            SET v_i = v_i + 1;
        END WHILE;
        
        -- Sumar servicios
        SET v_servicio_count = JSON_LENGTH(p_servicios_json);
        SET v_i = 0;
        
        WHILE v_i < v_servicio_count DO
            SET v_cantidad = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].cantidad'));
            SET v_precio_unitario = JSON_EXTRACT(p_servicios_json, CONCAT('$[', v_i, '].precio_unitario'));
            SET v_subtotal_base = v_subtotal_base + (v_cantidad * v_precio_unitario);
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 3. Calcular desglose automático
        -- gastos_generales = 10% del subtotal
        SET v_gastos_generales = v_subtotal_base * 0.10;
        
        -- utilidad = 15% del subtotal
        SET v_utilidad = v_subtotal_base * 0.15;
        
        -- igv = 18% del subtotal
        SET v_igv = v_subtotal_base * 0.18;
        
        -- supervision_obra = 5% del subtotal
        SET v_supervision_obra = v_subtotal_base * 0.05;
        
        -- monto_total = subtotal_base + (gastos + utilidad + igv + supervision)
        -- monto_total = subtotal_base + (subtotal_base * 0.48)
        SET v_monto_total = v_subtotal_base + v_gastos_generales + v_utilidad + v_igv + v_supervision_obra;
        
        -- 4. Insertar presupuesto CON desglose calculado
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
        
        SET v_id_presupuesto = LAST_INSERT_ID();
        SET p_id_presupuesto_created = v_id_presupuesto;
        
        -- 5. Insertar materiales desde JSON
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
            
            SET v_i = v_i + 1;
        END WHILE;
        
        -- 6. Insertar servicios desde JSON
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
            
            SET v_i = v_i + 1;
        END WHILE;
        
        COMMIT;
    END;
END$$

-- ============================================================================
-- ALIAS: sp_CrearPresupuestoCompleto apunta a este nuevo SP
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
    CALL sp_CrearPresupuestoConDesgloseAutomatico(
        p_id_empresa,
        p_id_obra,
        p_num_documento,
        p_comentarios,
        p_materiales_json,
        p_servicios_json,
        p_id_presupuesto_created
    );
END$$

-- ============================================================================
-- SP PARA ACTUALIZAR DESGLOSE (usado cuando se edita el presupuesto)
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ActualizarDesgloseAutomatico$$

CREATE PROCEDURE sp_ActualizarDesgloseAutomatico(
    IN p_id_presupuesto INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_subtotal_base DECIMAL(12, 2) DEFAULT 0;
    DECLARE v_gastos_generales DECIMAL(12, 2);
    DECLARE v_utilidad DECIMAL(12, 2);
    DECLARE v_igv DECIMAL(12, 2);
    DECLARE v_supervision_obra DECIMAL(12, 2);
    DECLARE v_monto_total DECIMAL(12, 2);
    
    -- Calcular subtotal base de los detalles actuales
    SELECT COALESCE(SUM(subtotal), 0)
    INTO v_subtotal_base
    FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Calcular desglose automático
    SET v_gastos_generales = v_subtotal_base * 0.10;
    SET v_utilidad = v_subtotal_base * 0.15;
    SET v_igv = v_subtotal_base * 0.18;
    SET v_supervision_obra = v_subtotal_base * 0.05;
    
    -- Calcular monto total
    SET v_monto_total = v_subtotal_base + v_gastos_generales + v_utilidad + v_igv + v_supervision_obra;
    
    -- Actualizar presupuesto
    UPDATE TblPresupuesto
    SET 
        gastos_generales = v_gastos_generales,
        utilidad = v_utilidad,
        igv = v_igv,
        supervision_obra = v_supervision_obra,
        monto_total = v_monto_total,
        fecha_actualizacion = NOW()
    WHERE id_presupuesto = p_id_presupuesto;
END$$

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✓ SP CREAR PRESUPUESTO CON DESGLOSE AUTOMÁTICO CREADO' as resultado;

-- Ejemplo de uso:
-- CALL sp_CrearPresupuestoConDesgloseAutomatico(
--     1,                              -- p_id_empresa
--     1,                              -- p_id_obra
--     12345678,                       -- p_num_documento
--     'Comentarios del presupuesto',  -- p_comentarios
--     '[{"id_material": 1, "cantidad": 10, "precio_unitario": 100}]', -- materiales
--     '[{"descripcion": "Servicio 1", "cantidad": 2, "precio_unitario": 500}]', -- servicios
--     @id_creado                      -- output
-- );
-- SELECT @id_creado;

-- ============================================================================
-- TABLA REFERENCIA DE CÁLCULOS
-- ============================================================================
/*
Ejemplo con Subtotal Base = S/. 1000

Gastos Generales:      1000 * 0.10 = S/.  100
Utilidad:              1000 * 0.15 = S/.  150
IGV:                   1000 * 0.18 = S/.  180
Supervisión de Obra:   1000 * 0.05 = S/.   50
                                      ─────────
Total a sumar:                        S/.  480

MONTO TOTAL = S/. 1000 + S/. 480 = S/. 1480

Factor multiplicador: 1.48
*/

-- ============================================================================
