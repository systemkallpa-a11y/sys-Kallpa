-- ============================================================================
-- SCRIPT: Corregir longitudes corrompidas en TblEmpresa
-- DESCRIPCIÓN: Algunos registros tienen longitud con demasiados dígitos
-- FECHA: 20 de Julio de 2026
-- ============================================================================

-- PASO 1: Si tienes safe_updates activado, desactívalo:
SET SQL_SAFE_UPDATES = 0;

-- Ver datos actuales problemáticos
SELECT 'ANTES - Empresas con longitud inválida:' as paso;
SELECT id_empresa, nombre, latitud, longitud 
FROM TblEmpresa 
WHERE ABS(longitud) > 180 OR longitud IS NULL;

-- Corregir longitud: dividir por 10 si está fuera de rango
-- Ej: -771.00000000 → -77.1 (divide entre 10)
SELECT 'DESPUÉS - Corrigiendo coordenadas...' as paso;

UPDATE TblEmpresa 
SET longitud = ROUND(longitud / 10, 6)
WHERE longitud < -180 OR longitud > 180;

-- También corregir latitudes si las hay
UPDATE TblEmpresa 
SET latitud = ROUND(latitud / 10, 6)
WHERE latitud < -90 OR latitud > 90;

-- PASO 2: Reactivar safe_updates
SET SQL_SAFE_UPDATES = 1;

-- Verificar que ahora son válidas
SELECT 'VERIFICACIÓN - Longitudes corregidas:' as paso;
SELECT id_empresa, nombre, latitud, longitud,
       CASE 
           WHEN longitud >= -180 AND longitud <= 180 THEN '✓ VÁLIDA'
           ELSE '✗ AÚN INVÁLIDA'
       END as estado
FROM TblEmpresa
ORDER BY id_empresa;

-- Resumen
SELECT 'RESUMEN FINAL:' as paso;
SELECT 
    COUNT(*) as total_empresas,
    SUM(CASE WHEN longitud >= -180 AND longitud <= 180 THEN 1 ELSE 0 END) as longitudes_validas,
    SUM(CASE WHEN longitud < -180 OR longitud > 180 THEN 1 ELSE 0 END) as longitudes_invalidas,
    SUM(CASE WHEN latitud >= -90 AND latitud <= 90 THEN 1 ELSE 0 END) as latitudes_validas,
    SUM(CASE WHEN latitud < -90 OR latitud > 90 THEN 1 ELSE 0 END) as latitudes_invalidas
FROM TblEmpresa;
