-- =============================================================================
-- PARTE 2 / 02 - UNIFICAR DUPLICADOS E INACTIVAR DATOS DE PRUEBA
-- -----------------------------------------------------------------------------
-- Para cada duplicado: sus referencias pasan al ítem que se conserva y el
-- duplicado queda INACTIVO. No se borra ninguna fila.
-- Todos los duplicados tienen stock 0 (verificado): no hay stock que mover.
-- Tablas reapuntadas: TblPresupuestoDetalle, TblRequerimientoDetalle,
--   TblMovimientoInventario, TblEntregaPersonalDetalle,
--   TblPresupuestoVersionDetalleHistorial, TblInventarioProveedor,
--   TblInventarioAtributos, TblInventarioAlmacen
-- =============================================================================

-- 1. Mapa de unificación
INSERT INTO `TblInventarioUnificacion` (id_duplicado, id_conservado, motivo)
VALUES
  (20, 1,  'Duplicado: Cemento Portland'),
  (21, 1,  'Dato de prueba: Cemento Portland Test'),
  (11, 9,  'Duplicado importado de PDF: Pegamento 476 ml'),
  (12, 10, 'Duplicado importado de PDF: Lubricante 1 GL'),
  (19, 18, 'Duplicado: Caliche'),
  (7,  6,  'Duplicado importado de PDF: Hoja de sierra'),
  (34, 25, 'Duplicado importado de PDF: Válvula de control 63 mm'),
  (35, 26, 'Duplicado importado de PDF: Válvula de aire 63 mm'),
  (36, 27, 'Duplicado importado de PDF: Tee 63 mm'),
  (37, 28, 'Duplicado importado de PDF: Codo 90° 63 mm'),
  (38, 29, 'Duplicado importado de PDF: Tapón 63 mm'),
  (39, 30, 'Duplicado importado de PDF: Tapa de fierro fundido'),
  (40, 31, 'Duplicado importado de PDF: Reducción 110 a 63 mm'),
  (42, 41, 'Duplicado importado de PDF: Yeso 5 kg'),
  (5,  NULL, 'Dato de prueba: iphone 17'),
  (58, NULL, 'Partida truncada en importación de PDF (sin uso)'),
  (59, NULL, 'Partida con dos nombres concatenados en importación de PDF (sin uso)'),
  (60, NULL, 'Partida truncada en importación de PDF (sin uso)'),
  (61, NULL, 'Partida truncada en importación de PDF (sin uso)'),
  (62, NULL, 'Partida con dos nombres concatenados en importación de PDF (sin uso)')
AS nuevo
ON DUPLICATE KEY UPDATE id_conservado = nuevo.id_conservado, motivo = nuevo.motivo;

-- 2. Registrar las filas que se van a reapuntar (para revertir)
INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblPresupuestoDetalle', d.id_detalle, d.id_inventario, u.id_conservado
FROM `TblPresupuestoDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblRequerimientoDetalle', d.id_detalle, d.id_inventario, u.id_conservado
FROM `TblRequerimientoDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblMovimientoInventario', d.id_movimiento, d.id_inventario, u.id_conservado
FROM `TblMovimientoInventario` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblEntregaPersonalDetalle', d.id_entrega_detalle, d.id_inventario, u.id_conservado
FROM `TblEntregaPersonalDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblPresupuestoVersionDetalleHistorial', d.id_detalle_version, d.id_inventario, u.id_conservado
FROM `TblPresupuestoVersionDetalleHistorial` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblInventarioProveedor', d.id_inventario_proveedor, d.id_inventario, u.id_conservado
FROM `TblInventarioProveedor` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

INSERT IGNORE INTO `aux_p2_reapuntes` (tabla, id_fila, id_anterior, id_nuevo)
SELECT 'TblInventarioAtributos', d.id_atributo, d.id_inventario, u.id_conservado
FROM `TblInventarioAtributos` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
WHERE u.id_conservado IS NOT NULL;

-- 3. Reapuntar referencias al ítem conservado
UPDATE `TblPresupuestoDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblRequerimientoDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblMovimientoInventario` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblEntregaPersonalDetalle` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblPresupuestoVersionDetalleHistorial` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblInventarioProveedor` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

UPDATE `TblInventarioAtributos` d JOIN `TblInventarioUnificacion` u ON u.id_duplicado = d.id_inventario
SET d.id_inventario = u.id_conservado WHERE u.id_conservado IS NOT NULL;

-- 4. Inactivar duplicados y datos de prueba
UPDATE `TblInventario` i JOIN `TblInventarioUnificacion` u ON u.id_duplicado = i.id_inventario
SET i.estado = 'INACTIVO', i.fecha_actualizacion = NOW()
WHERE i.estado <> 'INACTIVO';
