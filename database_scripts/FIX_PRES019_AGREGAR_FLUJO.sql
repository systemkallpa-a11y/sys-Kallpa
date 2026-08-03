-- ==============================================================================
-- FIX: Agregar flujo de aprobación al PRES-019
-- ==============================================================================
-- El PRES-019 se creó sin registros en TblRegistroAprobacion
-- Este script los agrega manualmente
-- ==============================================================================

USE kallpasystem$kallgwkn_kallpa_bd;

-- Verificar que el PRES-019 existe
SELECT 
    id_presupuesto,
    numero_presupuesto,
    estado,
    monto_total
FROM TblPresupuesto 
WHERE numero_presupuesto = 'PRES-019';

-- Agregar los registros de flujo de aprobación para el PRES-019
INSERT INTO TblRegistroAprobacion (
    id_tipo_documento,
    id_documento_referencia,
    numero_paso,
    id_cargo_aprobador,
    estado_aprobacion,
    fecha_asignacion
)
SELECT 
    fac.id_tipo_documento,
    (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-019'),
    fac.numero_paso,
    fac.id_cargo,
    'PENDIENTE',
    NOW()
FROM TblFlujoAprobacionCargos fac
WHERE fac.id_tipo_documento = 1  -- Presupuesto (ajusta si es diferente)
  AND fac.activo = 1
ORDER BY fac.numero_paso;

-- Verificar que se crearon los registros
SELECT 
    ra.id_registro,
    ra.id_tipo_documento,
    ra.numero_paso,
    ra.id_cargo_aprobador,
    c.nombre as cargo,
    ra.estado_aprobacion,
    ra.fecha_asignacion
FROM TblRegistroAprobacion ra
LEFT JOIN TblCargo c ON ra.id_cargo_aprobador = c.id_cargo
WHERE ra.id_documento_referencia = (SELECT id_presupuesto FROM TblPresupuesto WHERE numero_presupuesto = 'PRES-019')
  AND ra.id_tipo_documento = 1
ORDER BY ra.numero_paso;

-- ==============================================================================
-- FIN
-- ==============================================================================
