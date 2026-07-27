-- ============================================================================
-- SCRIPT: Crear Menú O.T (Órdenes de Trabajo)
-- Fecha: 9 Julio 2026
-- ============================================================================

-- 1. Insertar nuevo menú O.T (ID=5)
INSERT INTO TblMenu (nombre, ruta, icono, orden, estado)
VALUES ('O.T', '/ot', 'fa-briefcase', 5, 'ACTIVO');

-- 2. Obtener el ID del menú creado (debería ser 5)
-- SELECT @menu_ot_id := id_menu FROM TblMenu WHERE nombre = 'O.T' LIMIT 1;

-- 3. Insertar submenú Presupuesto bajo O.T
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado)
VALUES (5, 'Presupuesto', '/ot/presupuesto', 'fa-file-invoice-dollar', 1, 'ACTIVO');

-- Verificación
SELECT 'Menú O.T creado:' as info;
SELECT id_menu, nombre, ruta, icono, orden, estado FROM TblMenu WHERE id_menu = 5;

SELECT 'SubMenú Presupuesto creado:' as info;
SELECT id_submenu, id_menu, nombre, ruta, icono, orden, estado FROM TblSubMenu WHERE id_menu = 5;

-- ============================================================================
-- NOTAS:
-- - Menu O.T tiene ID = 5
-- - SubMenú Presupuesto tiene ID = 9 (el siguiente después de 8)
-- - Ruta principal: /ot
-- - Ruta submenú: /ot/presupuesto
-- ============================================================================
