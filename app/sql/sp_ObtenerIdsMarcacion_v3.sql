-- ============================================================
-- SP: sp_ObtenerIdsMarcacion   (v3)
-- ============================================================
-- Alimenta al boton lapiz de "Control de Asistencia" (modal de
-- edicion): /api/marcacion/obtener-ids. El front usa solo estas
-- 8 columnas (control_asistencia.html), igual que siempre.
--
-- Base: version desplegada en BD (v1: las 8 columnas, sin las
--       just_* del archivo _v2, que nunca se aplico).
--
-- Problema que resuelve (v3):
--   Repartia las marcas por ventanas de RELOJ (entrada <=14:00
--   = mañana, salida >14:00 = tarde). Con la tabla ya en v6
--   (turno por pareja), el modal quedaba descuadrado: por
--   ejemplo, Esther 15/09 muestra en la tabla "salida mañana
--   15:24", pero este SP seguia diciendo que no habia salida de
--   mañana (15:24 > 14:00) => ese campo salia apagado y no se
--   podia editar.
--
-- Regla nueva (MISMA que sp_reporte_asistencia_automatica v6):
--   1. La 1a ENTRADA del dia abre el turno MAÑANA.
--   2. Toda SALIDA cierra el turno abierto por su ultima
--      entrada (09:02 -> 15:24 = mañana).
--   3. La 2a ENTRADA abre el turno TARDE; la 3a en adelante se
--      acumula en el turno tarde.
--   4. Unico caso con reloj: SALIDA sin ENTRADA previa en el
--      dia => <=14:00 = mañana, despues = tarde.
--   5. id_tX_salida = ULTIMA salida de ese turno (igual que la
--      celda de la tabla, que el modal copia con la ultima
--      hora); id_tX_entrada = PRIMERA entrada de ese turno.
--
-- Sin cambios: mismas 8 columnas, mismo API, mismo modal (ni una
--   linea de control_asistencia.html cambia).
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP +
--   CREATE. Para revertir, guarda antes el estado actual:
--     SHOW CREATE PROCEDURE sp_ObtenerIdsMarcacion\G
--
-- Reemplaza a: version desplegada (v1) y al archivo _v2.sql
--   (que agregaba just_* que el front no usa).
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t1_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t1_salida,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS id_t2_entrada,
            
            (SELECT mt.id_marcacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS id_t2_salida,
            
            -- ===== TIPO UBICACION =====
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t1_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 1
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t1_sal,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'ENTRADA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t2_ent,
            
            (SELECT mt.tipo_ubicacion
             FROM (
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
                     WHERE mm.num_documento = v_num_documento
                       AND DATE(mm.fecha_marcacion) = p_fecha
                 ) base
             ) mt
             WHERE mt.tipo_marcacion = 'SALIDA' AND mt.turno = 2
             ORDER BY mt.fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t2_sal;
    END IF;
END$$

DELIMITER ;
