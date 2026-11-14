-- ============================================================================
-- 04: LIMPIEZA DE TABLAS AUXILIARES Y DE RESPALDO (13/11/2026)
-- -----------------------------------------------------------------------------
-- Tablas que existen en la BD (verificado el 13/11/2026). Ningún SP, vista,
-- trigger ni código de la app las usa; solo las usan los scripts de reversión.
--
--   aux_p2_items_antes, aux_p2_items_destino, aux_p2_reapuntes,
--   aux_p2_totales_presupuesto, aux_p2_totales_requerimiento
--       -> items_inventario/p2_01..p2_03 (fotos para p2_99_revertir.sql)
--   aux_p3_secciones_antes
--       -> items_inventario/p3_02 (foto para p3_99_revertir.sql)
--   respaldo_TblCargo_20261113               (cargos 73 y 74)
--   respaldo_TblRegistroAprobacion_20261113  (3 registros de obra con cargo 65)
--   respaldo_flujo_obra_paso1_20261113       (vacía)
--
-- AL BORRARLAS YA NO SE PUEDEN USAR p2_99_revertir.sql NI p3_99_revertir.sql.
-- Ejecutar solo cuando inventario, requerimientos y aprobaciones estén probados.
-- Re-ejecutable (DROP ... IF EXISTS).
-- ============================================================================

-- 1) Ver qué existe antes de borrar
SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND (TABLE_NAME LIKE 'respaldo\_%' OR TABLE_NAME LIKE 'aux\_p%')
ORDER BY TABLE_NAME;

-- 2) Auxiliares del plan de ítems de inventario (P2 / P3)
DROP TABLE IF EXISTS `aux_p2_items_antes`;
DROP TABLE IF EXISTS `aux_p2_items_destino`;
DROP TABLE IF EXISTS `aux_p2_reapuntes`;
DROP TABLE IF EXISTS `aux_p2_totales_presupuesto`;
DROP TABLE IF EXISTS `aux_p2_totales_requerimiento`;
DROP TABLE IF EXISTS `aux_p3_secciones_antes`;

-- 3) Respaldos de cargos / flujo de aprobación
DROP TABLE IF EXISTS `respaldo_TblCargo_20261113`;
DROP TABLE IF EXISTS `respaldo_TblRegistroAprobacion_20261113`;
DROP TABLE IF EXISTS `respaldo_flujo_obra_paso1_20261113`;

-- 4) Verificación (esperado: 0 filas)
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND (TABLE_NAME LIKE 'respaldo\_%' OR TABLE_NAME LIKE 'aux\_p%');
