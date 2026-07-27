-- ============================================================================
-- SCRIPT: Corrección de sp_CrearRequerimientoCompleto
-- DESCRIPCIÓN: Actualiza el SP para crear requerimientos con detalles
--              Usa JSON_UNQUOTE para evitar caracteres escapados
--              Calcula cantidad como SUM de items
-- FECHA: 2026-07-16
-- ACTUALIZADO: Verificación de tabla y SP con todas las correcciones
-- ============================================================================

SELECT '========== INICIANDO ACTUALIZACIÓN DE SP ===========' as status;

-- ============================================================================
-- PASO 1: VERIFICACIÓN DE ESTRUCTURA
-- ============================================================================
SELECT 'PASO 1: Verificando estructura de TblRequerimiento' as paso;

-- Mostrar todas las columnas de TblRequerimiento
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TblRequerimiento'
  AND TABLE_SCHEMA = DATABASE()
ORDER BY ORDINAL_POSITION;

-- Verificar que observaciones existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'TblRequerimiento' 
          AND COLUMN_NAME = 'observaciones'
          AND TABLE_SCHEMA = DATABASE()
    ),
    '✓ Columna observaciones EXISTE',
    '✗ ERROR: Columna observaciones NO EXISTE'
) as verificacion_observaciones;

-- Verificar que num_usuario existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'TblRequerimiento' 
          AND COLUMN_NAME = 'num_usuario'
          AND TABLE_SCHEMA = DATABASE()
    ),
    '✓ Columna num_usuario EXISTE',
    '✗ ERROR: Columna num_usuario NO EXISTE'
) as verificacion_num_usuario;

-- Verificar que id_presupuesto existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'TblRequerimiento' 
          AND COLUMN_NAME = 'id_presupuesto'
          AND TABLE_SCHEMA = DATABASE()
    ),
    '✓ Columna id_presupuesto EXISTE',
    '✗ ERROR: Columna id_presupuesto NO EXISTE'
) as verificacion_id_presupuesto;

-- Verificar que TblRequerimientoDetalle existe
SELECT IF(
    EXISTS(
        SELECT 1 FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() 
          AND TABLE_NAME = 'TblRequerimientoDetalle'
    ),
    '✓ Tabla TblRequerimientoDetalle EXISTE',
    '✗ ERROR: Tabla TblRequerimientoDetalle NO EXISTE'
) as verificacion_tabla_detalle;

-- ============================================================================
-- PASO 2: ELIMINAR SP ANTIGUO
-- ============================================================================
SELECT 'PASO 2: Eliminando SP antiguo' as paso;
DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto;

-- ============================================================================
-- PASO 3: CREAR SP NUEVO (VERSIÓN ACTUALIZADA)
-- ============================================================================
SELECT 'PASO 3: Creando SP nuevo sp_CrearRequerimientoCompleto' as paso;

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
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sqlstate = RETURNED_SQLSTATE, 
            @errno = MYSQL_ERRNO, 
            @text = MESSAGE_TEXT;
        
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = CONCAT('Error en sp_CrearRequerimientoCompleto: ', @text);
    END;
    
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
    
    -- Iniciar transacción
    START TRANSACTION;
    
    -- Insertar requerimiento principal
    -- NOTA: Todas estas columnas deben existir en TblRequerimiento
    -- - codigo: VARCHAR(50) - ✓ original
    -- - num_usuario: INT NOT NULL - ✓ agregada por ALTER
    -- - id_presupuesto: INT NULL - ✓ agregada por ALTER
    -- - descripcion: LONGTEXT NOT NULL - ✓ original
    -- - cantidad: INT NOT NULL - ✓ original (ahora = SUM de detalles)
    -- - estado: VARCHAR(50) - ✓ original
    -- - observaciones: LONGTEXT - ✓ original
    -- - fecha_creacion: DATETIME - ✓ original
    
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
        -- id_material: NULL para servicios, valor para materiales
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN NULL
            WHEN pd.id_material IS NULL OR pd.id_material = 0 THEN NULL
            ELSE pd.id_material
        END as id_material,
        COALESCE(pd.tipo_item, 'MATERIAL') as tipo_item,
        -- descripcion: usar JSON_UNQUOTE para evitar caracteres escapados
        CASE 
            WHEN COALESCE(pd.tipo_item, 'MATERIAL') = 'SERVICIO' THEN 
                COALESCE(JSON_UNQUOTE(JSON_EXTRACT(pd.descripcion, '$')), pd.descripcion, 'Servicio sin descripción')
            ELSE 
                COALESCE(m.nombre, JSON_UNQUOTE(JSON_EXTRACT(pd.descripcion, '$')), pd.descripcion, 'Material sin especificar')
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
    
    COMMIT;
    
END$$

DELIMITER ;

