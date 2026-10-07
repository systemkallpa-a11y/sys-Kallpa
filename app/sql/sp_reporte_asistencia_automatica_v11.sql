-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v11 - TARDANZA neta)
-- ============================================================
-- Alimenta la tabla "Control de Asistencia" del dashboard
-- (GET /api/reportes/control-asistencia) y su export Excel
-- (ambos consumidores leen por nombre de columna => el Excel no cambia).
--
-- v11 (cambio de regla SOLO en TARDANZA_T1/T2, estructura igual):
--   * Ubicacion: cuenta la 1a ENTRADA del turno de CUALQUIER
--     ubicacion (OFICINA o CAMPO; gana la mas temprana).
--   * Valor: retraso NETO de la prorroga de 5 minutos (300 s):
--       diff = 1a ENTRADA - hora_entrada del horario
--       diff <= 300 s  -> '-' (a tiempo, en el margen o antes de hora)
--       diff >  300 s  -> HH:MM:SS de (diff - 300)
--     Ej: horario 08:00 y entrada 08:20 => 00:15:00 (20 - 5 min)
--   * Solo se consideran marcaciones ENTRADA (las salidas no cuentan).
--   * DETALLE_OFI_T1/T2 SIN CAMBIOS (siguen solo OFICINA, umbral 300 s).
--
-- BASE: v11 = v10 con los dos bloques TARDANZA_* modificados; el
--   cuerpo coincide con el SHOW CREATE real de la BD (aplicado y
--   verificado el 2026-10-07: recalc independiente sept-2026 sin
--   diferencias, anclas 00:05:24 -> 00:00:24 y 00:05:59 -> 00:00:59).
--
-- Total de columnas de salida: 25 (sin cambios de estructura).
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP + CREATE.
--   Para revertir, guarda antes el estado actual:
--     SHOW CREATE PROCEDURE sp_reporte_asistencia_automatica\G
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
        -- Persona-dia CON horario activo ese dia: genera filas
        -- aunque no haya marcas (dias sin registro → FALTÓ).
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
        -- Persona-dia CON marcas: conserva EXACTAMENTE las filas
        -- que existen hoy (incluye dias sin horario).
        SELECT DISTINCT mm.num_documento, DATE(mm.fecha_marcacion)
        FROM TblMarcacion mm
        WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
    ),
    marcas AS (
        -- Asignacion de cada marca a su turno (Opcion A, IDENTICA
        -- a v7): la ultima ENTRADA que la precede decide el turno
        -- segun SU horario de ese dia.
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
    )
    SELECT 
        -- 1. INFORMACIÓN GENERAL
        IFNULL(e.nombre, 'Sin Empresa') AS EMPRESA,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS NOMBRES,
        p.documento_numero AS DNI_CE,
        IFNULL(c.nombre, 'Sin Cargo') AS CARGO,
        IFNULL(a.nombre, 'Sin Área') AS AREA,
        
        -- 2. SEDE: Siempre traer la sede del usuario
        IFNULL(
            (SELECT ub2.nombre_zona 
             FROM TblUbicacionMarcacion ub2 
             WHERE ub2.num_documento = p.num_documento 
               AND ub2.estado = 'ACTIVO' 
             LIMIT 1),
            'Sin Sede Asignada'
        ) AS SEDE_TRABAJO,
        
        -- 3. FECHA (desde la grilla: la fila existe aunque no haya marcas)
        DAY(g.gf) AS DIA,
        MONTH(g.gf) AS MES,
        YEAR(g.gf) AS ANO,
        ELT(DAYOFWEEK(g.gf), 'Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado') AS DIA_SEMANA,
        
        -- 4. OFICINA - TURNO MAÑANA (CON SEGUNDOS: %H:%i:%s)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T1,
        
        -- 5. OFICINA - TURNO TARDE (CON SEGUNDOS: %H:%i:%s)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T2,
        
        -- 6. CAMPO - TURNO MAÑANA (CON SEGUNDOS: %H:%i:%s)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T1,
        
        -- 7. CAMPO - TURNO TARDE (CON SEGUNDOS: %H:%i:%s)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i:%s') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T2,
        
        -- 8. HORAS LABORADAS TURNO MAÑANA (tiempo real trabajado, limitado por horario)
        -- Si marca antes de su hora de entrada, usa hora de entrada del horario
        -- Si marca después de su hora de salida, usa hora de salida del horario
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 
                CONCAT(
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        -- Entrada efectiva: si marca antes del horario, usa horario
                        CASE 
                            WHEN h.hora_entrada IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END,
                        -- Salida efectiva: si marca después del horario, usa horario
                        CASE 
                            WHEN h.hora_salida IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) DIV 3600, 2, '0'),
                    ':',
                    LPAD((TIMESTAMPDIFF(SECOND, 
                        CASE 
                            WHEN h.hora_entrada IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END,
                        CASE 
                            WHEN h.hora_salida IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) MOD 3600) DIV 60, 2, '0'),
                    ':',
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        CASE 
                            WHEN h.hora_entrada IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END,
                        CASE 
                            WHEN h.hora_salida IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) MOD 60, 2, '0')
                )
        END AS HORAS_LABORADAS_T1,
        
        -- 9. HORAS LABORADAS TURNO TARDE (tiempo real trabajado, limitado por horario)
        -- Si marca antes de su hora de entrada, usa hora de entrada del horario
        -- Si marca después de su hora de salida, usa hora de salida del horario
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 
                CONCAT(
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        -- Entrada efectiva: si marca antes del horario, usa horario
                        CASE 
                            WHEN h.hora_entrada2 IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada2
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END,
                        -- Salida efectiva: si marca después del horario, usa horario
                        CASE 
                            WHEN h.hora_salida2 IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida2
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) DIV 3600, 2, '0'),
                    ':',
                    LPAD((TIMESTAMPDIFF(SECOND, 
                        CASE 
                            WHEN h.hora_entrada2 IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada2
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END,
                        CASE 
                            WHEN h.hora_salida2 IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida2
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) MOD 3600) DIV 60, 2, '0'),
                    ':',
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        CASE 
                            WHEN h.hora_entrada2 IS NOT NULL THEN
                                GREATEST(
                                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_entrada2
                                )
                            ELSE MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END,
                        CASE 
                            WHEN h.hora_salida2 IS NOT NULL THEN
                                LEAST(
                                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                                    h.hora_salida2
                                )
                            ELSE MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                        END
                    ) MOD 60, 2, '0')
                )
        END AS HORAS_LABORADAS_T2,

        -- TARDANZA MAÑANA (v11): 1a ENTRADA de cualquier ubicacion (OFICINA o CAMPO)
        -- Retraso neto: descuenta la prorroga de 300 seg; '-' si no hay tardanza
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 1 THEN 1 END) = 0 THEN '-'
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)) - 300) DIV 3600, 2, '0'),
                ':',
                LPAD(((TIMESTAMPDIFF(SECOND, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)) - 300) MOD 3600) DIV 60, 2, '0'),
                ':',
                LPAD((TIMESTAMPDIFF(SECOND, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T1,

        -- TARDANZA TARDE (v11): misma regla, turno 2
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 2 THEN 1 END) = 0 THEN '-'
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL THEN '-'
            WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)) <= 300 THEN '-'
            ELSE CONCAT(
                LPAD((TIMESTAMPDIFF(SECOND, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)) - 300) DIV 3600, 2, '0'),
                ':',
                LPAD(((TIMESTAMPDIFF(SECOND, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)) - 300) MOD 3600) DIV 60, 2, '0'),
                ':',
                LPAD((TIMESTAMPDIFF(SECOND, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)) - 300) MOD 60, 2, '0')
            )
        END AS TARDANZA_T2,
        
        -- 10. DETALLE OFICINA MAÑANA (Tolerancia 300 segundos = 5 minutos)
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 1 THEN 1 END) = 0 THEN
                CASE
                    WHEN EXISTS (SELECT 1 FROM TblVacaciones v
                                 WHERE v.num_documento = p.num_documento
                                   AND v.estado = 'APROBADO'
                                   AND g.gf BETWEEN v.fecha_inicio AND v.fecha_fin)
                        THEN 'VACACIONES'
                    WHEN h.hora_entrada IS NULL OR h.hora_salida IS NULL THEN '-'
                    WHEN TIMESTAMP(g.gf, h.hora_salida) >= NOW() THEN '-'
                    ELSE 'FALTÓ'
                END
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 300 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T1,
        
        -- 11. DETALLE OFICINA TARDE (Tolerancia 300 segundos = 5 minutos)
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 2 THEN 1 END) = 0 THEN
                CASE
                    WHEN EXISTS (SELECT 1 FROM TblVacaciones v
                                 WHERE v.num_documento = p.num_documento
                                   AND v.estado = 'APROBADO'
                                   AND g.gf BETWEEN v.fecha_inicio AND v.fecha_fin)
                        THEN 'VACACIONES'
                    WHEN h.hora_entrada2 IS NULL OR h.hora_salida2 IS NULL THEN '-'
                    WHEN TIMESTAMP(g.gf, h.hora_salida2) >= NOW() THEN '-'
                    ELSE 'FALTÓ'
                END
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(SECOND, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 300 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T2,
        
        -- 12. DETALLE CAMPO MAÑANA
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 1 THEN 1 END) = 0 THEN
                CASE
                    WHEN EXISTS (SELECT 1 FROM TblVacaciones v
                                 WHERE v.num_documento = p.num_documento
                                   AND v.estado = 'APROBADO'
                                   AND g.gf BETWEEN v.fecha_inicio AND v.fecha_fin)
                        THEN 'VACACIONES'
                    WHEN h.hora_entrada IS NULL OR h.hora_salida IS NULL THEN '-'
                    WHEN TIMESTAMP(g.gf, h.hora_salida) >= NOW() THEN '-'
                    ELSE 'FALTÓ'
                END
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 'CAMPO'
        END AS DETALLE_CMP_T1,
        
        -- 13. DETALLE CAMPO TARDE
        CASE 
            WHEN COUNT(CASE WHEN m.turno = 2 THEN 1 END) = 0 THEN
                CASE
                    WHEN EXISTS (SELECT 1 FROM TblVacaciones v
                                 WHERE v.num_documento = p.num_documento
                                   AND v.estado = 'APROBADO'
                                   AND g.gf BETWEEN v.fecha_inicio AND v.fecha_fin)
                        THEN 'VACACIONES'
                    WHEN h.hora_entrada2 IS NULL OR h.hora_salida2 IS NULL THEN '-'
                    WHEN TIMESTAMP(g.gf, h.hora_salida2) >= NOW() THEN '-'
                    ELSE 'FALTÓ'
                END
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'CAMPO' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 'CAMPO'
        END AS DETALLE_CMP_T2,
        
        -- 14. JUSTIFICACIONES (misma regla de turno, en la consulta principal)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1
                      AND m.justificacion IS NOT NULL AND m.justificacion != ''
                 THEN m.justificacion END
            ORDER BY m.fecha_marcacion
            SEPARATOR ' | '
        ) AS JUSTIFICACION_ENT_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1
                      AND m.justificacion IS NOT NULL AND m.justificacion != ''
                 THEN m.justificacion END
            ORDER BY m.fecha_marcacion
            SEPARATOR ' | '
        ) AS JUSTIFICACION_SAL_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2
                      AND m.justificacion IS NOT NULL AND m.justificacion != ''
                 THEN m.justificacion END
            ORDER BY m.fecha_marcacion
            SEPARATOR ' | '
        ) AS JUSTIFICACION_ENT_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2
                      AND m.justificacion IS NOT NULL AND m.justificacion != ''
                 THEN m.justificacion END
            ORDER BY m.fecha_marcacion
            SEPARATOR ' | '
        ) AS JUSTIFICACION_SAL_T2

    FROM grid g
    INNER JOIN TblPersona p ON p.num_documento = g.gdoc
    LEFT JOIN marcas m ON m.num_documento = g.gdoc 
        AND DATE(m.fecha_marcacion) = g.gf
    INNER JOIN TblUsuario u ON u.num_documento = p.num_documento
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    
    LEFT JOIN TblHorarioTrabajo h ON h.num_documento = p.num_documento 
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

    WHERE (p_num_usuario IS NULL OR u.num_usuario = p_num_usuario)

    GROUP BY 
        p.num_documento, g.gf, e.nombre, p.nombres,
        p.apellido_paterno, p.apellido_materno, p.documento_numero,
        c.nombre, a.nombre

    ORDER BY g.gf ASC, p.apellido_paterno ASC;
END $$

DELIMITER ;
