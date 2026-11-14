-- =============================================================================
-- PARTE 1 / 99 - REVERTIR
-- -----------------------------------------------------------------------------
-- Deja catálogos como estaban el 13/11/2026 antes de la Parte 1.
-- Solo borra unidades/categorías nuevas si ningún ítem las usa.
-- =============================================================================

DROP TABLE IF EXISTS `TblInventarioConversion`;
DROP TABLE IF EXISTS `TblCategoriaUnidad`;
DROP TABLE IF EXISTS `TblUnidadConversion`;

-- Categorías nuevas (si no se usan)
DELETE c FROM `TblCategoriaInventario` c
WHERE c.codigo IN ('MAT-LAD','MAT-FER','MAT-DRY','HER-SEN','EQU-MEN')
  AND NOT EXISTS (SELECT 1 FROM `TblInventario` i WHERE i.id_categoria = c.id_categoria);

-- Categorías modificadas: valores originales
UPDATE `TblCategoriaInventario`
SET codigo = 'MAT-CEM', nombre = 'Cemento y Agregados',
    descripcion = 'Cemento, arena, piedra, etc.', icono = 'fa-box'
WHERE codigo = 'MAT-AGR';

UPDATE `TblCategoriaInventario`
SET descripcion = 'Migrada desde TblCategoriaMaterial: Cemento y Concreto', icono = NULL
WHERE codigo = 'MAT-CONCRETO';

UPDATE `TblCategoriaInventario` SET icono = NULL WHERE codigo IN ('SER','PAR');

-- Unidades nuevas (si no se usan)
DELETE u FROM `TblUnidadMedida` u
WHERE u.codigo IN ('GLB','PIE','P2','MES','DIA','MILLAR','JGO','RESMA','VIAJE')
  AND NOT EXISTS (SELECT 1 FROM `TblInventario` i WHERE i.id_unidad = u.id_unidad);

-- Unidades modificadas: valores originales
UPDATE `TblUnidadMedida` SET abreviatura = 'mtr' WHERE codigo IN ('M2','M3');
UPDATE `TblUnidadMedida` SET nombre = 'Metro', descripcion = 'Longitud en metros' WHERE codigo = 'M';
UPDATE `TblUnidadMedida` SET descripcion = 'Volumen en mililitros' WHERE codigo = 'ML';
UPDATE `TblUnidadMedida` SET estado = 'ACTIVO' WHERE codigo = 'TAZA';

-- Columna magnitud
SET @existe := (SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'TblUnidadMedida'
                  AND COLUMN_NAME = 'magnitud');
SET @sql := IF(@existe = 1, 'ALTER TABLE `TblUnidadMedida` DROP COLUMN `magnitud`', 'SELECT ''sin magnitud'' AS info');
PREPARE st FROM @sql;
EXECUTE st;
DEALLOCATE PREPARE st;
