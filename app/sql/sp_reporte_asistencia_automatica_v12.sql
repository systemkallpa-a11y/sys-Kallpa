-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v12 - tabla de control)
-- ============================================================
-- Alimenta la tabla "Control de Asistencia" del dashboard
-- (GET /api/reportes/control-asistencia).
--
-- Cambios v12 (mantiene el mismo contrato de columnas):
--   * Asignacion de cada marca al turno por la hora esperada mas
--     cercana de su mismo tipo (ENTRADA/SALIDA), no por la ultima
--     entrada. Esto corrige la salida de T2 que caia en T1.
--   * De cada turno se toma una sola entrada y una sola salida.
--     Si hay marcas extra, se ignora el resto.
--   * Estados por turno: ASISTENCIA, TARDANZA, INCOMPLETO, FALTO,
--     VACACIONES. CAMPO deja de ser estado: solo es ubicacion.
--   * El estado se muestra en el bloque de la primera entrada del
--     turno; si no hay entrada, en el bloque de la salida. Si el
--     turno no tiene marcas, se muestra en OFICINA y CAMPO queda
--     en '-'.
--   * Horas solo si el turno tiene entrada y salida. Se topan al
--     horario y nunca se emiten valores negativos.
--   * Tardanza por turno con la entrada elegida y prorroga de 5 min.
--   * SIN HORARIO se conserva como excepcion informativa.
--   * No se implementan feriados ni salida anticipada como estado.
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP + CREATE.
--   Para revertir, volver a aplicar:
--     app/sql/sp_reporte_asistencia_automatica_v11.sql
-- ============================================================

