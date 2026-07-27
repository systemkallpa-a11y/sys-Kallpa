-- ========================================================================
-- PRUEBA: Verificar SP de flujo de requerimientos
-- Ejecutar en MySQL Workbench para verificar que el SP funciona
-- ========================================================================

USE kallgwkn_kallpa_bd;

-- Probar el SP con el requerimiento ID 41
CALL sp_ObtenerPasosFlujoRequerimiento(41);

-- También verificar manualmente los datos
SELECT 
    'VERIFICACION MANUAL' as info,
    fac.numero_paso,
    fac.nombre_paso,
    fac.id_cargo,
    c.nombre_cargo,
    fac.es_requerido,
    fac.activo
FROM TblFlujoAprobacionCargos fac
LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
WHERE fac.id_tipo_documento = 2  -- Requerimientos
  AND fac.activo = 1
ORDER BY fac.numero_paso ASC;

-- Verificar si hay registros de aprobación para el requerimiento 41
SELECT 
    'REGISTROS APROBACION' as info,
    ra.*
FROM TblRegistroAprobacion ra
WHERE ra.id_tipo_documento = 2
  AND ra.id_documento_referencia = 41;