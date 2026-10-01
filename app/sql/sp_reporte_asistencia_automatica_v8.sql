-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v8 - VIGENTE)
-- ============================================================
-- Base: v7 (turnos por horario - Opcion A; aplicada y
--   verificada en BD el 30/09/2026).
--
-- Problema que resuelve (v8): FALTAS en Control de Asistencia.
--   v7 solo generaba filas donde HABIA marcas: un dia sin
--   ninguna marca no aparecia (septiembre-2026: 740 filas;
--   faltaban 646 dias con horario y sin registro), y un turno
--   vacio se pintaba '-', sin distinguir "aun no paso" de "falto".
--
-- Regla nueva (aplica por separado a turno 1 y turno 2):
--   SI el turno no tiene NINGUNA marca (entrada/salida,
--   oficina/campo):
--     1. Vacacion APROBADA ese dia         -> 'VACACIONES'
--     2. Turno inexistente ese dia (sin horario o sin turno 2) -> '-'
--     3. El turno aun no termina (fecha + hora_salida[2] >= NOW()) -> '-'
--     4. SI NO                            -> 'FALTÓ'
--   SI el turno SI tiene marcas:
--     -> logica ACTUAL intacta (ASISTENCIA / TARDANZA > 5 min /
--        CAMPO / SIN HORARIO / '-'). La entrada sin salida NO es
--        falta: se evalua por la entrada (ASISTENCIA/TARDANZA).
--   Excepciones con registro real en el sistema: solo
--   TblVacaciones (estado='APROBADO'); no existen tablas de
--   permisos/licencias. Descanso = dia sin horario (sin fila).
--
-- Filas (Opcion B): grilla =
--   (persona con horario activo ese dia) UNION (persona-dia con
--   marcas). septiembre-2026: 740 -> 1,386 filas (+646).
--
-- Sin cambios: columnas y su orden, regla de turnos (Opcion A),
--   MINUTOS_T1/T2, practorroga de 5 min, justificaciones,
--   filtros, consumidores y front. Tolerancia: SIGUE EN 5 MIN.
--
-- Consumidores (sin cambios de esquema):
--   GET /api/reportes/control-asistencia         -> JSON
--   GET /api/reportes/control-asistencia/excel   -> Excel
--
-- Verificado en BD (01/10/2026):
--   - 1,386 filas septiembre; regresion v7: 0 filas perdidas,
--     0 cambios en horas/MINUTOS, 0 cambios de DETALLE en
--     turnos con marcas.
--   - Casos: Kelvin 25/09 (manana FALTO, tarde ASISTENCIA),
--     doc 30 vacacion 21-26/09 -> VACACIONES, 8 personas con
--     horario y 0 marcas -> FALTO, hoy/futuro sin FALTO.
--   - Sesion MySQL de la app: time_zone = -05:00 (NOW() =
--     hora de Peru, se usa para el cierre de turno).
--   - TblPersona.num_documento unico (54/54); TblUsuario 1:1;
--     dia_semana limpio; las 54 personas 'Activo' (si alguien
--     se da de baja: poner su horario es_activo=0).
--   - CTE recursiva: rango maximo 1,000 dias.
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo de un
--   procedimiento => siempre DROP + CREATE. Antes de ejecutar,
--   guarda el estado actual para poder revertir:
--     SHOW CREATE PROCEDURE sp_reporte_asistencia_automatica\G
--
-- Reemplaza a:
--   _v7.sql -> base de esta version (turnos, ya aplicada)
--   _v6.sql, _v5.sql, _v4.sql, _v2.sql -> desactualizados
--   _v3.sql -> daniNO, NO ejecutar (2 parametros, incompatibles)
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
        -- aunque no haya marcas (dias sin registro -> FALTÓ).
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
        
        -- 4. OFICINA - TURNO MAÑANA (turno 1 por horario)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T1,
        
        -- 5. OFICINA - TURNO TARDE (turno 2 por horario)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T2,
        
        -- 6. CAMPO - TURNO MAÑANA (turno 1 por horario)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T1,
        
        -- 7. CAMPO - TURNO TARDE (turno 2 por horario)
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 AND m.tipo_ubicacion = 'CAMPO'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T2,
        
        -- 8. MINUTOS T1 (reales del turno 1 por horario - programados)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL OR h.hora_salida IS NULL THEN '-'
            ELSE CONCAT(
                IF(
                    (TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)) >= 0, '+', '-'),
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 1 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) MOD 60, 2, '0')
            )
        END AS MINUTOS_T1,
        
        -- 9. MINUTOS T2 (reales del turno 2 por horario - programados)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL OR h.hora_salida2 IS NULL THEN '-'
            ELSE CONCAT(
                IF(
                    (TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)) >= 0, '+', '-'),
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)
                ) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.turno = 2 THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)
                ) MOD 60, 2, '0')
            )
        END AS MINUTOS_T2,
        
        -- 10. DETALLE OFICINA MAÑANA (NUEVO: rama de turno vacio)
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
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T1,
        
        -- 11. DETALLE OFICINA TARDE (NUEVO: rama de turno vacio)
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
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T2,
        
        -- 12. DETALLE CAMPO MAÑANA (NUEVO: rama de turno vacio)
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
        
        -- 13. DETALLE CAMPO TARDE (NUEVO: rama de turno vacio)
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
