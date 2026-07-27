-- ============================================================================
-- SCRIPT: Implementar Flujo de Aprobación con Múltiples Cargos por Paso
-- PROPÓSITO: Permitir que varios cargos puedan aprobar en el mismo paso (OR)
-- FECHA: 17 de Julio de 2026
-- EJEMPLO: Jefe Administración O Gerente General pueden aprobar Requerimiento
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: Crear tabla intermedia TblFlujoAprobacionCargos
-- ============================================================================

SELECT '=== PASO 1: Creando tabla TblFlujoAprobacionCargos ===' as paso;

DROP TABLE IF EXISTS TblFlujoAprobacionCargos;

CREATE TABLE TblFlujoAprobacionCargos (
    id_flujo_cargo INT AUTO_INCREMENT PRIMARY KEY 
        COMMENT 'ID único de la relación flujo-cargo',
    
    id_flujo_aprobacion INT NOT NULL 
        COMMENT 'FK a TblFlujoAprobacion',
    
    id_cargo INT NOT NULL 
        COMMENT 'FK a TblCargo - cargo que puede aprobar en este paso',
    
    orden_visualizacion INT DEFAULT 0 
        COMMENT 'Orden para mostrar en la interfaz',
    
    activo TINYINT DEFAULT 1 
        COMMENT '1=Activo, 0=Inactivo',
    
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
        COMMENT 'Fecha de creación',
    
    -- Foreign Keys (usando CONSTRAINT para nombres únicos)
    CONSTRAINT fk_fac_flujo_aprobacion 
        FOREIGN KEY (id_flujo_aprobacion) 
        REFERENCES TblFlujoAprobacion(id_flujo_aprobacion) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    CONSTRAINT fk_fac_cargo 
        FOREIGN KEY (id_cargo) 
        REFERENCES TblCargo(id_cargo) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    CONSTRAINT uk_fac_flujo_cargo 
        UNIQUE (id_flujo_aprobacion, id_cargo),
    
    INDEX idx_fac_flujo (id_flujo_aprobacion),
    INDEX idx_fac_cargo (id_cargo),
    INDEX idx_fac_activo (activo)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabla intermedia: Múltiples cargos que pueden aprobar cada paso';

SELECT '✓ Tabla creada' as resultado;

-- ============================================================================
-- PASO 2: Migrar datos existentes de TblFlujoAprobacion
-- ============================================================================

SELECT '=== PASO 2: Migrando datos ===' as paso;

INSERT INTO TblFlujoAprobacionCargos (id_flujo_aprobacion, id_cargo, orden_visualizacion)
SELECT id_flujo_aprobacion, id_cargo, 0
FROM TblFlujoAprobacion
WHERE id_cargo IS NOT NULL
ON DUPLICATE KEY UPDATE activo = 1;

SELECT CONCAT('✓ ', COUNT(*), ' registros migrados') as resultado
FROM TblFlujoAprobacionCargos;

-- ============================================================================
-- PASO 3: Crear vista de compatibilidad
-- ============================================================================

SELECT '=== PASO 3: Creando vistas ===' as paso;

DROP VIEW IF EXISTS vw_flujo_aprobacion_con_cargos;

CREATE VIEW vw_flujo_aprobacion_con_cargos AS
SELECT 
    fa.id_flujo_aprobacion,
    fa.id_tipo_documento,
    fa.numero_paso,
    fa.nombre_paso,
    fa.descripcion,
    fa.es_final,
    fa.es_requerido,
    fa.permite_rechazo,
    fa.activo as flujo_activo,
    fa.fecha_creacion,
    fa.fecha_actualizacion,
    
    -- Información de cargos aprobadores
    GROUP_CONCAT(DISTINCT c.id_cargo) as ids_cargos,
    GROUP_CONCAT(DISTINCT c.nombre SEPARATOR ' | ') as nombres_cargos,
    COUNT(DISTINCT fc.id_cargo) as cantidad_cargos_aprobadores,
    
    -- Cargo legado (el primero para compatibilidad)
    MIN(fc.id_cargo) as id_cargo_principal
    
FROM TblFlujoAprobacion fa
LEFT JOIN TblFlujoAprobacionCargos fc 
    ON fa.id_flujo_aprobacion = fc.id_flujo_aprobacion 
    AND fc.activo = 1
LEFT JOIN TblCargo c 
    ON fc.id_cargo = c.id_cargo
WHERE fa.activo = 1
GROUP BY fa.id_flujo_aprobacion
ORDER BY fa.id_tipo_documento, fa.numero_paso;

SELECT '✓ Vista vw_flujo_aprobacion_con_cargos creada' as resultado;

-- Vista para obtener cargos aprobadores de un paso específico
DROP VIEW IF EXISTS vw_cargos_aprobadores_por_paso;

CREATE VIEW vw_cargos_aprobadores_por_paso AS
SELECT 
    fa.id_flujo_aprobacion,
    fa.id_tipo_documento,
    fa.numero_paso,
    fa.nombre_paso,
    
    c.id_cargo,
    c.nombre as nombre_cargo,
    c.descripcion as descripcion_cargo,
    c.id_area,
    
    fc.orden_visualizacion,
    fc.activo,
    
    -- Contar usuarios con este cargo
    COUNT(DISTINCT 
        CASE WHEN tu.estado = 'Activo' THEN tu.num_documento END
    ) as cantidad_usuarios_activos
    
FROM TblFlujoAprobacion fa
JOIN TblFlujoAprobacionCargos fc 
    ON fa.id_flujo_aprobacion = fc.id_flujo_aprobacion
JOIN TblCargo c 
    ON fc.id_cargo = c.id_cargo
LEFT JOIN TblUsuario tu 
    ON tu.id_cargo = c.id_cargo
WHERE fa.activo = 1 
    AND fc.activo = 1
GROUP BY fa.id_flujo_aprobacion, c.id_cargo
ORDER BY fa.id_tipo_documento, fa.numero_paso, fc.orden_visualizacion;

SELECT '✓ Vista vw_cargos_aprobadores_por_paso creada' as resultado;

-- ============================================================================
-- PASO 4: Procedimiento almacenado mejorado
-- ============================================================================

SELECT '=== PASO 4: Creando procedimientos almacenados ===' as paso;

DROP PROCEDURE IF EXISTS sp_ObtenerProximoPasoConCargos;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerProximoPasoConCargos(
    IN p_id_tipo_documento INT,
    IN p_id_documento INT
)
COMMENT 'Obtiene el próximo paso de aprobación con TODOS los cargos que pueden aprobar'
BEGIN
    DECLARE v_paso_actual INT DEFAULT 0;
    DECLARE v_proximo_paso INT;
    
    -- Obtener último paso aprobado
    SELECT IFNULL(MAX(numero_paso), 0) INTO v_paso_actual
    FROM TblRegistroAprobacion
    WHERE id_tipo_documento = p_id_tipo_documento
    AND id_documento_referencia = p_id_documento
    AND estado_aprobacion = 'APROBADO';
    
    SET v_proximo_paso = v_paso_actual + 1;
    
    -- Retornar información del próximo paso con todos los cargos
    SELECT 
        fa.id_flujo_aprobacion,
        fa.numero_paso,
        fa.nombre_paso,
        fa.descripcion,
        fa.es_final,
        fa.es_requerido,
        fa.permite_rechazo,
        fa.id_tipo_documento,
        COUNT(DISTINCT c.id_cargo) as cantidad_opciones,
        GROUP_CONCAT(
            JSON_OBJECT(
                'id_cargo', c.id_cargo,
                'nombre_cargo', c.nombre,
                'descripcion', c.descripcion,
                'id_area', c.id_area,
                'orden', fc.orden_visualizacion
            )
            ORDER BY fc.orden_visualizacion
        ) as cargos_aprobadores_json
    
    FROM TblFlujoAprobacion fa
    JOIN TblFlujoAprobacionCargos fc 
        ON fa.id_flujo_aprobacion = fc.id_flujo_aprobacion AND fc.activo = 1
    JOIN TblCargo c 
        ON fc.id_cargo = c.id_cargo
    
    WHERE fa.id_tipo_documento = p_id_tipo_documento
    AND fa.numero_paso = v_proximo_paso
    AND fa.activo = 1
    
    GROUP BY fa.id_flujo_aprobacion;
    
END$$

DELIMITER ;

SELECT '✓ Procedimiento sp_ObtenerProximoPasoConCargos creado' as resultado;

-- ============================================================================
-- PASO 5: Procedimiento para validar aprobación
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ValidarCargoAprobador;

DELIMITER $$

CREATE PROCEDURE sp_ValidarCargoAprobador(
    IN p_id_tipo_documento INT,
    IN p_numero_paso INT,
    IN p_id_cargo INT,
    OUT p_es_valido BOOLEAN
)
COMMENT 'Valida si un cargo está autorizado para aprobar en un paso específico'
BEGIN
    SELECT 
        CASE 
            WHEN COUNT(*) > 0 THEN TRUE
            ELSE FALSE
        END INTO p_es_valido
    FROM TblFlujoAprobacionCargos fc
    JOIN TblFlujoAprobacion fa 
        ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
    WHERE fa.id_tipo_documento = p_id_tipo_documento
    AND fa.numero_paso = p_numero_paso
    AND fc.id_cargo = p_id_cargo
    AND fc.activo = 1
    AND fa.activo = 1;
END$$

DELIMITER ;

SELECT '✓ Procedimiento sp_ValidarCargoAprobador creado' as resultado;

-- ============================================================================
-- PASO 6: DATOS DE PRUEBA (Reemplazar IDs según tu sistema)
-- ============================================================================

SELECT '=== PASO 6: Configurando datos de prueba ===' as paso;

-- Obtener IDs del flujo para Requerimiento
SET @id_flujo_req_paso1 = (
    SELECT id_flujo_aprobacion
    FROM TblFlujoAprobacion
    WHERE id_tipo_documento = 2
    AND numero_paso = 1
    LIMIT 1
);

SET @id_flujo_req_paso2 = (
    SELECT id_flujo_aprobacion
    FROM TblFlujoAprobacion
    WHERE id_tipo_documento = 2
    AND numero_paso = 2
    LIMIT 1
);

-- IMPORTANTE: Reemplaza estos IDs con los reales de tu sistema
-- Ejecuta primero: SELECT id_cargo, nombre FROM TblCargo LIMIT 20;
SET @id_jefe_admin = 47;       -- Jefe de Administración
SET @id_gerente_general = 13;  -- Gerente General
SET @id_gerente_compras = 51;  -- Gerente de Compras

-- Agregar aprobador alternativo para Requerimiento Paso 1 (si existe)
-- Esto permite: Jefe Admin O Gerente General aprueben el requerimiento
INSERT IGNORE INTO TblFlujoAprobacionCargos 
    (id_flujo_aprobacion, id_cargo, orden_visualizacion)
SELECT @id_flujo_req_paso1, @id_gerente_general, 1
WHERE @id_flujo_req_paso1 IS NOT NULL;

SELECT CASE 
    WHEN ROW_COUNT() > 0 
    THEN '✓ Configurado: Paso 1 Requerimiento con múltiples aprobadores'
    ELSE '⚠️ No se encontró flujo para Requerimiento Paso 1 (puede ser que ya esté configurado)'
END as resultado;

-- ============================================================================
-- VERIFICACIONES
-- ============================================================================

SELECT '=== VERIFICACIÓN 1: Tabla creada ====' as verificacion;
DESCRIBE TblFlujoAprobacionCargos;

SELECT '=== VERIFICACIÓN 2: Datos migrados ====' as verificacion;
SELECT 
    td.nombre as Tipo_Documento,
    fa.numero_paso as Paso,
    fa.nombre_paso as Nombre_Paso,
    GROUP_CONCAT(DISTINCT c.nombre SEPARATOR ' | ') as Cargos_Aprobadores,
    COUNT(DISTINCT fc.id_cargo) as Cantidad_Opciones
FROM TblFlujoAprobacionCargos fc
JOIN TblFlujoAprobacion fa 
    ON fc.id_flujo_aprobacion = fa.id_flujo_aprobacion
JOIN TblTipoDocumentoAprobacion td 
    ON fa.id_tipo_documento = td.id_tipo_documento
JOIN TblCargo c 
    ON fc.id_cargo = c.id_cargo
WHERE fc.activo = 1 AND fa.activo = 1
GROUP BY fa.id_tipo_documento, fa.numero_paso
ORDER BY td.nombre, fa.numero_paso;

SELECT '=== VERIFICACIÓN 3: Vistas disponibles ====' as verificacion;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'kallgwkn_kallpa_bd'
AND TABLE_NAME LIKE 'vw_%aprobacion%';

SELECT '=== VERIFICACIÓN 4: Cargos aprobadores por paso ====' as verificacion;
SELECT * FROM vw_cargos_aprobadores_por_paso;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

SELECT '✅ ============================================' as resumen;
SELECT '✅ MIGRACIÓN COMPLETADA EXITOSAMENTE' as resumen;
SELECT '✅ ============================================' as resumen;
SELECT '✓ Tabla TblFlujoAprobacionCargos creada' as paso_1;
SELECT '✓ Datos migrados exitosamente' as paso_2;
SELECT '✓ Vistas de compatibilidad creadas' as paso_3;
SELECT '✓ Procedimientos almacenados listos' as paso_4;
SELECT '✓ El sistema permite múltiples aprobadores por paso' as paso_5;
SELECT '' as espacio;
SELECT 'PRÓXIMOS PASOS: Actualizar código Python para usar los nuevos procedimientos' as proximo;
