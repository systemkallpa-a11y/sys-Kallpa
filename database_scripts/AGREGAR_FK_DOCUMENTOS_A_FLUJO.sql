-- ============================================================================
-- SCRIPT: Agregar FK en TblPresupuesto y TblRequerimiento
-- PROPÓSITO: Enlace explícito entre documentos y flujo de aprobación
-- FECHA: 21 de Julio de 2026
-- VENTAJA: Integridad referencial en BD, no en backend
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: VERIFICAR ESTRUCTURA ACTUAL
-- ============================================================================

SELECT 'ANTES DE LOS CAMBIOS' as fase;

SELECT 
    'TblPresupuesto' as tabla,
    COLUMN_NAME as columna,
    COLUMN_TYPE as tipo,
    IS_NULLABLE as nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME IN ('id_presupuesto', 'id_tipo_documento', 'estado')
ORDER BY ORDINAL_POSITION;

SELECT 
    'TblRequerimiento' as tabla,
    COLUMN_NAME as columna,
    COLUMN_TYPE as tipo,
    IS_NULLABLE as nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblRequerimiento'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME IN ('id_requerimiento', 'id_tipo_documento', 'estado')
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- PASO 2: AGREGAR COLUMNA id_tipo_documento A TblPresupuesto
-- ============================================================================

SELECT 'PASO 2: Agregando id_tipo_documento a TblPresupuesto' as operacion;

-- Verificar si la columna ya existe
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'TblPresupuesto'
            AND COLUMN_NAME = 'id_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN 'Ya existe'
        ELSE 'No existe'
    END as estado;

-- Agregar columna si no existe
ALTER TABLE TblPresupuesto
ADD COLUMN IF NOT EXISTS id_tipo_documento INT DEFAULT 1 NOT NULL 
COMMENT 'Tipo de documento para flujo de aprobación (FK a TblTipoDocumentoAprobacion)';

SELECT '✅ Columna id_tipo_documento agregada a TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 3: AGREGAR COLUMNA id_tipo_documento A TblRequerimiento
-- ============================================================================

SELECT 'PASO 3: Agregando id_tipo_documento a TblRequerimiento' as operacion;

-- Verificar si la columna ya existe
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'TblRequerimiento'
            AND COLUMN_NAME = 'id_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN 'Ya existe'
        ELSE 'No existe'
    END as estado;

-- Agregar columna si no existe
ALTER TABLE TblRequerimiento
ADD COLUMN IF NOT EXISTS id_tipo_documento INT DEFAULT 2 NOT NULL 
COMMENT 'Tipo de documento para flujo de aprobación (FK a TblTipoDocumentoAprobacion)';

SELECT '✅ Columna id_tipo_documento agregada a TblRequerimiento' as resultado;

-- ============================================================================
-- PASO 4: VALIDAR DATOS ANTES DE AGREGAR FK
-- ============================================================================

SELECT 'PASO 4: Validando datos antes de agregar FK' as operacion;

-- Presupuestos: verificar que id_tipo_documento sea válido
SELECT 
    'TblPresupuesto - Validación' as validacion,
    p.id_tipo_documento,
    COUNT(*) as cantidad,
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM TblTipoDocumentoAprobacion t 
            WHERE t.id_tipo_documento = p.id_tipo_documento
        ) THEN '✅ VÁLIDO'
        ELSE '❌ INVÁLIDO'
    END as estado
FROM TblPresupuesto p
GROUP BY p.id_tipo_documento;

-- Requerimientos: verificar que id_tipo_documento sea válido
SELECT 
    'TblRequerimiento - Validación' as validacion,
    r.id_tipo_documento,
    COUNT(*) as cantidad,
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM TblTipoDocumentoAprobacion t 
            WHERE t.id_tipo_documento = r.id_tipo_documento
        ) THEN '✅ VÁLIDO'
        ELSE '❌ INVÁLIDO'
    END as estado
FROM TblRequerimiento r
GROUP BY r.id_tipo_documento;

-- Verificar que existan en TblTipoDocumentoAprobacion
SELECT 
    'TblTipoDocumentoAprobacion - Tipos disponibles' as tabla,
    id_tipo_documento,
    nombre
