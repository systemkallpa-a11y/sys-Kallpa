-- ============================================================================
-- SCRIPT: Test completo del sistema de control de saldo
-- DESCRIPCIÓN: Valida que todo funciona correctamente
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║       TEST COMPLETO - CONTROL DE SALDO EN PRESUPUESTOS        ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- TEST 1: ESTRUCTURA DE TABLAS
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 1: VERIFICAR ESTRUCTURA DE TABLAS';
SELECT '═══════════════════════════════════════════════════════════════';

-- Verificar TblPresupuesto
SELECT 'Columnas de TblPresupuesto:' as test;
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%'
ORDER BY ORDINAL_POSITION;

-- Verificar TblRequerimientoAuditoria
SELECT '' as linea;
SELECT 'Tabla TblRequerimientoAuditoria existe:' as test;
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME = 'TblRequerimientoAuditoria'
        AND TABLE_SCHEMA = DATABASE()
    ),
    '✓ SÍ EXISTE',
    '✗ NO EXISTE'
) as resultado;

-- Verificar SPs
SELECT '' as linea;
SELECT 'SPs disponibles:' as test;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name LIKE '%Presupuesto%';

-- ============================================================================
-- TEST 2: DATOS INICIALES
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 2: VERIFICAR DATOS INICIALES';
SELECT '═══════════════════════════════════════════════════════════════';

SELECT 'Presupuestos con saldo:' as test;
SELECT 
    id_presupuesto,
    numero_presupuesto,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo
FROM TblPresupuesto
WHERE cantidad_original > 0
LIMIT 5;

-- ============================================================================
-- TEST 3: VALIDAR SALDO
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 3: VALIDAR SALDO (SP sp_ValidarSaldoPresupuesto)';
SELECT '═══════════════════════════════════════════════════════════════';

-- Obtener primer presupuesto con saldo
SELECT 'Ejecutando validación...' as test;

SET @saldo_disp = 0;
SET @permitido = FALSE;
SET @msg = '';

-- Usar ID de presupuesto real (asume que existe)
CALL sp_ValidarSaldoPresupuesto(
    1,      -- id_presupuesto - CAMBIAR SI NECESARIO
    50,     -- cantidad_requerida
    @saldo_disp,
    @permitido,
    @msg
);

SELECT @saldo_disp as 'Saldo disponible';
SELECT IF(@permitido, 'SÍ - Permitido', 'NO - Rechazado') as 'Permitido crear requerimiento de 50 und';
SELECT @msg as 'Mensaje';

-- ============================================================================
-- TEST 4: CREAR REQUERIMIENTO CON VALIDACIÓN
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 4: CREAR REQUERIMIENTO CON VALIDACIÓN';
SELECT '═══════════════════════════════════════════════════════════════';

SELECT 'Verificando datos antes de crear...' as test;

-- Ver estado inicial
SELECT 
    id_presupuesto,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo as 'Saldo antes'
FROM TblPresupuesto
WHERE id_presupuesto = 1
LIMIT 1;

-- Obtener usuario
SET @user_id = NULL;
SELECT num_usuario INTO @user_id FROM TblUsuario LIMIT 1;

SELECT CONCAT('Usuario a usar: ', COALESCE(@user_id, 'NO EXISTE')) as usuario;

-- Obtener item de presupuesto
SET @item_id = NULL;
SELECT id_detalle INTO @item_id FROM TblPresupuestoDetalle WHERE id_presupuesto = 1 LIMIT 1;

SELECT CONCAT('Item a usar: ', COALESCE(@item_id, 'NO EXISTE')) as item;

-- Si hay usuario e item, intentar crear
IF @user_id IS NOT NULL AND @item_id IS NOT NULL THEN
    SELECT 'Intentando crear requerimiento...' as test;
    
    SET @id_req = 0;
    
    -- Construir JSON
    SET @json = CONCAT('[{"id_detalle_presupuesto": ', @item_id, '}]');
    
    CALL sp_CrearRequerimientoCompleto(
        @user_id,
        'Test Validación Saldo',
        'Prueba de control de saldo',
        @json,
        @id_req
    );
    
    SELECT @id_req as 'Requerimiento creado';
    
    -- Ver estado después
    SELECT '' as linea;
    SELECT 'Estado después de crear:' as test;
    SELECT 
        id_presupuesto,
        cantidad_original,
        cantidad_consumida,
        cantidad_saldo as 'Saldo después'
    FROM TblPresupuesto
    WHERE id_presupuesto = 1;
    
ELSE
    SELECT '✗ No hay usuario o item disponible para probar' as error;
END IF;

-- ============================================================================
-- TEST 5: AUDITORÍA
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 5: VERIFICAR AUDITORÍA';
SELECT '═══════════════════════════════════════════════════════════════';

SELECT 'Últimos registros de auditoría:' as test;
SELECT 
    id_auditoria,
    fecha_registro,
    accion,
    id_presupuesto,
    cantidad_requerida,
    saldo_anterior,
    saldo_nuevo
FROM TblRequerimientoAuditoria
ORDER BY fecha_registro DESC
LIMIT 10;

-- ============================================================================
-- TEST 6: VISTA DE AUDITORÍA
-- ============================================================================
SELECT '';
SELECT '═══════════════════════════════════════════════════════════════';
SELECT 'TEST 6: VISTA vw_requerimiento_auditoria';
SELECT '═══════════════════════════════════════════════════════════════';

SELECT 'Datos desde la vista:' as test;
SELECT 
    id_auditoria,
    fecha_registro,
    accion,
    requerimiento_codigo,
    cantidad_requerida,
    saldo_anterior,
    saldo_nuevo
FROM vw_requerimiento_auditoria
ORDER BY fecha_registro DESC
LIMIT 5;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================
SELECT '';
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║                     RESUMEN DE TESTS                          ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

SELECT 'Verificación de componentes:' as verificacion;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='TblPresupuesto' AND COLUMN_NAME='cantidad_original')
        THEN '✓ cantidad_original en TblPresupuesto'
        ELSE '✗ FALTA cantidad_original'
    END as componente1;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='TblPresupuesto' AND COLUMN_NAME='cantidad_consumida')
        THEN '✓ cantidad_consumida en TblPresupuesto'
        ELSE '✗ FALTA cantidad_consumida'
    END as componente2;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='TblRequerimientoAuditoria')
        THEN '✓ TblRequerimientoAuditoria existe'
        ELSE '✗ FALTA TblRequerimientoAuditoria'
    END as componente3;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='sp_ValidarSaldoPresupuesto')
        THEN '✓ sp_ValidarSaldoPresupuesto existe'
        ELSE '✗ FALTA sp_ValidarSaldoPresupuesto'
    END as componente4;

SELECT 
    CASE 
        WHEN EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='sp_CrearRequerimientoCompleto')
        THEN '✓ sp_CrearRequerimientoCompleto existe'
        ELSE '✗ FALTA sp_CrearRequerimientoCompleto'
    END as componente5;

SELECT '' as linea;
SELECT '✓ TODOS LOS TESTS COMPLETADOS' as estado_final;
