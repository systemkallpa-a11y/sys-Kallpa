-- =============================================================================
-- PARTE 2 / 01 - TABLAS DE AUDITORÍA Y FOTOS PREVIAS
-- -----------------------------------------------------------------------------
-- Permanentes (documentan lo que se hizo, útiles para buscar):
--   TblInventarioUnificacion   duplicados unificados e ítems inactivados
--   TblInventarioCodigoAnterior código viejo -> código nuevo
-- Auxiliares (para verificar y revertir; se eliminan al cerrar la Parte 2):
--   aux_p2_items_antes, aux_p2_totales_presupuesto,
--   aux_p2_totales_requerimiento, aux_p2_reapuntes
-- Las fotos se toman UNA sola vez: si se re-ejecuta, no se pisan.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblInventarioUnificacion` (
  `id_unificacion` INT NOT NULL AUTO_INCREMENT,
  `id_duplicado`   INT NOT NULL COMMENT 'Ítem que queda INACTIVO',
  `id_conservado`  INT NULL COMMENT 'Ítem que recibe sus referencias (NULL = solo inactivado)',
  `motivo`         VARCHAR(255) NOT NULL,
  `fecha`          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_unificacion`),
  UNIQUE KEY `uq_unif_duplicado` (`id_duplicado`),
  KEY `idx_unif_conservado` (`id_conservado`),
  CONSTRAINT `fk_unif_duplicado`  FOREIGN KEY (`id_duplicado`)  REFERENCES `TblInventario` (`id_inventario`),
  CONSTRAINT `fk_unif_conservado` FOREIGN KEY (`id_conservado`) REFERENCES `TblInventario` (`id_inventario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Historial de ítems unificados o inactivados en la limpieza';

CREATE TABLE IF NOT EXISTS `TblInventarioCodigoAnterior` (
  `id_inventario`   INT NOT NULL,
  `codigo_anterior` VARCHAR(50) NOT NULL,
  `codigo_nuevo`    VARCHAR(50) NULL,
  `fecha`           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_inventario`),
  KEY `idx_codant_anterior` (`codigo_anterior`),
  CONSTRAINT `fk_codant_inventario` FOREIGN KEY (`id_inventario`) REFERENCES `TblInventario` (`id_inventario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Códigos de inventario antes de la recodificación';

-- Foto de los ítems antes de cualquier cambio
CREATE TABLE IF NOT EXISTS `aux_p2_items_antes` AS
SELECT id_inventario, codigo, nombre, descripcion, tipo_inventario,
       id_categoria, id_unidad, stock_actual, estado
FROM `TblInventario`;

-- Foto de totales para comprobar que nada cambia al reapuntar
CREATE TABLE IF NOT EXISTS `aux_p2_totales_presupuesto` AS
SELECT id_presupuesto, COUNT(*) AS lineas, SUM(cantidad) AS cantidad, SUM(subtotal) AS total
FROM `TblPresupuestoDetalle`
GROUP BY id_presupuesto;

CREATE TABLE IF NOT EXISTS `aux_p2_totales_requerimiento` AS
SELECT id_requerimiento, COUNT(*) AS lineas, SUM(cantidad) AS cantidad
FROM `TblRequerimientoDetalle`
GROUP BY id_requerimiento;

-- Registro de cada fila reapuntada (para poder revertir)
CREATE TABLE IF NOT EXISTS `aux_p2_reapuntes` (
  `tabla`          VARCHAR(64) NOT NULL,
  `id_fila`        INT NOT NULL,
  `id_anterior`    INT NOT NULL,
  `id_nuevo`       INT NOT NULL,
  PRIMARY KEY (`tabla`, `id_fila`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