FROM TblTipoDocumentoAprobacion
ORDER BY id_tipo_documento;

-- ============================================================================
-- PASO 5: CORREGIR DATOS SI ES NECESARIO
-- ============================================================================

/*
Si hay presupuestos con id_tipo_documento inválido, ejecutar:

UPDATE TblPresupuesto
SET id_tipo_documento = 1
WHERE id_tipo_documento NOT IN (SELECT id_tipo_documento FROM TblTipoDocumentoAprobacion);

UPDATE TblRequerimiento
SET id_tipo_documento = 2
WHERE id_tipo_documento NOT IN (SELECT id_tipo_documento FROM TblTipoDocumentoAprobacion);
*/

-- ============================================================================
-- PASO 6: AGREGAR FK A TblPresupuesto
-- ============================================================================

SELECT 'PASO 6: Agregando FK a TblPresupuesto' as operacion;

-- Eliminar FK anterior si existe
ALTER TABLE TblPresupuesto
DROP FOREIGN KEY IF EXISTS fk_presupuesto_tipo_documento;

-- Agregar FK
ALTER TABLE TblPresupuesto
ADD CONSTRAINT fk_presupuesto_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT
ON UPDATE CASCADE;

SELECT '✅ FK agregado a TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 7: AGREGAR FK A TblRequerimiento
-- ============================================================================

SELECT 'PASO 7: Agregando FK a TblRequerimiento' as operacion;

-- Eliminar FK anterior si existe
ALTER TABLE TblRequerimiento
DROP FOREIGN KEY IF EXISTS fk_requerimiento_tipo_documento;

-- Agregar FK
ALTER TABLE TblRequerimiento
ADD CONSTRAINT fk_requerimiento_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT
ON UPDATE CASCADE;

SELECT '✅ FK agregado a TblRequerimiento' as resultado;

-- ============================================================================
-- PASO 8: VERIFICAR FK CREADOS
-- ============================================================================

SELECT 'PASO 8: Verificando FK creados' as operacion;

SELECT 
    'TblPresupuesto' as tabla,
    CONSTRAINT_NAME as nombre_fk,
    COLUMN_NAME as columna_local,
    REFERENCED_TABLE_NAME as tabla_referenciada,
    REFERENCED_COLUMN_NAME as columna_referenciada
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME = 'id_tipo_documento'
AND REFERENCED_TABLE_NAME IS NOT NULL;

SELECT 
    'TblRequerimiento' as tabla,
    CONSTRAINT_NAME as nombre_fk,
    COLUMN_NAME as columna_local,
    REFERENCED_TABLE_NAME as tabla_referenciada,
    REFERENCED_COLUMN_NAME as columna_referenciada
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME = 'id_tipo_documento'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- ============================================================================
-- PASO 9: VISUALIZAR RELACIONES COMPLETAS
-- ============================================================================

SELECT 'PASO 9: Relaciones entre tablas' as operacion;

SELECT 
    'TblPresupuesto' as documento,
    COUNT(DISTINCT p.id_presupuesto) as cantidad,
    p.id_tipo_documento,
    t.nombre as tipo_documento,
    COUNT(DISTINCT f.id_flujo_cargo) as pasos_configurados
FROM TblPresupuesto p
LEFT JOIN TblTipoDocumentoAprobacion t ON p.id_tipo_documento = t.id_tipo_documento
LEFT JOIN TblFlujoAprobacionCargos f ON f.id_tipo_documento = p.id_tipo_documento
GROUP BY p.id_tipo_documento, t.nombre;

SELECT 
    'TblRequerimiento' as documento,
    COUNT(DISTINCT r.id_requerimiento) as cantidad,
    r.id_tipo_documento,
    t.nombre as tipo_documento,
    COUNT(DISTINCT f.id_flujo_cargo) as pasos_configurados
FROM TblRequerimiento r
LEFT JOIN TblTipoDocumentoAprobacion t ON r.id_tipo_documento = t.id_tipo_documento
LEFT JOIN TblFlujoAprobacionCargos f ON f.id_tipo_documento = r.id_tipo_documento
GROUP BY r.id_tipo_documento, t.nombre;

