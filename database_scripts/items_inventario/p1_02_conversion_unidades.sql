-- =============================================================================
-- PARTE 1 / 02 - CONVERSIONES GENERALES ENTRE UNIDADES
-- -----------------------------------------------------------------------------
-- Equivalencias fijas que no dependen del producto (1 TON = 1000 KG).
-- Se guarda un solo sentido: 1 origen = factor destino. El inverso es 1/factor.
-- Las equivalencias que dependen del producto (1 BOLSA de cemento = 42.5 KG)
-- van en TblInventarioConversion (p1_05).
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblUnidadConversion` (
  `id_conversion`     INT NOT NULL AUTO_INCREMENT,
  `id_unidad_origen`  INT NOT NULL COMMENT 'Unidad de partida',
  `id_unidad_destino` INT NOT NULL COMMENT 'Unidad equivalente',
  `factor`            DECIMAL(18,6) NOT NULL COMMENT '1 origen = factor destino',
  `observaciones`     VARCHAR(255) NULL,
  `estado`            ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `fecha_creacion`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_conversion`),
  UNIQUE KEY `uq_unidad_conversion` (`id_unidad_origen`, `id_unidad_destino`),
  KEY `idx_conv_destino` (`id_unidad_destino`),
  CONSTRAINT `fk_uconv_origen`  FOREIGN KEY (`id_unidad_origen`)  REFERENCES `TblUnidadMedida` (`id_unidad`),
  CONSTRAINT `fk_uconv_destino` FOREIGN KEY (`id_unidad_destino`) REFERENCES `TblUnidadMedida` (`id_unidad`),
  CONSTRAINT `ck_uconv_factor`    CHECK (`factor` > 0),
  CONSTRAINT `ck_uconv_distintas` CHECK (`id_unidad_origen` <> `id_unidad_destino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Equivalencias generales entre unidades de la misma magnitud';

INSERT INTO `TblUnidadConversion` (id_unidad_origen, id_unidad_destino, factor, observaciones)
SELECT o.id_unidad, d.id_unidad, x.factor, x.obs
FROM (
  SELECT 'TON' AS uo, 'KG' AS ud, 1000.000000 AS factor, 'Masa' AS obs
  UNION ALL SELECT 'KG',     'GR',  1000,     'Masa'
  UNION ALL SELECT 'M3',     'LT',  1000,     'Volumen'
  UNION ALL SELECT 'LT',     'ML',  1000,     'Volumen'
  UNION ALL SELECT 'GALÓN',  'LT',  3.785412, 'Galón americano'
  UNION ALL SELECT 'P2',     'M3',  0.002360, 'Pie tablar de madera (1/12 de pie cúbico)'
  UNION ALL SELECT 'M',      'CM',  100,      'Longitud'
  UNION ALL SELECT 'PIE',    'M',   0.304800, 'Longitud'
  UNION ALL SELECT 'DOCENA', 'UND', 12,       'Conteo'
  UNION ALL SELECT 'PARES',  'UND', 2,        'Conteo'
  UNION ALL SELECT 'MILLAR', 'UND', 1000,     'Conteo'
  UNION ALL SELECT 'DIA',    'HORA', 8,       'Jornada de 8 horas (alquiler de maquinaria)'
  UNION ALL SELECT 'MES',    'DIA', 30,       'Convención comercial de alquiler'
) x
JOIN `TblUnidadMedida` o ON o.codigo = x.uo COLLATE utf8mb4_unicode_ci
JOIN `TblUnidadMedida` d ON d.codigo = x.ud COLLATE utf8mb4_unicode_ci
ON DUPLICATE KEY UPDATE factor = x.factor, observaciones = x.obs;
