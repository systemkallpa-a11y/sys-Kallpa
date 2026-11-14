-- =============================================================================
-- PARTE 5 - EJECUCIÓN MANUAL (une p5_01 .. p5_03 en orden)
-- Ejecutar COMPLETO (rayo ⚡) en una pestaña NUEVA de Workbench, en
-- kallpasystem$kallgwkn_kallpa_bd. Para revertir: p5_99_revertir.sql
-- =============================================================================

SET autocommit = 1;

-- ################################################################ p5_01_tipo_documento.sql
-- =============================================================================
-- PARTE 5 / 01 - TIPO DE DOCUMENTO "ENTREGA_PERSONAL" EN EL KARDEX
-- -----------------------------------------------------------------------------
-- Las entregas al personal (vales de EPP / herramientas) descuentan stock pero
-- hoy no dejan movimiento. Para registrarlas se agrega su tipo de documento.
-- Agregar un valor AL FINAL de un ENUM no modifica los datos existentes.
-- Misma definición que la actual (NULL, DEFAULT NULL, sin comentario).
-- =============================================================================

ALTER TABLE `TblMovimientoInventario`
  MODIFY COLUMN `tipo_documento`
  ENUM('COMPRA','REQUERIMIENTO','ORDEN_TRABAJO','AJUSTE_INVENTARIO','TRANSFERENCIA','ENTREGA_PERSONAL')
  DEFAULT NULL;

