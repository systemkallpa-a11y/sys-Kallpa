-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v6 - VIGENTE)
-- ============================================================
-- Base: v5 (aplicado y verificado en BD el 30/09/2026).
--
-- Problema que resuelve (v6):
--   Las marcas se repartían por VENTANAS DE RELOJ (entrada
--   <12:00, salida <=14:00, etc.). Con eso, una salida tarde
--   "se salía" de su turno aunque la pareja entrada-salida dijera
--   lo contrario. Ejemplo real (Esther 15/09): entró 09:02 y
--   salió 15:24; con reloj esa salida caía en el turno tarde y
--   quedaba mezclada con la salida 17:36. Y Katy 28/09: entró
--   13:21 (turno mañana por reloj, aunque abrió su turno a las
--   13:21) pero su salida 15:15 se iba a la tarde.
--
-- Regla nueva (la pareja manda, no el reloj):
--   1. La 1a ENTRADA del día abre el turno MAÑANA (aunque sea
--      a las 13:21; no importa la hora).
--   2. Toda SALIDA cierra el turno abierto por su ultima
--      entrada: si abrió a las 09:02, su salida a las 15:24 es
--      del turno MAÑANA (salio tarde, pero es su salida de la
--      mañana). Mismo criterio que el modal "Detalle de
--      Marcaciones del dia".
--   3. La 2a ENTRADA abre el turno TARDE; la 3a en adelante se
--      acumula en el turno tarde (la tabla solo tiene 2 turnos).
--   4. Unico caso donde aun se usa el reloj: una SALIDA sin
--      ninguna ENTRADA previa en el dia (no hay pareja; caso
--      extremo tipo madrugada) => <=14:00 = mañana, despues =
--      tarde. En dias normales no se nota.
--   5. OFICINA/CAMPO: sigue saliendo del tipo_ubicacion de
--      cada marca (no cambia; el registro crudo no se toca).
--
-- Ejemplos esperados:
--   Esther 15/09  09:02, 15:24, 17:34, 17:36
--                 -> mañana 09:02 / 15:24 ; tarde 17:34 / 17:36
--   Katy 28/09    13:21, 13:22, 15:15, 19:34
--                 -> mañana 13:21 / 13:22 ; tarde 15:15 / 19:34
--   Katy 25/09    12:50, 13:09, 15:01 (sin salida tarde)
--                 -> mañana 12:50 / 13:09 ; tarde 15:01 / -
--
-- Que cambia respecto de v5 (solo la regla de asignacion):
--   1. De TblMarcacion se calcula la columna `turno` por
--      SECuencia (ventana COUNT de entradas por persona+dia) y
--      TODA condicion de ventana por reloj (12:00/14:00) pasa a
--      ser `turno = 1` / `turno = 2`: 8 celdas, MINUTOS_T1/T2,
--      DETALLE_* y justificaciones. Asi el tiempo extra de una
--      salida 15:24 se calcula en el turno de la mañana.
--   2. Las 4 subconsultas de JUSTIFICACION_* pasan a
--      GROUP_CONCAT en la consulta principal con la MISMA regla
--      de turno (mismos nombres de columna; sin filtro de
--      ubicacion, igual que antes).
--   Se elimina por completo la regla "a partir de las 12/14 es
--   la tarde". El reloj solo queda en el caso 4 de arriba.
--
-- Sin cambios: columnas y su orden, GROUP BY, joins, filtros,
--   MINUTOS/DETALLE (formulas y practorroga de 5 min), front
--   (control_asistencia.html) y Excel (leen las mismas 8 celdas).
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
--   _v5.sql -> base de esta version (ya aplicada)
--   _v4.sql, _v2.sql -> desactualizados
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
        
        -- 4. OFICINA - TURNO MAÑANA (turno 1 por pareja)
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
        
        -- 5. OFICINA - TURNO TARDE (turno 2 por pareja)
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
        
        -- 6. CAMPO - TURNO MAÑANA (turno 1 por pareja)
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
        
        -- 7. CAMPO - TURNO TARDE (turno 2 por pareja)
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
        
        -- 8. MINUTOS T1 (reales del turno 1 por pareja - programados)
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
        
        -- 9. MINUTOS T2 (reales del turno 2 por pareja - programados)
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
        -- Asignacion de cada marca a su turno por SECuencia:
        -- idx_entradas = cuantas ENTRADAS lleva esa persona hasta
        -- esta marca (incluida si es ella misma).
        --   entrada  -> turno = su posicion (1a = mañana, 2a+ = tarde)
        --   salida   -> turno del que cierra (las entradas anteriores)
        --   sin ninguna entrada antes -> reloj (caso extremo)
        SELECT base.*,
               CASE WHEN base.idx_entradas = 0
                         THEN CASE WHEN TIME(base.fecha_marcacion) <= '14:00:00' THEN 1 ELSE 2 END
                    ELSE LEAST(2, base.idx_entradas)
               END AS turno
        FROM (
            SELECT mm.*,
                   SUM(CASE WHEN mm.tipo_marcacion = 'ENTRADA' THEN 1 ELSE 0 END)
                       OVER (PARTITION BY mm.num_documento, DATE(mm.fecha_marcacion)
                             ORDER BY mm.fecha_marcacion, mm.id_marcacion
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS idx_entradas
            FROM TblMarcacion mm
            WHERE DATE(mm.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
        ) base
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
