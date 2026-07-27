-- ============================================================================
-- Script: Crear Dependencias Faltantes
-- Propósito: Insertar obra, proyecto, usuario, persona si faltan
-- Fecha: 10 Julio 2026
-- ============================================================================

SELECT '═══════════════════════════════════════════════════' as separador;
SELECT 'VERIFICANDO E INSERTANDO DEPENDENCIAS' as titulo;
SELECT '═══════════════════════════════════════════════════' as separador;

-- PASO 1: Crear Proyecto si no existe
SELECT 'PASO 1: Verificando TblProyecto (id=1)' as paso;
INSERT IGNORE INTO TblProyecto (id_proyecto, codigo_proyecto, nombre, descripcion)
VALUES (1, 'PRY-001', 'Casa Verde', 'Construcción de casa unifamiliar en Lima');
SELECT 'Proyecto creado/verificado ✓' as resultado;

-- PASO 2: Crear Obra si no existe
SELECT 'PASO 2: Verificando TblObra (id=1)' as paso;
INSERT IGNORE INTO TblObra (id_obra, codigo_obra, nombre, descripcion, id_proyecto, tipo_obra)
VALUES (1, 'OBR-001', 'Excavación y Cimientos', 'Excavación del terreno y construcción de cimientos', 1, 'Excavación');
SELECT 'Obra creada/verificada ✓' as resultado;

-- PASO 3: Crear Usuario si no existe
SELECT 'PASO 3: Verificando TblUsuario (num_documento=1)' as paso;
INSERT IGNORE INTO TblUsuario (num_usuario, num_documento, usuario, email, estado)
VALUES (1, 1, 'admin', 'admin@kallpa.com', 'ACTIVO');
SELECT 'Usuario creado/verificado ✓' as resultado;

-- PASO 4: Crear Persona si no existe
SELECT 'PASO 4: Verificando TblPersona (num_documento=1)' as paso;
INSERT IGNORE INTO TblPersona (num_documento, nombres, apellido_paterno, apellido_materno, email, tipo_documento, estado)
VALUES (1, 'Administrador', 'Sistema', 'Kallpa', 'admin@kallpa.com', 'DNI', 'ACTIVO');
SELECT 'Persona creada/verificada ✓' as resultado;

-- PASO 5: Crear Materiales si no existen
SELECT 'PASO 5: Verificando TblMateriales (id=1,2,3)' as paso;
INSERT IGNORE INTO TblMateriales (id_material, codigo_material, nombre, id_categoria, id_unidad, cantidad_stock, precio_unitario, estado)
VALUES 
(1, 'MAT-001', 'Cemento Portland', 1, 1, 100, 25.50, 'ACTIVO'),
(2, 'MAT-002', 'Acero Estructural', 2, 3, 50, 15.75, 'ACTIVO'),
(3, 'MAT-003', 'Arena Gruesa', 3, 9, 30, 18.50, 'ACTIVO');
SELECT 'Materiales creados/verificados ✓' as resultado;

SELECT '═══════════════════════════════════════════════════' as separador;
SELECT 'VERIFICACIÓN FINAL' as paso;
SELECT '═══════════════════════════════════════════════════' as separador;

-- Verificar que todo existe
SELECT 'TblProyecto (id=1):' as item;
SELECT * FROM TblProyecto WHERE id_proyecto = 1;

SELECT 'TblObra (id=1):' as item;
SELECT * FROM TblObra WHERE id_obra = 1;

SELECT 'TblUsuario (num_documento=1):' as item;
SELECT * FROM TblUsuario WHERE num_documento = 1;

SELECT 'TblPersona (num_documento=1):' as item;
SELECT * FROM TblPersona WHERE num_documento = 1;

SELECT 'TblMateriales (id=1,2,3):' as item;
SELECT * FROM TblMateriales WHERE id_material IN (1,2,3);

-- Ahora probar el SP
SELECT '═══════════════════════════════════════════════════' as separador;
SELECT 'PROBANDO EL SP' as paso;
SELECT '═══════════════════════════════════════════════════' as separador;

CALL sp_obtener_presupuesto_detalle_completo(1);

SELECT '═══════════════════════════════════════════════════' as separador;
SELECT '✅ LISTO - Todas las dependencias están creadas' as estado;
SELECT '═══════════════════════════════════════════════════' as separador;