-- ################################################################ p5_02_sp_stock.sql
-- =============================================================================
-- PARTE 5 / 02 - SPs DE STOCK
-- -----------------------------------------------------------------------------
-- Regla: stock_actual (TblInventario) es el SALDO oficial y TODA operación que
-- lo cambia deja su movimiento en TblMovimientoInventario (kardex).
--
--  sp_registrar_movimiento_stock   Núcleo. Cambia el saldo y registra el
--                                  movimiento. NO abre ni cierra transacción:
--                                  se suma a la del llamador (así Python puede
--                                  usarlo dentro de una entrega al personal).
--  sp_ajustar_stock                Misma firma que hoy (Inventario > movimiento
--                                  manual y stock inicial). Ahora usa el núcleo.
--  sp_verificar_kardex             Solo lectura: compara el saldo con el kardex.
--
-- Correcciones respecto al sp_ajustar_stock anterior:
--  · ENTRADA/DEVOLUCION/AJUSTE guardan el almacén en id_almacen_DESTINO
--    (antes iba en origen); SALIDA en id_almacen_origen.
--  · tipo_documento = AJUSTE_INVENTARIO en movimientos manuales (antes NULL).
--  · Código único por movimiento: ENT-000016, SAL-000017... (antes
--    ENT-<fecha>-<ítem>: una 2.ª entrada del mismo ítem el mismo día fallaba).
--  · El documento de referencia (texto) se guarda en observaciones.
--  · Bloquea la fila del ítem (FOR UPDATE): dos salidas simultáneas no pueden
--    dejar el stock negativo.
--  · Rechaza cantidad <= 0, ítems inactivos y servicios/partidas (sin stock).
--  · AJUSTE mantiene su significado: la cantidad es el stock resultante.
--    En observaciones queda "Stock anterior: X".
-- Original en sp_inventario_actuales_20261113.sql
-- =============================================================================

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_registrar_movimiento_stock`$$
CREATE PROCEDURE `sp_registrar_movimiento_stock`(
    IN  p_id_inventario    INT,
    IN  p_tipo_movimiento  VARCHAR(20),
    IN  p_cantidad         DECIMAL(10,2),
    IN  p_id_almacen       INT,
    IN  p_tipo_documento   VARCHAR(30),
    IN  p_id_documento     INT,
    IN  p_motivo           TEXT,
    IN  p_observaciones    TEXT,
    IN  p_realizado_por    INT,
    OUT p_success          BOOLEAN,
    OUT p_message          VARCHAR(255),
    OUT p_nuevo_stock      DECIMAL(10,2),
    OUT p_id_movimiento    INT
)
    MODIFIES SQL DATA
proc: BEGIN
    DECLARE v_stock     DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_nuevo     DECIMAL(10,2);
    DECLARE v_almacen   INT;
    DECLARE v_estado    VARCHAR(20);
    DECLARE v_tipo_inv  VARCHAR(20);
    DECLARE v_nombre    VARCHAR(200);
    DECLARE v_costo     DECIMAL(10,2);
    DECLARE v_prefijo   VARCHAR(5);
    DECLARE v_obs       TEXT;

    SET p_success = FALSE;
    SET p_nuevo_stock = NULL;
    SET p_id_movimiento = NULL;

    IF p_tipo_movimiento NOT IN ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION') THEN
        SET p_message = 'Tipo de movimiento inválido (ENTRADA, SALIDA, AJUSTE o DEVOLUCION)';
        LEAVE proc;
    END IF;

    IF p_cantidad IS NULL OR p_cantidad < 0
       OR (p_cantidad = 0 AND p_tipo_movimiento <> 'AJUSTE') THEN
        SET p_message = 'La cantidad debe ser mayor que cero';
        LEAVE proc;
    END IF;

    -- Bloquea el ítem hasta que termine la transacción del llamador
    SELECT stock_actual, id_almacen, estado, tipo_inventario, nombre, COALESCE(precio_compra, 0)
    INTO v_stock, v_almacen, v_estado, v_tipo_inv, v_nombre, v_costo
    FROM `TblInventario`
    WHERE id_inventario = p_id_inventario
    FOR UPDATE;

    IF v_nombre IS NULL THEN
        SET p_message = 'Ítem no encontrado';
        LEAVE proc;
    END IF;

    IF v_estado <> 'ACTIVO' THEN
        SET p_message = CONCAT('El ítem "', v_nombre, '" está inactivo');
        LEAVE proc;
    END IF;

    IF v_tipo_inv IN ('SERVICIO', 'PARTIDA') THEN
        SET p_message = 'Los servicios y partidas no manejan stock';
        LEAVE proc;
    END IF;

    SET v_stock = COALESCE(v_stock, 0);
    SET v_almacen = COALESCE(p_id_almacen, v_almacen);

    CASE p_tipo_movimiento
        WHEN 'ENTRADA'    THEN SET v_nuevo = v_stock + p_cantidad; SET v_prefijo = 'ENT';
        WHEN 'DEVOLUCION' THEN SET v_nuevo = v_stock + p_cantidad; SET v_prefijo = 'DEV';
        WHEN 'SALIDA'     THEN SET v_nuevo = v_stock - p_cantidad; SET v_prefijo = 'SAL';
        WHEN 'AJUSTE'     THEN SET v_nuevo = p_cantidad;           SET v_prefijo = 'AJU';
    END CASE;

    IF v_nuevo < 0 THEN
        SET p_message = CONCAT('Stock insuficiente de "', v_nombre, '". Disponible: ', v_stock);
        SET p_nuevo_stock = v_stock;
        LEAVE proc;
    END IF;

    SET v_obs = NULLIF(TRIM(p_observaciones), '');
    IF p_tipo_movimiento = 'AJUSTE' THEN
        SET v_obs = CONCAT_WS(' · ', CONCAT('Stock anterior: ', v_stock), v_obs);
    END IF;

    UPDATE `TblInventario`
    SET stock_actual = v_nuevo,
        fecha_actualizacion = NOW()
    WHERE id_inventario = p_id_inventario;

    INSERT INTO `TblMovimientoInventario` (
        codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
        id_almacen_origen, id_almacen_destino,
        tipo_documento, id_documento_referencia,
        costo_unitario, costo_total, motivo, observaciones,
        fecha_movimiento, realizado_por
    ) VALUES (
        NULL, p_id_inventario, p_tipo_movimiento, p_cantidad,
        IF(p_tipo_movimiento = 'SALIDA', v_almacen, NULL),
        IF(p_tipo_movimiento = 'SALIDA', NULL, v_almacen),
        COALESCE(p_tipo_documento, 'AJUSTE_INVENTARIO'), p_id_documento,
        v_costo, p_cantidad * v_costo, NULLIF(TRIM(p_motivo), ''), v_obs,
        NOW(), p_realizado_por
    );

    SET p_id_movimiento = LAST_INSERT_ID();

    -- Código único derivado del ID del movimiento
    UPDATE `TblMovimientoInventario`
    SET codigo_movimiento = CONCAT(v_prefijo, '-', LPAD(p_id_movimiento, GREATEST(6, CHAR_LENGTH(p_id_movimiento)), '0'))
    WHERE id_movimiento = p_id_movimiento;

    SET p_success = TRUE;
    SET p_nuevo_stock = v_nuevo;
    SET p_message = CONCAT('Movimiento registrado correctamente. Nuevo stock: ', v_nuevo);
END$$

DROP PROCEDURE IF EXISTS `sp_verificar_kardex`$$
CREATE PROCEDURE `sp_verificar_kardex`(
    IN p_solo_diferencias TINYINT
)
    READS SQL DATA
BEGIN
    -- Saldo según kardex = último AJUSTE (o 0) + entradas/devoluciones - salidas
    -- posteriores a ese ajuste. Se compara con stock_actual.
    SELECT k.id_inventario, k.codigo, k.nombre, k.stock_actual, k.saldo_kardex,
           k.stock_actual - k.saldo_kardex AS diferencia, k.movimientos
    FROM (
        SELECT i.id_inventario, i.codigo, i.nombre, i.stock_actual,
               COALESCE(MAX(a.cantidad), 0)
               + COALESCE(SUM(CASE
                                WHEN m.tipo_movimiento IN ('ENTRADA', 'DEVOLUCION') THEN m.cantidad
                                WHEN m.tipo_movimiento = 'SALIDA' THEN -m.cantidad
                                ELSE 0
                              END), 0) AS saldo_kardex,
               (SELECT COUNT(*) FROM `TblMovimientoInventario` x WHERE x.id_inventario = i.id_inventario) AS movimientos
        FROM `TblInventario` i
        LEFT JOIN (
            SELECT id_inventario, cantidad, fecha_movimiento, id_movimiento,
                   ROW_NUMBER() OVER (PARTITION BY id_inventario
                                      ORDER BY fecha_movimiento DESC, id_movimiento DESC) AS rn
            FROM `TblMovimientoInventario`
            WHERE tipo_movimiento = 'AJUSTE'
        ) a ON a.id_inventario = i.id_inventario AND a.rn = 1
        LEFT JOIN `TblMovimientoInventario` m
          ON m.id_inventario = i.id_inventario
         AND m.tipo_movimiento <> 'AJUSTE'
         AND (a.id_movimiento IS NULL
              OR (m.fecha_movimiento, m.id_movimiento) > (a.fecha_movimiento, a.id_movimiento))
        WHERE i.tipo_inventario NOT IN ('SERVICIO', 'PARTIDA')
        GROUP BY i.id_inventario, i.codigo, i.nombre, i.stock_actual
    ) k
    WHERE (p_solo_diferencias IS NULL OR p_solo_diferencias = 0 OR k.stock_actual <> k.saldo_kardex)
      AND (k.stock_actual <> 0 OR k.movimientos > 0 OR p_solo_diferencias = 1)
    ORDER BY k.codigo;
END$$

DELIMITER ;

-- sp_ajustar_stock se crea en el modo habitual del servidor (no estricto):
-- hoy Python puede enviarle el email del usuario en p_realizado_por y en modo
-- estricto eso daría error. Se corrige en la Parte 6.
SET SESSION sql_mode = 'NO_ENGINE_SUBSTITUTION';

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_ajustar_stock`$$
CREATE PROCEDURE `sp_ajustar_stock`(
    IN  p_id_inventario        INT,
    IN  p_tipo_movimiento      VARCHAR(20),
    IN  p_cantidad             DECIMAL(10,2),
    IN  p_motivo               TEXT,
    IN  p_documento_referencia VARCHAR(50),
    IN  p_realizado_por        INT,
    OUT p_success              BOOLEAN,
    OUT p_message              VARCHAR(255),
    OUT p_nuevo_stock          DECIMAL(10,2)
)
    MODIFIES SQL DATA
