-- ============================================================================
-- Script: Crear Menú y SubMenú para Gestión de Materiales
-- Fecha: 10 Julio 2026
-- ============================================================================

-- 1. Insertar nuevo menú Almacén (ID debería ser 6)
INSERT INTO TblMenu (nombre, ruta, icono, orden, estado)
VALUES ('Almacén', '/almacen', 'fa-warehouse', 6, 'ACTIVO');

-- 2. Insertar submenu Materiales bajo Almacén
INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado)
VALUES (6, 'Materiales', '/materiales', 'fa-cubes', 1, 'ACTIVO');

-- ============================================================================
-- Verificación
-- ============================================================================

SELECT 'Menú Almacén creado:' as info;
SELECT id_menu, nombre, ruta, icono, orden, estado 
FROM TblMenu 
WHERE id_menu = 6;

SELECT 'SubMenú Materiales creado:' as info;
SELECT id_submenu, id_menu, nombre, ruta, icono, orden, estado 
FROM TblSubMenu 
WHERE id_menu = 6;

-- ============================================================================
-- NOTAS:
-- - Menú Almacén tiene ID = 6
-- - SubMenú Materiales tiene ID = 10 (el siguiente después de 9)
-- - Ruta principal: /almacen
-- - Ruta submenu: /materiales
-- - Icono menu: fa-warehouse (icono de almacén)
-- - Icono submenu: fa-cubes (icono de cajas/cubos)
-- ============================================================================
