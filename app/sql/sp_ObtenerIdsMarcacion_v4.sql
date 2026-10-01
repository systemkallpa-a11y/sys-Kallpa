-- ============================================================
-- SP: sp_ObtenerIdsMarcacion   (v4)
-- ============================================================
-- Alimenta al boton lapiz de "Control de Asistencia" (modal de
-- edicion): /api/marcacion/obtener-ids. El front usa solo estas
-- 8 columnas (control_asistencia.html), igual que siempre.
--
-- Base: v3 (turno por pareja; ya aplicada en BD).
--
-- Problema que resuelve (v4):
--   v3 repartia por ORDEN (1a entrada = mañana) como la tabla
--   v6. Con la tabla ahora en v7 (turno segun el HORARIO de
--   cada persona), el modal quedaria descuadrado: por ejemplo
--   Kelvin 25/09 muestra en la tabla "tarde 15:04", pero v3
--   diria que 15:04 es su 1a entrada => turno mañana.
--
-- Regla nueva (MISMA que sp_reporte_asistencia_automatica v7):
--   1. Cada marca se clasifica por la ultima ENTRADA que la
--      precede, contra SU horario de ese dia (sin turno 2 ->
--      mañana; <= fin de su mañana -> turno 1; despues ->
--      turno 2; sin horario -> reloj <=14:00).
--   2. Toda SALIDA cierra el turno de su ultima entrada.
--   3. Salida sin entrada previa -> reloj <=14:00.
--   4. id_tX_salida = ULTIMA salida de ese turno; id_tX_entrada
--      = PRIMERA entrada de ese turno (igual que la celda).
--
-- Sin cambios: mismas 8 columnas, mismo API, mismo modal (ni una
--   linea de control_asistencia.html cambia).
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP +
--   CREATE. Para revertir, guarda antes el estado actual:
--     SHOW CREATE PROCEDURE sp_ObtenerIdsMarcacion\G
--
-- Reemplaza a: v3 (turno por pareja) y versiones anteriores.
-- ============================================================

DROP PROCEDURE IF EXISTS sp_ObtenerIdsMarcacion;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ObtenerIdsMarcacion`(
    IN p_documento_numero VARCHAR(20),
    IN p_fecha DATE
)
BEGIN
    DECLARE v_num_documento INT;
    
    SELECT num_documento INTO v_num_documento
    FROM TblPersona
    WHERE documento_numero = p_documento_numero
    LIMIT 1;
    
    IF v_num_documento IS NULL THEN
        SELECT NULL AS id_t1_entrada, NULL AS id_t1_salida, 
               NULL AS id_t2_entrada, NULL AS id_t2_salida,
               NULL AS tipo_ubi_t1_ent, NULL AS tipo_ubi_t1_sal,
               NULL AS tipo_ubi_t2_ent, NULL AS tipo_ubi_t2_sal;
    ELSE
        SELECT 
            -- ===== IDs =====
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t1_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t1_salida,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t2_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t2_salida,
            
            -- ===== TIPO UBICACION =====
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t1_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t1_sal,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t2_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
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
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t2_sal;
    END IF;
END$$

DELIMITER ;
