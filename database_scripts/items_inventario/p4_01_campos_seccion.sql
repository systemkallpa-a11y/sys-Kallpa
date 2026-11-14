-- =============================================================================
-- PARTE 4 / 01 - PRESENTACIÓN DE LOS CAMPOS DE CADA SECCIÓN
-- -----------------------------------------------------------------------------
-- La ESTRUCTURA de cada campo se lee de la BD (information_schema):
--   tipo de dato -> control (texto/número/lista), largo máximo, decimales,
--   opciones de las listas (ENUM).
-- Esta tabla guarda solo la PRESENTACIÓN: etiqueta, texto de ayuda, orden y
-- si se muestra. Si se agrega una columna a una sección y no se registra aquí,
-- igual aparece en el formulario con su nombre formateado ("material_tela" ->
-- "Material tela").
-- Se eligió una tabla en vez de COMMENT de columna para no reescribir la
-- definición de columnas en tablas con datos.
-- =============================================================================

CREATE TABLE IF NOT EXISTS `TblInventarioCampoSeccion` (
  `tipo_inventario` VARCHAR(20)  NOT NULL,
  `columna`         VARCHAR(64)  NOT NULL,
  `etiqueta`        VARCHAR(100) NOT NULL,
  `placeholder`     VARCHAR(150) NULL,
  `orden`           INT NOT NULL DEFAULT 0,
  `visible`         TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0 = no se muestra en el formulario',
  PRIMARY KEY (`tipo_inventario`, `columna`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Etiqueta, ayuda y orden de los campos de cada sección de inventario';

INSERT INTO `TblInventarioCampoSeccion` (tipo_inventario, columna, etiqueta, placeholder, orden, visible)
VALUES
  -- ROPA
  ('ROPA', 'talla',               'Talla',                 'Ej: M, L, XL, 42',           1, 1),
  ('ROPA', 'color',               'Color',                 'Ej: Azul, Blanco',           2, 1),
  ('ROPA', 'genero',              'Género',                NULL,                         3, 1),
  ('ROPA', 'material_tela',       'Material / Tela',       'Ej: Algodón 100%, Cuero',    4, 1),
  ('ROPA', 'norma_certificacion', 'Norma (EPP)',           'Ej: ANSI Z89.1',             5, 1),
  ('ROPA', 'tipo_proteccion',     'Tipo de protección',    'Ej: Cabeza, Manos, Pies',    6, 1),
  -- MATERIAL
  ('MATERIAL', 'tipo',             'Tipo',                 'Ej: Portland Tipo I, PVC C-7.5', 1, 1),
  ('MATERIAL', 'presentacion',     'Presentación',         'Ej: Bolsa 42.5 kg',          2, 1),
  ('MATERIAL', 'marca',            'Marca',                NULL,                         3, 1),
  ('MATERIAL', 'medida',           'Medida',               'Ej: 1/2", 63 mm',            4, 1),
  ('MATERIAL', 'norma',            'Norma',                'Ej: NTP 334.009',            5, 1),
  ('MATERIAL', 'resistencia',      'Resistencia',          'Ej: f''c=210 kg/cm²',        6, 1),
  ('MATERIAL', 'color',            'Color',                NULL,                         7, 1),
  ('MATERIAL', 'peso_unitario_kg', 'Peso por unidad (kg)', NULL,                         8, 1),
  ('MATERIAL', 'largo_cm',         'Largo (cm)',           NULL,                         9, 1),
  ('MATERIAL', 'ancho_cm',         'Ancho (cm)',           NULL,                        10, 1),
  ('MATERIAL', 'alto_cm',          'Alto (cm)',            NULL,                        11, 1),
  ('MATERIAL', 'lote',             'Lote',                 NULL,                        12, 0),
  -- HERRAMIENTA
  ('HERRAMIENTA', 'tipo_herramienta', 'Tipo de herramienta', NULL,                       1, 1),
  ('HERRAMIENTA', 'marca',            'Marca',               NULL,                       2, 1),
  ('HERRAMIENTA', 'modelo',           'Modelo',              NULL,                       3, 1),
  ('HERRAMIENTA', 'potencia',         'Potencia',            'Ej: 850 W',                4, 1),
  ('HERRAMIENTA', 'voltaje',          'Voltaje',             'Ej: 220 V',                5, 1),
  ('HERRAMIENTA', 'numero_serie',     'Número de serie',     NULL,                       6, 1),
  ('HERRAMIENTA', 'peso_kg',          'Peso (kg)',           NULL,                       7, 1),
  ('HERRAMIENTA', 'largo_cm',         'Largo (cm)',          NULL,                       8, 1),
  ('HERRAMIENTA', 'ancho_cm',         'Ancho (cm)',          NULL,                       9, 1),
  ('HERRAMIENTA', 'alto_cm',          'Alto (cm)',           NULL,                      10, 1),
  -- EQUIPO
  ('EQUIPO', 'marca',            'Marca',              NULL,                  1, 1),
  ('EQUIPO', 'modelo',           'Modelo',             NULL,                  2, 1),
  ('EQUIPO', 'capacidad',        'Capacidad',          'Ej: 9 p3, 1 t',       3, 1),
  ('EQUIPO', 'potencia',         'Potencia',           'Ej: 5 HP',            4, 1),
  ('EQUIPO', 'numero_serie',     'Número de serie',    NULL,                  5, 1),
  ('EQUIPO', 'anio_fabricacion', 'Año de fabricación', NULL,                  6, 1),
  ('EQUIPO', 'placa',            'Placa',              NULL,                  7, 1),
  ('EQUIPO', 'peso_kg',          'Peso (kg)',          NULL,                  8, 1),
  ('EQUIPO', 'largo_cm',         'Largo (cm)',         NULL,                  9, 1),
  ('EQUIPO', 'ancho_cm',         'Ancho (cm)',         NULL,                 10, 1),
  ('EQUIPO', 'alto_cm',          'Alto (cm)',          NULL,                 11, 1),
  -- TECNOLOGIA
  ('TECNOLOGIA', 'marca',             'Marca',             NULL,                    1, 1),
  ('TECNOLOGIA', 'modelo',            'Modelo',            NULL,                    2, 1),
  ('TECNOLOGIA', 'procesador',        'Procesador',        'Ej: Intel Core i7',     3, 1),
  ('TECNOLOGIA', 'ram',               'Memoria RAM',       'Ej: 16GB',              4, 1),
  ('TECNOLOGIA', 'almacenamiento',    'Almacenamiento',    'Ej: 512GB SSD',         5, 1),
  ('TECNOLOGIA', 'pantalla',          'Pantalla',          'Ej: 15.6"',             6, 1),
  ('TECNOLOGIA', 'sistema_operativo', 'Sistema operativo', 'Ej: Windows 11 Pro',    7, 1),
  ('TECNOLOGIA', 'numero_serie',      'Número de serie',   NULL,                    8, 1),
  ('TECNOLOGIA', 'garantia_meses',    'Garantía (meses)',  NULL,                    9, 1),
  ('TECNOLOGIA', 'peso_kg',           'Peso (kg)',         NULL,                   10, 1),
  ('TECNOLOGIA', 'largo_cm',          'Largo (cm)',        NULL,                   11, 1),
  ('TECNOLOGIA', 'ancho_cm',          'Ancho (cm)',        NULL,                   12, 1),
  ('TECNOLOGIA', 'alto_cm',           'Alto (cm)',         NULL,                   13, 1),
  -- CONSUMIBLE
  ('CONSUMIBLE', 'marca',            'Marca',                 NULL,             1, 1),
  ('CONSUMIBLE', 'presentacion',     'Presentación',          'Ej: Caja x 10',  2, 1),
  ('CONSUMIBLE', 'tamano',           'Tamaño',                'Ej: A4, Carta',  3, 1),
  ('CONSUMIBLE', 'gramaje',          'Gramaje (g/m²)',        'Ej: 75',         4, 1),
  ('CONSUMIBLE', 'color',            'Color',                 NULL,             5, 1),
  ('CONSUMIBLE', 'unidades_paquete', 'Unidades por paquete',  NULL,             6, 1),
  ('CONSUMIBLE', 'blancura_pct',     'Blancura (%)',          NULL,             7, 1)
AS n
ON DUPLICATE KEY UPDATE etiqueta = n.etiqueta, placeholder = n.placeholder,
                        orden = n.orden, visible = n.visible;