-- ============================================================================
-- PASO 4: VERIFICAR SP CREADO
-- ============================================================================
SELECT 'PASO 4: Verificando SP creado' as paso;
SHOW PROCEDURE STATUS WHERE Name = 'sp_CrearRequerimientoCompleto' AND Db = DATABASE();

-- ============================================================================
-- PASO 5: ACTUALIZAR sp_ActualizarRequerimiento CON JSON_UNQUOTE
-- ============================================================================
SELECT 'PASO 5: Actualizando sp_ActualizarRequerimiento' as paso;
DROP PROCEDURE IF EXISTS sp_ActualizarRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_ActualizarRequerimiento(
    IN p_id_requerimiento INT,
    IN p_descripcion VARCHAR(500),
    IN p_observaciones LONGTEXT,
    IN p_detalles_json LONGTEXT,
    OUT p_resultado INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_detalle_index INT DEFAULT 0;
    DECLARE v_total_detalles INT DEFAULT 0;
    DECLARE v_id_detalle INT;
    DECLARE v_desc_detalle VARCHAR(255);
    DECLARE v_cantidad_detalle INT;
    DECLARE v_cantidad_total INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sqlstate = RETURNED_SQLSTATE, 
            @errno = MYSQL_ERRNO, 
            @text = MESSAGE_TEXT;
        
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = CONCAT('Error en sp_ActualizarRequerimiento: ', @text);
    END;
    
    -- Verificar que el requerimiento existe
    SELECT COUNT(*)
    INTO v_existe
    FROM TblRequerimiento
    WHERE id_requerimiento = p_id_requerimiento;
    
    IF v_existe = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requerimiento no existe';
        SET p_resultado = 0;
    ELSE
        -- INICIO TRANSACCIÓN
        START TRANSACTION;
        
        -- Actualizar detalles si se proporcionan
        IF p_detalles_json IS NOT NULL AND p_detalles_json != '[]' THEN
            -- Procesar cada detalle del JSON
            SET v_detalle_index = 0;
            SET v_total_detalles = JSON_LENGTH(p_detalles_json);
            
            WHILE v_detalle_index < v_total_detalles DO
                -- Extraer datos del detalle (desescapando strings con JSON_UNQUOTE)
                SET v_id_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].id_detalle'));
                SET v_desc_detalle = JSON_UNQUOTE(JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].descripcion')));
                SET v_cantidad_detalle = JSON_EXTRACT(p_detalles_json, CONCAT('$[', v_detalle_index, '].cantidad'));
                
                -- Acumular cantidad total
                SET v_cantidad_total = v_cantidad_total + COALESCE(v_cantidad_detalle, 0);
                
                -- Actualizar el detalle
                UPDATE TblRequerimientoDetalle
                SET
                    descripcion = v_desc_detalle,
                    cantidad = v_cantidad_detalle,
                    fecha_actualizacion = NOW()
                WHERE id_detalle = v_id_detalle
                  AND id_requerimiento = p_id_requerimiento;
                
                SET v_detalle_index = v_detalle_index + 1;
            END WHILE;
        ELSE
            -- Si no hay JSON, calcular suma de cantidades actuales
            SELECT COALESCE(SUM(cantidad), 0)
            INTO v_cantidad_total
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = p_id_requerimiento;
        END IF;
        
        -- Actualizar datos del requerimiento (incluyendo cantidad total)
        UPDATE TblRequerimiento
        SET
            descripcion = p_descripcion,
            observaciones = p_observaciones,
            cantidad = v_cantidad_total,
            fecha_actualizacion = NOW()
        WHERE id_requerimiento = p_id_requerimiento;
        
        COMMIT;
        SET p_resultado = 1;
    END IF;
    
END$$

DELIMITER ;

-- ============================================================================
-- PASO 6: VERIFICAR SPs CREADOS
-- ============================================================================
SELECT 'PASO 6: Verificando SPs finales' as paso;
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name IN ('sp_CrearRequerimientoCompleto', 'sp_ActualizarRequerimiento');

-- ============================================================================
-- PASO 7: RESUMEN
-- ============================================================================
SELECT '========== ACTUALIZACIÓN COMPLETADA ===========' as status;
SELECT 'SPs actualizados:' as resumen;
SELECT '  ✓ sp_CrearRequerimientoCompleto - v2.0' as sp1;
SELECT '  ✓ sp_ActualizarRequerimiento - v2.0 con JSON_UNQUOTE' as sp2;
SELECT '' as linea;
SELECT 'Cambios principales:' as cambios;
SELECT '  • Cantidad = SUM de cantidades de items' as cambio1;
SELECT '  • JSON_UNQUOTE para evitar caracteres escapados' as cambio2;
SELECT '  • Soporte para crear requerimientos desde presupuestos' as cambio3;
SELECT '  • Transacciones para consistencia de datos' as cambio4;
