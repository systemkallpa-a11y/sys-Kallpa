-- ============================================================================
-- OPTIMIZACIÓN: Agregar FK directo en TblPresupuesto
-- PROPÓSITO: Enlace explícito y normalizador entre Presupuesto y Flujo
-- FECHA: 21 de Julio de 2026
-- VENTAJA: Integridad referencial en BD, no en backend
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: ANÁLISIS ACTUAL
-- ============================================================================

/*
ESTADO ACTUAL:
──────────────────────────────────────────────────────────────────

TblPresupuesto
  ├─ id_presupuesto (PK)
  ├─ id_tipo_documento (INT) ← SUELTO, sin FK explícito
  ├─ estado
  └─ ... otros campos

TblFlujoAprobacionCargos
  ├─ id_flujo_cargo (PK)
  ├─ id_tipo_documento (FK a TblTipoDocumentoAprobacion)
  ├─ numero_paso
  └─ ... otros campos

PROBLEMA:
─────────
El enlace se hace en BACKEND con hardcoding:
    if id_tipo_documento == 1:
        SELECT FROM TblFlujoAprobacionCargos WHERE id_tipo_documento = 1

MEJOR ENFOQUE:
──────────────
Agregar FK explícito en TblPresupuesto:
    ALTER TABLE TblPresupuesto
    ADD CONSTRAINT fk_presupuesto_tipo_doc
    FOREIGN KEY (id_tipo_documento)
    REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)

VENTAJAS:
──────────
1. Integridad referencial garantizada por BD
2. No se puede insertar presupuesto con tipo_doc inválido
3. Queries más limpias
4. Documentación clara de relaciones
5. Mejor normalización
6. Backend más simple
*/

-- ============================================================================
-- PASO 2: VERIFICAR ESTRUCTURA ACTUAL
-- ============================================================================

SELECT 
    'Tabla TblPresupuesto' as tabla,
    COLUMN_NAME as columna,
    COLUMN_TYPE as tipo,
    IS_NULLABLE as nullable,
    COLUMN_KEY as clave
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuesto'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME = 'id_tipo_documento';

SELECT 
    'Tabla TblTipoDocumentoAprobacion' as tabla,
    COLUMN_NAME as columna,
    COLUMN_TYPE as tipo
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblTipoDocumentoAprobacion'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
LIMIT 5;

-- ============================================================================
-- PASO 3: VERIFICAR FK EXISTENTES EN TblPresupuesto
-- ============================================================================

SELECT 
    CONSTRAINT_NAME as nombre_fk,
    COLUMN_NAME as columna,
    REFERENCED_TABLE_NAME as tabla_referenciada,
    REFERENCED_COLUMN_NAME as columna_referenciada
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- ============================================================================
-- PASO 4: VALIDAR DATOS ANTES DEL CAMBIO
-- ============================================================================

-- Verificar que todos los presupuestos tienen id_tipo_documento válido
SELECT 
    p.id_tipo_documento,
    COUNT(*) as cantidad_presupuestos,
    CASE 
        WHEN EXISTS(
            SELECT 1 FROM TblTipoDocumentoAprobacion t 
            WHERE t.id_tipo_documento = p.id_tipo_documento
        ) THEN 'VÁLIDO'
        ELSE '⚠️ INVÁLIDO'
    END as estado
FROM TblPresupuesto p
GROUP BY p.id_tipo_documento;

-- Verificar valores específicos
SELECT 
    DISTINCT p.id_tipo_documento,
    t.nombre as tipo_documento
FROM TblPresupuesto p
LEFT JOIN TblTipoDocumentoAprobacion t ON p.id_tipo_documento = t.id_tipo_documento
ORDER BY p.id_tipo_documento;

-- ============================================================================
-- PASO 5: AGREGAR FK EN TblPresupuesto
-- ============================================================================

-- Primero, verificar si ya existe el FK
SELECT 
    CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
