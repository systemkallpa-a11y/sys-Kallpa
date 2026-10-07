-- ============================================================
-- SP: sp_tardanzas_por_empleado   (v2 - espejo del dashboard)
-- ============================================================
-- Alimenta al Excel "Tardanzas por Empleado"
-- (GET /api/marcacion/tardanzas-excel en app/routes/marcacion.py).
--
-- REEMPLAZA al SP anterior: misma logica de
-- sp_reporte_asistencia_automatica v9 (el dashboard), para que
-- el Excel coincida fila por fila con la tabla en pantalla:
--   * Misma grilla persona-dia (horario activo + dias con marcas)
--   * Misma asignacion de turnos (Opcion A / CTE marcas)
--   * Tardanza SOLO en OFICINA (1a ENTRADA del turno), > 300 seg
--     (mismo orden de condiciones que DETALLE_OFI_T1/T2 de v9)
--   * Campo nunca genera tardanza (igual que el dashboard)
--   * Total por empleado = SUMA(segundos de cada dia-turno
--     TARDANZA) DIV 60 (piso); Total Horas se deriva de ahi.
--
-- Columnas de salida (10): las 8 originales del Excel
--   (N, empresa, dni_ce, nombres, cargo, horario,
--    total_minutos_tarde, total_horas_tarde)
--   + 2 extras SOLO para filtros del backend (el Excel NO las
--   usa; marcacion.py las lee por nombre):
--     area       : IFNULL(a.nombre,'Sin Área')  <- igual que el
--                  dashboard (via u.id_cargo -> c.id_area)
--     nombres_dash: formato del dashboard
--                  CONCAT(p.nombres,' ',p.apellido_paterno,' ',
--                  p.apellido_materno) para replicar el filtro
--                  de empleado del Control (contains ignore-case).
-- Solo empleados con total_minutos_tarde > 0; orden por total
--   descendente. Diagnostico previo (sept-2026): 39 empleados /
--   22,680 min con el SP viejo vs 41 / ~22,482 con esta regla.
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP +
--   CREATE. Para revertir, guarda antes el estado actual:
--     SHOW CREATE PROCEDURE sp_tardanzas_por_empleado\G
-- ============================================================

