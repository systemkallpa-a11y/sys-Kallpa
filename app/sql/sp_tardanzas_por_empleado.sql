-- ============================================================
-- SP: sp_tardanzas_por_empleado   (regla de turno Opcion A)
-- ============================================================
-- Alimenta al Excel "Tardanzas por Empleado"
-- (GET /api/marcacion/tardanzas-excel en app/routes/marcacion.py).
--
-- Cambio respecto de la version anterior (SOLO la regla de turno):
--   ANTES: separaba turnos por RELOJ (entrada <12:00 = turno 1;
--   >=12:00 = turno 2). Una entrada 12:30 con horario hasta las
--   13:00 se iba a la tarde y no contaba, mientras la tabla del
--   Control si la mostraba como mañana.
--   AHORA: misma regla que sp_reporte_asistencia_automatica v7
--   y sp_ObtenerIdsMarcacion v4 (Opcion A): la ENTRADA se
--   clasifica contra SU horario de ese dia:
--     - Sin horario ese dia -> reloj (<=14:00 = turno 1)
--     - Sin turno 2 ese dia -> turno 1
--     - Entrada <= hora_salida (fin de su mañana) -> turno 1
--     - Despues -> turno 2
--   (Solo mira ENTRADAS: es lo unico que usa para tardanzas.)
--
-- SIN CAMBIOS: columnas de salida (N, empresa, dni_ce, nombres,
--   cargo, horario, total_minutos_tarde, total_horas_tarde),
--   tolerancia de 5 min (tardanza_tX > 5), HAVING > 0, orden,
--   agrupaciones y consumidor. El Excel queda igual por fuera.
--
-- Impacto medido (septiembre-2026, en frio): 45 personas con
--   marcas; 39 con tardanzas; 10 personas cambian su total,
--   todas en aumento (llegadas 12:00-13:00 y sabados de un
--   solo turno ahora cuentan); nadie pierde minutos.
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP +
--   CREATE. Para revertir, guarda antes el estado actual:
--     SHOW CREATE PROCEDURE sp_tardanzas_por_empleado\G
--
-- Este SP solo existia en la BD (fuera del repo); con este
--   archivo queda versionado en app/sql/.
-- ============================================================

DROP PROCEDURE IF EXISTS sp_tardanzas_por_empleado;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_tardanzas_por_empleado`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SET @row_num := 0;
    
    SELECT 
        @row_num := @row_num + 1 AS N,
        t.empresa,
        t.dni_ce,
        t.nombres,
        t.cargo,
        t.horario,
        t.total_minutos_tarde,
        CONCAT(
            LPAD(t.total_minutos_tarde DIV 60, 2, '0'), ':',
            LPAD(t.total_minutos_tarde MOD 60, 2, '0')
        ) AS total_horas_tarde
    FROM (
        SELECT 
            IFNULL(e.nombre, 'Sin Empresa') AS empresa,
            p.documento_numero AS dni_ce,
            CONCAT(p.apellido_paterno, ' ', p.apellido_materno, ', ', p.nombres) AS nombres,
            IFNULL(c.nombre, 'Sin Cargo') AS cargo,
            (SELECT CONCAT(h2.hora_entrada, '-', h2.hora_salida, 
                          IF(h2.hora_entrada2 IS NOT NULL, CONCAT(' / ', h2.hora_entrada2, '-', h2.hora_salida2), ''))
             FROM TblHorarioTrabajo h2 
             WHERE h2.num_documento = p.num_documento AND h2.es_activo = 1
             GROUP BY h2.hora_entrada, h2.hora_salida, h2.hora_entrada2, h2.hora_salida2
             ORDER BY COUNT(*) DESC LIMIT 1) AS horario,
            SUM(
                CASE 
                    WHEN tardanza_t1 > 5 THEN tardanza_t1
                    ELSE 0
                END
            ) + SUM(
                CASE 
                    WHEN tardanza_t2 > 5 THEN tardanza_t2
                    ELSE 0
                END
            ) AS total_minutos_tarde
        FROM (
            SELECT 
                marks.num_documento,
                marks.num_usuario,
                marks.fecha,
                CASE 
                    WHEN MIN(CASE WHEN marks.tipo_marcacion = 'ENTRADA' AND marks.turno = 1 THEN marks.hora_marca END) IS NULL THEN 0
                    ELSE TIMESTAMPDIFF(MINUTE, marks.hora_entrada, MIN(CASE WHEN marks.tipo_marcacion = 'ENTRADA' AND marks.turno = 1 THEN marks.hora_marca END))
                END AS tardanza_t1,
                CASE 
                    WHEN MIN(CASE WHEN marks.tipo_marcacion = 'ENTRADA' AND marks.turno = 2 THEN marks.hora_marca END) IS NULL THEN 0
                    ELSE TIMESTAMPDIFF(MINUTE, marks.hora_entrada2, MIN(CASE WHEN marks.tipo_marcacion = 'ENTRADA' AND marks.turno = 2 THEN marks.hora_marca END))
                END AS tardanza_t2
            FROM (
                SELECT 
                    m.num_documento,
                    m.num_usuario,
                    DATE(m.fecha_marcacion) AS fecha,
                    m.tipo_marcacion,
                    TIME(m.fecha_marcacion) AS hora_marca,
                    h.hora_entrada,
                    h.hora_salida,
                    h.hora_entrada2,
                    h.hora_salida2,
                    CASE
                        WHEN h.num_documento IS NULL THEN CASE WHEN TIME(m.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                        WHEN h.hora_entrada2 IS NULL OR h.hora_salida IS NULL THEN 1
                        WHEN TIME(m.fecha_marcacion) <= h.hora_salida THEN 1
                        ELSE 2
                    END AS turno
                FROM TblMarcacion m
                LEFT JOIN TblHorarioTrabajo h ON m.num_documento = h.num_documento 
                    AND UPPER(h.dia_semana) = CASE DAYOFWEEK(m.fecha_marcacion)
                        WHEN 1 THEN 'DOMINGO'
                        WHEN 2 THEN 'LUNES'
                        WHEN 3 THEN 'MARTES'
                        WHEN 4 THEN 'MIÉRCOLES'
                        WHEN 5 THEN 'JUEVES'
                        WHEN 6 THEN 'VIERNES'
                        WHEN 7 THEN 'SÁBADO'
                    END
                    AND h.es_activo = 1
                WHERE DATE(m.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
            ) marks
            GROUP BY marks.num_documento, marks.num_usuario, marks.fecha,
                     marks.hora_entrada, marks.hora_salida, marks.hora_entrada2, marks.hora_salida2
        ) AS daily_data
        INNER JOIN TblPersona p ON daily_data.num_documento = p.num_documento
        INNER JOIN TblUsuario u ON daily_data.num_usuario = u.num_usuario
        LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
        LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
        GROUP BY p.num_documento, e.nombre, p.nombres, p.apellido_paterno, p.apellido_materno, 
                 p.documento_numero, c.nombre
        HAVING total_minutos_tarde > 0
        ORDER BY total_minutos_tarde DESC
    ) AS t;
END$$

DELIMITER ;
