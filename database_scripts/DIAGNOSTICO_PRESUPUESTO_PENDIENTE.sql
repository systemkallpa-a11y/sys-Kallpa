-- ============================================================================
-- DIAGNÓSTICO: ¿Por qué sigue apareciendo 1 presupuesto pendiente?
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- 1. Ver TODOS los presupuestos con estado ELIMINADO que tienen registros PENDIENTES
SELECT 
    '1. PRESUPUESTOS ELIMINADOS CON REGISTROS PENDIENTES' as diagnostico,
    p.numero_presupuesto,
    p.estado as estado_presupuesto,
    ra.numero_paso,
    ra.estado_aprobacion,
    c.nombre as cargo_aprobador,
    ra.fecha_asignacion
FROM TblPresupuesto p
INNER JOIN TblRegistroAprobacion ra ON p.id_presupuesto = ra.id_documento_referencia
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 1
AND ra.estado_aprobacion = 'PENDIENTE'
AND p.estado = 'ELIMINADO'
ORDER BY ra.fecha_asignacion DESC;

-- 2. Ver TODOS los registros PENDIENTES para tu cargo (cargo 57)
SELECT 
    '2. REGISTROS PENDIENTES PARA CARGO 57' as diagnostico,
    ra.id_documento_referencia,
    ra.numero_paso,
    ra.estado_aprobacion,
    ra.id_tipo_documento,
    p.numero_presupuesto,
    p.estado as estado_presupuesto,
    ra.fecha_asignacion
FROM TblRegistroAprobacion ra
LEFT JOIN TblPresupuesto p ON ra.id_documento_referencia = p.id_presupuesto AND ra.id_tipo_documento = 1
WHERE ra.id_cargo_aprobador = 57
AND ra.estado_aprobacion = 'PENDIENTE'
ORDER BY ra.fecha_asignacion DESC;

-- 3. Ver si el SP sp_ObtenerDocumentosPendientesPorCargo existe y cuándo fue actualizado
SELECT 
    '3. VERIFICAR SP EXISTE' as diagnostico,
    ROUTINE_NAME,
    CREATED,
    LAST_ALTERED
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'kallpasystem$kallgwkn_kallpa_bd'
AND ROUTINE_NAME = 'sp_ObtenerDocumentosPendientesPorCargo';

-- 4. Ejecutar el SP directamente para cargo 16 y tipo documento 1 (Presupuestos)
CALL sp_ObtenerDocumentosPendientesPorCargo(16, 1);

-- 5. Ver qué retorna la consulta que usa el endpoint de notificaciones
-- (Esta es la consulta que usa /api/notificaciones/pendientes)
SELECT 
    '5. CONSULTA DEL ENDPOINT NOTIFICACIONES' as diagnostico,
    tda.id_tipo_documento,
    tda.nombre AS nombre_documento,
    COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
    fac.numero_paso,
    MIN(ra.fecha_asignacion) AS documento_mas_antiguo
FROM 
    TblTipoDocumentoAprobacion tda
INNER JOIN 
    TblFlujoAprobacionCargos fac ON tda.id_tipo_documento = fac.id_tipo_documento
INNER JOIN 
    TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
        AND ra.numero_paso = fac.numero_paso 
        AND ra.estado_aprobacion = 'PENDIENTE'
-- ⭐ VERIFICAR SI ESTOS JOINS ESTÁN APLICADOS
LEFT JOIN 
    TblPresupuesto p ON ra.id_tipo_documento = 1 AND ra.id_documento_referencia = p.id_presupuesto
LEFT JOIN 
    TblRequerimiento r ON ra.id_tipo_documento = 2 AND ra.id_documento_referencia = r.id_requerimiento
WHERE 
    fac.id_cargo = 16
    AND fac.activo = 1
    AND fac.es_requerido = 1
    AND tda.activo = 1
    AND tda.requiere_aprobacion = 1
    -- ⭐ VERIFICAR SI ESTE FILTRO ESTÁ APLICADO
    AND (
        (ra.id_tipo_documento = 1 AND p.id_presupuesto IS NOT NULL AND p.estado <> 'ELIMINADO')
        OR (ra.id_tipo_documento = 2 AND r.id_requerimiento IS NOT NULL AND r.estado <> 'ELIMINADO')
        OR (ra.id_tipo_documento NOT IN (1, 2))
    )
    AND NOT EXISTS (
        SELECT 1 
        FROM TblRegistroAprobacion ra_prev
        WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
          AND ra_prev.id_documento_referencia = ra.id_documento_referencia
          AND ra_prev.numero_paso < ra.numero_paso
          AND ra_prev.estado_aprobacion <> 'APROBADO'
    )
GROUP BY 
    tda.id_tipo_documento,
    tda.nombre,
    fac.numero_paso
ORDER BY 
    cantidad_pendientes DESC,
    documento_mas_antiguo ASC;

-- 6. Ver TODOS los presupuestos activos (no ELIMINADOS) con registros PENDIENTES
SELECT 
    '6. PRESUPUESTOS ACTIVOS CON REGISTROS PENDIENTES' as diagnostico,
    p.numero_presupuesto,
    p.estado as estado_presupuesto,
    p.monto,
    ra.numero_paso,
    ra.estado_aprobacion,
    c.nombre as cargo_aprobador,
    ra.fecha_asignacion
FROM TblPresupuesto p
INNER JOIN TblRegistroAprobacion ra ON p.id_presupuesto = ra.id_documento_referencia
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 1
AND ra.estado_aprobacion = 'PENDIENTE'
AND p.estado <> 'ELIMINADO'
AND ra.id_cargo_aprobador = 16
ORDER BY ra.fecha_asignacion DESC;

-- ============================================================================
-- INSTRUCCIONES:
-- ============================================================================
-- 1. Ejecuta este script completo en MySQL Workbench
-- 2. Copia TODOS los resultados aquí
-- 3. Eso me dirá exactamente qué está pasando
-- ============================================================================