BEGIN
    DECLARE v_error TEXT;
    DECLARE v_id_mov INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = LEFT(CONCAT('Error al procesar el movimiento: ', COALESCE(v_error, 'desconocido')), 255);
        SET p_nuevo_stock = 0;
    END;

    START TRANSACTION;

    CALL sp_registrar_movimiento_stock(
        p_id_inventario, p_tipo_movimiento, p_cantidad,
        NULL,                       -- almacén del ítem
        'AJUSTE_INVENTARIO', NULL,  -- movimiento manual
        p_motivo,
        IF(NULLIF(TRIM(p_documento_referencia), '') IS NULL, NULL,
           CONCAT('Doc. ref.: ', TRIM(p_documento_referencia))),
        p_realizado_por,
        p_success, p_message, p_nuevo_stock, v_id_mov
    );

    IF p_success THEN
        COMMIT;
    ELSE
        ROLLBACK;
        SET p_nuevo_stock = COALESCE(p_nuevo_stock, 0);
    END IF;
END$$

DELIMITER ;

-- ################################################################ p5_03_kardex_entregas.sql
-- =============================================================================
-- PARTE 5 / 03 - COMPLETAR EL KARDEX CON LAS ENTREGAS AL PERSONAL EXISTENTES
-- -----------------------------------------------------------------------------
-- /api/entregas-personal/guardar descontó stock_actual sin registrar
-- movimiento. Aquí se agrega el movimiento SALIDA que faltaba por cada línea
-- de entrega, con su fecha original.
-- NO modifica stock_actual (ya fue descontado en su momento).
-- Código: SAL-ENT<entrega>-<ítem>, mismo estilo que SAL-RQA... de requerimientos.
-- Idempotente: no duplica si se ejecuta otra vez.
-- Las entregas NUEVAS registrarán su movimiento desde la Parte 6 (Python usará
-- sp_registrar_movimiento_stock).
-- =============================================================================

