-- =============================================================================
-- PARTE 1 / 05 - CONVERSIONES POR ÍTEM (solo estructura)
-- -----------------------------------------------------------------------------
-- Equivalencias que dependen del producto:
--   1 BOLSA de cemento = 42.5 KG · 1 VARA de acero 1/2" = 8.94 KG
-- `factor`: p3_03 fija el sentido definitivo = cantidad de `id_unidad` que
--           contiene 1 unidad BASE del ítem (1 BOLSA = 42.5 KG).
-- Los datos se cargan en la Parte 3, después de limpiar los ítems.
-- No la usa ningún SP actual: agregarla no afecta nada existente.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblInventarioConversion` (
  `id_conversion`  INT NOT NULL AUTO_INCREMENT,
  `id_inventario`  INT NOT NULL COMMENT 'Ítem (TblInventario)',
  `id_unidad`      INT NOT NULL COMMENT 'Unidad alternativa',
  `factor`         DECIMAL(18,6) NOT NULL COMMENT '1 id_unidad = factor en la unidad base del ítem',
  `observaciones`  VARCHAR(255) NULL,
  `estado`         ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `creado_por`     INT NULL,
  `fecha_creacion` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_conversion`),
  UNIQUE KEY `uq_inventario_unidad` (`id_inventario`, `id_unidad`),
  KEY `idx_invconv_unidad` (`id_unidad`),
  CONSTRAINT `fk_invconv_inventario` FOREIGN KEY (`id_inventario`) REFERENCES `TblInventario` (`id_inventario`),
  CONSTRAINT `fk_invconv_unidad`     FOREIGN KEY (`id_unidad`)     REFERENCES `TblUnidadMedida` (`id_unidad`),
  CONSTRAINT `ck_invconv_factor`     CHECK (`factor` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Equivalencias de unidades propias de cada ítem';