-- ============================================================================
-- PASO 10: DIAGRAMA FINAL
-- ============================================================================

SELECT '
════════════════════════════════════════════════════════════════════════════════

ESTRUCTURA FINAL (DESPUÉS DE CAMBIOS):

TblPresupuesto
  ├─ id_presupuesto (PK)
  ├─ id_tipo_documento (INT, FK) ← NUEVO FK
  ├─ estado
  └─ ... otros campos

         ↓ (FK)

TblTipoDocumentoAprobacion
  ├─ id_tipo_documento (PK) = 1 (Presupuesto)
  └─ nombre

         ↑ (FK)

TblFlujoAprobacionCargos
  ├─ id_flujo_cargo (PK)
  ├─ id_tipo_documento = 1 (FK)
  ├─ numero_paso
  └─ id_cargo


─────────────────────────────────────────────────────────────────────────────


TblRequerimiento
  ├─ id_requerimiento (PK)
  ├─ id_tipo_documento (INT, FK) ← NUEVO FK
  ├─ estado
  └─ ... otros campos

         ↓ (FK)

TblTipoDocumentoAprobacion
  ├─ id_tipo_documento (PK) = 2 (Requerimiento)
  └─ nombre

         ↑ (FK)

TblFlujoAprobacionCargos
  ├─ id_flujo_cargo (PK)
  ├─ id_tipo_documento = 2 (FK)
  ├─ numero_paso
  └─ id_cargo


════════════════════════════════════════════════════════════════════════════════
' as diagrama_final;

-- ============================================================================
-- PASO 11: VALIDACIÓN FINAL
-- ============================================================================

SELECT 'PASO 11: Validación final' as operacion;

SELECT '✅ ÉXITO - FK agregados correctamente' as estado;

SELECT COUNT(*) as presupuestos_con_fk_valido
FROM TblPresupuesto p
INNER JOIN TblTipoDocumentoAprobacion t ON p.id_tipo_documento = t.id_tipo_documento;

SELECT COUNT(*) as requerimientos_con_fk_valido
FROM TblRequerimiento r
INNER JOIN TblTipoDocumentoAprobacion t ON r.id_tipo_documento = t.id_tipo_documento;

-- ============================================================================
-- PASO 12: RESUMEN FINAL
-- ============================================================================

SELECT '
════════════════════════════════════════════════════════════════════════════════

✅ OPTIMIZACIÓN COMPLETADA

CAMBIOS REALIZADOS:
───────────────────
1. ✅ Agregada columna id_tipo_documento a TblPresupuesto (default = 1)
2. ✅ Agregada columna id_tipo_documento a TblRequerimiento (default = 2)
3. ✅ FK fk_presupuesto_tipo_documento en TblPresupuesto
4. ✅ FK fk_requerimiento_tipo_documento en TblRequerimiento

BENEFICIOS:
───────────
1. ✅ Integridad referencial garantizada en BD
2. ✅ No se pueden insertar documentos con tipo_doc inválido
3. ✅ Backend sin hardcoding
4. ✅ Escalable a nuevos tipos de documento
5. ✅ Mejor normalización

RELACIONES AHORA EXPLÍCITAS:
─────────────────────────────
Presupuesto ──FK──> TblTipoDocumentoAprobacion <──FK── TblFlujoAprobacionCargos
Requerimiento ──FK──> TblTipoDocumentoAprobacion <──FK── TblFlujoAprobacionCargos

IMPACT:
───────
Backend: POSITIVO (sin hardcoding)
Frontend: SIN CAMBIOS
Funcionalidad: 100% IGUAL (pero más robusta)

PRÓXIMOS PASOS:
───────────────
1. ✅ Ejecutar este script en BD
2. ⏳ Actualizar backend.py (obtener tipo_doc desde presupuesto)
3. ⏳ Testing end-to-end
4. ⏳ Documentación

════════════════════════════════════════════════════════════════════════════════
' as resumen_final;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

