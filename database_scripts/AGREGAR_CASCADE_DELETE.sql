-- ============================================================================
-- AGREGAR CASCADE DELETE A TblRegistroAprobacion
-- ============================================================================
-- Propósito: Cuando se elimine un presupuesto o requerimiento, automáticamente
--            eliminar sus registros de aprobación
-- Ventaja: No hay que modificar código, la BD lo maneja automáticamente
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Verificar constraints existentes
-- ============================================================================

SELECT 
    'CONSTRAINTS ACTUALES EN TblRegistroAprobacion' as info,
    CONSTRAINT_NAME,
    CONSTRAINT_TYPE,
    TABLE_NAME
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
AND TABLE_NAME = 'TblRegistroAprobacion';

-- Ver las foreign keys específicas
SELECT 
    'FOREIGN KEYS ACTUALES' as info,
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
AND TABLE_NAME = 'TblRegistroAprobacion'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- ============================================================================
-- PASO 2: Eliminar constraint existente si existe
-- ============================================================================
-- NOTA: Cambia el nombre del constraint según lo que veas en el resultado anterior

-- Ejemplo (ajusta según tu base de datos):
-- ALTER TABLE TblRegistroAprobacion DROP FOREIGN KEY fk_registro_presupuesto;

-- ============================================================================
-- PASO 3: Agregar nueva Foreign Key con CASCADE
-- ============================================================================

-- ⚠️ IMPORTANTE: Este enfoque NO funciona porque TblRegistroAprobacion 
--    puede apuntar a DIFERENTES tablas (Presupuesto O Requerimiento)
--    según id_tipo_documento
--
-- MySQL NO permite foreign keys condicionales
-- Por lo tanto, debemos usar la SOLUCIÓN 2: TRIGGERS

-- ============================================================================
-- MEJOR SOLUCIÓN: USAR TRIGGERS
-- ============================================================================

-- TRIGGER 1: Cuando se elimine un PRESUPUESTO
DROP TRIGGER IF EXISTS trg_eliminar_presupuesto_registros;

DELIMITER $$

CREATE TRIGGER trg_eliminar_presupuesto_registros
BEFORE DELETE ON TblPresupuesto
FOR EACH ROW
BEGIN
    -- Eliminar todos los registros de aprobación de este presupuesto
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 1
    AND id_documento_referencia = OLD.id_presupuesto;
END$$

DELIMITER ;

-- TRIGGER 2: Cuando se elimine un REQUERIMIENTO
DROP TRIGGER IF EXISTS trg_eliminar_requerimiento_registros;

DELIMITER $$

CREATE TRIGGER trg_eliminar_requerimiento_registros
BEFORE DELETE ON TblRequerimiento
FOR EACH ROW
BEGIN
    -- Eliminar todos los registros de aprobación de este requerimiento
    DELETE FROM TblRegistroAprobacion
    WHERE id_tipo_documento = 2
    AND id_documento_referencia = OLD.id_requerimiento;
END$$

DELIMITER ;

-- TRIGGER 3: Cuando un PRESUPUESTO cambie a estado ELIMINADO
DROP TRIGGER IF EXISTS trg_presupuesto_eliminado;

DELIMITER $$

CREATE TRIGGER trg_presupuesto_eliminado
AFTER UPDATE ON TblPresupuesto
FOR EACH ROW
BEGIN
    -- Si el estado cambió a ELIMINADO, eliminar registros de aprobación
    IF NEW.estado = 'ELIMINADO' AND OLD.estado <> 'ELIMINADO' THEN
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = 1
        AND id_documento_referencia = NEW.id_presupuesto;
    END IF;
END$$

DELIMITER ;

-- TRIGGER 4: Cuando un REQUERIMIENTO cambie a estado ELIMINADO
DROP TRIGGER IF EXISTS trg_requerimiento_eliminado;

DELIMITER $$

CREATE TRIGGER trg_requerimiento_eliminado
AFTER UPDATE ON TblRequerimiento
FOR EACH ROW
BEGIN
    -- Si el estado cambió a ELIMINADO, eliminar registros de aprobación
    IF NEW.estado = 'ELIMINADO' AND OLD.estado <> 'ELIMINADO' THEN
        DELETE FROM TblRegistroAprobacion
        WHERE id_tipo_documento = 2
        AND id_documento_referencia = NEW.id_requerimiento;
    END IF;
END$$

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT 
    '✅ TRIGGERS CREADOS' as resultado,
    TRIGGER_NAME,
    EVENT_MANIPULATION,
    EVENT_OBJECT_TABLE,
    ACTION_TIMING
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
AND TRIGGER_NAME LIKE 'trg_eliminar_%' OR TRIGGER_NAME LIKE 'trg_%_eliminado';

-- ============================================================================
-- PRUEBA (OPCIONAL - DESCOMENTA PARA PROBAR)
-- ============================================================================

/*
-- Crear presupuesto de prueba
INSERT INTO TblPresupuesto (id_empresa, numero_presupuesto, id_obra, num_documento, monto, estado)
VALUES (2, 'TEST-999', 2, 8, 100.00, 'PENDIENTE');

SET @test_id = LAST_INSERT_ID();

-- Crear registro de aprobación de prueba
INSERT INTO TblRegistroAprobacion (id_tipo_documento, id_documento_referencia, numero_paso, id_cargo_aprobador, estado_aprobacion, fecha_asignacion)
VALUES (1, @test_id, 1, 57, 'PENDIENTE', NOW());

-- Ver que se creó
SELECT 'ANTES DE ELIMINAR' as momento, COUNT(*) as registros
FROM TblRegistroAprobacion
WHERE id_tipo_documento = 1 AND id_documento_referencia = @test_id;

-- Eliminar presupuesto (debería eliminar registro automáticamente)
DELETE FROM TblPresupuesto WHERE id_presupuesto = @test_id;

-- Verificar que se eliminó automáticamente
SELECT 'DESPUÉS DE ELIMINAR' as momento, COUNT(*) as registros
FROM TblRegistroAprobacion
WHERE id_tipo_documento = 1 AND id_documento_referencia = @test_id;
*/

SELECT '✅ Triggers instalados - Los registros de aprobación se eliminarán automáticamente' as mensaje;