DROP PROCEDURE IF EXISTS sp_reporte_asistencia_automatica;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_reporte_asistencia_automatica`(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_num_usuario INT
)
BEGIN
    WITH RECURSIVE fechas AS (
        SELECT p_fecha_inicio AS f WHERE p_fecha_inicio <= p_fecha_fin
        UNION ALL
        SELECT f + INTERVAL 1 DAY FROM fechas WHERE f < p_fecha_fin
    ),
    grid AS (
        -- Persona-dia CON horario activo ese dia.
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
        -- Persona-dia CON marcas: conserva filas sin horario.
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    calendario AS (
        SELECT g.gdoc, g.gf,
               h.hora_entrada, h.hora_salida,
               h.hora_entrada2, h.hora_salida2
        FROM grid g
        LEFT JOIN TblHorarioTrabajo h
          ON h.num_documento = g.gdoc
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
    ),
    marcas_base AS (
        SELECT mm.id_marcacion,
               mm.num_documento,
               c.gf,
               TIME(mm.fecha_marcacion) AS hora,
               mm.tipo_marcacion,
               mm.tipo_ubicacion,
               mm.justificacion,
               c.hora_entrada,
               c.hora_salida,
               c.hora_entrada2,
               c.hora_salida2
        FROM TblMarcacion mm
        JOIN calendario c
          ON c.gdoc = mm.num_documento
         AND c.gf = DATE(mm.fecha_marcacion)
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    candidatos AS (
        -- Turno por hora esperada mas cercana del mismo tipo.
        SELECT mb.*,
               CASE
                    WHEN mb.tipo_marcacion = 'ENTRADA' THEN
                        CASE
                            -- Sin horario: se conserva la marca para poder
                            -- mostrar SIN HORARIO; el corte informativo es 14:00.
                            WHEN mb.hora_entrada IS NULL AND mb.hora_entrada2 IS NULL THEN
                                CASE WHEN mb.hora <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN mb.hora_entrada2 IS NULL THEN 1
                            WHEN mb.hora_entrada IS NULL THEN 2
                            WHEN ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_entrada))
                                 <= ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_entrada2)) THEN 1
                            ELSE 2
                        END
                    WHEN mb.tipo_marcacion = 'SALIDA' THEN
                        CASE
                            WHEN mb.hora_salida IS NULL AND mb.hora_salida2 IS NULL THEN
                                CASE WHEN mb.hora <= '14:00:00' THEN 1 ELSE 2 END
                            WHEN mb.hora_salida2 IS NULL THEN 1
                            WHEN mb.hora_salida IS NULL THEN 2
                            WHEN ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_salida))
                                 <= ABS(TIMESTAMPDIFF(SECOND, mb.hora, mb.hora_salida2)) THEN 1
                            ELSE 2
                        END
                END AS turno
        FROM marcas_base mb
    ),
    entradas AS (
        SELECT c.num_documento, c.gf, c.turno, c.hora,
               c.tipo_ubicacion, c.justificacion,
               CASE WHEN c.turno = 1 THEN c.hora_entrada
                    ELSE c.hora_entrada2 END AS esperada
        FROM candidatos c
        WHERE c.tipo_marcacion = 'ENTRADA'
          AND c.turno IS NOT NULL
    ),
    salidas AS (
        SELECT c.num_documento, c.gf, c.turno, c.hora,
               c.tipo_ubicacion, c.justificacion,
               CASE WHEN c.turno = 1 THEN c.hora_salida
                    ELSE c.hora_salida2 END AS esperada
        FROM candidatos c
        WHERE c.tipo_marcacion = 'SALIDA'
          AND c.turno IS NOT NULL
    ),
    entradas_rank AS (
        -- Preferimos una entrada dentro de +/-2 h de la esperada.
        -- Si hay varias, primero la que esta en/hacia adelante de
        -- la hora esperada (evita tomar una marca de refrigerio).
        SELECT e.*,
               ROW_NUMBER() OVER (
                   PARTITION BY e.num_documento, e.gf, e.turno
                   ORDER BY
                       CASE WHEN e.esperada IS NULL THEN 1 ELSE 0 END,
                       CASE WHEN e.esperada IS NULL THEN 0
                            WHEN ABS(TIMESTAMPDIFF(SECOND, e.hora, e.esperada)) <= 7200 THEN 0
                            ELSE 1 END,
                       CASE WHEN e.esperada IS NULL THEN 0
                            WHEN e.hora >= e.esperada THEN 0
                            ELSE 1 END,
                       ABS(TIMESTAMPDIFF(SECOND, e.hora, e.esperada)),
                       e.hora ASC
               ) AS rn
        FROM entradas e
    ),
    salidas_rank AS (
        -- Simetrico: preferimos una salida en/hacia atras de la
        -- hora esperada, para no tomar una salida posterior de mas.
        SELECT s.*,
               ROW_NUMBER() OVER (
                   PARTITION BY s.num_documento, s.gf, s.turno
                   ORDER BY
                       CASE WHEN s.esperada IS NULL THEN 1 ELSE 0 END,
                       CASE WHEN s.esperada IS NULL THEN 0
                            WHEN ABS(TIMESTAMPDIFF(SECOND, s.hora, s.esperada)) <= 7200 THEN 0
                            ELSE 1 END,
                       CASE WHEN s.esperada IS NULL THEN 0
                            WHEN s.hora <= s.esperada THEN 0
                            ELSE 1 END,
                       ABS(TIMESTAMPDIFF(SECOND, s.hora, s.esperada)),
                       s.hora DESC
               ) AS rn
        FROM salidas s
    ),
    seleccion AS (
        SELECT c.gdoc, c.gf,
               c.hora_entrada, c.hora_salida,
               c.hora_entrada2, c.hora_salida2,
               e1.hora AS e1, e1.tipo_ubicacion AS e1_ubi, e1.justificacion AS e1_just,
               s1.hora AS s1, s1.tipo_ubicacion AS s1_ubi, s1.justificacion AS s1_just,
               e2.hora AS e2, e2.tipo_ubicacion AS e2_ubi, e2.justificacion AS e2_just,
               s2.hora AS s2, s2.tipo_ubicacion AS s2_ubi, s2.justificacion AS s2_just
        FROM calendario c
        LEFT JOIN entradas_rank e1
          ON e1.num_documento = c.gdoc AND e1.gf = c.gf
         AND e1.turno = 1 AND e1.rn = 1
        LEFT JOIN salidas_rank s1
          ON s1.num_documento = c.gdoc AND s1.gf = c.gf
         AND s1.turno = 1 AND s1.rn = 1
        LEFT JOIN entradas_rank e2
          ON e2.num_documento = c.gdoc AND e2.gf = c.gf
         AND e2.turno = 2 AND e2.rn = 1
        LEFT JOIN salidas_rank s2
          ON s2.num_documento = c.gdoc AND s2.gf = c.gf
         AND s2.turno = 2 AND s2.rn = 1
    ),
    evaluacion AS (
        SELECT sel.*,
               CASE
                   WHEN sel.hora_entrada IS NULL OR sel.hora_salida IS NULL THEN 'SIN HORARIO'
                   WHEN sel.e1 IS NULL AND sel.s1 IS NULL THEN
                       CASE
                           WHEN EXISTS (
                               SELECT 1 FROM TblVacaciones v
                               WHERE v.num_documento = sel.gdoc
                                 AND v.estado = 'APROBADO'
                                 AND sel.gf BETWEEN v.fecha_inicio AND v.fecha_fin
                           ) THEN 'VACACIONES'
                           WHEN TIMESTAMP(sel.gf, sel.hora_salida) >= NOW() THEN '-'
                           ELSE 'FALTÓ'
                       END
                   WHEN sel.e1 IS NULL OR sel.s1 IS NULL THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.e1, sel.s1) <= 0 THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada, sel.e1) > 300 THEN 'TARDANZA'
                   ELSE 'ASISTENCIA'
               END AS estado_t1,
               CASE
                   WHEN sel.hora_entrada2 IS NULL OR sel.hora_salida2 IS NULL THEN 'SIN HORARIO'
                   WHEN sel.e2 IS NULL AND sel.s2 IS NULL THEN
                       CASE
                           WHEN EXISTS (
                               SELECT 1 FROM TblVacaciones v
                               WHERE v.num_documento = sel.gdoc
                                 AND v.estado = 'APROBADO'
                                 AND sel.gf BETWEEN v.fecha_inicio AND v.fecha_fin
                           ) THEN 'VACACIONES'
                           WHEN TIMESTAMP(sel.gf, sel.hora_salida2) >= NOW() THEN '-'
                           ELSE 'FALTÓ'
                       END
                   WHEN sel.e2 IS NULL OR sel.s2 IS NULL THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.e2, sel.s2) <= 0 THEN 'INCOMPLETO'
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada2, sel.e2) > 300 THEN 'TARDANZA'
                   ELSE 'ASISTENCIA'
               END AS estado_t2
        FROM seleccion sel
    )
    SELECT
        IFNULL(e.nombre, 'Sin Empresa') AS EMPRESA,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS NOMBRES,
        p.documento_numero AS DNI_CE,
        IFNULL(c.nombre, 'Sin Cargo') AS CARGO,
        IFNULL(a.nombre, 'Sin Área') AS AREA,
        IFNULL(
            (SELECT ub2.nombre_zona
             FROM TblUbicacionMarcacion ub2
             WHERE ub2.num_documento = p.num_documento
               AND ub2.estado = 'ACTIVO'
             LIMIT 1),
            'Sin Sede Asignada'
        ) AS SEDE_TRABAJO,
        DAY(ev.gf) AS DIA,
        MONTH(ev.gf) AS MES,
        YEAR(ev.gf) AS ANO,
        ELT(DAYOFWEEK(ev.gf), 'Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado') AS DIA_SEMANA,

        -- OFICINA - T1
        CASE WHEN ev.e1_ubi = 'OFICINA' THEN TIME_FORMAT(ev.e1, '%H:%i:%s') END AS H_ENTRADA_OFI_T1,
        CASE WHEN ev.s1_ubi = 'OFICINA' THEN TIME_FORMAT(ev.s1, '%H:%i:%s') END AS H_SALIDA_OFI_T1,
        -- OFICINA - T2
        CASE WHEN ev.e2_ubi = 'OFICINA' THEN TIME_FORMAT(ev.e2, '%H:%i:%s') END AS H_ENTRADA_OFI_T2,
        CASE WHEN ev.s2_ubi = 'OFICINA' THEN TIME_FORMAT(ev.s2, '%H:%i:%s') END AS H_SALIDA_OFI_T2,
        -- CAMPO - T1
        CASE WHEN ev.e1_ubi = 'CAMPO' THEN TIME_FORMAT(ev.e1, '%H:%i:%s') END AS H_ENTRADA_CMP_T1,
        CASE WHEN ev.s1_ubi = 'CAMPO' THEN TIME_FORMAT(ev.s1, '%H:%i:%s') END AS H_SALIDA_CMP_T1,
        -- CAMPO - T2
        CASE WHEN ev.e2_ubi = 'CAMPO' THEN TIME_FORMAT(ev.e2, '%H:%i:%s') END AS H_ENTRADA_CMP_T2,
        CASE WHEN ev.s2_ubi = 'CAMPO' THEN TIME_FORMAT(ev.s2, '%H:%i:%s') END AS H_SALIDA_CMP_T2,

        -- HORAS T1: solo turno completo, topadas al horario, sin negativos.
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.hora_salida IS NULL THEN '-'
            WHEN ev.e1 IS NULL OR ev.s1 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(
                     SECOND,
                     GREATEST(ev.e1, ev.hora_entrada),
                     LEAST(ev.s1, ev.hora_salida)
                 ) <= 0 THEN '-'
            ELSE CONCAT(
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) DIV 3600, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e1, ev.hora_entrada),
                         LEAST(ev.s1, ev.hora_salida)
                     ) MOD 60, 2, '0')
            )
        END AS HORAS_LABORADAS_T1,

        -- HORAS T2
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.hora_salida2 IS NULL THEN '-'
            WHEN ev.e2 IS NULL OR ev.s2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(
                     SECOND,
                     GREATEST(ev.e2, ev.hora_entrada2),
                     LEAST(ev.s2, ev.hora_salida2)
                 ) <= 0 THEN '-'
            ELSE CONCAT(
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) DIV 3600, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD(TIMESTAMPDIFF(
                         SECOND,
                         GREATEST(ev.e2, ev.hora_entrada2),
                         LEAST(ev.s2, ev.hora_salida2)
                     ) MOD 60, 2, '0')
            )
        END AS HORAS_LABORADAS_T2,

        -- TARDANZA T1 (prorroga 5 min)
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.e1 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) DIV 3600, 2, '0'), ':',
                LPAD(((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T1,

        -- TARDANZA T2
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.e2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) DIV 3600, 2, '0'), ':',
                LPAD(((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) MOD 3600) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T2,

        -- DETALLE OFICINA/CAMPO: un solo estado por turno.
        -- SIN HORARIO solo es informativo: se muestra si el turno tiene
        -- marcas. Un turno que no existe en el horario (ej. sin T2) y
        -- sin marcas queda en '-', no en SIN HORARIO.
        CASE
            WHEN ev.estado_t1 = '-' THEN '-'
            WHEN ev.estado_t1 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'OFICINA'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e1 IS NULL AND ev.s1 IS NULL THEN ev.estado_t1
            WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'OFICINA' THEN ev.estado_t1
            ELSE '-'
        END AS DETALLE_OFI_T1,
        CASE
            WHEN ev.estado_t1 = '-' THEN '-'
            WHEN ev.estado_t1 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'CAMPO'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e1 IS NULL AND ev.s1 IS NULL THEN '-'
            WHEN COALESCE(ev.e1_ubi, ev.s1_ubi) = 'CAMPO' THEN ev.estado_t1
            ELSE '-'
        END AS DETALLE_CMP_T1,
        CASE
            WHEN ev.estado_t2 = '-' THEN '-'
            WHEN ev.estado_t2 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'OFICINA'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e2 IS NULL AND ev.s2 IS NULL THEN ev.estado_t2
            WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'OFICINA' THEN ev.estado_t2
            ELSE '-'
        END AS DETALLE_OFI_T2,
        CASE
            WHEN ev.estado_t2 = '-' THEN '-'
            WHEN ev.estado_t2 = 'SIN HORARIO' THEN
                CASE WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'CAMPO'
                     THEN 'SIN HORARIO' ELSE '-' END
            WHEN ev.e2 IS NULL AND ev.s2 IS NULL THEN '-'
            WHEN COALESCE(ev.e2_ubi, ev.s2_ubi) = 'CAMPO' THEN ev.estado_t2
            ELSE '-'
        END AS DETALLE_CMP_T2,

        -- JUSTIFICACIONES de las marcas elegidas
        ev.e1_just AS JUSTIFICACION_ENT_T1,
        ev.s1_just AS JUSTIFICACION_SAL_T1,
        ev.e2_just AS JUSTIFICACION_ENT_T2,
        ev.s2_just AS JUSTIFICACION_SAL_T2

    FROM evaluacion ev
    INNER JOIN TblPersona p ON p.num_documento = ev.gdoc
    INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    WHERE (p_num_usuario IS NULL OR u.num_usuario = p_num_usuario)
    ORDER BY ev.gf ASC, p.apellido_paterno ASC;
END $$

DELIMITER ;
