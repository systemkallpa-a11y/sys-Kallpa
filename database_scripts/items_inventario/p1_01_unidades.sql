-- =============================================================================
-- PARTE 1 / 01 - UNIDADES DE MEDIDA
-- -----------------------------------------------------------------------------
-- 1. Agrega la columna `magnitud` (define qué unidades se pueden convertir).
-- 2. Agrega unidades usadas en edificación: GLB, PIE, P2, MES, DIA, MILLAR,
--    JGO, RESMA, VIAJE.
-- 3. Corrige abreviaturas (M2 y M3 tenían 'mtr') y nombres ambiguos.
-- 4. Inactiva TAZA (sin uso en ningún ítem).
-- Idempotente: se puede ejecutar más de una vez.
-- =============================================================================

-- 1. Columna magnitud (solo si no existe)
SET @existe := (SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'TblUnidadMedida'
                  AND COLUMN_NAME = 'magnitud');
SET @sql := IF(@existe = 0,
  'ALTER TABLE `TblUnidadMedida` ADD COLUMN `magnitud` ENUM(''CONTEO'',''EMPAQUE'',''MASA'',''VOLUMEN'',''LONGITUD'',''AREA'',''TIEMPO'',''GLOBAL'') NULL COMMENT ''Magnitud: solo se convierten unidades de la misma magnitud. EMPAQUE se convierte por item'' AFTER `abreviatura`',
  'SELECT ''magnitud ya existe'' AS info');
PREPARE st FROM @sql;
EXECUTE st;
DEALLOCATE PREPARE st;

-- 2. Unidades nuevas
INSERT INTO `TblUnidadMedida` (codigo, nombre, abreviatura, descripcion, estado)
VALUES
  ('GLB',    'Global',      'glb',  'Partida o servicio a suma alzada',            'ACTIVO'),
  ('PIE',    'Pie',         'pie',  'Longitud en pies (0.3048 m)',                 'ACTIVO'),
  ('P2',     'Pie tablar',  'p2',   'Volumen de madera: 1 pie x 1 pie x 1 pulgada', 'ACTIVO'),
  ('MES',    'Mes',         'mes',  'Alquileres y servicios mensuales',            'ACTIVO'),
  ('DIA',    'Día',         'día',  'Alquileres y servicios diarios',              'ACTIVO'),
  ('MILLAR', 'Millar',      'mll',  'Mil unidades (ladrillos, clavos)',            'ACTIVO'),
  ('JGO',    'Juego',       'jgo',  'Conjunto de piezas que se venden juntas',     'ACTIVO'),
  ('RESMA',  'Resma',       'rsm',  'Paquete de 500 hojas',                        'ACTIVO'),
  ('VIAJE',  'Viaje',       'vje',  'Flete o transporte por viaje',                'ACTIVO')
AS nueva
ON DUPLICATE KEY UPDATE
  nombre = nueva.nombre,
  abreviatura = nueva.abreviatura,
  descripcion = nueva.descripcion;

-- 3. Correcciones de abreviatura, nombre y descripción
UPDATE `TblUnidadMedida` SET abreviatura = 'm²' WHERE codigo = 'M2';
UPDATE `TblUnidadMedida` SET abreviatura = 'm³' WHERE codigo = 'M3';
UPDATE `TblUnidadMedida` SET nombre = 'Metro lineal', descripcion = 'Longitud en metros (metro lineal)' WHERE codigo = 'M';
UPDATE `TblUnidadMedida` SET descripcion = 'Longitud en centímetros' WHERE codigo = 'CM';
UPDATE `TblUnidadMedida` SET descripcion = 'Volumen en mililitros (no confundir con metro lineal)' WHERE codigo = 'ML';

-- 4. TAZA: sin uso en construcción (solo si ningún ítem la usa)
UPDATE `TblUnidadMedida` u
SET u.estado = 'INACTIVO'
WHERE u.codigo = 'TAZA'
  AND NOT EXISTS (SELECT 1 FROM `TblInventario` i WHERE i.id_unidad = u.id_unidad);

-- 5. Magnitud de cada unidad
UPDATE `TblUnidadMedida` SET magnitud = 'CONTEO'   WHERE codigo IN ('UND','DOCENA','PARES','MILLAR','VIAJE');
UPDATE `TblUnidadMedida` SET magnitud = 'EMPAQUE'  WHERE codigo IN ('CAJA','PAQUETE','ROLLO','BOLSA','VARA','JGO','RESMA');
UPDATE `TblUnidadMedida` SET magnitud = 'MASA'     WHERE codigo IN ('KG','GR','TON');
UPDATE `TblUnidadMedida` SET magnitud = 'VOLUMEN'  WHERE codigo IN ('LT','ML','M3','GALÓN','TAZA','P2');
UPDATE `TblUnidadMedida` SET magnitud = 'LONGITUD' WHERE codigo IN ('M','CM','PIE');
UPDATE `TblUnidadMedida` SET magnitud = 'AREA'     WHERE codigo IN ('M2');
UPDATE `TblUnidadMedida` SET magnitud = 'TIEMPO'   WHERE codigo IN ('HORA','DIA','MES');
UPDATE `TblUnidadMedida` SET magnitud = 'GLOBAL'   WHERE codigo IN ('GLB');
