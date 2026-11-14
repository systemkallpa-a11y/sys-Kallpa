-- =============================================================================
-- PARTE 1 / 04 - UNIDADES PERMITIDAS POR CATEGORÍA
-- -----------------------------------------------------------------------------
-- Regla: al crear un ítem, solo se ofrecen las unidades de su categoría.
--   - Si la subcategoría (nivel 2) no tiene filas, hereda las de su padre.
--   - Cada categoría tiene como máximo una unidad predeterminada
--     (lo garantiza el índice único sobre la columna generada).
-- La regla se aplica a ítems NUEVOS. Los existentes se corrigen en la Parte 2.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblCategoriaUnidad` (
  `id_categoria`   INT NOT NULL,
  `id_unidad`      INT NOT NULL,
  `predeterminada` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = se preselecciona al crear el ítem',
  `pred_unica`     INT GENERATED ALWAYS AS (IF(`predeterminada` = 1, `id_categoria`, NULL)) STORED
                   COMMENT 'Técnica: garantiza una sola predeterminada por categoría',
  PRIMARY KEY (`id_categoria`, `id_unidad`),
  UNIQUE KEY `uq_catunidad_predeterminada` (`pred_unica`),
  KEY `idx_catunidad_unidad` (`id_unidad`),
  CONSTRAINT `fk_catunidad_categoria` FOREIGN KEY (`id_categoria`) REFERENCES `TblCategoriaInventario` (`id_categoria`),
  CONSTRAINT `fk_catunidad_unidad`    FOREIGN KEY (`id_unidad`)    REFERENCES `TblUnidadMedida` (`id_unidad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Unidades de medida permitidas por categoría (las subcategorías heredan del padre)';

