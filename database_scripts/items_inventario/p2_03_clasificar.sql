-- =============================================================================
-- PARTE 2 / 03 - TIPO, CATEGORÍA, UNIDAD, NOMBRE Y DESCRIPCIÓN
-- -----------------------------------------------------------------------------
-- Cada fila de aux_p2_items_destino es el estado final de un ítem ACTIVO.
-- Tipo, categoría, unidad y nombre van siempre completos.
-- Descripción NULL = se iguala al nombre (Servicios y Partidas: hoy son el
-- mismo texto en MAYÚSCULAS importado del PDF).
-- No se mezclan columnas de TblInventario con la tabla auxiliar en
-- COALESCE/IN: tienen collations distintas (error 1270).
-- Unidades de partidas validadas con las cantidades de los presupuestos:
--   limpieza/trazo/perfilado 3160.12 -> M2 · concreto veredas 316.01 -> M3 ·
--   juntas y encofrado de juntas 1004.66 -> M
-- Ningún ítem que cambia de tipo tiene ficha (las FK no se ven afectadas).
-- =============================================================================

CREATE TABLE IF NOT EXISTS `aux_p2_items_destino` (
  `id_inventario`   INT NOT NULL PRIMARY KEY,
  `tipo_inventario` VARCHAR(20) NULL,
  `cat`             VARCHAR(20) NULL,
  `uni`             VARCHAR(20) NULL,
  `nombre`          VARCHAR(200) NULL,
  `descripcion`     TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `aux_p2_items_destino` (id_inventario, tipo_inventario, cat, uni, nombre, descripcion)
VALUES
  -- ------------------------------------------------ MATERIAL
  (1,  'MATERIAL', 'MAT-CONCRETO', 'BOLSA', 'Cemento Portland Tipo I x 42.5 kg', 'Cemento de construcción de uso general, bolsa de 42.5 kg'),
  (8,  'MATERIAL', 'MAT-ACERO',    'VARA',  'Acero corrugado 1/2" x 9 m', 'Varilla de acero corrugado de 1/2 pulgada, 9 m'),
  (9,  'MATERIAL', 'MAT-ADHESIVO', 'UND',   'Pegamento para PVC azul Oatey x 476 ml', 'Pegamento para tubería PVC, frasco de 476 ml'),
  (10, 'MATERIAL', 'MAT-ADHESIVO', 'GALÓN', 'Lubricante para tubería PVC x 1 gal', 'Lubricante para unión de tubería PVC'),
  (13, 'MATERIAL', 'MAT-AGR',      'M3',    'Arena gruesa', 'Arena gruesa para concreto'),
  (14, 'MATERIAL', 'MAT-AGR',      'M3',    'Piedra chancada 3/4"', 'Piedra chancada (grava) de 3/4 pulgada'),
  (15, 'MATERIAL', 'MAT-AGR',      'M3',    'Arena gruesa para cama y sobrecama de tubería', 'Arena gruesa sin cernir para cama y sobrecama de red de agua'),
  (16, 'MATERIAL', 'MAT-AGR',      'M3',    'Agregados varios', 'Agregados para obra sin especificar'),
  (17, 'MATERIAL', 'MAT-AGR',      'M3',    'Material de relleno', 'Material de préstamo para relleno'),
  (18, 'MATERIAL', 'MAT-AGR',      'M3',    'Caliche', 'Material de préstamo (caliche)'),
  (22, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Cinta teflón roja Magnun', 'Cinta teflón para sellado de roscas, rollo'),
  (23, 'MATERIAL', 'MAT-TUBERIA',  'VARA',  'Tubo PVC 4"', 'Tubería PVC de 4 pulgadas'),
  (24, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Tubería PVC C-7.5 63 mm x 6 m', 'Tubería PVC clase 7.5 de 63 mm, tubo de 6 m'),
  (25, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Válvula de control de acero 63 mm', 'Válvula de control de acero de 63 mm'),
  (26, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Válvula de aire de acero 63 mm', 'Válvula de aire de acero de 63 mm'),
  (27, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Tee PVC C-7.5 63 mm', 'Tee de PVC clase 7.5 de 63 mm'),
  (28, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Codo PVC 90° C-7.5 63 mm', 'Codo de 90° de PVC clase 7.5 de 63 mm'),
  (29, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Tapón PVC C-7.5 63 mm', 'Tapón de PVC clase 7.5 de 63 mm, simple presión'),
  (30, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Tapa de fierro fundido para válvulas de agua', 'Tapa de fierro fundido para caja de válvulas de agua'),
  (31, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Reducción de 110 mm a 63 mm', 'Reducción de 110 mm a 63 mm'),
  (32, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Caja prefabricada para válvulas de control', 'Caja prefabricada para válvulas de control'),
  (33, 'MATERIAL', 'MAT-TUBERIA',  'UND',   'Tubería PVC C-10 63 mm', 'Tubería PVC clase 10 de 63 mm'),
  (41, 'MATERIAL', 'MAT-YESO',     'BOLSA', 'Yeso x 5 kg', 'Yeso en bolsa de 5 kg'),
  -- ------------------------------------------------ HERRAMIENTA
  (3,  'HERRAMIENTA', 'HER-MAN', 'UND', 'Martillo de uña 16 oz', 'Martillo de carpintero con mango de fibra'),
  (6,  'HERRAMIENTA', 'HER-MAN', 'UND', 'Hoja de sierra', 'Hoja de sierra para arco'),
  (71, 'HERRAMIENTA', 'HER-SEN', 'UND', 'Cono de seguridad naranja reflectivo 28"', 'Cono de señalización naranja con cinta reflectiva, 28 pulgadas'),
  -- ------------------------------------------------ TECNOLOGIA
  (4,  'TECNOLOGIA', 'TEC-COM', 'UND', 'Laptop HP 15.6" Core i5 8GB 256GB SSD', 'Computadora portátil para oficina'),
  -- ------------------------------------------------ ROPA
  (2,  'ROPA', 'ROP-EPP', 'UND', 'Casco de seguridad', 'Casco tipo jockey con barbiquejo'),
  (69, 'ROPA', 'ROP-EPP', 'UND', 'Casco de seguridad blanco', 'Casco para personal staff'),
  (70, 'ROPA', 'ROP-EPP', 'UND', 'Casco de seguridad verde', 'Casco para personal eléctrico'),
  -- ------------------------------------------------ SERVICIO
  (72, 'SERVICIO', 'SER', 'VIAJE', 'Flete terrestre', NULL),
  (73, 'SERVICIO', 'SER', 'M3',    'Carguío y transporte (eliminación de material excedente)', NULL),
  (74, 'SERVICIO', 'SER', 'GLB',   'Costo de construcción por administración directa - servicios', NULL),
  (75, 'SERVICIO', 'SER', 'HORA',  'Alquiler de maquinaria pesada', NULL),
  (76, 'SERVICIO', 'SER', 'HORA',  'Alquiler de retroexcavadora 65 HP para zanjas', NULL),
  (77, 'SERVICIO', 'SER', 'GLB',   'Mano de obra para ejecución de veredas', NULL),
  (78, 'SERVICIO', 'SER', 'MES',   'Alquiler de almacén', NULL),
  -- ------------------------------------------------ PARTIDA
  (43, 'PARTIDA', 'PAR', 'M2',  'Limpieza manual en terreno normal', NULL),
  (44, 'PARTIDA', 'PAR', 'M2',  'Trazo y replanteo durante el proceso constructivo', NULL),
  (45, 'PARTIDA', 'PAR', 'M3',  'Corte superficial manual de sub base', NULL),
  (46, 'PARTIDA', 'PAR', 'M3',  'Acarreo de material de corte', NULL),
  (47, 'PARTIDA', 'PAR', 'M2',  'Perfilado y compactación de sub base de vereda', NULL),
  (48, 'PARTIDA', 'PAR', 'M2',  'Extendido, riego y compactación de material seleccionado para sub base', NULL),
  (49, 'PARTIDA', 'PAR', 'M2',  'Encofrado y desencofrado de sardinel', NULL),
  (50, 'PARTIDA', 'PAR', 'M3',  'Concreto en sardinel f''c=175 kg/cm²', NULL),
  (51, 'PARTIDA', 'PAR', 'M3',  'Concreto en veredas f''c=175 kg/cm²', NULL),
  (52, 'PARTIDA', 'PAR', 'M',   'Relleno de juntas de dilatación en veredas', NULL),
  (53, 'PARTIDA', 'PAR', 'M',   'Pintado de sardinel línea continua', NULL),
  (54, 'PARTIDA', 'PAR', 'M3',  'Excavación manual de sardinel en terreno compactado', NULL),
  (55, 'PARTIDA', 'PAR', 'M',   'Encofrado de separación de acera peatonal (juntas)', NULL),
  (56, 'PARTIDA', 'PAR', 'UND', 'Suministro y colocación de cajas prefabricadas de desagüe', NULL),
  (57, 'PARTIDA', 'PAR', 'UND', 'Suministro y colocación de cajas prefabricadas de agua', NULL),
  (63, 'PARTIDA', 'PAR', 'GLB', 'Costo de construcción por administración directa - bienes', NULL),
  (64, 'PARTIDA', 'PAR', 'GLB', 'Materiales de ferretería y otros', NULL),
  (65, 'PARTIDA', 'PAR', 'M',   'Construcción de red matriz de agua (incluye prueba hidráulica)', NULL),
  (66, 'PARTIDA', 'PAR', 'GLB', 'Varios', NULL),
  (67, 'PARTIDA', 'PAR', 'GLB', 'Imprevistos', NULL),
  (68, 'PARTIDA', 'PAR', 'GLB', 'Presupuesto de ejecución de obra', NULL)
AS n
ON DUPLICATE KEY UPDATE
  tipo_inventario = n.tipo_inventario, cat = n.cat, uni = n.uni,
  nombre = n.nombre, descripcion = n.descripcion;

-- Aplicar (solo a ítems activos)
UPDATE `TblInventario` i
JOIN `aux_p2_items_destino` a ON a.id_inventario = i.id_inventario
LEFT JOIN `TblCategoriaInventario` c ON c.codigo = a.cat COLLATE utf8mb4_0900_ai_ci
LEFT JOIN `TblUnidadMedida` u        ON u.codigo = a.uni COLLATE utf8mb4_unicode_ci
SET i.tipo_inventario     = a.tipo_inventario,
    i.id_categoria        = COALESCE(c.id_categoria, i.id_categoria),
    i.id_unidad           = COALESCE(u.id_unidad, i.id_unidad),
    i.nombre              = a.nombre,
    i.descripcion         = IF(a.descripcion IS NULL, a.nombre, a.descripcion),
    i.fecha_actualizacion = NOW()
WHERE i.estado = 'ACTIVO';
