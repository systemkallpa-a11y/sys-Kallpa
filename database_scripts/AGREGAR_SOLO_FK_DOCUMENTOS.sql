-- ============================================================================
-- SCRIPT: Agregar Foreign Keys en Documentos hacia Flujo de Aprobación
-- PROPÓSITO: Enlazar TblPresupuesto y TblRequerimiento con TblTipoDocumentoAprobacion
-- FECHA: 21 de Julio de 2026
-- NOTA: Las columnas id_tipo_documento ya existen, solo agregamos las FKs
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: VERIFICAR QUE LAS COLUMNAS EXISTEN
-- ============================================================================

SELECT 'PASO 1: Verificando que existen las columnas' as paso;

-- Verificar en TblPresupuesto
SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'TblPresupuesto'
            AND COLUMN_NAME = 'id_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN '✅ TblPresupuesto.id_tipo_documento existe'
        ELSE '❌ NO EXISTE (problema)'
    END as presupuesto;

-- Verificar en TblRequerimiento
SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'TblRequerimiento'
            AND COLUMN_NAME = 'id_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN '✅ TblRequerimiento.id_tipo_documento existe'
        ELSE '❌ NO EXISTE (problema)'
    END as requerimiento;

-- ============================================================================
-- PASO 2: VERIFICAR QUE TblTipoDocumentoAprobacion EXISTE
-- ============================================================================

SELECT 'PASO 2: Verificando TblTipoDocumentoAprobacion' as paso;

SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME = 'TblTipoDocumentoAprobacion'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN '✅ TblTipoDocumentoAprobacion existe'
        ELSE '❌ NO EXISTE (problema)'
    END as tipo_documento_tabla;

-- ============================================================================
-- PASO 3: VERIFICAR QUE NO EXISTEN LOS FKs YA
-- ============================================================================

SELECT 'PASO 3: Verificando que los FKs no existan' as paso;

SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_NAME = 'fk_presupuesto_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN '⚠️ FK presupuesto ya existe'
        ELSE '✅ FK presupuesto no existe (OK para crear)'
    END as fk_presupuesto_status;

SELECT 
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
            WHERE CONSTRAINT_NAME = 'fk_requerimiento_tipo_documento'
            AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
        ) THEN '⚠️ FK requerimiento ya existe'
        ELSE '✅ FK requerimiento no existe (OK para crear)'
    END as fk_requerimiento_status;

-- ============================================================================
-- PASO 4: AGREGAR FOREIGN KEY EN TblPresupuesto
-- ============================================================================

SELECT 'PASO 4: Agregando FK en TblPresupuesto' as paso;

ALTER TABLE TblPresupuesto
ADD CONSTRAINT fk_presupuesto_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT
ON UPDATE CASCADE;

SELECT '✅ FK agregado en TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 5: AGREGAR FOREIGN KEY EN TblRequerimiento
-- ============================================================================

SELECT 'PASO 5: Agregando FK en TblRequerimiento' as paso;

ALTER TABLE TblRequerimiento
ADD CONSTRAINT fk_requerimiento_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT
ON UPDATE CASCADE;

SELECT '✅ FK agregado en TblRequerimiento' as resultado;

-- ============================================================================
-- PASO 6: VERIFICACIÓN FINAL
-- ============================================================================

SELECT 'PASO 6: Verificación final de FKs' as paso;

-- Mostrar FKs creados
SELECT 
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND (CONSTRAINT_NAME LIKE 'fk_presupuesto%' 
     OR CONSTRAINT_NAME LIKE 'fk_requerimiento%')
ORDER BY TABLE_NAME;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT '
════════════════════════════════════════════════════════════════════════════════

✅ FOREIGN KEYS AGREGADOS

CAMBIOS:
────────
1. ✅ FK agregado: TblPresupuesto.id_tipo_documento → TblTipoDocumentoAprobacion
2. ✅ FK agregado: TblRequerimiento.id_tipo_documento → TblTipoDocumentoAprobacion

REGLAS:
────────
- ON DELETE RESTRICT: No se puede eliminar tipo documento si hay documentos
- ON UPDATE CASCADE: Si cambia id_tipo_documento, se actualiza en documentos

INTEGRIDAD:
───────────
✅ TblPresupuesto solo puede tener id_tipo_documento válidos
✅ TblRequerimiento solo puede tener id_tipo_documento válidos
✅ Está garantizado el enlace con TblFlujoAprobacionCargos

PRÓXIMOS PASOS:
───────────────
1. Reiniciar Flask
2. Probar crear presupuesto
3. Probar aprobar presupuesto
4. Verificar que funciona el flujo completo

════════════════════════════════════════════════════════════════════════════════
' as resumen_final;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