WHERE TABLE_NAME = 'TblPresupuesto'
AND CONSTRAINT_SCHEMA = 'kallgwkn_kallpa_bd'
AND REFERENCED_TABLE_NAME = 'TblTipoDocumentoAprobacion';

-- Si existe, eliminarlo
ALTER TABLE TblPresupuesto
DROP FOREIGN KEY fk_presupuesto_tipo_documento;

-- Agregar el FK
ALTER TABLE TblPresupuesto
ADD CONSTRAINT fk_presupuesto_tipo_documento
FOREIGN KEY (id_tipo_documento)
REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)
ON DELETE RESTRICT
ON UPDATE CASCADE;

SELECT '✅ FK agregado a TblPresupuesto.id_tipo_documento' as resultado;

-- ============================================================================
-- PASO 6: VERIFICAR FK CREADO
-- ============================================================================

SELECT 
    'TblPresupuesto - FK agregado' as verificacion,
    CONSTRAINT_NAME as nombre_fk,
    COLUMN_NAME as columna_local,
    REFERENCED_TABLE_NAME as tabla_referenciada,
    REFERENCED_COLUMN_NAME as columna_referenciada
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'TblPresupuesto'
AND TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND COLUMN_NAME = 'id_tipo_documento'
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- ============================================================================
-- PASO 7: VERIFICAR RELACIÓN COMPLETA
-- ============================================================================

/*
AHORA EL ENLACE ES:

TblPresupuesto (id_tipo_documento)
         │
         ↓ (FK)
TblTipoDocumentoAprobacion (id_tipo_documento)
         │
         ↑ (FK)
TblFlujoAprobacionCargos (id_tipo_documento)

Esto es MUCHO MÁS CLARO y NORMALIZADO
*/

-- Ver el diagrama de relaciones
SELECT '
════════════════════════════════════════════════════════════════════════════════

FK AHORA AGREGADO EN BD:

TblPresupuesto
  ├─ id_presupuesto (PK)
  ├─ id_tipo_documento (PK, FK) ← ENLACE EXPLÍCITO
  ├─ estado
  └─ ... otros campos

       ↓ (FK)
       
TblTipoDocumentoAprobacion
  ├─ id_tipo_documento (PK)
  ├─ nombre
  └─ ... otros campos

       ↑ (FK)
       
TblFlujoAprobacionCargos
  ├─ id_flujo_cargo (PK)
  ├─ id_tipo_documento (FK) ← Mismo valor que presupuesto
  ├─ numero_paso
  ├─ id_cargo
  └─ ... otros campos

════════════════════════════════════════════════════════════════════════════════
' as estructura;

-- ============================================================================
-- PASO 8: QUERY MEJORADA (SIN HARDCODING)
-- ============================================================================

/*
ANTES (Backend - Hardcoded):
──────────────────────────────

    # presupuesto.py
    presupuesto_id = 5
    tipo_doc = 1  ← HARDCODED
    
    # SQL Query
    cursor.execute('''
        SELECT * FROM TblFlujoAprobacionCargos
        WHERE id_tipo_documento = %s
    ''', (tipo_doc,))

AHORA (Backend - Limpio):
──────────────────────────

    # presupuesto.py
    presupuesto_id = 5
    
    # SQL Query
    cursor.execute('''
        SELECT f.* FROM TblFlujoAprobacionCargos f
        INNER JOIN TblPresupuesto p 
            ON f.id_tipo_documento = p.id_tipo_documento
        WHERE p.id_presupuesto = %s
    ''', (presupuesto_id,))
    
    # O más simple (gracias al FK en BD):
    
    cursor.execute('''
        SELECT f.* FROM TblFlujoAprobacionCargos f
        WHERE f.id_tipo_documento = (
            SELECT id_tipo_documento FROM TblPresupuesto 
            WHERE id_presupuesto = %s
        )
    ''', (presupuesto_id,))
*/

-- ============================================================================
-- PASO 9: SCRIPT PARA BACKEND (NUEVA FORMA)
-- ============================================================================

