-- ============================================================
-- SP: sp_ObtenerHistorialConEstados   (v3)
-- ============================================================
-- Historial del trabajador: pantalla de marcacion (tabla de dias
-- anteriores) y dashboard (/api/marcacion/historial).
--
-- REQUIERE: vista vw_casillas_marcacion v3 (app/sql/vw_casillas_marcacion_v3.sql).
--
-- Cambios v3:
--   * Tardanza igual que el reporte de RR.HH.: atraso en minutos
--     enteros, hasta 5 min es puntual (ASISTIÓ) y desde el minuto 6
--     se muestra (atraso - 5). Ya no se usa 'ASISTIÓ +5'.
--   * Columnas iguales a v2.
--
-- Cambios v2:
--   * El turno y la casilla de cada marca salen de vw_casillas_marcacion,
--     la REGLA UNICA del detalle y del reporte. Antes se cortaba a las
--     12:00, y el trabajador podia ver algo distinto de lo que ve RR.HH.
--   * El horario es el vigente en la fecha (lo trae la vista). Antes se
--     unia sin vigencia ni tildes ('MIERCOLES', 'SABADO' no coincidian).
--   * Estado y minutos de la ENTRADA se calculan contra la entrada del
--     turno de su casilla (E1 -> hora_entrada, E2 -> hora_entrada2).
--     Una entrada EXTRA queda con estado 'EXTRA'.
--   * Mismas columnas que v1 (mismo orden) + casilla y estado_marca al final.
--
-- Para revertir: volver a aplicar app/sql/sp_ObtenerHistorialConEstados_v2.sql
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP + CREATE.
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
        vc.id_marcacion,
        vc.num_documento,
        vc.tipo_marcacion,
        vc.fecha_marcacion,
        vc.hora AS hora_marcacion,
        vc.fecha,
        CASE DAYOFWEEK(vc.fecha)
            WHEN 1 THEN 'DOMINGO'
            WHEN 2 THEN 'LUNES'
            WHEN 3 THEN 'MARTES'
            WHEN 4 THEN 'MIERCOLES'
            WHEN 5 THEN 'JUEVES'
            WHEN 6 THEN 'VIERNES'
            WHEN 7 THEN 'SABADO'
        END AS dia_semana,
        vc.he1 AS hora_entrada,
        vc.hs1 AS hora_salida,
        vc.he2 AS hora_entrada2,
        vc.hs2 AS hora_salida2,
        vc.turno,
        -- Estados: VACACIONES, ASISTIÓ, TARDE, SALIDA, SIN HORARIO, EXTRA
        -- Misma regla que el reporte (sp_reporte_asistencia_automatica):
        -- atraso en minutos enteros; hasta 5 min es puntual (ASISTIÓ) y
        -- desde el minuto 6 la tardanza es (atraso - 5).
        CASE
            WHEN vc.tipo_marcacion = 'ENTRADA'
                 AND EXISTS (
                     SELECT 1 FROM TblVacaciones v
                     WHERE v.num_documento = vc.num_documento
                       AND v.estado = 'APROBADO'
                       AND vc.fecha BETWEEN v.fecha_inicio AND v.fecha_fin
                 ) THEN 'VACACIONES'
            WHEN vc.tipo_marcacion = 'ENTRADA' THEN
                CASE
                    WHEN vc.casilla IS NULL THEN 'EXTRA'
                    WHEN (CASE WHEN vc.casilla = 'E1' THEN vc.he1 ELSE vc.he2 END) IS NULL THEN 'SIN HORARIO'
                    WHEN (TIME_TO_SEC(vc.hora) - TIME_TO_SEC(CASE WHEN vc.casilla = 'E1' THEN vc.he1 ELSE vc.he2 END)) DIV 60 <= 5 THEN 'ASISTIÓ'
                    ELSE 'TARDE'
                END
            ELSE 'SALIDA'
        END AS estado_asistencia,
        CASE
            WHEN vc.tipo_marcacion = 'ENTRADA' AND vc.casilla IS NOT NULL
                 AND (CASE WHEN vc.casilla = 'E1' THEN vc.he1 ELSE vc.he2 END) IS NOT NULL
                 AND (TIME_TO_SEC(vc.hora) - TIME_TO_SEC(CASE WHEN vc.casilla = 'E1' THEN vc.he1 ELSE vc.he2 END)) DIV 60 > 5
            THEN (TIME_TO_SEC(vc.hora) - TIME_TO_SEC(CASE WHEN vc.casilla = 'E1' THEN vc.he1 ELSE vc.he2 END)) DIV 60 - 5
            ELSE 0
        END AS minutos_diferencia,
        vc.justificacion,
        vc.casilla,
        vc.estado_marca
    FROM vw_casillas_marcacion vc
    WHERE vc.num_documento = p_num_documento
      AND vc.fecha >= DATE(NOW() - INTERVAL p_dias DAY)
    ORDER BY vc.fecha_marcacion DESC
    LIMIT 100;
END$$

DELIMITER ;
