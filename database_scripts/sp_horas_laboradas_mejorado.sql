-- ==============================================================================
-- STORED PROCEDURE: Horas Laboradas (Mejorado - Soporte para Todos los Empleados)
-- ==============================================================================
-- Descripción: Calcula horas laboradas por empleado(s) en un rango de fechas
-- Parámetros:
--   - p_fecha_inicio: Fecha inicial del rango
--   - p_fecha_fin: Fecha final del rango
--   - p_num_documento: DNI del empleado (NULL = TODOS los empleados)
-- Fecha: 28 Septiembre 2026
-- ==============================================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_horas_laboradas_v2$$

CREATE PROCEDURE sp_horas_laboradas_v2(
    IN p_fecha_inicio DATE,
    IN p_fecha_fin DATE,
    IN p_num_documento INT  -- Puede ser NULL para TODOS los empleados
)
BEGIN
    -- Si p_num_documento es NULL, obtener TODOS los empleados
    -- Si p_num_documento tiene valor, obtener solo ese empleado
    
    SELECT 
        p.num_documento,
        p.documento_numero AS dni,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        e.nombre AS empresa,
        c.nombre AS cargo,
        DATE(m.fecha_marcacion) AS fecha,
        DAYNAME(m.fecha_marcacion) AS dia,
        
        -- Turno Mañana - Entrada
        MIN(CASE 
            WHEN m.tipo_marcacion = 'ENTRADA' 
                 AND TIME(m.fecha_marcacion) < '14:00:00'
            THEN TIME(m.fecha_marcacion)
        END) AS entrada_t1,
        
        -- Turno Mañana - Salida
        MAX(CASE 
            WHEN m.tipo_marcacion = 'SALIDA' 
                 AND TIME(m.fecha_marcacion) < '14:00:00'
            THEN TIME(m.fecha_marcacion)
        END) AS salida_t1,
        
        -- Turno Tarde - Entrada
        MIN(CASE 
            WHEN m.tipo_marcacion = 'ENTRADA' 
                 AND TIME(m.fecha_marcacion) >= '14:00:00'
            THEN TIME(m.fecha_marcacion)
        END) AS entrada_t2,
        
        -- Turno Tarde - Salida
        MAX(CASE 
            WHEN m.tipo_marcacion = 'SALIDA' 
                 AND TIME(m.fecha_marcacion) >= '14:00:00'
            THEN TIME(m.fecha_marcacion)
        END) AS salida_t2,
        
        -- Calcular minutos totales
        COALESCE(
            TIMESTAMPDIFF(MINUTE, 
                MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' THEN m.fecha_marcacion END),
                MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' THEN m.fecha_marcacion END)
            ), 0
        ) AS minutos_totales,
        
        -- Calcular horas laboradas en formato HH:MM
        CONCAT(
            LPAD(FLOOR(COALESCE(
                TIMESTAMPDIFF(MINUTE, 
                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' THEN m.fecha_marcacion END),
                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' THEN m.fecha_marcacion END)
                ), 0
            ) / 60), 2, '0'),
            ':',
            LPAD(COALESCE(
                TIMESTAMPDIFF(MINUTE, 
                    MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' THEN m.fecha_marcacion END),
                    MAX(CASE WHEN m.tipo_marcacion = 'SALIDA' THEN m.fecha_marcacion END)
                ), 0
            ) % 60, 2, '0')
        ) AS horas_laboradas
        
    FROM TblMarcacion m
    INNER JOIN TblPersona p ON m.num_documento = p.num_documento
    INNER JOIN TblUsuario u ON m.num_usuario = u.num_usuario
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblHorarioTrabajo h ON u.id_horario = h.id_horario
    
    WHERE DATE(m.fecha_marcacion) BETWEEN p_fecha_inicio AND p_fecha_fin
      AND u.estado = 'ACTIVO'
      AND (p_num_documento IS NULL OR m.num_documento = p_num_documento)
    
    GROUP BY 
        p.num_documento,
        p.documento_numero,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        e.nombre,
        c.nombre,
        h.nombre,
        DATE(m.fecha_marcacion)
    
    HAVING minutos_totales > 0  -- Solo incluir días con marcaciones válidas
    
    ORDER BY 
        p.apellido_paterno,
        p.apellido_materno,
        p.nombres,
        DATE(m.fecha_marcacion);
END$$

DELIMITER ;

-- ==============================================================================
-- TESTING
-- ==============================================================================
-- Un solo empleado:
-- CALL sp_horas_laboradas_v2('2026-10-01', '2026-10-31', 12345678);

-- TODOS los empleados:
-- CALL sp_horas_laboradas_v2('2026-10-01', '2026-10-31', NULL);
