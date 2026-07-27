-- ========================================================================
-- CONSULTA DE VERIFICACIÓN CORREGIDA - TASK 9
-- Usar después de crear requerimientos para verificar que id_material se insertó
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Query CORRECTA para verificar últimos requerimientos con unidades
SELECT 
    rd.id_detalle,
    rd.descripcion,
    rd.cantidad,
    rd.id_material,
    rd.tipo_item,
    m.nombre as nombre_material,
    m.descripcion as descripcion_material,
    um.nombre as nombre_unidad,
    um.abreviatura,
    um.codigo as codigo_unidad
FROM TblRequerimientoDetalle rd
LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
WHERE rd.id_requerimiento = (SELECT MAX(id_requerimiento) FROM TblRequerimiento)
ORDER BY rd.id_detalle DESC
LIMIT 10;

-- Verificar que no hay id_material en NULL (salvo servicios)
SELECT 
    'Verificación id_material' as verificacion,
    COUNT(*) as total_items,
    SUM(CASE WHEN id_material IS NULL THEN 1 ELSE 0 END) as items_sin_material,
    SUM(CASE WHEN id_material IS NOT NULL THEN 1 ELSE 0 END) as items_con_material
FROM TblRequerimientoDetalle rd
WHERE rd.id_requerimiento = (SELECT MAX(id_requerimiento) FROM TblRequerimiento);

-- Ver los últimos 5 requerimientos creados
SELECT 
    r.id_requerimiento,
    r.codigo,
    r.descripcion,
    r.estado,
    r.fecha_creacion,
    COUNT(rd.id_detalle) as cantidad_items
FROM TblRequerimiento r
LEFT JOIN TblRequerimientoDetalle rd ON r.id_requerimiento = rd.id_requerimiento
WHERE r.fecha_creacion >= CURDATE() - INTERVAL 1 DAY
GROUP BY r.id_requerimiento
ORDER BY r.id_requerimiento DESC
LIMIT 5;