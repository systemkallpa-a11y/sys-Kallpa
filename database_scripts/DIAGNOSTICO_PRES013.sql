-- ============================================================================
-- DIAGNÓSTICO: ¿Por qué PRES-013 no cambia a APROBADO?
-- ============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- 1. Ver el presupuesto PRES-013
SELECT 
    '1. ESTADO ACTUAL DE PRES-013' as diagnostico,
    id_presupuesto,
    numero_presupuesto,
    estado,
    monto,
    fecha_creacion
FROM TblPresupuesto
WHERE numero_presupuesto = 'PRES-013';

-- 2. Ver los pasos del flujo configurados para Presupuestos (tipo 1)
SELECT 
    '2. FLUJO CONFIGURADO PARA PRESUPUESTOS' as diagnostico,
    fac.numero_paso,
    fac.id_cargo,
    c.nombre as cargo_nombre,
    fac.es_requerido,
    fac.es_final,
    fac.activo
FROM TblFlujoAprobacionCargos fac
INNER JOIN TblCargo c ON fac.id_cargo = c.id_cargo
WHERE fac.id_tipo_documento = 1
ORDER BY fac.numero_paso;

-- 3. Ver los registros de aprobación de PRES-013
SELECT 
    '3. REGISTROS DE APROBACIÓN DE PRES-013' as diagnostico,
    ra.numero_paso,
    ra.estado_aprobacion,
    ra.fecha_aprobacion,
    c.nombre as cargo_aprobador,
    ra.num_documento_aprobador
FROM TblRegistroAprobacion ra
INNER JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_tipo_documento = 1
AND ra.id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013')
ORDER BY ra.numero_paso;

-- 4. Contar pasos totales vs aprobados
SELECT 
    '4. CONTEO DE PASOS' as diagnostico,
    (SELECT COUNT(DISTINCT numero_paso) 
     FROM TblFlujoAprobacionCargos 
     WHERE id_tipo_documento = 1 
     AND es_requerido = 1 
     AND activo = 1) as pasos_totales,
    (SELECT COUNT(*) 
     FROM TblRegistroAprobacion 
     WHERE id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013')
     AND id_tipo_documento = 1 
     AND estado_aprobacion = 'APROBADO') as pasos_aprobados;

-- 5. Verificar cuál es el máximo paso y si coincide con el aprobado
SELECT 
    '5. VERIFICACIÓN DEL ÚLTIMO PASO' as diagnostico,
    (SELECT MAX(numero_paso) 
     FROM TblFlujoAprobacionCargos 
     WHERE id_tipo_documento = 1 
     AND es_requerido = 1 
     AND activo = 1) as max_paso_flujo,
    (SELECT MAX(numero_paso) 
     FROM TblRegistroAprobacion 
     WHERE id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013')
     AND id_tipo_documento = 1 
     AND estado_aprobacion = 'APROBADO') as max_paso_aprobado,
    (SELECT es_final 
     FROM TblFlujoAprobacionCargos 
     WHERE id_tipo_documento = 1 
     AND numero_paso = (SELECT MAX(numero_paso) 
                        FROM TblFlujoAprobacionCargos 
                        WHERE id_tipo_documento = 1 
                        AND es_requerido = 1 
                        AND activo = 1)) as es_final_ultimo_paso;

-- 6. Simular la lógica del SP
SELECT 
    '6. SIMULACIÓN DE LÓGICA DEL SP' as diagnostico,
    CASE 
        WHEN (SELECT MAX(numero_paso) FROM TblFlujoAprobacionCargos WHERE id_tipo_documento = 1 AND es_requerido = 1 AND activo = 1) = 
             (SELECT MAX(numero_paso) FROM TblRegistroAprobacion WHERE id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013') AND id_tipo_documento = 1 AND estado_aprobacion = 'APROBADO')
        THEN 'SÍ, es el último paso'
        ELSE 'NO, no es el último paso'
    END as es_ultimo_paso,
    CASE 
        WHEN (SELECT COUNT(DISTINCT numero_paso) FROM TblFlujoAprobacionCargos WHERE id_tipo_documento = 1 AND es_requerido = 1 AND activo = 1) = 
             (SELECT COUNT(*) FROM TblRegistroAprobacion WHERE id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-013') AND id_tipo_documento = 1 AND estado_aprobacion = 'APROBADO')
        THEN 'SÍ, todos aprobados'
        ELSE 'NO, faltan pasos'
    END as todos_aprobados;

-- ============================================================================
-- RESULTADO ESPERADO:
-- Si hay solo 1 paso configurado y está aprobado, debería cambiar a APROBADO
-- ============================================================================
