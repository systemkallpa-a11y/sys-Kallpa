-- ============================================================
-- SP: sp_reporte_asistencia_automatica   (v5 - REEMPLAZADO por _v6.sql)
-- Vigente: _v6.sql (turno por pareja, no por reloj).
-- ============================================================
-- Base: cuerpo DESPLEGADO en BD (verificado con SHOW CREATE),
--       que resultó ser _v4 sin las columnas opcionales
--       ID_EMPRESA / ID_AREA (el deploy nunca las tuvo y el
--       front no las usa: los filtros filtran por nombre
--       EMPRESA / AREA).
--
-- Problema que resuelve (v5):
--   Las 8 celdas de hora usaban MIN/MAX por ventana => solo
--   se veía la 1ª entrada y la última salida de cada ventana;
--   las demás marcas DESAPARECÍAN de la tabla (y del Excel).
--   Ejemplo real: Katy 28/09 -> 4 marcas crudas, 3 celdas
--   visibles (se perdía la entrada 15:15 porque la 13:21 ya
--   "ocupaba" la ventana). 62 de 722 días de sep-2026 con
--   pérdidas. Mismo caso de Esther: 4 registros en el detalle
--   del modal, 3 en la tabla de Control.
--
-- Cambios v5 (2):
--   1. 8 celdas: MIN/MAX -> GROUP_CONCAT(... ORDER BY
--      fecha_marcacion SEPARATOR ', ') => la celda muestra
--      TODAS las marcas de la ventana ("13:21, 15:15"),
--      sin perder lo que muestra el detalle del modal de
--      Reportes > Ver detalle del día.
--   2. Ventana de SALIDA T1: TIME < '14:00:00' -> <= '14:00:00'
--      (una salida exacta a las 14:00:00 no caía en NINGUNA
--      ventana y se perdía). Aplicado también en MINUTOS_T1 y
--      JUSTIFICACION_SAL_T1 para que todo cuadre.
--
-- Sin cambios: MINUTOS_T1/T2 y DETALLE_* (siguen con MIN/MAX =
--   1ª entrada / última salida de la ventana; el tema de
--   tardanzas vs horario queda para después), justificaciones,
--   joins, GROUP BY y columnas de filtros.
--
-- Consumidores (sin cambios de esquema):
--   GET /api/reportes/control-asistencia         -> JSON
--   GET /api/reportes/control-asistencia/excel   -> Excel
--   control_asistencia.html: celdaHora() imprime el valor crudo
--   (escapeHtml) y el modal de editar toma la hora de la celda.
--
-- IMPORTANTE: MySQL no permite alterar el cuerpo de un
--   procedimiento (no existe ALTER PROCEDURE de cuerpo) =>
--   siempre DROP + CREATE. Antes de ejecutar, guardá el estado
--   actual para poder revertir:
--     SHOW CREATE PROCEDURE sp_reporte_asistencia_automatica\G
--
-- Reemplaza a:
--   _v4.sql  -> base de esta versión (ID_EMPRESA/ID_AREA
--               opcionales, no aplicados en BD)
--   _v2.sql  -> desactualizado (falta la prórroga de 5 min)
--   _v3.sql  -> dañino, NO ejecutar (2 parámetros, incompatibles)
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
        
        -- 4. OFICINA - TURNO MAÑANA
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) <= '14:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T1,
        
        -- 5. OFICINA - TURNO TARDE
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_OFI_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) > '14:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_OFI_T2,
        
        -- 6. CAMPO - TURNO MAÑANA
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) < '12:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T1,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) <= '14:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T1,
        
        -- 7. CAMPO - TURNO TARDE
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) >= '12:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_ENTRADA_CMP_T2,
        GROUP_CONCAT(
            CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) > '14:00:00'
                 THEN DATE_FORMAT(TIME(m.fecha_marcacion), '%H:%i') END
            ORDER BY m.fecha_marcacion
            SEPARATOR ', '
        ) AS H_SALIDA_CMP_T2,
        
        -- 8. MINUTOS T1 (reales - programados, con prórroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) <= '14:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL OR h.hora_salida IS NULL THEN '-'
            ELSE CONCAT(
                IF(
                    (TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) <= '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)) >= 0, '+', '-'),
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) <= '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) <= '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) MOD 60, 2, '0')
            )
        END AS MINUTOS_T1,
        
        -- 9. MINUTOS T2 (reales - programados, con prórroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL OR h.hora_salida2 IS NULL THEN '-'
            ELSE CONCAT(
                IF(
                    (TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)) >= 0, '+', '-'),
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)
                ) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada2, h.hora_salida2)
                ) MOD 60, 2, '0')
            )
        END AS MINUTOS_T2,
        
        -- 10. DETALLE OFICINA MAÑANA (con prórroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T1,
        
        -- 11. DETALLE OFICINA TARDE (con prórroga 5 min)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
            WHEN TIMESTAMPDIFF(MINUTE, h.hora_entrada2, MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END)) > 5 THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T2,
        
        -- 12. DETALLE CAMPO MAÑANA
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 'CAMPO'
        END AS DETALLE_CMP_T1,
        
        -- 13. DETALLE CAMPO TARDE
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            ELSE 'CAMPO'
        END AS DETALLE_CMP_T2,
        
        -- 14. JUSTIFICACIONES
        (
          SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'ENTRADA'
              AND TIME(mj.fecha_marcacion) < '12:00:00'
        ) AS JUSTIFICACION_ENT_T1,
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'SALIDA'
              AND TIME(mj.fecha_marcacion) <= '14:00:00'
        ) AS JUSTIFICACION_SAL_T1,
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'ENTRADA'
              AND TIME(mj.fecha_marcacion) >= '12:00:00'
        ) AS JUSTIFICACION_ENT_T2,
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'SALIDA'
              AND TIME(mj.fecha_marcacion) > '14:00:00'
        ) AS JUSTIFICACION_SAL_T2

    FROM TblMarcacion m
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
