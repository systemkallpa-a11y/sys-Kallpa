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
        
        -- 2. SEDE
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
        
        -- 4. OFICINA - TURNO MAÑANA
        TIME_FORMAT(MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_ENTRADA_OFI_T1,
        TIME_FORMAT(MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_SALIDA_OFI_T1,
        
        -- 5. OFICINA - TURNO TARDE
        TIME_FORMAT(MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_ENTRADA_OFI_T2,
        TIME_FORMAT(MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'OFICINA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_SALIDA_OFI_T2,
        
        -- 6. CAMPO - TURNO MAÑANA
        TIME_FORMAT(MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) < '12:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_ENTRADA_CMP_T1,
        TIME_FORMAT(MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_SALIDA_CMP_T1,
        
        -- 7. CAMPO - TURNO TARDE
        TIME_FORMAT(MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) >= '12:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_ENTRADA_CMP_T2,
        TIME_FORMAT(MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND m.tipo_ubicacion = 'CAMPO' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END), '%H:%i') AS H_SALIDA_CMP_T2,
        
        -- 8. MINUTOS T1
        CASE 
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_salida IS NULL THEN '-'
            ELSE CONCAT(
                IF(TIMESTAMPDIFF(MINUTE, h.hora_salida, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END)) >= 0, '+', '-'),
                LPAD(ABS(TIMESTAMPDIFF(MINUTE, h.hora_salida, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END))) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(TIMESTAMPDIFF(MINUTE, h.hora_salida, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) < '14:00:00' THEN TIME(m.fecha_marcacion) END))) MOD 60, 2, '0')
            )
        END AS MINUTOS_T1,
        
        -- 9. MINUTOS T2
        CASE 
            WHEN MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END) IS NULL THEN '-'
            WHEN h.hora_salida2 IS NULL THEN '-'
            ELSE CONCAT(
                IF(TIMESTAMPDIFF(MINUTE, h.hora_salida2, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END)) >= 0, '+', '-'),
                LPAD(ABS(TIMESTAMPDIFF(MINUTE, h.hora_salida2, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END))) DIV 60, 2, '0'),
                ':',
                LPAD(ABS(TIMESTAMPDIFF(MINUTE, h.hora_salida2, MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' AND TIME(m.fecha_marcacion) > '14:00:00' THEN TIME(m.fecha_marcacion) END))) MOD 60, 2, '0')
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
        -- ENTRADA T1: justificaciones de ENTRADAs antes de 12:00
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'ENTRADA'
              AND TIME(mj.fecha_marcacion) < '12:00:00'
        ) AS JUSTIFICACION_ENT_T1,
        
        -- SALIDA T1: justificaciones de SALIDAs antes de 14:00
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'SALIDA'
              AND TIME(mj.fecha_marcacion) < '14:00:00'
        ) AS JUSTIFICACION_SAL_T1,
        
        -- ENTRADA T2: justificaciones de ENTRADAs después de 12:00
        (
            SELECT GROUP_CONCAT(mj.justificacion SEPARATOR ' | ') 
            FROM TblMarcacion mj 
            WHERE mj.num_documento = m.num_documento 
              AND DATE(mj.fecha_marcacion) = DATE(m.fecha_marcacion)
              AND mj.justificacion IS NOT NULL AND mj.justificacion != ''
              AND mj.tipo_marcacion = 'ENTRADA'
              AND TIME(mj.fecha_marcacion) >= '12:00:00'
        ) AS JUSTIFICACION_ENT_T2,
        
        -- SALIDA T2: justificaciones de SALIDAs después de 14:00
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
        c.nombre

    ORDER BY DATE(m.fecha_marcacion) ASC, p.apellido_paterno ASC;
END