-- ============================================================
-- SP: sp_reporte_asistencia_automatica v3
-- Cambio: MINUTOS calcula (reales - programados) considerando entrada y salida
-- ============================================================
-- ADVERTENCIA: NO EJECUTAR en la base de datos actual.
-- Tiene el mismo nombre que el SP en uso, asi que lo BORRA y lo
-- sustituye por uno incompatible con el sistema:
--   * el backend lo llama con 3 parametros, este define solo 2,
--   * sus columnas no coinciden con las que espera el frontend,
--   * usa u.sede, u.nombre_empresa y vista_horarios (no existen aqui).
-- Resultado: "Reportes > Control de Asistencia" deja de cargar y los
-- Excel salen vacios. El SP correcto y vigente es:
--   sp_reporte_asistencia_automatica_v2.sql
-- ============================================================
DROP PROCEDURE IF EXISTS sp_reporte_asistencia_automatica;

DELIMITER $$

CREATE PROCEDURE sp_reporte_asistencia_automatica(
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE
)
BEGIN
    SELECT 
        e.documento_numero AS DNI,
        e.nombre_completo AS NOMBRES,
        e.email AS EMAIL,
        e.cargo AS CARGO,
        COALESCE(u.nombre_empresa, 'Sin empresa') AS EMPRESA,
        COALESCE(u.sede, 'Sin sede') AS SEDE,
        YEAR(m.fecha_marcacion) AS ANO,
        MONTH(m.fecha_marcacion) AS MES,
        DAY(m.fecha_marcacion) AS DIA,
        DATE_FORMAT(m.fecha_marcacion, '%d/%m/%Y') AS FECHA,
        
        -- HORA ENTRADA T1 (mínima ENTRADA antes de 12:00)
        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' 
            THEN DATE_FORMAT(m.fecha_marcacion, '%H:%i') END) AS HORA_ENTRADA_T1,
        
        -- HORA SALIDA T1 (máxima SALIDA antes de 14:00)
        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' 
            THEN DATE_FORMAT(m.fecha_marcacion, '%H:%i') END) AS HORA_SALIDA_T1,
        
        -- 8. MINUTOS T1 (reales - programados)
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL OR h.hora_salida IS NULL THEN '-'
            ELSE CONCAT(
                IF(
                    (TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)) >= 0, '+', '-'),
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(
                    TIMESTAMPDIFF(MINUTE, 
                        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END),
                        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END)
                    ) - TIMESTAMPDIFF(MINUTE, h.hora_entrada, h.hora_salida)
                ) MOD 60, 2, '0')
            )
        END AS MINUTOS_T1,
        
        -- HORA ENTRADA T2 (mínima ENTRADA desde 12:00)
        MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' 
            THEN DATE_FORMAT(m.fecha_marcacion, '%H:%i') END) AS HORA_ENTRADA_T2,
        
        -- HORA SALIDA T2 (máxima SALIDA desde 14:00)
        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' 
            THEN DATE_FORMAT(m.fecha_marcacion, '%H:%i') END) AS HORA_SALIDA_T2,
        
        -- 9. MINUTOS T2 (reales - programados)
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
        
        -- 10. DETALLE OFICINA MAÑANA
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada IS NULL THEN 'SIN HORARIO'
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) > h.hora_entrada THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS DETALLE_OFI_T1,
        
        -- 11. DETALLE OFICINA TARDE
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_entrada2 IS NULL THEN 'SIN HORARIO'
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) > h.hora_entrada2 THEN 'TARDANZA'
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
        
        -- 14. JUSTIFICACIONES (4 columnas: ENT/SAL x T1/T2)
        MAX(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN m.justificacion END) AS JUSTIFICACION_ENT_T1,
        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN m.justificacion END) AS JUSTIFICACION_SAL_T1,
        MAX(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN m.justificacion END) AS JUSTIFICACION_ENT_T2,
        MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN m.justificacion END) AS JUSTIFICACION_SAL_T2,
        
        -- 15. ESTADO GENERAL
        CASE 
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL 
                 AND MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN 'INASISTENCIA'
            WHEN MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) IS NOT NULL 
                 AND MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END) > h.hora_entrada THEN 'TARDANZA'
            ELSE 'ASISTENCIA'
        END AS ESTADO
        
    FROM TblMarcacion m
    INNER JOIN TblPersona e ON m.num_documento = e.num_documento
    LEFT JOIN TblUsuario u ON e.num_documento = u.num_documento
    LEFT JOIN vista_horarios h ON h.num_documento = e.num_documento 
        AND h.dia_semana = DAYOFWEEK(m.fecha_marcacion)
    WHERE DATE(m.fecha_marcacion) BETWEEN p_fecha_desde AND p_fecha_hasta
    GROUP BY e.documento_numero, e.nombre_completo, e.email, e.cargo, u.nombre_empresa, u.sede, 
             YEAR(m.fecha_marcacion), MONTH(m.fecha_marcacion), DAY(m.fecha_marcacion), DATE_FORMAT(m.fecha_marcacion, '%d/%m/%Y'),
             h.hora_entrada, h.hora_salida, h.hora_entrada2, h.hora_salida2
    ORDER BY e.nombre_completo, m.fecha_marcacion;

END$$

DELIMITER ;
