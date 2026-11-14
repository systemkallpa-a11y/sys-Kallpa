-- =============================================================================
-- PARTE 4 - PRUEBA MANUAL DE sp_guardar_item
-- -----------------------------------------------------------------------------
-- Ejecutar COMPLETO (rayo ⚡ de Workbench) en una pestaña nueva.
-- Crea 1 ítem "PRUEBA P4 Botas T42", muestra cómo quedó, prueba 6 rechazos
-- y al final BORRA todo lo que tenga nombre "PRUEBA P4%" y hace COMMIT.
-- La limpieza no depende de variables de sesión.
-- =============================================================================

SET autocommit = 1;

SET @cat_epp = (SELECT id_categoria FROM TblCategoriaInventario WHERE codigo = 'ROP-EPP');
SET @cat_tec = (SELECT id_categoria FROM TblCategoriaInventario WHERE codigo = 'TEC-COM');
SET @uni_par = (SELECT id_unidad FROM TblUnidadMedida WHERE codigo = 'PARES');
SET @uni_kg  = (SELECT id_unidad FROM TblUnidadMedida WHERE codigo = 'KG');
SET @uni_und = (SELECT id_unidad FROM TblUnidadMedida WHERE codigo = 'UND');

-- 1. Alta correcta: ropa con ficha y stock inicial 10
CALL sp_guardar_item('PRUEBA P4 Botas T42', 'Ítem de prueba', 'ROPA', @cat_epp, @uni_par,
                     0, 0, 85, 1, NULL,
                     '{"talla":"42","color":"Negro","genero":"UNISEX","tipo_proteccion":"Pies"}',
                     10, 0, @ok, @msg, @id, @codigo);
SELECT '1. Alta correcta' AS caso, @ok AS exito, @msg AS mensaje, @codigo AS codigo;

-- 2. Cómo quedó (esperado: ROP-004, stock 10, ficha llena, movimiento INI-ROP-004)
SELECT i.codigo, i.stock_actual, r.talla, r.color, r.genero, r.tipo_proteccion,
       m.codigo_movimiento, m.cantidad, m.costo_total
FROM TblInventario i
JOIN TblInventarioRopa r ON r.id_inventario = i.id_inventario
LEFT JOIN TblMovimientoInventario m ON m.id_inventario = i.id_inventario
WHERE i.nombre = 'PRUEBA P4 Botas T42';

-- 3. Rechazos (esperado en todos: exito = 0 con mensaje claro)
CALL sp_guardar_item('PRUEBA P4 X', NULL, 'TECNOLOGIA', @cat_tec, @uni_kg, 0,0,0, NULL,NULL, NULL, 0,0, @ok,@msg,@x,@y);
SELECT '2. Laptop en KG' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_guardar_item('PRUEBA P4 X', NULL, 'ROPA', @cat_epp, @uni_und, 0,0,0, NULL,NULL, '{"genero":"NIÑO"}', 0,0, @ok,@msg,@x,@y);
SELECT '3. Género fuera de lista' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_guardar_item('PRUEBA P4 X', NULL, 'TECNOLOGIA', @cat_tec, @uni_und, 0,0,0, NULL,NULL, '{"peso_kg":"abc"}', 0,0, @ok,@msg,@x,@y);
SELECT '4. Peso no numérico' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_guardar_item('PRUEBA P4 X', NULL, 'ROPA', @cat_epp, @uni_und, 10,5,0, NULL,NULL, NULL, 0,0, @ok,@msg,@x,@y);
SELECT '5. Mínimo mayor que máximo' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_guardar_item('PRUEBA P4 X', NULL, 'ROPA', @cat_tec, @uni_und, 0,0,0, NULL,NULL, NULL, 0,0, @ok,@msg,@x,@y);
SELECT '6. Tipo distinto a la categoría' AS caso, @ok AS exito, @msg AS mensaje;

CALL sp_guardar_item('PRUEBA P4 Botas T42', NULL, 'ROPA', @cat_epp, @uni_par, 0,0,0, NULL,NULL, NULL, 0,0, @ok,@msg,@x,@y);
SELECT '7. Nombre repetido' AS caso, @ok AS exito, @msg AS mensaje;

SELECT COUNT(*) AS creados_por_rechazos_esperado_0 FROM TblInventario WHERE nombre = 'PRUEBA P4 X';

-- 4. Limpieza por nombre (no depende de @id) + COMMIT
DELETE m FROM TblMovimientoInventario m JOIN TblInventario i ON i.id_inventario = m.id_inventario WHERE i.nombre LIKE 'PRUEBA P4%';
DELETE r FROM TblInventarioRopa r       JOIN TblInventario i ON i.id_inventario = r.id_inventario WHERE i.nombre LIKE 'PRUEBA P4%';
DELETE t FROM TblInventarioTecnologia t JOIN TblInventario i ON i.id_inventario = t.id_inventario WHERE i.nombre LIKE 'PRUEBA P4%';
DELETE FROM TblInventario WHERE nombre LIKE 'PRUEBA P4%';
COMMIT;

SELECT COUNT(*) AS restantes_prueba_esperado_0 FROM TblInventario WHERE nombre LIKE 'PRUEBA P4%';
