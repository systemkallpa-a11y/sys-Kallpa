-- ============================================================================
-- MIGRACIÓN: Requerimiento pasa de LOGÍSTICA a O.T + nuevo Requerimiento General
-- FECHA: 13/11/2026
-- AUTOR: Plan aprobado (mover submenú 4 a menú 5 y crear submenú 16)
--
-- RESULTADO:
--   Menú 5 (O.T)            : Expediente Técnico (1) | Presupuesto (2) |
--                              Requerimiento O.T (3)
--   Menú 2 (Logística)      : Requerimiento General (1) | Órdenes de Compra (2) |
--                              Proveedores (3)
--   Accesos: mismos 10 usuarios en ambos.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) RESPALDOS (previos a cualquier modificación)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `respaldo_TblSubMenu_20261113` AS
    SELECT * FROM `TblSubMenu` WHERE `id_submenu` = 4;

CREATE TABLE IF NOT EXISTS `respaldo_TblUsuarioAccesos_20261113` AS
    SELECT * FROM `TblUsuarioAccesos` WHERE `id_submenu` = 4;

-- ----------------------------------------------------------------------------
-- 1) FASE A - Mover el submenú 4 a O.T (debajo de Presupuesto) y renombrarlo
-- ----------------------------------------------------------------------------
UPDATE `TblSubMenu`
SET `id_menu`          = 5,
    `orden`            = 3,
    `nombre`           = 'Requerimiento O.T',
    `fecha_actualizacion` = NOW()
WHERE `id_submenu` = 4;

-- ----------------------------------------------------------------------------
-- 2) FASE A - Mover los permisos de los 10 usuarios (OBLIGATORIO:
--    validar_acceso_usuario exige id_menu + id_submenu a la vez).
--    Actualiza 10 filas.
-- ----------------------------------------------------------------------------
UPDATE `TblUsuarioAccesos`
SET `id_menu` = 5
WHERE `id_submenu` = 4;

-- ----------------------------------------------------------------------------
-- 3) FASE B - Nuevo submenú "Requerimiento General" en Logística, posición 1
--    (id_submenu = 16 por AUTO_INCREMENT)
-- ----------------------------------------------------------------------------
INSERT INTO `TblSubMenu` (`id_menu`, `nombre`, `ruta`, `icono`, `orden`, `estado`)
VALUES (2, 'Requerimiento General', '/requerimiento-logistica', 'fa-clipboard-list', 1, 'ACTIVO');

-- ----------------------------------------------------------------------------
-- 4) FASE B - Mismos 10 usuarios con acceso al nuevo submenú
-- ----------------------------------------------------------------------------
INSERT INTO `TblUsuarioAccesos` (`num_documento`, `id_menu`, `id_submenu`, `estado`)
VALUES (3,  2, 16, 'ACTIVO'),
       (4,  2, 16, 'ACTIVO'),
       (1,  2, 16, 'ACTIVO'),
       (61, 2, 16, 'ACTIVO'),
       (19, 2, 16, 'ACTIVO'),
       (10, 2, 16, 'ACTIVO'),
       (11, 2, 16, 'ACTIVO'),
       (35, 2, 16, 'ACTIVO'),
       (72, 2, 16, 'ACTIVO'),
       (73, 2, 16, 'ACTIVO');

-- ----------------------------------------------------------------------------
-- 5) VERIFICACIÓN
-- ----------------------------------------------------------------------------
SELECT `id_submenu`, `id_menu`, `nombre`, `ruta`, `orden`, `estado`
FROM `TblSubMenu`
WHERE `id_menu` IN (2, 5)
ORDER BY `id_menu`, `orden`;

SELECT `num_documento`, `id_menu`, `id_submenu`, `estado`
FROM `TblUsuarioAccesos`
WHERE `id_submenu` IN (4, 16)
ORDER BY `id_submenu`, `num_documento`;
