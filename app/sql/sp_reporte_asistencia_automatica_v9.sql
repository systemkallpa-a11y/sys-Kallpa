-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v9 - VIGENTE)
-- ============================================================
-- Base: v8 (faltas y vacaciones)
--
-- Problema que resuelve (v9): PRECISIÓN EN MARCACIONES Y HORAS LABORADAS
--   - v8 mostraba horas sin segundos (%H:%i), generando imprecisión visual
--   - El campo MINUTOS causaba confusión y duplicación entre oficina/campo
--   - No se mostraban las horas reales trabajadas por turno
--
-- Cambios v9:
--   1. MOSTRAR SEGUNDOS: Todas las horas ahora usan formato %H:%i:%s
--   2. ELIMINAR MINUTOS: Se removieron las columnas MINUTOS_T1/T2 por
--      generar confusión. Las horas con segundos son suficientes para
--      verificar cumplimiento de horarios.
--   3. HORAS LABORADAS: Se agregaron 2 nuevas columnas que calculan el
--      tiempo real trabajado por turno (considerando que una persona puede
--      entrar en oficina y salir en campo, o viceversa):
--      - HORAS_LABORADAS_T1: Primera entrada a última salida turno mañana
--      - HORAS_LABORADAS_T2: Primera entrada a última salida turno tarde
--   4. Tolerancia sigue en 5 minutos (300 segundos) para ASISTENCIA/TARDANZA
--
-- Ejemplo mejorado:
--   Entrada Oficina: 08:30:55, Salida Campo: 13:02:14
--   HORAS_LABORADAS_T1: 04:31:19 (tiempo real trabajado)
--   
-- Caso Jhedelinda (01/10/2026):
--   H_ENTRADA_OFI_T1: 08:30:55 ✅ (clara, precisa)
--   H_SALIDA_OFI_T1:  13:02:14 ✅ (clara, precisa)
--   HORAS_LABORADAS_T1: 04:31:19 ✅ (tiempo real trabajado)
--   DETALLE_OFI_T1:   ASISTENCIA ✅
--
-- Sin cambios: lógica de turnos, FALTAS, VACACIONES, filtros, estructura
--
-- IMPORTANTE: Ejecutar en BD de producción para actualizar reportes
-- ============================================================

-- USE kallpasystem$kallgwkn_kallpa_bd;

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
        
        -- 8. HORAS LABORADAS TURNO MAÑANA (tiempo real trabajado)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 
                CONCAT(
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) DIV 3600, 2, '0'),
                    ':',
                    LPAD((TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) MOD 3600) DIV 60, 2, '0'),
                    ':',
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) MOD 60, 2, '0')
                )
        END AS HORAS_LABORADAS_T1,
        
        -- 9. HORAS LABORADAS TURNO TARDE (tiempo real trabajado)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 
                CONCAT(
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) DIV 3600, 2, '0'),
                    ':',
                    LPAD((TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) MOD 3600) DIV 60, 2, '0'),
                    ':',
                    LPAD(TIMESTAMPDIFF(SECOND, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) MOD 60, 2, '0')
                )
        END AS HORAS_LABORADAS_T2,
        
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
END$$

DELIMITER ;
