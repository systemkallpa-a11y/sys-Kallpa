-- ============================================================================
-- SCRIPT MAESTRO: Limpieza + Corrección de SP
-- DESCRIPCIÓN:
--   1. Ejecuta script de limpieza (00_LIMPIAR_Y_RECONSTRUIR.sql)
--   2. Corrige SP sp_CrearRequerimientoCompleto (elimina observaciones de detalles)
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║  EJECUTAR LIMPIEZA Y CORREGIR STORED PROCEDURES               ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';

-- ============================================================================
-- PASO 1: ELIMINAR COLUMNAS INCORRECTAS DE TblPresupuesto
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 1: Eliminando columnas incorrectas de TblPresupuesto' as paso;

ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_saldo;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_consumida;
ALTER TABLE TblPresupuesto DROP COLUMN IF EXISTS cantidad_original;

SELECT '✓ Columnas eliminadas de TblPresupuesto' as resultado;

-- ============================================================================
-- PASO 2: ELIMINAR TABLA DE AUDITORÍA INCOMPLETA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 2: Eliminando tabla de auditoría (se recreará)' as paso;

DROP TABLE IF EXISTS TblRequerimientoAuditoria;
DROP VIEW IF EXISTS vw_requerimiento_auditoria;

SELECT '✓ Tabla y vista eliminadas' as resultado;

-- ============================================================================
-- PASO 3: AGREGAR COLUMNAS A TblPresupuestoDetalle
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 3: Agregando columnas a TblPresupuestoDetalle' as paso;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_original DECIMAL(10, 2)
COMMENT 'Cantidad presupuestada originalmente'
AFTER cantidad;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_consumida DECIMAL(10, 2) DEFAULT 0
COMMENT 'Cantidad usada en requerimientos'
AFTER cantidad_original;

ALTER TABLE TblPresupuestoDetalle 
ADD COLUMN IF NOT EXISTS cantidad_saldo DECIMAL(10, 2) GENERATED ALWAYS AS (COALESCE(cantidad_original, 0) - COALESCE(cantidad_consumida, 0)) STORED
COMMENT 'Saldo disponible = original - consumida'
AFTER cantidad_consumida;

ALTER TABLE TblPresupuestoDetalle 
ADD INDEX IF NOT EXISTS idx_cantidad_saldo (cantidad_saldo);

SELECT '✓ Columnas agregadas a TblPresupuestoDetalle' as resultado;

-- ============================================================================
-- PASO 4: INICIALIZAR cantidad_original
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 4: Inicializando cantidad_original = cantidad' as paso;

SET SQL_SAFE_UPDATES = 0;

UPDATE TblPresupuestoDetalle
SET cantidad_original = cantidad
WHERE cantidad_original IS NULL;

SET SQL_SAFE_UPDATES = 1;

SELECT 'Detalles inicializados' as resultado;

-- ============================================================================
-- PASO 5: CREAR TABLA DE AUDITORÍA CORRECTA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 5: Creando tabla de auditoría correcta' as paso;

