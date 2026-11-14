-- =============================================================================
-- PARTE 1 / 03 - CATEGORÍAS
-- -----------------------------------------------------------------------------
-- 1. Separa "Cemento y Agregados" (MAT-CEM) y "Cemento y Concreto"
--    (MAT-CONCRETO), que se superponían:
--      - MAT-CEM pasa a ser MAT-AGR "Agregados" (arena, piedra, hormigón...)
--      - MAT-CONCRETO queda para cemento y concreto
--    Los ítems se reubican en la Parte 2.
-- 2. Subcategorías nuevas, frecuentes en edificación:
--      MAT-LAD Ladrillos y Bloques · MAT-FER Ferretería ·
--      MAT-DRY Drywall y Fibrocemento · HER-SEN Señalización y Seguridad ·
--      EQU-MEN Equipos Menores
-- 3. Íconos de Servicios y Partidas.
-- Ningún SP ni código usa los códigos MAT-CEM o MAT-CONCRETO (verificado).
-- =============================================================================

-- 1. Separar agregados de cemento
UPDATE `TblCategoriaInventario`
SET codigo = 'MAT-AGR',
    nombre = 'Agregados',
    descripcion = 'Arena, piedra chancada, hormigón, afirmado y material de préstamo',
    icono = 'fa-mountain'
WHERE codigo = 'MAT-CEM';

UPDATE `TblCategoriaInventario`
SET descripcion = 'Cemento, concreto premezclado y aditivos',
    icono = 'fa-box'
WHERE codigo = 'MAT-CONCRETO';

-- 2. Subcategorías nuevas (solo si no existen)
INSERT INTO `TblCategoriaInventario` (codigo, nombre, descripcion, id_categoria_padre, nivel, tipo_aplicable, icono, orden, estado)
SELECT 'MAT-LAD', 'Ladrillos y Bloques', 'Ladrillos de arcilla, bloques de concreto, bloquetas', p.id_categoria, 2, 'MATERIAL', 'fa-border-all', 103, 'ACTIVO'
FROM `TblCategoriaInventario` p
WHERE p.codigo = 'MAT' AND NOT EXISTS (SELECT 1 FROM (SELECT codigo FROM `TblCategoriaInventario`) t WHERE t.codigo = 'MAT-LAD');

INSERT INTO `TblCategoriaInventario` (codigo, nombre, descripcion, id_categoria_padre, nivel, tipo_aplicable, icono, orden, estado)
SELECT 'MAT-FER', 'Ferretería', 'Clavos, alambre, pernos, tornillos, anclajes', p.id_categoria, 2, 'MATERIAL', 'fa-screwdriver', 107, 'ACTIVO'
FROM `TblCategoriaInventario` p
WHERE p.codigo = 'MAT' AND NOT EXISTS (SELECT 1 FROM (SELECT codigo FROM `TblCategoriaInventario`) t WHERE t.codigo = 'MAT-FER');

INSERT INTO `TblCategoriaInventario` (codigo, nombre, descripcion, id_categoria_padre, nivel, tipo_aplicable, icono, orden, estado)
SELECT 'MAT-DRY', 'Drywall y Fibrocemento', 'Planchas de yeso, fibrocemento, perfiles y accesorios', p.id_categoria, 2, 'MATERIAL', 'fa-layer-group', 108, 'ACTIVO'
FROM `TblCategoriaInventario` p
WHERE p.codigo = 'MAT' AND NOT EXISTS (SELECT 1 FROM (SELECT codigo FROM `TblCategoriaInventario`) t WHERE t.codigo = 'MAT-DRY');

INSERT INTO `TblCategoriaInventario` (codigo, nombre, descripcion, id_categoria_padre, nivel, tipo_aplicable, icono, orden, estado)
SELECT 'HER-SEN', 'Señalización y Seguridad', 'Conos, cintas de peligro, mallas y letreros de obra', p.id_categoria, 2, 'HERRAMIENTA', 'fa-triangle-exclamation', 4, 'ACTIVO'
FROM `TblCategoriaInventario` p
WHERE p.codigo = 'HER' AND NOT EXISTS (SELECT 1 FROM (SELECT codigo FROM `TblCategoriaInventario`) t WHERE t.codigo = 'HER-SEN');

INSERT INTO `TblCategoriaInventario` (codigo, nombre, descripcion, id_categoria_padre, nivel, tipo_aplicable, icono, orden, estado)
SELECT 'EQU-MEN', 'Equipos Menores', 'Mezcladoras, vibradoras, compactadoras, cortadoras', p.id_categoria, 2, 'EQUIPO', 'fa-gears', 3, 'ACTIVO'
FROM `TblCategoriaInventario` p
WHERE p.codigo = 'EQU' AND NOT EXISTS (SELECT 1 FROM (SELECT codigo FROM `TblCategoriaInventario`) t WHERE t.codigo = 'EQU-MEN');

-- 3. Íconos faltantes
UPDATE `TblCategoriaInventario` SET icono = 'fa-handshake'      WHERE codigo = 'SER' AND icono IS NULL;
UPDATE `TblCategoriaInventario` SET icono = 'fa-clipboard-list' WHERE codigo = 'PAR' AND icono IS NULL;