INSERT INTO `TblCategoriaUnidad` (id_categoria, id_unidad, predeterminada)
SELECT c.id_categoria, u.id_unidad, x.pred
FROM (
  -- ---------------- Nivel 1 (base que heredan las subcategorías) ----------------
            SELECT 'MAT' AS cat, 'UND' AS uni, 1 AS pred
  UNION ALL SELECT 'MAT', 'KG', 0      UNION ALL SELECT 'MAT', 'TON', 0
  UNION ALL SELECT 'MAT', 'M', 0       UNION ALL SELECT 'MAT', 'M2', 0
  UNION ALL SELECT 'MAT', 'M3', 0      UNION ALL SELECT 'MAT', 'BOLSA', 0
  UNION ALL SELECT 'MAT', 'CAJA', 0    UNION ALL SELECT 'MAT', 'ROLLO', 0
  UNION ALL SELECT 'MAT', 'VARA', 0    UNION ALL SELECT 'MAT', 'GALÓN', 0
  UNION ALL SELECT 'MAT', 'LT', 0      UNION ALL SELECT 'MAT', 'PAQUETE', 0
  UNION ALL SELECT 'MAT', 'MILLAR', 0  UNION ALL SELECT 'MAT', 'P2', 0
  UNION ALL SELECT 'HER', 'UND', 1     UNION ALL SELECT 'HER', 'JGO', 0
  UNION ALL SELECT 'EQU', 'UND', 1
  UNION ALL SELECT 'TEC', 'UND', 1
  UNION ALL SELECT 'ROP', 'UND', 1     UNION ALL SELECT 'ROP', 'PARES', 0
  UNION ALL SELECT 'ROP', 'DOCENA', 0  UNION ALL SELECT 'ROP', 'CAJA', 0
  UNION ALL SELECT 'OFI', 'UND', 1     UNION ALL SELECT 'OFI', 'PAQUETE', 0
  UNION ALL SELECT 'OFI', 'CAJA', 0    UNION ALL SELECT 'OFI', 'DOCENA', 0
  UNION ALL SELECT 'OFI', 'RESMA', 0
  UNION ALL SELECT 'SER', 'GLB', 1     UNION ALL SELECT 'SER', 'HORA', 0
  UNION ALL SELECT 'SER', 'DIA', 0     UNION ALL SELECT 'SER', 'MES', 0
  UNION ALL SELECT 'SER', 'VIAJE', 0   UNION ALL SELECT 'SER', 'M3', 0
  UNION ALL SELECT 'SER', 'UND', 0
  UNION ALL SELECT 'PAR', 'GLB', 1     UNION ALL SELECT 'PAR', 'M', 0
  UNION ALL SELECT 'PAR', 'M2', 0      UNION ALL SELECT 'PAR', 'M3', 0
  UNION ALL SELECT 'PAR', 'KG', 0      UNION ALL SELECT 'PAR', 'UND', 0
  -- ---------------- Materiales: subcategorías con reglas propias ----------------
  UNION ALL SELECT 'MAT-CONCRETO', 'BOLSA', 1 UNION ALL SELECT 'MAT-CONCRETO', 'KG', 0
  UNION ALL SELECT 'MAT-CONCRETO', 'TON', 0   UNION ALL SELECT 'MAT-CONCRETO', 'M3', 0
  UNION ALL SELECT 'MAT-AGR', 'M3', 1         UNION ALL SELECT 'MAT-AGR', 'TON', 0
  UNION ALL SELECT 'MAT-AGR', 'BOLSA', 0      UNION ALL SELECT 'MAT-AGR', 'KG', 0
  UNION ALL SELECT 'MAT-YESO', 'BOLSA', 1     UNION ALL SELECT 'MAT-YESO', 'KG', 0
  UNION ALL SELECT 'MAT-ACERO', 'VARA', 1     UNION ALL SELECT 'MAT-ACERO', 'KG', 0
  UNION ALL SELECT 'MAT-ACERO', 'TON', 0      UNION ALL SELECT 'MAT-ACERO', 'M', 0
  UNION ALL SELECT 'MAT-FER', 'KG', 1         UNION ALL SELECT 'MAT-FER', 'UND', 0
  UNION ALL SELECT 'MAT-FER', 'CAJA', 0       UNION ALL SELECT 'MAT-FER', 'ROLLO', 0
  UNION ALL SELECT 'MAT-FER', 'MILLAR', 0
  UNION ALL SELECT 'MAT-LAD', 'MILLAR', 1     UNION ALL SELECT 'MAT-LAD', 'UND', 0
  UNION ALL SELECT 'MAT-TUBERIA', 'UND', 1    UNION ALL SELECT 'MAT-TUBERIA', 'VARA', 0
  UNION ALL SELECT 'MAT-TUBERIA', 'M', 0
  UNION ALL SELECT 'MAT-ELE', 'UND', 1        UNION ALL SELECT 'MAT-ELE', 'M', 0
  UNION ALL SELECT 'MAT-ELE', 'ROLLO', 0      UNION ALL SELECT 'MAT-ELE', 'CAJA', 0
  UNION ALL SELECT 'MAT-CABLE', 'M', 1        UNION ALL SELECT 'MAT-CABLE', 'ROLLO', 0
  UNION ALL SELECT 'MAT-SAN', 'UND', 1        UNION ALL SELECT 'MAT-SAN', 'JGO', 0
  UNION ALL SELECT 'MAT-PIN', 'GALÓN', 1      UNION ALL SELECT 'MAT-PIN', 'LT', 0
  UNION ALL SELECT 'MAT-PIN', 'UND', 0
  UNION ALL SELECT 'MAT-IMPERM', 'GALÓN', 1   UNION ALL SELECT 'MAT-IMPERM', 'LT', 0
  UNION ALL SELECT 'MAT-IMPERM', 'KG', 0      UNION ALL SELECT 'MAT-IMPERM', 'M2', 0
  UNION ALL SELECT 'MAT-IMPERM', 'UND', 0
  UNION ALL SELECT 'MAT-ADHESIVO', 'UND', 1   UNION ALL SELECT 'MAT-ADHESIVO', 'GALÓN', 0
  UNION ALL SELECT 'MAT-ADHESIVO', 'LT', 0    UNION ALL SELECT 'MAT-ADHESIVO', 'KG', 0
  UNION ALL SELECT 'MAT-ADHESIVO', 'BOLSA', 0
  UNION ALL SELECT 'MAT-CERAMICA', 'M2', 1    UNION ALL SELECT 'MAT-CERAMICA', 'CAJA', 0
  UNION ALL SELECT 'MAT-CERAMICA', 'UND', 0
  UNION ALL SELECT 'MAT-MADERA', 'P2', 1      UNION ALL SELECT 'MAT-MADERA', 'UND', 0
  UNION ALL SELECT 'MAT-MADERA', 'M', 0       UNION ALL SELECT 'MAT-MADERA', 'PIE', 0
  UNION ALL SELECT 'MAT-VIDRIO', 'M2', 1      UNION ALL SELECT 'MAT-VIDRIO', 'UND', 0
  UNION ALL SELECT 'MAT-MALLAS', 'M2', 1      UNION ALL SELECT 'MAT-MALLAS', 'ROLLO', 0
  UNION ALL SELECT 'MAT-MALLAS', 'M', 0
  UNION ALL SELECT 'MAT-TOLDOS', 'M2', 1      UNION ALL SELECT 'MAT-TOLDOS', 'ROLLO', 0
  UNION ALL SELECT 'MAT-TOLDOS', 'UND', 0
  UNION ALL SELECT 'MAT-AISLANTE', 'M2', 1    UNION ALL SELECT 'MAT-AISLANTE', 'ROLLO', 0
  UNION ALL SELECT 'MAT-PUERTA', 'UND', 1     UNION ALL SELECT 'MAT-PUERTA', 'M2', 0
  UNION ALL SELECT 'MAT-ESTRUC', 'KG', 1      UNION ALL SELECT 'MAT-ESTRUC', 'UND', 0
  UNION ALL SELECT 'MAT-ESTRUC', 'M', 0       UNION ALL SELECT 'MAT-ESTRUC', 'TON', 0
  UNION ALL SELECT 'MAT-DRY', 'UND', 1        UNION ALL SELECT 'MAT-DRY', 'M2', 0
  UNION ALL SELECT 'MAT-DECOR', 'UND', 1
  -- ---------------- Herramientas, Tecnología, Ropa, Oficina ----------------
  UNION ALL SELECT 'HER-SEN', 'UND', 1        UNION ALL SELECT 'HER-SEN', 'ROLLO', 0
  UNION ALL SELECT 'HER-SEN', 'M', 0
  UNION ALL SELECT 'TEC-ACC', 'UND', 1        UNION ALL SELECT 'TEC-ACC', 'PAQUETE', 0
  UNION ALL SELECT 'TEC-ACC', 'CAJA', 0
  UNION ALL SELECT 'ROP-UNI', 'UND', 1        UNION ALL SELECT 'ROP-UNI', 'DOCENA', 0
  UNION ALL SELECT 'ROP-EPP', 'UND', 1        UNION ALL SELECT 'ROP-EPP', 'PARES', 0
  UNION ALL SELECT 'ROP-EPP', 'CAJA', 0
  UNION ALL SELECT 'ROP-ACC', 'UND', 1        UNION ALL SELECT 'ROP-ACC', 'PARES', 0
  UNION ALL SELECT 'OFI-PAP', 'RESMA', 1      UNION ALL SELECT 'OFI-PAP', 'PAQUETE', 0
  UNION ALL SELECT 'OFI-PAP', 'UND', 0        UNION ALL SELECT 'OFI-PAP', 'CAJA', 0
  UNION ALL SELECT 'OFI-ESC', 'UND', 1        UNION ALL SELECT 'OFI-ESC', 'CAJA', 0
  UNION ALL SELECT 'OFI-ESC', 'DOCENA', 0
  UNION ALL SELECT 'OFI-MOB', 'UND', 1
) x
JOIN `TblCategoriaInventario` c ON c.codigo = x.cat COLLATE utf8mb4_0900_ai_ci
JOIN `TblUnidadMedida` u        ON u.codigo = x.uni COLLATE utf8mb4_unicode_ci
ON DUPLICATE KEY UPDATE predeterminada = x.pred;
