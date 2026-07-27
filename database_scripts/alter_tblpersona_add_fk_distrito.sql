-- ============================================================================
-- ALTER TABLE: Agregar Foreign Key TblPersona -> TblDistrito
-- DESCRIPCIÓN: Crea relación entre TblPersona.id_distrito y TblDistrito.id_distrito
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Verificar si la FK ya existe antes de agregarla
ALTER TABLE TblPersona
ADD CONSTRAINT fk_tblpersona_tblditrito 
FOREIGN KEY (id_distrito) REFERENCES TblDistrito(id_distrito)
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- ============================================================================
-- NOTAS:
-- - ON DELETE RESTRICT: No permitir eliminar un distrito si está en uso
-- - ON UPDATE CASCADE: Si cambia el id_distrito, actualizar automáticamente
-- ============================================================================
