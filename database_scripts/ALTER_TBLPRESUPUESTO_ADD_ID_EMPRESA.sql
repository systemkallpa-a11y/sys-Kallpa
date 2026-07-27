-- ============================================================================
-- ALTER TABLE TBLPRESUPUESTO - Agregar columna id_empresa
-- ============================================================================
-- Propósito: Establecer relación directa entre TblPresupuesto y TblEmpresa
-- para que al editar un presupuesto, la empresa se cargue automáticamente
-- sin necesidad de seleccionar manualmente
-- ============================================================================

-- 1. Agregar la columna id_empresa a TblPresupuesto
ALTER TABLE TblPresupuesto
ADD COLUMN id_empresa INT NULL AFTER id_presupuesto;

-- 2. Agregar constraintFK a TblEmpresa
ALTER TABLE TblPresupuesto
ADD CONSTRAINT fk_presupuesto_empresa
FOREIGN KEY (id_empresa) REFERENCES TblEmpresa(id_empresa);

-- 3. Verificar la estructura actualizada
-- Ejecutar después de aplicar el script:
-- DESCRIBE TblPresupuesto;

-- ============================================================================
