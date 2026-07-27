-- ============================================================================
-- SCRIPT: Inicializar saldos en presupuestos existentes
-- DESCRIPCIÓN: Establece cantidad_original en presupuestos con saldo inicial
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '========== INICIALIZANDO SALDOS DE PRESUPUESTOS ==========' as paso;

-- PASO 1: Ver presupuestos sin cantidad_original
SELECT 'PASO 1: Presupuestos sin cantidad_original establecida' as paso;
SELECT 
    id_presupuesto,
    numero_presupuesto,
    cantidad_original,
    cantidad_consumida,
    COALESCE(cantidad_saldo, 0) as cantidad_saldo
FROM TblPresupuesto
WHERE cantidad_original IS NULL OR cantidad_original = 0
LIMIT 10;

-- PASO 2: OPCIÓN A - Establecer cantidad_original automáticamente
-- (suma de cantidades en TblPresupuestoDetalle)
SELECT 'PASO 2A: Calculando cantidad_original desde detalles' as paso;

UPDATE TblPresupuesto p
SET cantidad_original = (
    SELECT COALESCE(SUM(cantidad), 0)
    FROM TblPresupuestoDetalle
    WHERE id_presupuesto = p.id_presupuesto
)
WHERE cantidad_original IS NULL OR cantidad_original = 0;

SELECT 'Actualizados los presupuestos con sus sumas' as resultado;

-- PASO 3: OPCIÓN B - Si quieres establecer manualmente valores específicos
-- (descomentar y modificar según necesites)

-- UPDATE TblPresupuesto 
-- SET cantidad_original = 150 
-- WHERE id_presupuesto = 1;
-- 
-- UPDATE TblPresupuesto 
-- SET cantidad_original = 200 
-- WHERE id_presupuesto = 2;

-- PASO 4: Ver presupuestos después de inicialización
SELECT 'PASO 4: Presupuestos después de inicialización' as paso;
SELECT 
    id_presupuesto,
    numero_presupuesto,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo,
    estado
FROM TblPresupuesto
ORDER BY id_presupuesto DESC
LIMIT 10;

-- PASO 5: Verificar integridad
SELECT 'PASO 5: Verificación de integridad' as paso;
SELECT 
    id_presupuesto,
    numero_presupuesto,
    CASE 
        WHEN cantidad_original IS NULL THEN '✗ cantidad_original NULA'
        WHEN cantidad_original = 0 THEN '✗ cantidad_original = 0'
        ELSE '✓ cantidad_original OK'
    END as estado_original,
    CASE 
        WHEN cantidad_consumida IS NULL THEN '✗ cantidad_consumida NULA'
        ELSE '✓ cantidad_consumida OK'
    END as estado_consumida,
    CASE 
        WHEN cantidad_saldo IS NULL THEN '✗ cantidad_saldo NULA'
        ELSE '✓ cantidad_saldo OK'
    END as estado_saldo
FROM TblPresupuesto;

SELECT '========== INICIALIZACIÓN COMPLETADA ==========' as estado;
SELECT 'Todos los presupuestos tienen cantidad_original establecida' as mensaje;
SELECT '' as linea;
SELECT 'Recuerda: cantidad_saldo = cantidad_original - cantidad_consumida' as formula;
