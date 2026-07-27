-- ============================================================================
-- SCRIPT MAESTRO: Implementar control de saldo en presupuestos
-- DESCRIPCIÓN: Ejecuta TODOS los scripts necesarios en orden correcto
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║     INICIANDO IMPLEMENTACIÓN DE CONTROL DE SALDO               ║';
SELECT '║              EN PRESUPUESTOS Y REQUERIMIENTOS                  ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: AGREGAR COLUMNAS A TblPresupuesto
-- ============================================================================
SELECT '';
SELECT '┌─ PASO 1: Agregando columnas de control a TblPresupuesto ─────┐';
SELECT '└────────────────────────────────────────────────────────────────┘';

ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_original INT 
COMMENT 'Cantidad total presupuestada (materiales + servicios)'
AFTER estado;

ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_consumida INT DEFAULT 0 
COMMENT 'Cantidad usada en requerimientos'
AFTER cantidad_original;

ALTER TABLE TblPresupuesto 
ADD COLUMN IF NOT EXISTS cantidad_saldo INT GENERATED ALWAYS AS (COALESCE(cantidad_original, 0) - COALESCE(cantidad_consumida, 0)) STORED 
COMMENT 'Saldo disponible = original - consumida'
AFTER cantidad_consumida;

ALTER TABLE TblPresupuesto 
ADD INDEX IF NOT EXISTS idx_cantidad_saldo (cantidad_saldo);

SELECT '✓ PASO 1 COMPLETADO: Columnas agregadas' as estado;

-- ============================================================================
-- PASO 2: CREAR TABLA DE AUDITORÍA
-- ============================================================================
SELECT '';
SELECT '┌─ PASO 2: Creando tabla de auditoría ─────────────────────────┐';
SELECT '└────────────────────────────────────────────────────────────────┘';

DROP TABLE IF EXISTS TblRequerimientoAuditoria;

