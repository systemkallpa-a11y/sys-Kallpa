-- ============================================================
-- SP: sp_ObtenerHistorialConEstados   (v1 - version en produccion al 2026-11-13)
-- ============================================================
-- Historial del trabajador (pantalla de marcacion y dashboard).
-- Copia exacta de la BD (verificada el 2026-11-16). Sirve para
-- REVERTIR a la version anterior a la v2.
-- ============================================================

DROP PROCEDURE IF EXISTS `sp_ObtenerHistorialConEstados`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerHistorialConEstados`(
    IN p_num_documento INT,
    IN p_dias INT
)
    READS SQL DATA
BEGIN
    SELECT 
        m.id_marcacion,
        m.num_documento,
        m.tipo_marcacion,
        m.fecha_marcacion,
        TIME(m.fecha_marcacion) as hora_marcacion,
        DATE(m.fecha_marcacion) as fecha,
        CASE DAYNAME(m.fecha_marcacion)
            WHEN 'Monday' THEN 'LUNES'
            WHEN 'Tuesday' THEN 'MARTES'
            WHEN 'Wednesday' THEN 'MIERCOLES'
            WHEN 'Thursday' THEN 'JUEVES'
            WHEN 'Friday' THEN 'VIERNES'
            WHEN 'Saturday' THEN 'SABADO'
            WHEN 'Sunday' THEN 'DOMINGO'
        END as dia_semana,
        h.hora_entrada,
        h.hora_salida,
        h.hora_entrada2,
        h.hora_salida2,
        CASE WHEN TIME(m.fecha_marcacion) < '12:00:00' THEN 1 ELSE 2 END as turno,
        -- Estados: VACACIONES, ASISTIÓ, ASISTIÓ +5, TARDE, SALIDA, SIN HORARIO
        CASE 
            WHEN m.tipo_marcacion = 'ENTRADA'
                 AND EXISTS (
                     SELECT 1 FROM TblVacaciones v
                     WHERE v.num_documento = m.num_documento
                       AND v.estado = 'APROBADO'
                       AND DATE(m.fecha_marcacion) BETWEEN v.fecha_inicio AND v.fecha_fin
                 ) THEN 'VACACIONES'
            WHEN m.tipo_marcacion = 'ENTRADA' THEN
                CASE
                    WHEN h.hora_entrada IS NULL AND h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
                    WHEN TIME(m.fecha_marcacion) < '12:00:00' THEN
                        CASE
                            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
                            WHEN TIME(m.fecha_marcacion) < h.hora_entrada THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) = h.hora_entrada THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) > h.hora_entrada 
                                AND TIME(m.fecha_marcacion) <= ADDTIME(h.hora_entrada, '00:05:00') 
                            THEN 'ASISTIÓ +5'
                            ELSE 'TARDE'
                        END
                    WHEN TIME(m.fecha_marcacion) >= '12:00:00' THEN
                        CASE
                            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
                            WHEN TIME(m.fecha_marcacion) < h.hora_entrada2 THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) = h.hora_entrada2 THEN 'ASISTIÓ'
                            WHEN TIME(m.fecha_marcacion) > h.hora_entrada2 
                                AND TIME(m.fecha_marcacion) <= ADDTIME(h.hora_entrada2, '00:05:00') 
                            THEN 'ASISTIÓ +5'
                            ELSE 'TARDE'
                        END
                    ELSE 'ASISTIÓ'
                END
            WHEN m.tipo_marcacion = 'SALIDA' THEN 'SALIDA'
            ELSE 'ASISTIÓ'
        END as estado_asistencia,
        CASE 
            WHEN m.tipo_marcacion = 'ENTRADA' THEN
                CASE
                    WHEN TIME(m.fecha_marcacion) < '12:00:00' AND h.hora_entrada IS NOT NULL
                    THEN TIMESTAMPDIFF(MINUTE, h.hora_entrada, TIME(m.fecha_marcacion))
                    WHEN TIME(m.fecha_marcacion) >= '12:00:00' AND h.hora_entrada2 IS NOT NULL
                    THEN TIMESTAMPDIFF(MINUTE, h.hora_entrada2, TIME(m.fecha_marcacion))
                    ELSE 0
                END
            ELSE 0
        END as minutos_diferencia,
         m.justificacion
    FROM TblMarcacion m
    LEFT JOIN TblHorarioTrabajo h ON (
        m.num_documento = h.num_documento 
        AND h.dia_semana = CASE DAYNAME(m.fecha_marcacion)
            WHEN 'Monday' THEN 'LUNES'
            WHEN 'Tuesday' THEN 'MARTES'
            WHEN 'Wednesday' THEN 'MIERCOLES'
            WHEN 'Thursday' THEN 'JUEVES'
            WHEN 'Friday' THEN 'VIERNES'
            WHEN 'Saturday' THEN 'SABADO'
            WHEN 'Sunday' THEN 'DOMINGO'
        END
        AND h.es_activo = 1
        AND h.estado = 'ACTIVO'
    )
    WHERE m.num_documento = p_num_documento
        AND DATE(m.fecha_marcacion) >= DATE(NOW() - INTERVAL p_dias DAY)
    ORDER BY m.fecha_marcacion DESC
    LIMIT 100;
END$$

DELIMITER ;
