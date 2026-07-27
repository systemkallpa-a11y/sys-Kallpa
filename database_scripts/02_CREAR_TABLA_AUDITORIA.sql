-- ============================================================================
-- SCRIPT: Crear tabla de auditoría para control de requerimientos
-- DESCRIPCIÓN: Registra cada cambio en los saldos de presupuesto
-- FECHA: 2026-07-16
-- ============================================================================

SELECT '========== CREANDO TABLA TblRequerimientoAuditoria ==========' as paso;

-- PASO 1: Eliminar tabla si existe (para recrearla)
SELECT 'PASO 1: Preparando tabla' as paso;
DROP TABLE IF EXISTS TblRequerimientoAuditoria;

-- PASO 2: Crear tabla
SELECT 'PASO 2: Creando tabla de auditoría' as paso;

CREATE TABLE TblRequerimientoAuditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro de auditoría',
    
    -- Referencias
    id_presupuesto INT NOT NULL COMMENT 'FK a TblPresupuesto',
    id_requerimiento INT NOT NULL COMMENT 'FK a TblRequerimiento',
    
    -- Valores
    cantidad_requerida INT NOT NULL COMMENT 'Cantidad solicitada en el requerimiento',
    cantidad_anterior_consumida INT COMMENT 'Consumo antes de esta acción',
    cantidad_nueva_consumida INT COMMENT 'Consumo después de esta acción',
    saldo_anterior INT COMMENT 'Saldo antes de esta acción',
    saldo_nuevo INT COMMENT 'Saldo después de esta acción',
    
    -- Metadata
    accion VARCHAR(20) NOT NULL COMMENT 'CREAR, ACTUALIZAR, CANCELAR',
    num_usuario INT COMMENT 'Usuario que realizó la acción',
    observaciones LONGTEXT COMMENT 'Notas adicionales',
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Cuándo se registró',
    
    -- Constraints
    CONSTRAINT fk_auditoria_presupuesto 
        FOREIGN KEY (id_presupuesto) 
        REFERENCES TblPresupuesto(id_presupuesto) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_auditoria_requerimiento 
        FOREIGN KEY (id_requerimiento) 
        REFERENCES TblRequerimiento(id_requerimiento) 
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    -- Índices
    INDEX idx_id_presupuesto (id_presupuesto),
    INDEX idx_id_requerimiento (id_requerimiento),
    INDEX idx_accion (accion),
    INDEX idx_fecha_registro (fecha_registro)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Auditoría de cambios en requerimientos y saldos de presupuesto';

-- PASO 3: Verificar tabla creada
SELECT 'PASO 3: Verificando tabla creada' as paso;
DESCRIBE TblRequerimientoAuditoria;

-- PASO 4: Crear vista para ver auditoría con nombres
SELECT 'PASO 4: Creando vista de auditoría' as paso;

DROP VIEW IF EXISTS vw_requerimiento_auditoria;

CREATE VIEW vw_requerimiento_auditoria AS
SELECT 
    a.id_auditoria,
    a.fecha_registro,
    a.accion,
    a.id_presupuesto,
    a.id_requerimiento,
    a.cantidad_requerida,
    a.cantidad_anterior_consumida,
    a.cantidad_nueva_consumida,
    a.saldo_anterior,
    a.saldo_nuevo,
    a.num_usuario,
    r.codigo as requerimiento_codigo
FROM TblRequerimientoAuditoria a
LEFT JOIN TblRequerimiento r ON a.id_requerimiento = r.id_requerimiento;

-- PASO 5: Resumen
SELECT '========== TABLA CREADA EXITOSAMENTE ==========' as estado;
SELECT 'TblRequerimientoAuditoria' as tabla_nueva;
SELECT '' as linea;
SELECT 'Campos de auditoría:' as campos;
SELECT '  • id_auditoria (PK)' as campo1;
SELECT '  • id_presupuesto, id_requerimiento (FKs)' as campo2;
SELECT '  • cantidad_requerida' as campo3;
SELECT '  • cantidad_anterior_consumida, cantidad_nueva_consumida' as campo4;
SELECT '  • saldo_anterior, saldo_nuevo' as campo5;
SELECT '  • accion (CREAR, ACTUALIZAR, CANCELAR)' as campo6;
SELECT '  • fecha_registro (timestamp automático)' as campo7;
SELECT '' as linea;
SELECT 'Vista disponible: vw_requerimiento_auditoria' as vista;
