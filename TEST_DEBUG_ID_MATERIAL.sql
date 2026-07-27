-- ========================================================================
-- DEBUG: Verificar id_material en presupuestos
-- Ejecutar para ver si los presupuestos tienen id_material
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Ver si TblPresupuestoDetalle tiene id_material
SELECT 
    'PRESUPUESTO DETALLE' as info,
    pd.id_detalle,
    pd.descripcion,
    pd.id_material,
    pd.tipo_item,
    m.nombre as nombre_material
FROM TblPresupuestoDetalle pd
LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
WHERE pd.id_presupuesto = (
    SELECT id_presupuesto 
    FROM TblPresupuesto 
    ORDER BY id_presupuesto DESC 
    LIMIT 1
)
LIMIT 5;

-- Ver el último requerimiento creado
SELECT 
    'ULTIMO REQUERIMIENTO' as info,
    rd.id_detalle,
    rd.descripcion,
    rd.id_material,
    rd.tipo_item
FROM TblRequerimientoDetalle rd
WHERE rd.id_requerimiento = (
    SELECT MAX(id_requerimiento)
    FROM TblRequerimiento
);