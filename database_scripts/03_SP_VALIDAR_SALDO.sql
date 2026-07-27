-- ============================================================================
-- SCRIPT: Crear SP para validar saldo en presupuesto
-- DESCRIPCIÓN: Valida que hay suficiente saldo antes de crear requerimiento
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '========== CREANDO SP sp_ValidarSaldoPresupuesto ==========' as paso;

-- PASO 1: Eliminar SP si existe
SELECT 'PASO 1: Eliminando versión anterior' as paso;
DROP PROCEDURE IF EXISTS sp_ValidarSaldoPresupuesto;

-- PASO 2: Crear SP de validación
SELECT 'PASO 2: Creando SP' as paso;

DELIMITER $$

CREATE PROCEDURE sp_ValidarSaldoPresupuesto(
    IN p_id_presupuesto INT,
    IN p_cantidad_requerida INT,
    OUT p_saldo_disponible INT,
    OUT p_permitido BOOLEAN,
    OUT p_mensaje VARCHAR(255)
)
READS SQL DATA
BEGIN
    DECLARE v_cantidad_original INT;
    DECLARE v_cantidad_consumida INT;
    
    -- Verificar que el presupuesto existe
    SELECT cantidad_original, cantidad_consumida
    INTO v_cantidad_original, v_cantidad_consumida
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_cantidad_original IS NULL THEN
        SET p_permitido = FALSE;
        SET p_saldo_disponible = 0;
        SET p_mensaje = 'Presupuesto no existe';
    ELSE
        -- Calcular saldo disponible
        SET p_saldo_disponible = v_cantidad_original - v_cantidad_consumida;
        
        -- Validar si hay saldo suficiente
        IF p_saldo_disponible >= p_cantidad_requerida THEN
            SET p_permitido = TRUE;
            SET p_mensaje = CONCAT('Saldo suficiente. Disponible: ', p_saldo_disponible, ' und, Requerido: ', p_cantidad_requerida, ' und');
        ELSE
            SET p_permitido = FALSE;
            SET p_mensaje = CONCAT('SALDO INSUFICIENTE. Disponible: ', p_saldo_disponible, ' und, Requerido: ', p_cantidad_requerida, ' und');
        END IF;
    END IF;
    
END$$

DELIMITER ;

-- PASO 3: Crear SP para registrar en auditoría
SELECT 'PASO 3: Creando SP de auditoría' as paso;

DROP PROCEDURE IF EXISTS sp_RegistrarAuditoriaRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_RegistrarAuditoriaRequerimiento(
    IN p_id_presupuesto INT,
    IN p_id_requerimiento INT,
    IN p_cantidad_requerida INT,
    IN p_accion VARCHAR(20),
    IN p_num_usuario INT,
    OUT p_result INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_cantidad_consumida_anterior INT;
    DECLARE v_saldo_anterior INT;
    DECLARE v_saldo_nuevo INT;
    
    -- Obtener consumo anterior
    SELECT cantidad_consumida, cantidad_saldo
    INTO v_cantidad_consumida_anterior, v_saldo_anterior
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    -- Calcular nuevo saldo (depende de la acción)
    IF p_accion = 'CREAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior - p_cantidad_requerida;
    ELSEIF p_accion = 'CANCELAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior + p_cantidad_requerida;
    ELSE
        SET v_saldo_nuevo = v_saldo_anterior;
    END IF;
    
    -- Registrar en auditoría
    INSERT INTO TblRequerimientoAuditoria (
        id_presupuesto,
        id_requerimiento,
        cantidad_requerida,
        cantidad_anterior_consumida,
        cantidad_nueva_consumida,
        saldo_anterior,
        saldo_nuevo,
        accion,
        num_usuario,
        fecha_registro
    ) VALUES (
        p_id_presupuesto,
        p_id_requerimiento,
        p_cantidad_requerida,
        v_cantidad_consumida_anterior,
        CASE 
            WHEN p_accion = 'CREAR' THEN v_cantidad_consumida_anterior + p_cantidad_requerida
            WHEN p_accion = 'CANCELAR' THEN v_cantidad_consumida_anterior - p_cantidad_requerida
            ELSE v_cantidad_consumida_anterior
        END,
        v_saldo_anterior,
        v_saldo_nuevo,
        p_accion,
        p_num_usuario,
        NOW()
    );
    
    SET p_result = 1;
    
END$$

DELIMITER ;

-- PASO 4: Verificar SPs creados
SELECT 'PASO 4: Verificando SPs' as paso;
SHOW PROCEDURE STATUS WHERE Name IN ('sp_ValidarSaldoPresupuesto', 'sp_RegistrarAuditoriaRequerimiento');

-- PASO 5: Resumen
SELECT '========== SPs CREADOS EXITOSAMENTE ==========' as estado;
SELECT '' as linea;
SELECT 'SP sp_ValidarSaldoPresupuesto:' as sp1_nombre;
SELECT '  - Valida si hay saldo suficiente' as sp1_desc1;
SELECT '  - Retorna: saldo_disponible, permitido (BOOLEAN), mensaje' as sp1_desc2;
SELECT '' as linea;
SELECT 'SP sp_RegistrarAuditoriaRequerimiento:' as sp2_nombre;
SELECT '  - Registra cambios en auditoría' as sp2_desc1;
SELECT '  - Acciones: CREAR, ACTUALIZAR, CANCELAR' as sp2_desc2;
SELECT '  - Retorna: result (1 = éxito)' as sp2_desc3;
