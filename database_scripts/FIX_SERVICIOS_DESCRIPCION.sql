-- ============================================================================
-- SCRIPT: Corrección de servicios sin descripción
-- DESCRIPCIÓN: Actualiza servicios existentes que tienen observaciones NULL
-- FECHA: 2026-07-14
-- ============================================================================

-- Para servicios que tengan observaciones NULL, pero sabemos que "alquiler de auto" 
-- es el servicio, se puede actualizar manualmente o investigar cuál era la descripción.

-- Este script marca los servicios que tienen NULL en observaciones
SELECT 
    id_detalle,
    id_presupuesto,
    tipo_item,
    observaciones,
    cantidad,
    precio_unitario
FROM TblPresupuestoDetalle
WHERE tipo_item = 'SERVICIO' 
AND (observaciones IS NULL OR observaciones = '')
ORDER BY id_presupuesto;

-- Nota: Para corregir manualmente:
-- UPDATE TblPresupuestoDetalle
-- SET observaciones = 'alquiler de auto'
-- WHERE id_detalle = 29 AND tipo_item = 'SERVICIO';
