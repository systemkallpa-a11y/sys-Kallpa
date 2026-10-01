-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v7 - REEMPLAZADO por _v8.sql)
-- ============================================================
-- Base: v6 (aplicado y verificado en BD el 30/09/2026).
--
-- Problema que resuelve (v7):
--   v6 asignaba el turno por ORDEN de marcas: la 1a entrada
--   del dia siempre abria el turno mañana, sin mirar la hora
--   ni el horario. Caso real (Kelvin 25/09): entro 15:04 y
--   salio 19:50, pero v6 lo ponia en el turno de la mañana.
--
-- Regla nueva (Opcion A - el horario de cada persona manda):
--   1. Cada marca se clasifica por la ultima ENTRADA que la
--      precede (o ella misma si es ENTRADA), contra SU horario
--      de ese dia:
--      - Dia de un solo turno (sin hora_entrada2) -> todo
--        turno 1 (mañana).
--      - Entrada <= hora en que termina su mañana
--        (hora_salida, p.ej. 13:00/13:30) -> turno 1;
--        despues -> turno 2.
--      - Sin horario ese dia -> reloj (<=14:00 = mañana).
--   2. Toda SALIDA cierra el turno de su ultima entrada
--      (Esther 09:02 -> salida 15:24 = mañana).
--   3. Unico caso con reloj sobre la marca: SALIDA sin
--      ninguna ENTRADA previa en el dia (<=14:00 = mañana).
--   4. OFICINA/CAMPO: sin cambios (tipo_ubicacion de cada
--      marca; el registro crudo no se toca).
--
-- Ejemplos:
--   Kelvin 25/09  15:04, 19:50 (08:30-13:00 / 15:00-19:00)
--                 -> mañana -  ; tarde 15:04 / 19:50
--   Esther 15/09  09:02, 15:24, 17:34, 17:36
--                 -> mañana 09:02 / 15:24 ; tarde 17:34 / 17:36
--   Katy 25/09    12:50, 13:09, 15:01 (su mañana termina 13:00)
--                 -> mañana 12:50 / 13:09 ; tarde 15:01 / -
--   Katy 28/09    13:21, 13:22, 15:15, 19:34 (> 13:00 = tarde)
--                 -> mañana - ; tarde 13:21 / 19:34
--
-- Impacto medido (septiembre-2026, en frio):
--   2,156 marcas / 740 dias-persona; 121 marcas en 66 dias
--   cambian de celda (59 entradas mañana->tarde, 7 al reves);
--   0 marcas perdidas. Tolerancia de tardanza: SIGUE EN 5 MIN.
--
-- Sin cambios: columnas y su orden, MINUTOS_T1/T2, DETALLE
--   (formulas y practorroga de 5 min), justificaciones,
--   GROUP BY, joins, filtros, front (control_asistencia.html)
--   y Excel (leen las mismas celdas).
--
-- Consumidores (sin cambios de esquema):
--   GET /api/reportes/control-asistencia         -> JSON
--   GET /api/reportes/control-asistencia/excel   -> Excel
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo de un
--   procedimiento => siempre DROP + CREATE. Antes de ejecutar,
--   guarda el estado actual para poder revertir:
--     SHOW CREATE PROCEDURE sp_reporte_asistencia_automatica\G
--
-- Reemplaza a:
--   _v6.sql -> base de esta version (ya aplicada)
--   _v5.sql, _v4.sql, _v2.sql -> desactualizados
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
        
        -- 3. FECHA
        DAY(m.fecha_marcacion) AS DIA,
        MONTH(m.fecha_marcacion) AS MES,
        YEAR(m.fecha_marcacion) AS ANO,
        ELT(DAYOFWEEK(MIN(m.fecha_marcacion)), 'Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado') AS DIA_SEMANA,
        
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
        
        -- 10. DETALLE OFICINA MAÑANA (entrada del turno 1 en oficina; practorroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T1,
        
        -- 11. DETALLE OFICINA TARDE (entrada del turno 2 en oficina; practorroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 2 AND m.tipo_ubicacion = 'OFICINA' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T2,
        
        -- 12. DETALLE CAMPO MAÑANA (entrada del turno 1 en campo)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.turno = 1 AND m.tipo_ubicacion = 'CAMPO' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 'CAMPO'
        END AS DETALLE_CMP_T1,
        
        -- 13. DETALLE CAMPO TARDE (entrada del turno 2 en campo)
        CASE 
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

    FROM (
        -- Asignacion de cada marca a su turno (Opcion A):
        -- la ultima ENTRADA que la precede (o ella misma si es
        -- ENTRADA) decide el turno segun SU horario de ese dia.
        --   ult_ent = fecha/hora de la ultima ENTRADA hasta
        --   esta marca (NULL si no hubo ninguna).
        SELECT a.*,
               CASE
                   -- Salida sin ninguna entrada previa -> reloj
                   WHEN a.ult_ent IS NULL
                        THEN CASE WHEN TIME(a.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                   -- Sin horario ese dia -> reloj sobre su entrada
                   WHEN hh.num_documento IS NULL
                        THEN CASE WHEN TIME(a.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                   -- Dia de un solo turno -> todo es turno 1
                   WHEN hh.hora_entrada2 IS NULL OR hh.hora_salida IS NULL THEN 1
                   -- Entrada hasta el fin de SU mañana -> turno 1
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
    ) m
    INNER JOIN TblPersona p ON m.num_documento = p.num_documento
    INNER JOIN TblUsuario u ON m.num_usuario = u.num_usuario
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    
    LEFT JOIN TblHorarioTrabajo h ON p.num_documento = h.num_documento 
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
      AND (p_num_usuario IS NULL OR u.num_usuario = p_num_usuario)

    GROUP BY 
        p.num_documento, DATE(m.fecha_marcacion), e.nombre, p.nombres,
        p.apellido_paterno, p.apellido_materno, p.documento_numero,
        c.nombre, a.nombre

    ORDER BY DATE(m.fecha_marcacion) ASC, p.apellido_paterno ASC;
END$$

DELIMITER ;
