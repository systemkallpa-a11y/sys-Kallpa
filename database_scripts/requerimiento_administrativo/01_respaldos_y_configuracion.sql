-- ============================================================================
-- REQUERIMIENTO ADMINISTRATIVO - 01: RESPALDOS Y CONFIGURACIÓN
-- FECHA: 13/11/2026
--
-- Qué hace:
--   0) Respaldos de las tablas/filas que se modifican.
--   1) Tipo de requerimiento 1: "Oficina" -> "Administrativo".
--   2) Los requerimientos existentes que vienen de un presupuesto pasan a Obra (tipo 2).
--   3) Nuevo tipo de documento de aprobación 7 = "Requerimiento Administrativo".
--   4) Flujo de 1 paso: Jefe de Logística Administrativo (cargo 65).
--
-- Re-ejecutable: los respaldos usan IF NOT EXISTS y los INSERT usan NOT EXISTS.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) RESPALDOS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `respaldo_TblTipoRequerimiento_20261113` AS
    SELECT * FROM `TblTipoRequerimiento`;

CREATE TABLE IF NOT EXISTS `respaldo_TblRequerimiento_20261113` AS
    SELECT * FROM `TblRequerimiento`;

CREATE TABLE IF NOT EXISTS `respaldo_TblTipoDocumentoAprobacion_20261113` AS
    SELECT * FROM `TblTipoDocumentoAprobacion`;

CREATE TABLE IF NOT EXISTS `respaldo_TblFlujoAprobacionCargos_20261113` AS
    SELECT * FROM `TblFlujoAprobacionCargos`;

-- ----------------------------------------------------------------------------
-- 1) Renombrar el tipo 1
-- ----------------------------------------------------------------------------
UPDATE `TblTipoRequerimiento`
SET `nombre`      = 'Administrativo',
    `descripcion` = 'Requerimientos administrativos generales (stock de almacén)'
WHERE `id_tipo_requerimiento` = 1;

-- ----------------------------------------------------------------------------
-- 2) Reclasificar como Obra los que vienen de presupuesto (hoy son 3)
-- ----------------------------------------------------------------------------
UPDATE `TblRequerimiento`
SET `id_tipo_requerimiento` = 2
WHERE `id_tipo_requerimiento` = 1
  AND `id_presupuesto` IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 3) Tipo de documento de aprobación 7 (id fijo: lo usan los SP del módulo)
-- ----------------------------------------------------------------------------
INSERT INTO `TblTipoDocumentoAprobacion`
    (`id_tipo_documento`, `nombre`, `descripcion`, `icono`, `color`, `requiere_aprobacion`, `activo`, `orden`)
SELECT 7, 'Requerimiento Administrativo', 'Requerimientos administrativos creados desde el Dashboard',
       'fa-clipboard-list', 'orange', 1, 1, 3
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM `TblTipoDocumentoAprobacion` WHERE `id_tipo_documento` = 7);

-- ----------------------------------------------------------------------------
-- 4) Flujo: paso 1 = Jefe de Logística Administrativo (cargo 65)
-- ----------------------------------------------------------------------------
INSERT INTO `TblFlujoAprobacionCargos`
    (`id_tipo_documento`, `id_cargo`, `numero_paso`, `nombre_paso`, `descripcion`,
     `es_final`, `es_requerido`, `permite_rechazo`, `orden_visualizacion`, `activo`)
SELECT 7, 65, 1, 'Aprobación Jefe de Logística Administrativo',
       'Aprueba o rechaza los requerimientos administrativos', 1, 1, 1, 0, 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM `TblFlujoAprobacionCargos`
    WHERE `id_tipo_documento` = 7 AND `numero_paso` = 1 AND `id_cargo` = 65
);

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN
-- ----------------------------------------------------------------------------
SELECT `id_tipo_requerimiento`, `nombre`, `descripcion` FROM `TblTipoRequerimiento`;

SELECT `id_requerimiento`, `codigo`, `id_tipo_requerimiento`, `id_presupuesto`, `estado` FROM `TblRequerimiento`;

SELECT `id_tipo_documento`, `nombre`, `activo` FROM `TblTipoDocumentoAprobacion` ORDER BY `id_tipo_documento`;

SELECT `id_flujo_cargo`, `id_tipo_documento`, `id_cargo`, `numero_paso`, `nombre_paso`, `activo`
FROM `TblFlujoAprobacionCargos` WHERE `id_tipo_documento` = 7;
