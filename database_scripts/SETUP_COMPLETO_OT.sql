-- ============================================================================
-- SETUP COMPLETO: Menú O.T + Tabla TblOT
-- Ejecutar TODO este script de una vez
-- ============================================================================

-- PARTE 1: Crear Menú O.T
-- ============================================================================

INSERT INTO TblMenu (nombre, ruta, icono, orden, estado)
VALUES ('O.T', '/ot', 'fa-briefcase', 5, 'ACTIVO');

-- PARTE 2: Crear SubMenú Presupuesto
-- ============================================================================

INSERT INTO TblSubMenu (id_menu, nombre, ruta, icono, orden, estado)
VALUES (5, 'Presupuesto', '/ot/presupuesto', 'fa-file-invoice-dollar', 1, 'ACTIVO');

-- PARTE 3: Crear Tabla TblOT
-- ============================================================================

CREATE TABLE IF NOT EXISTS TblOT (
    id_ot INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único de la O.T',
    numero_ot VARCHAR(50) NOT NULL UNIQUE COMMENT 'Número único de la O.T (Ej: OT-001)',
    descripcion LONGTEXT NOT NULL COMMENT 'Descripción detallada de la O.T',
    proyecto VARCHAR(150) NOT NULL COMMENT 'Nombre del proyecto',
    estado VARCHAR(50) NOT NULL DEFAULT 'PENDIENTE' COMMENT 'Estado: PENDIENTE, EN_PROCESO, COMPLETADA, CANCELADA, ELIMINADA',
    monto_presupuestado DECIMAL(12, 2) NOT NULL DEFAULT 0 COMMENT 'Monto presupuestado en soles',
    monto_gastado DECIMAL(12, 2) DEFAULT 0 COMMENT 'Monto gastado en soles',
    obs_presupuesto LONGTEXT COMMENT 'Observaciones sobre el presupuesto',
    observaciones LONGTEXT COMMENT 'Observaciones adicionales',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación de la O.T',
    fecha_actualizacion DATETIME NULL ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última fecha de actualización',
    
    INDEX idx_numero_ot (numero_ot),
    INDEX idx_estado (estado),
    INDEX idx_proyecto (proyecto),
    INDEX idx_fecha_creacion (fecha_creacion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tabla de órdenes de trabajo';

-- PARTE 4: Verificación
-- ============================================================================

SELECT '✅ MENÚ O.T CREADO:' as info;
SELECT id_menu, nombre, ruta FROM TblMenu WHERE id_menu = 5;

SELECT '✅ SUBMENÚ PRESUPUESTO CREADO:' as info;
SELECT id_submenu, nombre, ruta FROM TblSubMenu WHERE id_menu = 5;

SELECT '✅ TABLA TBLOT CREADA:' as info;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TblOT';

SELECT '✅ SETUP COMPLETO' as resultado;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
