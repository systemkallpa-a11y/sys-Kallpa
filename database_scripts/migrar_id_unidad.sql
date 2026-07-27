-- =============================================================================
-- MIGRACIÓN: Cambiar unidad_medida (varchar) por id_unidad (FK)
-- =============================================================================

-- PASO 1: Agregar columna id_unidad
ALTER TABLE TblRequerimientoDetalle 
ADD COLUMN id_unidad INT(11) NULL DEFAULT NULL 
AFTER id_material;

-- PASO 2: Crear FK a TblUnidadMedida
ALTER TABLE TblRequerimientoDetalle 
ADD CONSTRAINT fk_requerimiento_detalle_unidad 
FOREIGN KEY (id_unidad) REFERENCES TblUnidadMedida(id_unidad);

-- PASO 3: Migrar datos existentes desde unidad_medida a id_unidad
-- Buscar la unidad por nombre y asignar el id
UPDATE TblRequerimientoDetalle rd
SET rd.id_unidad = (
    SELECT um.id_unidad 
    FROM TblUnidadMedida um 
    WHERE LOWER(TRIM(um.nombre)) = LOWER(TRIM(rd.unidad_medida))
    LIMIT 1
)
WHERE rd.unidad_medida IS NOT NULL;

-- PASO 4: Para los que no encuentren coincidencia, asignar unidad por defecto (und)
UPDATE TblRequerimientoDetalle rd
SET rd.id_unidad = (
    SELECT id_unidad FROM TblUnidadMedida 
    WHERE nombre = 'und' 
    LIMIT 1
)
WHERE rd.id_unidad IS NULL;

-- PASO 5: Eliminar columna unidad_medida
ALTER TABLE TblRequerimientoDetalle 
DROP COLUMN unidad_medida;

-- =============================================================================
-- VERIFICACIÓN
-- =============================================================================
-- DESC TblRequerimientoDetalle;
-- SELECT id_detalle, id_material, id_unidad, descripcion FROM TblRequerimientoDetalle LIMIT 5;