INSERT INTO `TblMovimientoInventario` (
    codigo_movimiento, id_inventario, tipo_movimiento, cantidad,
    id_almacen_origen, id_almacen_destino, tipo_documento, id_documento_referencia,
    costo_unitario, costo_total, motivo, observaciones, fecha_movimiento, realizado_por
)
SELECT
    CONCAT('SAL-ENT', LPAD(e.id_entrega, 6, '0'), '-', LPAD(d.id_inventario, 5, '0')),
    d.id_inventario,
    'SALIDA',
    SUM(d.cantidad),
    i.id_almacen,
    NULL,
    'ENTREGA_PERSONAL',
    e.id_entrega,
    COALESCE(i.precio_compra, 0),
    SUM(d.cantidad) * COALESCE(i.precio_compra, 0),
    CONCAT('Entrega al personal ', e.codigo_entrega),
    'Registrado en la Parte 5: la entrega descontó stock sin movimiento',
    e.fecha_entrega,
    CAST(NULLIF(e.creado_por, '') AS UNSIGNED)
FROM `TblEntregaPersonal` e
JOIN `TblEntregaPersonalDetalle` d ON d.id_entrega = e.id_entrega
JOIN `TblInventario` i ON i.id_inventario = d.id_inventario
WHERE NOT EXISTS (
    SELECT 1 FROM `TblMovimientoInventario` m
    WHERE m.tipo_documento = 'ENTREGA_PERSONAL'
      AND m.id_documento_referencia = e.id_entrega
      AND m.id_inventario = d.id_inventario
)
GROUP BY e.id_entrega, e.codigo_entrega, e.fecha_entrega, e.creado_por,
         d.id_inventario, i.id_almacen, i.precio_compra;

-- ################################################################ verificación
COMMIT;
-- Debe devolver 0 filas (ninguna diferencia entre stock y kardex):
CALL sp_verificar_kardex(1);