CREATE TABLE TblRequerimientoAuditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro de auditoría',
    
    -- Referencias
    id_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuesto',
    id_requerimiento INT NOT NULL COMMENT 'FK a TblRequerimiento',
    
    -- Valores
    cantidad_requerida INT NOT NULL COMMENT 'Cantidad solicitada en el requerimiento',
    cantidad_anterior_consumida INT COMMENT 'Consumo antes de esta acción',
    cantidad_nueva_consumida INT COMMENT 'Consumo después de esta acción',
    saldo_anterior INT COMMENT 'Saldo antes de esta acción',
    saldo_nuevo INT COMMENT 'Saldo después de esta acción',
    
    -- Metadata
    accion VARCHAR(20) NOT NULL COMMENT 'CREAR, ACTUALIZAR, CANCELAR',
    num_usuario INT COMMENT 'Usuario que realizó la acción',
    observaciones LONGTEXT COMMENT 'Notas adicionales',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Cuándo se registró',
    
    -- Constraints
    CONSTRAINT fk_auditoria_presupuesto 
        FOREIGN KEY (id_presupuesto) 
        REFERENCES TblPresupuesto(id_presupuesto) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_requerimiento 
        FOREIGN KEY (id_requerimiento) 
        REFERENCES TblRequerimiento(id_requerimiento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_requerimiento (id_requerimiento),
    INDEX idx_accion (accion),
    INDEX idx_fecha_registro (fecha_registro)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Auditoría de cambios en requerimientos y saldos de presupuesto';

DROP VIEW IF EXISTS vw_requerimiento_auditoria;

CREATE VIEW vw_requerimiento_auditoria AS
SELECT 
    a.id_auditoria,
    a.fecha_registro,
    a.accion,
    a.id_presupuesto,
    a.id_requerimiento,
    a.cantidad_requerida,
    a.cantidad_anterior_consumida,
    a.cantidad_nueva_consumida,
    a.saldo_anterior,
    a.saldo_nuevo,
    a.num_usuario,
    r.codigo as requerimiento_codigo
FROM TblRequerimientoAuditoria a
LEFT JOIN TblRequerimiento r ON a.id_requerimiento = r.id_requerimiento;

SELECT '✓ PASO 2 COMPLETADO: Tabla y vista de auditoría creadas' as estado;

-- ============================================================================
-- PASO 3: CREAR SPs DE VALIDACIÓN
-- ============================================================================
SELECT '';
SELECT '┌─ PASO 3: Creando SPs de validación y auditoría ──────────────┐';
SELECT '└────────────────────────────────────────────────────────────────┘';

DROP PROCEDURE IF EXISTS sp_ValidarSaldoPresupuesto;

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
    
    SELECT cantidad_original, cantidad_consumida
    INTO v_cantidad_original, v_cantidad_consumida
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_cantidad_original IS NULL THEN
        SET p_permitido = FALSE;
        SET p_saldo_disponible = 0;
        SET p_mensaje = 'Presupuesto no existe';
    ELSE
        SET p_saldo_disponible = v_cantidad_original - v_cantidad_consumida;
        
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
    
    SELECT cantidad_consumida, cantidad_saldo
    INTO v_cantidad_consumida_anterior, v_saldo_anterior
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF p_accion = 'CREAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior - p_cantidad_requerida;
    ELSEIF p_accion = 'CANCELAR' THEN
        SET v_saldo_nuevo = v_saldo_anterior + p_cantidad_requerida;
    ELSE
        SET v_saldo_nuevo = v_saldo_anterior;
    END IF;
    
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

SELECT '✓ PASO 3 COMPLETADO: SPs de validación creados' as estado;

-- ============================================================================
-- PASO 4: VERIFICACIÓN FINAL
-- ============================================================================
SELECT '';
SELECT '┌─ PASO 4: Verificación final ──────────────────────────────────┐';
SELECT '└────────────────────────────────────────────────────────────────┘';

SELECT 'Nuevas columnas en TblPresupuesto:' as verificacion;
SHOW COLUMNS FROM TblPresupuesto WHERE Field LIKE 'cantidad%';

SELECT '' as linea;
SELECT 'Tabla TblRequerimientoAuditoria creada:' as verificacion;
SHOW TABLES LIKE 'TblRequerimientoAuditoria';

SELECT '' as linea;
SELECT 'Vista vw_requerimiento_auditoria creada:' as verificacion;
SHOW TABLES LIKE 'vw_requerimiento_auditoria';

SELECT '' as linea;
SELECT 'SPs creados:' as verificacion;
SHOW PROCEDURE STATUS WHERE Name IN ('sp_ValidarSaldoPresupuesto', 'sp_RegistrarAuditoriaRequerimiento');

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================
SELECT '';
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║                  ✓ IMPLEMENTACIÓN COMPLETADA                   ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'Cambios realizados:' as resumen;
SELECT '  1. ✓ Agregadas columnas de control a TblPresupuesto' as cambio1;
SELECT '       - cantidad_original (total presupuestado)' as cambio1a;
SELECT '       - cantidad_consumida (suma de requerimientos)' as cambio1b;
SELECT '       - cantidad_saldo (calculada automáticamente)' as cambio1c;
SELECT '';
SELECT '  2. ✓ Creada tabla TblRequerimientoAuditoria' as cambio2;
SELECT '       - Registra cada cambio en saldos' as cambio2a;
SELECT '       - Acciones: CREAR, ACTUALIZAR, CANCELAR' as cambio2b;
SELECT '';
SELECT '  3. ✓ Creados SPs de validación' as cambio3;
SELECT '       - sp_ValidarSaldoPresupuesto' as cambio3a;
SELECT '       - sp_RegistrarAuditoriaRequerimiento' as cambio3b;
SELECT '';
SELECT '  4. ✓ Creada vista vw_requerimiento_auditoria' as cambio4;
SELECT '';
SELECT 'PRÓXIMO PASO: Actualizar sp_CrearRequerimientoCompleto' as siguiente;
SELECT 'con validación de saldo' as siguiente_desc;
