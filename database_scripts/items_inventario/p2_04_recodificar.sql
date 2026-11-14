-- =============================================================================
-- PARTE 2 / 04 - RECODIFICAR A FORMATO CORTO  PREFIJO-001
-- -----------------------------------------------------------------------------
-- Prefijo = código de la categoría de nivel 1 del ítem:
--   MAT, HER, EQU, TEC, ROP, OFI, SER, PAR
-- Numeración por prefijo: primero los activos (por orden de categoría y
-- nombre), luego los inactivos. Mínimo 3 dígitos; crece a 4 si pasa de 999
-- (sin cortar el número, a diferencia de LPAD simple).
-- Las relaciones usan id_inventario, no el código: nada se rompe.
-- El código viejo queda en TblInventarioCodigoAnterior.
-- =============================================================================

-- 1. Guardar código anterior (solo la primera vez)
INSERT IGNORE INTO `TblInventarioCodigoAnterior` (id_inventario, codigo_anterior)
SELECT id_inventario, codigo FROM `TblInventario`;

-- 2. Paso intermedio para no chocar con el índice único de `codigo`
UPDATE `TblInventario` SET codigo = CONCAT('TMP-', id_inventario);

-- 3. Código definitivo
UPDATE `TblInventario` i
JOIN (
  SELECT x.id_inventario,
         CONCAT(x.prefijo, '-', LPAD(x.rn, GREATEST(3, CHAR_LENGTH(x.rn)), '0')) AS codigo
  FROM (
    SELECT inv.id_inventario,
           COALESCE(padre.codigo, cat.codigo) AS prefijo,
           ROW_NUMBER() OVER (
             PARTITION BY COALESCE(padre.codigo, cat.codigo)
             ORDER BY (inv.estado = 'ACTIVO') DESC, cat.orden, inv.nombre, inv.id_inventario
           ) AS rn
    FROM `TblInventario` inv
    JOIN `TblCategoriaInventario` cat ON cat.id_categoria = inv.id_categoria
    LEFT JOIN `TblCategoriaInventario` padre ON padre.id_categoria = cat.id_categoria_padre
  ) x
) n ON n.id_inventario = i.id_inventario
SET i.codigo = n.codigo;

-- 4. Completar el registro
UPDATE `TblInventarioCodigoAnterior` a
JOIN `TblInventario` i ON i.id_inventario = a.id_inventario
SET a.codigo_nuevo = i.codigo;
