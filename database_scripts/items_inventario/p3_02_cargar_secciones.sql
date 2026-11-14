-- =============================================================================
-- PARTE 3 / 02 - CARGAR LAS SECCIONES DE LOS ÍTEMS EXISTENTES
-- -----------------------------------------------------------------------------
-- 1. Foto de las filas de sección que ya existen (para revertir).
-- 2. Crea la fila de sección de TODOS los ítems físicos (activos e inactivos)
--    que no la tengan (sp_sincronizar_secciones_inventario).
-- 3. Completa los datos que salen del nombre del ítem o de propiedades
--    físicas estándar (16 oz = 0.454 kg, 28" = 71 cm). No se inventan normas,
--    grados ni marcas que el ítem no indique: dependen del producto comprado.
--    El ítem 5 (iPhone, inactivo) ya tenía su ficha y no se toca.
-- =============================================================================

-- 1. Foto previa (solo la primera vez)
CREATE TABLE IF NOT EXISTS `aux_p3_secciones_antes` AS
          SELECT 'TblInventarioMaterial'    AS tabla, id_inventario FROM `TblInventarioMaterial`
UNION ALL SELECT 'TblInventarioHerramienta',  id_inventario FROM `TblInventarioHerramienta`
UNION ALL SELECT 'TblInventarioEquipo',       id_inventario FROM `TblInventarioEquipo`
UNION ALL SELECT 'TblInventarioTecnologia',   id_inventario FROM `TblInventarioTecnologia`
UNION ALL SELECT 'TblInventarioRopa',         id_inventario FROM `TblInventarioRopa`
UNION ALL SELECT 'TblInventarioConsumible',   id_inventario FROM `TblInventarioConsumible`;

-- 2. Fila de sección para cada ítem físico que no la tenga (usa el SP de p3_01)
CALL sp_sincronizar_secciones_inventario(@secciones_creadas);
SELECT @secciones_creadas AS secciones_creadas;

-- 3a. Datos de MATERIAL
INSERT INTO `TblInventarioMaterial`
  (id_inventario, presentacion, marca, `tipo`, medida, color, peso_unitario_kg, largo_cm)
VALUES
  (1,  'Bolsa 42.5 kg',  NULL,     'Portland Tipo I',           NULL,             NULL,    42.500, NULL),
  (8,  'Varilla de 9 m', NULL,     'Corrugado',                 '1/2"',           NULL,     8.946, 900),
  (9,  'Frasco 476 ml',  'Oatey',  'Cemento solvente para PVC', NULL,             'Azul',    NULL, NULL),
  (10, 'Galón',          NULL,     'Lubricante para PVC',       NULL,             NULL,      NULL, NULL),
  (13, NULL,             NULL,     'Arena gruesa',              NULL,             NULL,      NULL, NULL),
  (14, NULL,             NULL,     'Piedra chancada',           '3/4"',           NULL,      NULL, NULL),
  (15, NULL,             NULL,     'Arena gruesa sin cernir',   NULL,             NULL,      NULL, NULL),
  (17, NULL,             NULL,     'Material de préstamo',      NULL,             NULL,      NULL, NULL),
  (18, NULL,             NULL,     'Material de préstamo',      NULL,             NULL,      NULL, NULL),
  (22, 'Rollo',          'Magnun', 'Cinta teflón',              NULL,             'Rojo',    NULL, NULL),
  (23, NULL,             NULL,     'PVC',                       '4"',             NULL,      NULL, NULL),
  (24, 'Tubo de 6 m',    NULL,     'PVC C-7.5',                 '63 mm',          NULL,      NULL, 600),
  (25, NULL,             NULL,     'Válvula de control, acero', '63 mm',          NULL,      NULL, NULL),
  (26, NULL,             NULL,     'Válvula de aire, acero',    '63 mm',          NULL,      NULL, NULL),
  (27, NULL,             NULL,     'Tee PVC C-7.5',             '63 mm',          NULL,      NULL, NULL),
  (28, NULL,             NULL,     'Codo 90° PVC C-7.5',        '63 mm',          NULL,      NULL, NULL),
  (29, NULL,             NULL,     'Tapón PVC C-7.5',           '63 mm',          NULL,      NULL, NULL),
  (30, NULL,             NULL,     'Fierro fundido',            NULL,             NULL,      NULL, NULL),
  (31, NULL,             NULL,     'Reducción',                 '110 mm a 63 mm', NULL,      NULL, NULL),
  (33, NULL,             NULL,     'PVC C-10',                  '63 mm',          NULL,      NULL, NULL),
  (41, 'Bolsa 5 kg',     NULL,     'Yeso',                      NULL,             NULL,     5.000, NULL)
AS n
ON DUPLICATE KEY UPDATE
  presentacion = n.presentacion, marca = n.marca, `tipo` = n.`tipo`, medida = n.medida,
  color = n.color, peso_unitario_kg = n.peso_unitario_kg, largo_cm = n.largo_cm;

-- 3b. Datos de HERRAMIENTA
INSERT INTO `TblInventarioHerramienta` (id_inventario, tipo_herramienta, peso_kg, alto_cm)
VALUES
  (3,  'MANUAL', 0.454, NULL),
  (6,  'MANUAL', NULL,  NULL),
  (71, 'OTRO',   NULL,  71.00)
AS n
ON DUPLICATE KEY UPDATE tipo_herramienta = n.tipo_herramienta, peso_kg = n.peso_kg, alto_cm = n.alto_cm;

-- 3c. Datos de TECNOLOGIA
INSERT INTO `TblInventarioTecnologia` (id_inventario, marca, procesador, ram, almacenamiento, pantalla)
VALUES
  (4, 'HP', 'Intel Core i5', '8GB', '256GB SSD', '15.6"')
AS n
ON DUPLICATE KEY UPDATE marca = n.marca, procesador = n.procesador, ram = n.ram,
  almacenamiento = n.almacenamiento, pantalla = n.pantalla;

-- 3d. Datos de ROPA
INSERT INTO `TblInventarioRopa` (id_inventario, color, tipo_proteccion)
VALUES
  (2,  NULL,     'Cabeza'),
  (69, 'Blanco', 'Cabeza'),
  (70, 'Verde',  'Cabeza')
AS n
ON DUPLICATE KEY UPDATE color = n.color, tipo_proteccion = n.tipo_proteccion;
