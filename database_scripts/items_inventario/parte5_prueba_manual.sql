-- =============================================================================
-- PARTE 5 - PRUEBA MANUAL DEL NÚCLEO DE STOCK (no deja datos)
-- -----------------------------------------------------------------------------
-- Ejecutar COMPLETO (rayo ⚡) en una pestaña nueva, DESPUÉS de parte5_manual.sql.
-- Todo ocurre dentro de START TRANSACTION ... ROLLBACK: al final el stock y el
-- kardex quedan exactamente como estaban.
-- Usa el ítem MAT-023 (Yeso x 5 kg, stock 20).
-- =============================================================================

SET @yeso = (SELECT id_inventario FROM TblInventario WHERE codigo = 'MAT-023');
SET @serv = (SELECT id_inventario FROM TblInventario WHERE codigo = 'SER-001');
SELECT 'ANTES' AS momento, stock_actual FROM TblInventario WHERE id_inventario = @yeso;

START TRANSACTION;

-- 1. Entrada de 5 (esperado: 1, stock 25, código ENT-0000xx, almacén en DESTINO)
CALL sp_registrar_movimiento_stock(@yeso, 'ENTRADA', 5, NULL, 'AJUSTE_INVENTARIO', NULL, 'Prueba entrada', NULL, 0, @ok, @msg, @st, @mov);
SELECT '1. Entrada 5' AS caso, @ok AS exito, @msg AS mensaje, @st AS nuevo_stock;
SELECT codigo_movimiento, tipo_movimiento, cantidad, id_almacen_origen, id_almacen_destino, tipo_documento
FROM TblMovimientoInventario WHERE id_movimiento = @mov;

-- 2. Segunda entrada el mismo día (antes fallaba por código repetido)
CALL sp_registrar_movimiento_stock(@yeso, 'ENTRADA', 1, NULL, 'AJUSTE_INVENTARIO', NULL, 'Prueba 2da entrada', NULL, 0, @ok, @msg, @st, @mov);
SELECT '2. Segunda entrada mismo día' AS caso, @ok AS exito, @msg AS mensaje, @st AS nuevo_stock;

-- 3. Salida de 6 (esperado: 1, stock 20, almacén en ORIGEN)
CALL sp_registrar_movimiento_stock(@yeso, 'SALIDA', 6, NULL, 'ENTREGA_PERSONAL', NULL, 'Prueba salida', NULL, 0, @ok, @msg, @st, @mov);
SELECT '3. Salida 6' AS caso, @ok AS exito, @msg AS mensaje, @st AS nuevo_stock;
SELECT codigo_movimiento, tipo_movimiento, id_almacen_origen, id_almacen_destino, tipo_documento
FROM TblMovimientoInventario WHERE id_movimiento = @mov;

-- 4. Rechazos (esperado: exito = 0 con mensaje)
CALL sp_registrar_movimiento_stock(@yeso, 'SALIDA', 999, NULL, NULL, NULL, 'Prueba', NULL, 0, @ok, @msg, @st, @mov);
SELECT '4. Salida mayor al stock' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_registrar_movimiento_stock(@yeso, 'ENTRADA', 0, NULL, NULL, NULL, 'Prueba', NULL, 0, @ok, @msg, @st, @mov);
SELECT '5. Cantidad cero' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_registrar_movimiento_stock(@serv, 'ENTRADA', 1, NULL, NULL, NULL, 'Prueba', NULL, 0, @ok, @msg, @st, @mov);
SELECT '6. Stock a un servicio' AS caso, @ok AS exito, @msg AS mensaje;

-- 7. Ajuste a 18 (esperado: 1, stock 18, observaciones "Stock anterior: 20")
CALL sp_registrar_movimiento_stock(@yeso, 'AJUSTE', 18, NULL, NULL, NULL, 'Prueba ajuste', NULL, 0, @ok, @msg, @st, @mov);
SELECT '7. Ajuste a 18' AS caso, @ok AS exito, @st AS nuevo_stock,
       (SELECT observaciones FROM TblMovimientoInventario WHERE id_movimiento = @mov) AS observaciones;

-- 8. Kardex dentro de la transacción (esperado: 0 filas, todo cuadra)
CALL sp_verificar_kardex(1);

ROLLBACK;

-- Después del ROLLBACK (esperado: stock 20 otra vez, 0 movimientos de prueba)
SELECT 'DESPUÉS' AS momento, stock_actual FROM TblInventario WHERE id_inventario = @yeso;
SELECT COUNT(*) AS movimientos_de_prueba_esperado_0 FROM TblMovimientoInventario WHERE motivo LIKE 'Prueba%';