DROP PROCEDURE IF EXISTS sp_tardanzas_por_empleado;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_tardanzas_por_empleado`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE
)
BEGIN
    SET @row_num := 0;

    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS f WHERE p_fecha_inicio <= p_fecha_fin
        UNION ALL
        SELECT f + INTERVAL 1 DAY FROM fechas WHERE f < p_fecha_fin
    ),
    grid AS (
        SELECT DISTINCT h.num_documento AS gdoc, fe.f AS gf
        FROM TblHorarioTrabajo h
        JOIN fechas fe
          ON UPPER(h.dia_semana) = CASE DAYOFWEEK(fe.f)
                 WHEN 1 THEN 'DOMINGO'
                 WHEN 2 THEN 'LUNES'
                 WHEN 3 THEN 'MARTES'
                 WHEN 4 THEN 'MIÉRCOLES'
                 WHEN 5 THEN 'JUEVES'
                 WHEN 6 THEN 'VIERNES'
                 WHEN 7 THEN 'SÁBADO'
             END
        WHERE h.es_activo = 1
        UNION
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    marcas AS (
        SELECT a.*,
               CASE
                    WHEN a.ult_ent IS NULL
                         THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                    WHEN hh.num_documento IS NULL
                         THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                    WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                    WHEN TIME(a.ult_ent) <= hh.hora_salida THEN 1
                    ELSE 2
               END AS turno
        FROM (
            SELECT mm.*,
                   MAX(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN mm.fecha_marcacion END)
                       OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                             ORDER BY mm.fecha_marcacion, mm.id_marcacion
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ult_ent
            FROM TblMarcacion mm
            WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
        ) a
        LEFT JOIN TblHorarioTrabajo hh ON hh.num_documento = a.num_documento
            AND UPPER(hh.dia_semana) = CASE DAYOFWEEK(a.fecha_marcacion)
                WHEN 1 THEN 'DOMINGO'
                WHEN 2 THEN 'LUNES'
                WHEN 3 THEN 'MARTES'
                WHEN 4 THEN 'MIÉRCOLES'
                WHEN 5 THEN 'JUEVES'
                WHEN 6 THEN 'VIERNES'
                WHEN 7 THEN 'SÁBADO'
            END
            AND hh.es_activo = 1
    ),
    dias AS (
        SELECT
            g.gdoc,
            g.gf,
            -- Segundos de tardanza turno 1 (misma logica y mismo
            -- orden de condiciones que DETALLE_OFI_T1 de v9:
            -- sin marcas / sin ENTRADA OFICINA / sin horario =>
            -- 0; si no, solo cuenta si la diferencia > 300 seg)
            CASE
                WHEN COUNT(CASE WHEN m.turno = 1 THEN 1 END) = 0 THEN 0
                WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                              AND m.tipo_ubicacion = 'OFICINA'
                              THEN TIME(m.fecha_marcacion) END) IS NULL THEN 0
                WHEN h.hora_entrada IS NULL THEN 0
                WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN 0
                ELSE TIMESTAMPDIFF(SECOND, h.hora_entrada,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END))
            END AS seg_t1,
            -- Segundos de tardanza turno 2 (idem DETALLE_OFI_T2)
            CASE
                WHEN COUNT(CASE WHEN m.turno = 2 THEN 1 END) = 0 THEN 0
                WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                              AND m.tipo_ubicacion = 'OFICINA'
                              THEN TIME(m.fecha_marcacion) END) IS NULL THEN 0
                WHEN h.hora_entrada2 IS NULL THEN 0
                WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada2,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN 0
                ELSE TIMESTAMPDIFF(SECOND, h.hora_entrada2,
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                                 AND m.tipo_ubicacion = 'OFICINA'
                                 THEN TIME(m.fecha_marcacion) END))
            END AS seg_t2
        FROM grid g
        LEFT JOIN marcas m ON m.num_documento = g.gdoc
            AND DATE(m.fecha_marcacion) = g.gf
        LEFT JOIN TblHorarioTrabajo h ON h.num_documento = g.gdoc
            AND UPPER(h.dia_semana) = CASE DAYOFWEEK(g.gf)
                WHEN 1 THEN 'DOMINGO'
                WHEN 2 THEN 'LUNES'
                WHEN 3 THEN 'MARTES'
                WHEN 4 THEN 'MIÉRCOLES'
                WHEN 5 THEN 'JUEVES'
                WHEN 6 THEN 'VIERNES'
                WHEN 7 THEN 'SÁBADO'
            END
            AND h.es_activo = 1
        GROUP BY g.gdoc, g.gf, h.hora_entrada, h.hora_entrada2
    )
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
        ) AS total_horas_tarde,
        t.area,
        t.nombres_dash
    FROM (
        SELECT
            IFNULL(e.nombre, 'Sin Empresa') AS empresa,
            p.documento_numero AS dni_ce,
            CONCAT(p.apellido_paterno, ' ', p.apellido_materno, ', ', p.nombres) AS nombres,
            IFNULL(c.nombre, 'Sin Cargo') AS cargo,
            (SELECT CONCAT(h2.hora_entrada, '-', h2.hora_salida,
                          IF(h2.hora_entrada2 IS NOT NULL,
                             CONCAT(' / ', h2.hora_entrada2, '-', h2.hora_salida2), ''))
             FROM TblHorarioTrabajo h2
             WHERE h2.num_documento = p.num_documento AND h2.es_activo = 1
             GROUP BY h2.hora_entrada, h2.hora_salida, h2.hora_entrada2, h2.hora_salida2
             ORDER BY COUNT(*) DESC LIMIT 1) AS horario,
            (SUM(d.seg_t1) + SUM(d.seg_t2)) DIV 60 AS total_minutos_tarde,
            IFNULL(a.nombre, 'Sin Área') AS area,
            CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS nombres_dash
        FROM dias d
        INNER JOIN TblPersona p ON p.num_documento = d.gdoc
        INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
        LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
        LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
        LEFT JOIN TblArea a ON c.id_area = a.id_area
        GROUP BY p.num_documento, e.nombre, p.nombres, p.apellido_paterno,
                 p.apellido_materno, p.documento_numero, c.nombre, a.nombre
        HAVING (SUM(d.seg_t1) + SUM(d.seg_t2)) DIV 60 > 0
        ORDER BY total_minutos_tarde DESC
    ) AS t;
END$$

DELIMITER ;
