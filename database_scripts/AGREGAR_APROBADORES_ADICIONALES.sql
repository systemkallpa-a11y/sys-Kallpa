-- ============================================================================
-- SCRIPT: Agregar aprobadores adicionales a los pasos
-- PROPÓSITO: Configurar múltiples cargos que puedan aprobar
-- FECHA: 17 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Ver cargos disponibles
-- ============================================================================

SELECT '===== Cargos disponibles en el sistema =====' as info;
SELECT id_cargo, nombre, descripcion FROM TblCargo ORDER BY nombre;

-- ============================================================================
-- PASO 2: Ver configuración actual
-- ============================================================================

SELECT '===== Configuración actual de aprobadores =====' as info;
SELECT 
    fa.id_flujo_aprobacion,
    td.nombre as Tipo_Documento,
    fa.numero_paso,
    fa.nombre_paso,
    GROUP_CONCAT(c.nombre SEPARATOR ' | ') as Cargos_Actuales,
    COUNT(*) as Cantidad_Cargos
FROM TblFlujoAprobacionCargos fc
JOIN TblFlujoAprobacion fa ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
JOIN TblTipoDocumentoAprobacion td ON fa.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
GROUP BY fa.id_flujo_aprobacion
ORDER BY td.nombre, fa.numero_paso;

-- ============================================================================
-- PASO 3: EJEMPLOS - Agregar aprobadores
-- ============================================================================

-- EJEMPLO 1: Agregar Gerente General como segundo aprobador para Requerimiento Paso 1
-- INSTRUCCIÓN: Descomenta y ejecuta si quieres usar este ejemplo

SELECT '===== EJEMPLO 1: Requerimiento Paso 1 =====' as ejemplo;

-- Obtener ID del flujo
SELECT @id_flujo := id_flujo_aprobacion
FROM TblFlujoAprobacion
WHERE id_tipo_documento = 2  -- Requerimiento
AND numero_paso = 1;

-- Ver si ya existe
SELECT 'Cargos actuales:' as info;
SELECT c.id_cargo, c.nombre
FROM TblFlujoAprobacionCargos fc
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.id_flujo_aprobacion = @id_flujo AND fc.activo = 1;

-- Agregar Gerente General (id_cargo = 13) con orden 1
-- INSERT IGNORE INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
-- SELECT @id_flujo, 13, 1
-- WHERE @id_flujo IS NOT NULL;

-- ============================================================================
-- PASO 4: TEMPLATE - Para agregar tus propios aprobadores
-- ============================================================================

SELECT '===== TEMPLATE: Cómo agregar aprobadores =====' as info;

/*
INSTRUCCIONES:
1. Reemplaza los valores [ID_FLUJO], [ID_CARGO] y [ORDEN] 
2. Descomenta el INSERT
3. Ejecuta

Ejemplo real:
  ID_FLUJO = 5 (Requerimiento Paso 1)
  ID_CARGO = 13 (Gerente General)
  ORDEN = 1 (mostrar en posición 1)

INSERT IGNORE INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
VALUES ([ID_FLUJO], [ID_CARGO], [ORDEN]);
*/

-- ============================================================================
-- PASO 5: SCRIPT RÁPIDO - Agregar múltiples aprobadores
-- ============================================================================

SELECT '===== Agregando aprobadores para Requerimiento =====' as info;

-- Requerimiento Paso 1: Coordinador Operaciones + Gerente General
SET @id_flujo_req_p1 = (SELECT id_flujo_aprobacion FROM TblFlujoAprobacion WHERE id_tipo_documento = 2 AND numero_paso = 1 LIMIT 1);

INSERT IGNORE INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
SELECT @id_flujo_req_p1, 13, 1  -- Gerente General
WHERE @id_flujo_req_p1 IS NOT NULL;

SELECT 'Paso 1: Agregado Gerente General' as resultado;

-- Requerimiento Paso 2: Gerente Compras + Gerente General
SET @id_flujo_req_p2 = (SELECT id_flujo_aprobacion FROM TblFlujoAprobacion WHERE id_tipo_documento = 2 AND numero_paso = 2 LIMIT 1);

INSERT IGNORE INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
SELECT @id_flujo_req_p2, 13, 1  -- Gerente General
WHERE @id_flujo_req_p2 IS NOT NULL;

SELECT 'Paso 2: Agregado Gerente General' as resultado;

-- ============================================================================
-- PASO 6: Verificar resultado
-- ============================================================================

SELECT '===== Configuración final =====' as info;
SELECT 
    td.nombre as Tipo_Documento,
    fa.numero_paso as Paso,
    fa.nombre_paso,
    GROUP_CONCAT(c.nombre SEPARATOR ' | ') as Cargos_Aprobadores,
    COUNT(*) as Total_Opciones
FROM TblFlujoAprobacionCargos fc
JOIN TblFlujoAprobacion fa ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
JOIN TblTipoDocumentoAprobacion td ON fa.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1
GROUP BY fa.id_flujo_aprobacion
ORDER BY td.nombre, fa.numero_paso;

SELECT '✅ Script completado' as estado;
