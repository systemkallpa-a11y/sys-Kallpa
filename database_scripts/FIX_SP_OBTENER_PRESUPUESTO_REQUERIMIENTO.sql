-- ============================================================================
-- SCRIPT: Corregir SP_ObtenerPresupuestoRequerimiento
-- DESCRIPCIÓN: Actualizar el SP que obtiene lista de requerimientos
-- PROBLEMA: Estaba seleccionando columnas que no existen
-- FECHA: 2026-07-16
-- ============================================================================

SELECT 'Actualizando SP: sp_ObtenerPresupuestoRequerimiento' as paso;

DROP PROCEDURE IF EXISTS sp_ObtenerPresupuestoRequerimiento;

DELIMITER $$

CREATE PROCEDURE sp_ObtenerPresupuestoRequerimiento()
READS SQL DATA
BEGIN
    SELECT DISTINCT
        r.id_requerimiento,
        r.codigo,
        r.descripcion,
        r.cantidad,
        r.estado,
        r.observaciones,
        r.fecha_creacion,
        r.fecha_actualizacion,
        r.id_presupuesto,
        u.num_usuario,
        u.usuario as usuario_nombre,
        p.nombres as solicitante_nombres,
        p.apellido_paterno as solicitante_apellido,
        CONCAT(p.nombres, ' ', p.apellido_paterno) as solicitante
    FROM TblRequerimiento r
    INNER JOIN TblUsuario u ON r.num_usuario = u.num_usuario
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    WHERE r.estado != 'ELIMINADO'
    ORDER BY r.fecha_creacion DESC;
END$$

DELIMITER ;

SELECT '✓ SP actualizado correctamente' as resultado;

-- Verificar que el SP existe
SELECT 
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
AND ROUTINE_NAME = 'sp_ObtenerPresupuestoRequerimiento';
