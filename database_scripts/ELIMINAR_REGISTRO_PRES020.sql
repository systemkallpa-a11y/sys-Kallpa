-- ============================================================================
-- ELIMINAR REGISTRO DE APROBACIÓN HUÉRFANO DE PRES-020
-- ============================================================================
-- Problema: PRES-020 está ELIMINADO pero tiene registros PENDIENTES
-- Solución: Eliminar esos registros de TblRegistroAprobacion
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- 1. VERIFICAR qué se va a eliminar
SELECT 
    'ANTES DE ELIMINAR - Registro que se eliminará' as accion,
    ra.id_registro,
    p.numero_presupuesto,
    p.estado,
    ra.numero_paso,
    ra.estado_aprobacion,
    c.nombre as cargo
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 1
AND p.numero_presupuesto = 'PRES-020';

-- 2. ELIMINAR los registros de aprobación de PRES-020
DELETE ra
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
WHERE ra.id_tipo_documento = 1
AND p.numero_presupuesto = 'PRES-020';

-- 3. VERIFICAR que se eliminó
SELECT 
    'DESPUÉS DE ELIMINAR - Debería estar vacío' as accion,
    COUNT(*) as registros_restantes
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
WHERE ra.id_tipo_documento = 1
AND p.numero_presupuesto = 'PRES-020';

-- 4. ELIMINAR TODOS los registros de aprobación de presupuestos ELIMINADOS
-- (Esto limpia cualquier otro presupuesto eliminado que tenga registros huérfanos)
DELETE ra
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
WHERE ra.id_tipo_documento = 1
AND p.estado = 'ELIMINADO';

-- 5. VERIFICACIÓN FINAL
SELECT 
    '✅ LIMPIEZA COMPLETADA' as resultado,
    COUNT(*) as presupuestos_eliminados_con_registros
FROM TblRegistroAprobacion ra
INNER JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto
WHERE ra.id_tipo_documento = 1
AND p.estado = 'ELIMINADO';

SELECT '✅ Si el resultado anterior es 0, la limpieza fue exitosa' as mensaje;
