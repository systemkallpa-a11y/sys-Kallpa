-- =============================================================================
-- PARTE 3 / 03 - CONVERSIONES POR ÍTEM
-- -----------------------------------------------------------------------------
-- Sentido de `factor`: cuántas `id_unidad` contiene 1 unidad BASE del ítem.
--   Cemento (base BOLSA):  1 BOLSA = 42.5 KG
--   Acero 1/2" (base VARA): 1 VARA = 9 M = 8.946 KG (0.994 kg/m nominal)
-- Este sentido es exacto (evita decimales periódicos como 1/42.5).
-- Las unidades derivadas salen de TblUnidadConversion:
--   1 BOLSA = 42.5 KG y 1 TON = 1000 KG  ->  1 TON = 23.53 BOLSAS
-- Densidades de agregados: valores aproximados de material suelto.
-- =============================================================================

ALTER TABLE `TblInventarioConversion`
  MODIFY COLUMN `factor` DECIMAL(18,6) NOT NULL
  COMMENT 'Cantidad de id_unidad que contiene 1 unidad base del ítem (1 BOLSA = 42.5 KG)';

INSERT INTO `TblInventarioConversion` (id_inventario, id_unidad, factor, observaciones)
SELECT x.id_inventario, u.id_unidad, x.factor, x.obs
FROM (
            SELECT 1 AS id_inventario, 'KG' AS uni, 42.500000 AS factor, 'Bolsa de cemento de 42.5 kg' AS obs
  UNION ALL SELECT 41, 'KG',  5.000000, 'Bolsa de yeso de 5 kg'
  UNION ALL SELECT 8,  'M',   9.000000, 'Varilla de 9 m'
  UNION ALL SELECT 8,  'KG',  8.946000, 'Peso nominal 1/2": 0.994 kg/m x 9 m'
  UNION ALL SELECT 24, 'M',   6.000000, 'Tubo de 6 m'
  UNION ALL SELECT 9,  'ML',  476.000000, 'Frasco de 476 ml'
  UNION ALL SELECT 13, 'TON', 1.600000, 'Aproximado: arena gruesa suelta 1.6 t/m3'
  UNION ALL SELECT 15, 'TON', 1.600000, 'Aproximado: arena gruesa suelta 1.6 t/m3'
  UNION ALL SELECT 14, 'TON', 1.500000, 'Aproximado: piedra chancada suelta 1.5 t/m3'
) x
JOIN `TblUnidadMedida` u ON u.codigo = x.uni COLLATE utf8mb4_unicode_ci
ON DUPLICATE KEY UPDATE factor = x.factor, observaciones = x.obs;
