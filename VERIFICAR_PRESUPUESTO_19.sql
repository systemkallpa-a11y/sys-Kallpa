-- ============================================================================
-- VERIFICAR: ¿Qué datos tiene el presupuesto #19?
-- ============================================================================

USE kallgwkn_kallpa_bd;

SELECT '🔍 VERIFICANDO PRESUPUESTO #19' AS DEBUG;

-- Ver datos completos del presupuesto #19
SELECT 
    id_presupuesto,
    numero_presupuesto,
    monto,
    monto_total,
    gastos_generales,
    utilidad,
    supervision_obra,
    igv,
    estado,
    observaciones
FROM TblPresupuesto 
WHERE id_presupuesto = 19;

-- Ver si la consulta que usa el backend devuelve los datos correctos
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    p.id_empresa,
    e.nombre as nombre_empresa,
    p.id_obra,
    p.num_documento,
    COALESCE(p.monto_total, 0) as monto_total,
    COALESCE(p.monto_aprobado, 0) as monto_aprobado,
    COALESCE(p.gastos_generales, 0) as gastos_generales,  -- ⭐ ESTE DEBE TENER VALOR
    COALESCE(p.utilidad, 0) as utilidad,                  -- ⭐ ESTE DEBE TENER VALOR
    COALESCE(p.igv, 0) as igv,                           -- ⭐ ESTE DEBE TENER VALOR
    COALESCE(p.supervision_obra, 0) as supervision_obra,  -- ⭐ ESTE DEBE TENER VALOR
    p.estado,
    p.observaciones,
    o.id_proyecto,
    o.nombre as nombre_obra,
    pr.nombre as nombre_proyecto
FROM TblPresupuesto p
LEFT JOIN TblEmpresa e ON p.id_empresa = e.id_empresa
LEFT JOIN TblObra o ON p.id_obra = o.id_obra
LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
WHERE p.id_presupuesto = 19;