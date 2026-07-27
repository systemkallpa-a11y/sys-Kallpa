-- Eliminar unidad_medida de TblRequerimientoDetalle
-- Ya no es necesario porque se obtiene via id_material → TblMateriales → TblUnidadMedida

ALTER TABLE TblRequerimientoDetalle DROP COLUMN unidad_medida;

-- Verificar estructura
DESC TblRequerimientoDetalle;