/*
RECOMENDACIÓN PARA presupuesto.py:
───────────────────────────────────

OPCIÓN 1: Query más simple (sin FK en consulta)
    cursor.execute('''
        SELECT id_tipo_documento FROM TblPresupuesto
        WHERE id_presupuesto = %s
    ''', (id_presupuesto,))
    tipo_doc = cursor.fetchone()[0]
    
    # Luego usar tipo_doc en SP normalmente

OPCIÓN 2: Query con JOIN explícito (más robusta)
    cursor.execute('''
        SELECT f.* FROM TblFlujoAprobacionCargos f
        WHERE f.id_tipo_documento = (
            SELECT id_tipo_documento FROM TblPresupuesto 
            WHERE id_presupuesto = %s
        )
    ''', (id_presupuesto,))

OPCIÓN 3: SP Mejorado que reciba presupuesto_id directamente
    # Cambiar SP para que acepte id_presupuesto
    # y obtenga id_tipo_documento internamente
    
    cursor.callproc('sp_AprobarPresupuesto_Progresivo_v3',
                    [id_presupuesto, num_documento])
    
    # En el SP:
    SELECT id_tipo_documento INTO p_id_tipo_documento
    FROM TblPresupuesto WHERE id_presupuesto = p_id_presupuesto;
*/

-- ============================================================================
-- PASO 10: VERIFICACIÓN VISUAL
-- ============================================================================

SELECT 
    'FK Agregado en TblPresupuesto' as operacion,
    'id_tipo_documento' as columna,
    'TblTipoDocumentoAprobacion' as tabla_referenciada,
    'ON DELETE RESTRICT, ON UPDATE CASCADE' as reglas,
    '✅ COMPLETADO' as estado;

SELECT 
    p.id_presupuesto,
    p.id_tipo_documento as presupuesto_tipo_doc,
    t.nombre as tipo_documento,
    COUNT(f.id_flujo_cargo) as total_pasos_configurados
FROM TblPresupuesto p
LEFT JOIN TblTipoDocumentoAprobacion t ON p.id_tipo_documento = t.id_tipo_documento
LEFT JOIN TblFlujoAprobacionCargos f ON f.id_tipo_documento = p.id_tipo_documento
WHERE p.id_presupuesto IN (1, 2, 3, 4, 5)
GROUP BY p.id_presupuesto, p.id_tipo_documento, t.nombre
LIMIT 5;

-- ============================================================================
-- RESUMEN
-- ============================================================================

SELECT '
════════════════════════════════════════════════════════════════════════════════

✅ OPTIMIZACIÓN COMPLETADA

CAMBIO:
───────
Se agregó FK explícito en TblPresupuesto:
    ALTER TABLE TblPresupuesto
    ADD CONSTRAINT fk_presupuesto_tipo_documento
    FOREIGN KEY (id_tipo_documento)
    REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento)

BENEFICIOS:
───────────
1. Integridad referencial en BD (no solo en backend)
2. No se pueden crear presupuestos con tipo_doc inválido
3. Backend más limpio (sin hardcoding de valores)
4. Queries más robustas
5. Mejor documentación de relaciones

IMPACT ON BACKEND:
──────────────────
MÍNIMO - Solo cambio la forma de obtener tipo_documento:

    # ANTES (con hardcode)
    tipo_doc = 1
    
    # DESPUÉS (desde BD)
    tipo_doc = cursor.execute(
        "SELECT id_tipo_documento FROM TblPresupuesto 
         WHERE id_presupuesto = %s", (id_presupuesto,)
    ).fetchone()[0]

O MEJOR: Modificar SP para que acepte presupuesto_id directamente

PRÓXIMOS PASOS:
───────────────
1. ✅ Ejecutar este script (crear FK)
2. ⏳ Actualizar SP para usar presupuesto_id
3. ⏳ Actualizar backend.py (opcional, pero recomendado)
4. ⏳ Testing

════════════════════════════════════════════════════════════════════════════════
' as resumen;

