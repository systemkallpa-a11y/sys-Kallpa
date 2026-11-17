-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v15 - tabla de control)
-- ============================================================
-- Alimenta la tabla "Control de Asistencia" del dashboard
-- (GET /api/reportes/control-asistencia).
--
-- REQUIERE: vista vw_casillas_marcacion (app/sql/vw_casillas_marcacion_v2.sql).
--   Aplicar la vista ANTES que este SP.
--
-- Cambios v15 (mismo contrato de columnas que v14):
--   * Que marca va en cada casilla (E1, S1, E2, S2) ya no se decide
--     aqui: se lee de vw_casillas_marcacion, la REGLA UNICA que
--     tambien usa Marcacion. Se eliminan los bloques marcas_base,
--     candidatos, entradas/salidas y sus rankings ("hora programada
--     mas cercana"), que desalineaban el reporte y Marcacion.
--   * Horario del dia: si hubiera dos vigentes (dia de cambio de
--     horario) se usa el mas reciente; la fila del dia no se duplica.
--   * Formulas de tardanza, horas y estados: sin cambios (v13/v14).
--   * Para revertir, volver a aplicar:
--       app/sql/sp_reporte_asistencia_automatica_v14.sql
--
-- Cambios v14 (se mantienen):
--   * Horas laboradas en MINUTOS ENTEROS: las marcas se truncan al
--     minuto (08:57:07 => 08:57) y el resultado sale como HH:MM:00.
--   * Tolerancia como gracia: si la entrada cae dentro de la tolerancia
--     (hasta la hora programada + 5:59), las horas se cuentan desde la
--     hora programada. Si llega tarde, desde su entrada real (al minuto).
--   * Se cumple: horas laboradas + minutos de atraso = jornada, cuando
--     la salida es a la hora o despues (ej. 08:30-13:30, entra 08:57
--     => 04:33 + 27 min = 5:00).
--   * Para revertir, volver a aplicar:
--       app/sql/sp_reporte_asistencia_automatica_v13.sql
--
-- Cambios v13 (se mantienen):
--   * Tolerancia de 5 min evaluada por MINUTO ENTERO, en T1 y T2:
--       - Puntual hasta la hora programada + 5:59 (ej. 08:05:59).
--       - TARDANZA desde la hora programada + 6:00 (ej. 08:06:00).
--       - Tardanza = minutos enteros de atraso - 5 (08:10 => 00:05:00).
--     Antes (v12) se comparaba al segundo: 08:05:33 era tardanza de 33 s.
--   * Para revertir, volver a aplicar:
--       app/sql/sp_reporte_asistencia_automatica_v12.sql
--
-- Cambios v12 (se mantienen):
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
          AND h.fecha_vigencia_inicio <= fe.f
          AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= fe.f)
        UNION
        -- Persona-dia CON marcas: conserva filas sin horario.
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    calendario AS (
        -- Horario vigente del dia. Si hubiera dos vigentes (dia de cambio
        -- de horario) se usa el mas reciente: misma eleccion que
        -- vw_casillas_marcacion, y nunca se duplica la fila del dia.
        SELECT gdoc, gf, hora_entrada, hora_salida, hora_entrada2, hora_salida2
        FROM (
            SELECT g.gdoc, g.gf,
                   h.hora_entrada, h.hora_salida,
                   h.hora_entrada2, h.hora_salida2,
                   ROW_NUMBER() OVER (
                       PARTITION BY g.gdoc, g.gf
                       ORDER BY h.fecha_vigencia_inicio DESC,
                                (h.fecha_vigencia_fin IS NULL) DESC
                   ) AS rn_h
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
             AND h.fecha_vigencia_inicio <= g.gf
             AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= g.gf)
        ) ch
        WHERE ch.rn_h = 1
    ),
    casillas AS (
        -- Las 4 casillas del dia segun la REGLA UNICA (vw_casillas_marcacion),
        -- la misma que muestra y edita Marcacion.
        SELECT vc.num_documento, vc.fecha,
               MAX(CASE WHEN vc.casilla = 'E1' THEN vc.hora END)           AS e1,
               MAX(CASE WHEN vc.casilla = 'E1' THEN vc.tipo_ubicacion END) AS e1_ubi,
               MAX(CASE WHEN vc.casilla = 'E1' THEN vc.justificacion END)  AS e1_just,
               MAX(CASE WHEN vc.casilla = 'S1' THEN vc.hora END)           AS s1,
               MAX(CASE WHEN vc.casilla = 'S1' THEN vc.tipo_ubicacion END) AS s1_ubi,
               MAX(CASE WHEN vc.casilla = 'S1' THEN vc.justificacion END)  AS s1_just,
               MAX(CASE WHEN vc.casilla = 'E2' THEN vc.hora END)           AS e2,
               MAX(CASE WHEN vc.casilla = 'E2' THEN vc.tipo_ubicacion END) AS e2_ubi,
               MAX(CASE WHEN vc.casilla = 'E2' THEN vc.justificacion END)  AS e2_just,
               MAX(CASE WHEN vc.casilla = 'S2' THEN vc.hora END)           AS s2,
               MAX(CASE WHEN vc.casilla = 'S2' THEN vc.tipo_ubicacion END) AS s2_ubi,
               MAX(CASE WHEN vc.casilla = 'S2' THEN vc.justificacion END)  AS s2_just
        FROM vw_casillas_marcacion vc
        WHERE vc.fecha BETWEEN p_fecha_inicio AND p_fecha_fin
          AND vc.casilla IS NOT NULL
        GROUP BY vc.num_documento, vc.fecha
    ),
    seleccion AS (
        SELECT c.gdoc, c.gf,
               c.hora_entrada, c.hora_salida,
               c.hora_entrada2, c.hora_salida2,
               k.e1, k.e1_ubi, k.e1_just,
               k.s1, k.s1_ubi, k.s1_just,
               k.e2, k.e2_ubi, k.e2_just,
               k.s2, k.s2_ubi, k.s2_just
        FROM calendario c
        LEFT JOIN casillas k
          ON k.num_documento = c.gdoc AND k.fecha = c.gf
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
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada, sel.e1) DIV 60 > 5 THEN 'TARDANZA'
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
                   WHEN TIMESTAMPDIFF(SECOND, sel.hora_entrada2, sel.e2) DIV 60 > 5 THEN 'TARDANZA'
                   ELSE 'ASISTENCIA'
               END AS estado_t2,
               -- Inicio/fin efectivos del turno en segundos, al minuto entero.
               -- Inicio: dentro de la tolerancia (o antes) => hora programada;
               --         tarde => entrada real truncada al minuto.
               -- Fin: salida real truncada al minuto, topada a la hora programada.
               CASE
                   WHEN sel.hora_entrada IS NULL OR sel.e1 IS NULL THEN NULL
                   WHEN (TIME_TO_SEC(sel.e1) - TIME_TO_SEC(sel.hora_entrada)) DIV 60 <= 5
                        THEN TIME_TO_SEC(sel.hora_entrada)
                   ELSE TIME_TO_SEC(sel.e1) DIV 60 * 60
               END AS ini1,
               CASE
                   WHEN sel.hora_salida IS NULL OR sel.s1 IS NULL THEN NULL
                   ELSE LEAST(TIME_TO_SEC(sel.s1) DIV 60 * 60, TIME_TO_SEC(sel.hora_salida))
               END AS fin1,
               CASE
                   WHEN sel.hora_entrada2 IS NULL OR sel.e2 IS NULL THEN NULL
                   WHEN (TIME_TO_SEC(sel.e2) - TIME_TO_SEC(sel.hora_entrada2)) DIV 60 <= 5
                        THEN TIME_TO_SEC(sel.hora_entrada2)
                   ELSE TIME_TO_SEC(sel.e2) DIV 60 * 60
               END AS ini2,
               CASE
                   WHEN sel.hora_salida2 IS NULL OR sel.s2 IS NULL THEN NULL
                   ELSE LEAST(TIME_TO_SEC(sel.s2) DIV 60 * 60, TIME_TO_SEC(sel.hora_salida2))
               END AS fin2
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

        -- HORAS T1: solo turno completo, en minutos enteros, topadas al
        -- horario, con la tolerancia como gracia (ver ini1/fin1).
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.hora_salida IS NULL THEN '-'
            WHEN ev.e1 IS NULL OR ev.s1 IS NULL THEN '-'
            WHEN ev.fin1 - ev.ini1 <= 0 THEN '-'
            ELSE CONCAT(
                LPAD((ev.fin1 - ev.ini1) DIV 3600, 2, '0'), ':',
                LPAD(((ev.fin1 - ev.ini1) MOD 3600) DIV 60, 2, '0'), ':00'
            )
        END AS HORAS_LABORADAS_T1,

        -- HORAS T2 (misma regla, ver ini2/fin2)
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.hora_salida2 IS NULL THEN '-'
            WHEN ev.e2 IS NULL OR ev.s2 IS NULL THEN '-'
            WHEN ev.fin2 - ev.ini2 <= 0 THEN '-'
            ELSE CONCAT(
                LPAD((ev.fin2 - ev.ini2) DIV 3600, 2, '0'), ':',
                LPAD(((ev.fin2 - ev.ini2) MOD 3600) DIV 60, 2, '0'), ':00'
            )
        END AS HORAS_LABORADAS_T2,

        -- TARDANZA T1 (tolerancia 5 min por minuto entero: desde hh:06)
        CASE
            WHEN ev.hora_entrada IS NULL OR ev.e1 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) DIV 60 <= 5 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) DIV 60 - 5) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada, ev.e1) DIV 60 - 5) MOD 60, 2, '0'), ':00'
            )
        END AS TARDANZA_T1,

        -- TARDANZA T2 (misma regla)
        CASE
            WHEN ev.hora_entrada2 IS NULL OR ev.e2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) DIV 60 <= 5 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) DIV 60 - 5) DIV 60, 2, '0'), ':',
                LPAD((TIMESTAMPDIFF(SECOND, ev.hora_entrada2, ev.e2) DIV 60 - 5) MOD 60, 2, '0'), ':00'
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
