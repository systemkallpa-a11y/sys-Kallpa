-- ============================================================================
-- SCRIPT: Verificación Final del Setup Completo
-- DESCRIPCIÓN: Verifica que todas las tablas y constraints están correctos
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '====== VERIFICACIÓN FINAL DEL SETUP ======' as titulo;

-- PASO 1: Verificar estructura de TblRequerimiento
SELECT '1. ESTRUCTURA DE TblRequerimiento:' as paso;
DESCRIBE TblRequerimiento;

-- PASO 2: Verificar estructura de TblRequerimientoDetalle
SELECT '2. ESTRUCTURA DE TblRequerimientoDetalle:' as paso;
DESCRIBE TblRequerimientoDetalle;

-- PASO 3: Verificar FKs en TblRequerimiento
SELECT '3. FOREIGN KEYS EN TblRequerimiento:' as paso;
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimiento' 
AND CONSTRAINT_NAME != 'PRIMARY'
ORDER BY CONSTRAINT_NAME;

-- PASO 4: Verificar FKs en TblRequerimientoDetalle
SELECT '4. FOREIGN KEYS EN TblRequerimientoDetalle:' as paso;
SELECT 
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle' 
AND CONSTRAINT_NAME != 'PRIMARY'
ORDER BY CONSTRAINT_NAME;

-- PASO 5: Verificar que NO hay FK en id_material
SELECT '5. VALIDACIÓN: id_material SIN FK (correcto):' as paso;
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'OK - No hay FK en id_material'
        ELSE 'ERROR - Hay FK en id_material'
    END as resultado
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle' 
AND COLUMN_NAME = 'id_material'
AND CONSTRAINT_NAME != 'PRIMARY'
AND CONSTRAINT_NAME NOT LIKE '%id_material%';

-- PASO 6: Verificar índices
SELECT '6. ÍNDICES:' as paso;
SELECT 
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX,
    NON_UNIQUE
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_NAME IN ('TblRequerimiento', 'TblRequerimientoDetalle')
AND INDEX_NAME != 'PRIMARY'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- PASO 7: Verificar SPs
SELECT '7. STORED PROCEDURES:' as paso;
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
AND ROUTINE_NAME LIKE '%Requerimiento%'
ORDER BY ROUTINE_NAME;

-- PASO 8: Listar todas las FKs del sistema
SELECT '8. TODAS LAS FOREIGN KEYS:' as paso;
SELECT 
    TABLE_NAME,
    CONSTRAINT_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME IN ('TblRequerimiento', 'TblRequerimientoDetalle')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- PASO 9: Resumen final
SELECT '9. RESUMEN:' as paso;
SELECT 
    'TblRequerimiento FK (num_usuario)' as item,
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_NAME = 'TblRequerimiento' 
            AND CONSTRAINT_NAME = 'fk_requerimiento_usuario'
        ) THEN '✓ OK'
        ELSE '✗ FALTA'
    END as estado
UNION ALL
SELECT 
    'TblRequerimiento FK (id_presupuesto)',
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_NAME = 'TblRequerimiento' 
            AND CONSTRAINT_NAME = 'fk_requerimiento_presupuesto'
        ) THEN '✓ OK'
        ELSE '✗ FALTA'
    END
UNION ALL
SELECT 
    'TblRequerimientoDetalle FK (id_requerimiento)',
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
            WHERE TABLE_NAME = 'TblRequerimientoDetalle' 
            AND CONSTRAINT_NAME = 'fk_requerimiento_detalle'
        ) THEN '✓ OK'
        ELSE '✗ FALTA'
    END
UNION ALL
SELECT 
    'TblRequerimientoDetalle id_material (SIN FK)',
    CASE 
        WHEN COUNT(*) = 0 THEN '✓ OK'
        ELSE '✗ ERROR - Tiene FK'
    END
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblRequerimientoDetalle' 
AND COLUMN_NAME = 'id_material'
AND CONSTRAINT_NAME NOT IN ('PRIMARY')
UNION ALL
SELECT 
    'SP sp_CrearRequerimientoCompleto',
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES 
            WHERE ROUTINE_NAME = 'sp_CrearRequerimientoCompleto'
        ) THEN '✓ OK'
        ELSE '✗ FALTA'
    END
UNION ALL
SELECT 
    'SP sp_ObtenerRequerimientoDetalles',
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES 
            WHERE ROUTINE_NAME = 'sp_ObtenerRequerimientoDetalles'
        ) THEN '✓ OK'
        ELSE '✗ FALTA'
    END;

SELECT '====== VERIFICACIÓN COMPLETADA ======' as resultado;