CREATE TABLE IF NOT EXISTS TblRequerimientoAuditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de auditoría',
    
    id_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuesto',
    id_detalle_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuestoDetalle - EL ITEM',
    id_requerimiento INT NOT NULL COMMENT 'FK a TblRequerimiento',
    
    cantidad_requerida INT NOT NULL COMMENT 'Cantidad solicitada en el requerimiento',
    cantidad_anterior_consumida INT COMMENT 'Consumo del item ANTES',
    cantidad_nueva_consumida INT COMMENT 'Consumo del item DESPUÉS',
    saldo_anterior INT COMMENT 'Saldo del item ANTES',
    saldo_nuevo INT COMMENT 'Saldo del item DESPUÉS',
    
    accion VARCHAR(20) NOT NULL COMMENT 'CREAR, ACTUALIZAR, CANCELAR',
    num_usuario INT COMMENT 'Usuario que realizó la acción',
    observaciones LONGTEXT COMMENT 'Notas adicionales',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Cuándo ocurrió',
    
    CONSTRAINT fk_auditoria_presupuesto 
        FOREIGN KEY (id_presupuesto) 
        REFERENCES TblPresupuesto(id_presupuesto) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_detalle 
        FOREIGN KEY (id_detalle_presupuesto) 
        REFERENCES TblPresupuestoDetalle(id_detalle) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_requerimiento 
        FOREIGN KEY (id_requerimiento) 
        REFERENCES TblRequerimiento(id_requerimiento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_detalle (id_detalle_presupuesto),
    INDEX idx_id_requerimiento (id_requerimiento),
    INDEX idx_accion (accion),
    INDEX idx_fecha_registro (fecha_registro)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Auditoría de cambios en items de presupuesto';

SELECT '✓ Tabla de auditoría creada' as resultado;

-- ============================================================================
-- PASO 6: CREAR VISTA DE AUDITORÍA
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 6: Creando vista de auditoría' as paso;

CREATE VIEW vw_requerimiento_auditoria AS
SELECT 
    a.id_auditoria,
    a.fecha_registro,
    a.accion,
    p.numero_presupuesto,
    a.id_presupuesto,
    pd.descripcion as item_descripcion,
    a.id_detalle_presupuesto,
    r.codigo as requerimiento_codigo,
    a.id_requerimiento,
    a.cantidad_requerida,
    a.cantidad_anterior_consumida,
    a.cantidad_nueva_consumida,
    a.saldo_anterior,
    a.saldo_nuevo,
    a.num_usuario
FROM TblRequerimientoAuditoria a
LEFT JOIN TblPresupuesto p ON a.id_presupuesto = p.id_presupuesto
LEFT JOIN TblPresupuestoDetalle pd ON a.id_detalle_presupuesto = pd.id_detalle
LEFT JOIN TblRequerimiento r ON a.id_requerimiento = r.id_requerimiento;

SELECT '✓ Vista creada' as resultado;

-- ============================================================================
-- PASO 7: RECREAR STORED PROCEDURE sp_CrearRequerimientoCompleto (CORREGIDO)
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 7: Recreando SP sp_CrearRequerimientoCompleto (SIN observaciones en detalles)' as paso;

DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

DELIMITER $$

CREATE PROCEDURE sp_CrearRequerimientoCompleto(
    IN p_num_usuario INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_id_requerimiento_created INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_codigo VARCHAR(20);
    DECLARE v_cantidad_total DECIMAL(10, 2) DEFAULT 0;
    DECLARE v_id_presupuesto INT DEFAULT NULL;
    
    -- Validar que el usuario existe
    IF NOT EXISTS (SELECT 1 FROM TblUsuario WHERE num_usuario = p_num_usuario) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no existe';
    END IF;
    
    -- Validar que JSON no está vacío
    IF JSON_LENGTH(p_detalles_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Detalles vacíos: debe proporcionar al menos un item';
    END IF;
    
    -- Generar código automáticamente
    SELECT CONCAT('REQ-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo, 5) AS UNSIGNED)), 0) + 1, 5, '0'))
    INTO v_codigo
    FROM TblRequerimiento
    WHERE codigo LIKE 'REQ-%';
    
    -- Si no existe código previo, iniciar en 1
    IF v_codigo IS NULL OR v_codigo = 'REQ-' THEN
        SET v_codigo = 'REQ-00001';
    END IF;
    
    -- Calcular cantidad total de items desde el presupuesto
    SELECT COALESCE(SUM(pd.cantidad), 0)
    INTO v_cantidad_total
    FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (id_detalle INT PATH '$.id_detalle_presupuesto')) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle;
    
    -- Obtener id_presupuesto del primer item del JSON
    SELECT COALESCE(pd.id_presupuesto, NULL)
    INTO v_id_presupuesto
    FROM JSON_TABLE(
        p_detalles_json, 
        '$[*]' 
        COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto'
        )
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LIMIT 1;
    
    -- Insertar requerimiento principal
    INSERT INTO TblRequerimiento (
        codigo,
        num_usuario,
        id_presupuesto,
        descripcion,
        cantidad,
        estado,
        observaciones,
        fecha_creacion
    ) VALUES (
        v_codigo,
        p_num_usuario,
        v_id_presupuesto,
        p_descripcion,
        COALESCE(v_cantidad_total, 0),
        'PENDIENTE',
        COALESCE(p_observaciones, ''),
        NOW()
    );
    
    SET p_id_requerimiento_created = LAST_INSERT_ID();
    
    -- Insertar detalles del requerimiento desde TblPresupuestoDetalle
    -- IMPORTANTE: NO incluye observaciones (eliminado de TblRequerimientoDetalle)
    INSERT INTO TblRequerimientoDetalle (
        id_requerimiento,
        id_material,
        tipo_item,
        descripcion,
        cantidad,
        unidad_medida,
        fecha_creacion
    )
    SELECT
        p_id_requerimiento_created,
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
            WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
            ELSE pd.id_material
        END as id_material,
        COALESCE(pd.tipo_item, 'MATERIAL') as tipo_item,
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN 
                COALESCE(pd.descripcion, 'Servicio sin descripción')
            ELSE 
                COALESCE(m.nombre, pd.descripcion, 'Material sin especificar')
        END as descripcion,
        COALESCE(pd.cantidad, 1) as cantidad,
        COALESCE(um.nombre, 'und') as unidad_medida,
        NOW()
    FROM JSON_TABLE(
        p_detalles_json, 
        '$[*]' 
        COLUMNS (
            id_detalle INT PATH '$.id_detalle_presupuesto'
        )
    ) jt
    INNER JOIN TblPresupuestoDetalle pd ON pd.id_detalle = jt.id_detalle
    LEFT JOIN TblMateriales m ON pd.id_material = m.id_material AND pd.id_material > 0
    LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad;
    
END$$

DELIMITER ;

SELECT '✓ SP recre ado correctamente' as resultado;

-- ============================================================================
-- PASO 8: VERIFICACIÓN FINAL
-- ============================================================================
SELECT '' as linea;
SELECT 'PASO 8: Verificación final' as paso;

SELECT 'Columnas en TblPresupuestoDetalle (cantidad):' as verificacion1;
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblPresupuestoDetalle'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME LIKE '%cantidad%'
ORDER BY ORDINAL_POSITION;

SELECT '' as linea;
SELECT 'Tabla TblRequerimientoAuditoria existe:' as verificacion2;
SELECT IF(
    EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_NAME = 'TblRequerimientoAuditoria' 
           AND TABLE_SCHEMA = DATABASE()),
    '✓ SÍ existe',
    '✗ NO existe'
) as resultado;

SELECT '' as linea;
SELECT '╔════════════════════════════════════════════════════════════════╗';
SELECT '║              ✓ LIMPIEZA Y CORRECCIÓN COMPLETA                 ║';
SELECT '╚════════════════════════════════════════════════════════════════╝';
SELECT '';
SELECT 'CAMBIOS REALIZADOS:' as resumen;
SELECT '  ✓ Eliminadas columnas incorrectas de TblPresupuesto' as c1;
SELECT '  ✓ Agregadas columnas correctas a TblPresupuestoDetalle' as c2;
SELECT '  ✓ Tabla de auditoría recreada con id_detalle_presupuesto' as c3;
SELECT '  ✓ SP sp_CrearRequerimientoCompleto corregido' as c4;
SELECT '';
SELECT 'ESTADO: Listo para usar' as estado;
