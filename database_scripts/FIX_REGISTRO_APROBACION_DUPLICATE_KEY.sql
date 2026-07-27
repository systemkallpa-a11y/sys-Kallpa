-- ============================================================================
-- SCRIPT: Arreglar TblRegistroAprobacion - Error errno 121 (Duplicate Key)
-- PROBLEMA: La tabla existe con índices duplicados o conflictivos
-- SOLUCIÓN: Recrreaar la tabla limpiamente
-- FECHA: 17 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Verificar la estructura actual
-- ============================================================================

SELECT '=== PASO 1: Verificando estructura actual ===' as paso;

SHOW CREATE TABLE TblRegistroAprobacion\G

-- ============================================================================
-- PASO 2: Hacer backup de los datos existentes
-- ============================================================================

SELECT '=== PASO 2: Respaldando datos ===' as paso;

CREATE TABLE TblRegistroAprobacion_BACKUP AS
SELECT * FROM TblRegistroAprobacion;

SELECT CONCAT('✓ Backup creado con ', COUNT(*), ' registros') as resultado
FROM TblRegistroAprobacion_BACKUP;

-- ============================================================================
-- PASO 3: Eliminar tabla actual (que tiene problemas)
-- ============================================================================

SELECT '=== PASO 3: Eliminando tabla actual ===' as paso;

DROP TABLE IF EXISTS TblRegistroAprobacion;

SELECT '✓ Tabla eliminada' as resultado;

-- ============================================================================
-- PASO 4: Recrear tabla SIN conflictos de índices
-- ============================================================================

SELECT '=== PASO 4: Recreando tabla ===' as paso;

CREATE TABLE TblRegistroAprobacion (
    id_registro INT AUTO_INCREMENT PRIMARY KEY 
        COMMENT 'ID único del registro de aprobación',
    
    id_tipo_documento INT NOT NULL 
        COMMENT 'FK a TblTipoDocumentoAprobacion',
    
    id_documento_referencia INT NOT NULL 
        COMMENT 'ID del documento (id_presupuesto, id_requerimiento, etc)',
    
    numero_paso INT NOT NULL 
        COMMENT 'Número de paso completado/pendiente',
    
    id_cargo_aprobador INT 
        COMMENT 'FK a TblCargo - cargo que aprobó/rechazó',
    
    num_documento_aprobador INT 
        COMMENT 'FK a TblPersona - usuario que aprobó/rechazó',
    
    estado_aprobacion ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO') 
        DEFAULT 'PENDIENTE' 
        COMMENT 'Estado del paso',
    
    comentario TEXT 
        COMMENT 'Comentarios del aprobador',
    
    fecha_asignacion TIMESTAMP 
        DEFAULT CURRENT_TIMESTAMP 
        COMMENT 'Fecha cuando se asignó al aprobador',
    
    fecha_aprobacion TIMESTAMP NULL 
        COMMENT 'Fecha cuando se aprobó/rechazó',
    
    -- ========== FOREIGN KEYS ==========
    CONSTRAINT fk_ra_tipo_documento 
        FOREIGN KEY (id_tipo_documento) 
        REFERENCES TblTipoDocumentoAprobacion(id_tipo_documento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_ra_cargo_aprobador 
        FOREIGN KEY (id_cargo_aprobador) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    CONSTRAINT fk_ra_persona_aprobador 
        FOREIGN KEY (num_documento_aprobador) 
        REFERENCES TblPersona(num_documento) 
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    -- ========== ÍNDICES (sin duplicados) ==========
    INDEX idx_ra_tipo_documento (id_tipo_documento),
    INDEX idx_ra_documento_referencia (id_documento_referencia),
    INDEX idx_ra_estado (estado_aprobacion),
    INDEX idx_ra_fecha_aprobacion (fecha_aprobacion),
    INDEX idx_ra_aprobador (num_documento_aprobador),
    
    -- Índice compuesto para búsquedas frecuentes
    INDEX idx_ra_documento_estado (id_documento_referencia, estado_aprobacion),
    INDEX idx_ra_tipo_paso (id_tipo_documento, numero_paso)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro de auditoría de todas las aprobaciones del sistema';

SELECT '✓ Tabla recreada correctamente' as resultado;

-- ============================================================================
-- PASO 5: Restaurar datos
-- ============================================================================

SELECT '=== PASO 5: Restaurando datos ===' as paso;

INSERT INTO TblRegistroAprobacion (
    id_registro,
    id_tipo_documento,
    id_documento_referencia,
    numero_paso,
    id_cargo_aprobador,
    num_documento_aprobador,
    estado_aprobacion,
    comentario,
    fecha_asignacion,
    fecha_aprobacion
)
SELECT 
    id_registro,
    id_tipo_documento,
    id_documento_referencia,
    numero_paso,
    id_cargo_aprobador,
    num_documento_aprobador,
    estado_aprobacion,
    comentario,
    fecha_asignacion,
    fecha_aprobacion
FROM TblRegistroAprobacion_BACKUP;

SELECT CONCAT('✓ ', COUNT(*), ' registros restaurados') as resultado
FROM TblRegistroAprobacion;

-- ============================================================================
-- PASO 6: Verificar integridad
-- ============================================================================

SELECT '=== PASO 6: Verificando integridad ===' as paso;

-- Verificar estructura
DESCRIBE TblRegistroAprobacion;

-- Verificar conteos
SELECT 
    COUNT(*) as total_registros,
    COUNT(DISTINCT id_tipo_documento) as tipos_documento,
    COUNT(DISTINCT estado_aprobacion) as estados_unicos,
    MAX(fecha_aprobacion) as fecha_ultima_aprobacion
FROM TblRegistroAprobacion;

-- Verificar estados
SELECT 
    estado_aprobacion,
    COUNT(*) as cantidad
FROM TblRegistroAprobacion
GROUP BY estado_aprobacion;

-- ============================================================================
-- PASO 7: Limpiar backup si todo está OK
-- ============================================================================

SELECT '=== PASO 7: Limpieza ===' as paso;

-- Descomenta la siguiente línea si quieres eliminar el backup
-- DROP TABLE TblRegistroAprobacion_BACKUP;

SELECT 'Backup guardado en: TblRegistroAprobacion_BACKUP' as nota;
SELECT 'Para eliminar: DROP TABLE TblRegistroAprobacion_BACKUP;' as comando;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT '✅ ============================================' as resumen;
SELECT '✅ SCRIPT COMPLETADO EXITOSAMENTE' as resumen;
SELECT '✅ ============================================' as resumen;
SELECT '✓ Tabla TblRegistroAprobacion recreada' as paso_1;
SELECT '✓ Datos restaurados' as paso_2;
SELECT '✓ Foreign keys reparadas' as paso_3;
SELECT '✓ Índices optimizados' as paso_4;
SELECT '' as espacio;
SELECT 'La tabla está lista para usar' as estado;
