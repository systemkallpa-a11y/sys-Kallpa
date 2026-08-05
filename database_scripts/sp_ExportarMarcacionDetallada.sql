-- ============================================================================
-- STORED PROCEDURE: sp_ExportarMarcacionDetallada
-- Exporta marcaciones detalladas por usuario con turnos organizados
-- FECHA: 05 Agosto 2026
-- ============================================================================

USE Kallpa;

DROP PROCEDURE IF EXISTS `sp_ExportarMarcacionDetallada`;

DELIMITER $$

CREATE DEFINER=`kallpasystem`@`%` PROCEDURE `sp_ExportarMarcacionDetallada`(
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE
)
READS SQL DATA
BEGIN
    -- ========================================================================
    -- DESCRIPCIÓN:
    -- Genera un reporte detallado de marcaciones por usuario y fecha
    -- con turnos organizados (Entrada 1, Salida 1, Entrada 2, Salida 2)
    -- ========================================================================
    
    SELECT 
        u.num_documento AS 'Número Documento',
        CONCAT(
            COALESCE(p.nombres, ''), ' ',
            COALESCE(p.apellido_paterno, ''), ' ',
            COALESCE(p.apellido_materno, '')
        ) AS 'Nombres Completos',
        DATE(m.fecha_marcacion) AS 'Fecha',
        
        -- TURNO 1 - MAÑANA
        (SELECT TIME(fecha_marcacion) 
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'ENTRADA'
           AND TIME(m1.fecha_marcacion) < '13:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Entrada 1',
        
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'SALIDA'
           AND TIME(m1.fecha_marcacion) < '14:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Salida 1',
        
        -- TURNO 2 - TARDE
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'ENTRADA'
           AND TIME(m1.fecha_marcacion) >= '13:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Entrada 2',
        
        (SELECT TIME(fecha_marcacion)
         FROM TblMarcacion m1
         WHERE m1.num_documento = u.num_documento
           AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
           AND m1.tipo_marcacion = 'SALIDA'
           AND TIME(m1.fecha_marcacion) >= '14:00:00'
         ORDER BY m1.fecha_marcacion ASC
         LIMIT 1) AS 'Salida 2',
        
        -- ESTADO
        CASE
            WHEN EXISTS (
                SELECT 1 FROM TblMarcacion m1
                WHERE m1.num_documento = u.num_documento
                  AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
                  AND m1.tipo_marcacion = 'ENTRADA'
                LIMIT 1
            ) THEN (
                -- Si tiene entrada, usar el estado de la primera entrada
                SELECT m1.estado
                FROM TblMarcacion m1
                WHERE m1.num_documento = u.num_documento
                  AND DATE(m1.fecha_marcacion) = DATE(m.fecha_marcacion)
                  AND m1.tipo_marcacion = 'ENTRADA'
                ORDER BY m1.fecha_marcacion ASC
                LIMIT 1
            )
            ELSE 'SIN MARCA'
        END AS 'Estado'
        
    FROM TblUsuario u
    
    -- JOIN con TblPersona para obtener nombres
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    
    -- Generar todas las fechas del rango para cada usuario
    CROSS JOIN (
        SELECT DATE(a.fecha) AS fecha_generada
        FROM (
            SELECT DATE_ADD(p_fecha_desde, INTERVAL t.n DAY) AS fecha
            FROM (
                SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL 
                SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL 
                SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL 
                SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL 
                SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL 
                SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL 
                SELECT 24 UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL 
                SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30 UNION ALL SELECT 31 UNION ALL 
                SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35 UNION ALL 
                SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39 UNION ALL 
                SELECT 40 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43 UNION ALL 
                SELECT 44 UNION ALL SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47 UNION ALL 
                SELECT 48 UNION ALL SELECT 49 UNION ALL SELECT 50 UNION ALL SELECT 51 UNION ALL 
                SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55 UNION ALL 
                SELECT 56 UNION ALL SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59 UNION ALL 
                SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63
            ) t
        ) a
        WHERE DATE(a.fecha) BETWEEN p_fecha_desde AND p_fecha_hasta
    ) fechas
    
    -- LEFT JOIN con marcaciones (para incluir días sin marcación)
    LEFT JOIN TblMarcacion m ON u.num_documento = m.num_documento
        AND DATE(m.fecha_marcacion) = fechas.fecha_generada
    
    WHERE u.estado = 'ACTIVO'
    
    GROUP BY 
        u.num_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        fechas.fecha_generada
    
    ORDER BY 
        p.apellido_paterno,
        p.apellido_materno,
        p.nombres,
        fechas.fecha_generada;
    
END$$

DELIMITER ;


-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

SELECT '✅ sp_ExportarMarcacionDetallada creado correctamente' AS mensaje;

-- ============================================================================
-- EJEMPLO DE USO
-- ============================================================================

/*
-- Exportar marcaciones del mes de agosto 2026
CALL sp_ExportarMarcacionDetallada('2026-08-01', '2026-08-31');

-- Exportar marcaciones de una semana
CALL sp_ExportarMarcacionDetallada('2026-08-01', '2026-08-07');
*/


-- ============================================================================
-- ESTRUCTURA DE SALIDA
-- ============================================================================

/*
╔════════════════════╦═══════════════════════╦════════════╦═══════════╦══════════╦═══════════╦══════════╦═══════════════╗
║ Número Documento   ║ Nombres Completos     ║ Fecha      ║ Entrada 1 ║ Salida 1 ║ Entrada 2 ║ Salida 2 ║ Estado        ║
╠════════════════════╬═══════════════════════╬════════════╬═══════════╬══════════╬═══════════╬══════════╬═══════════════╣
║ 12345678           ║ Juan Pérez López      ║ 2026-08-01 ║ 08:00:00  ║ 12:30:00 ║ 14:00:00  ║ 18:00:00 ║ ASISTIO       ║
║ 12345678           ║ Juan Pérez López      ║ 2026-08-02 ║ 08:15:00  ║ 12:25:00 ║ NULL      ║ NULL     ║ TARDE         ║
║ 12345678           ║ Juan Pérez López      ║ 2026-08-03 ║ NULL      ║ NULL     ║ NULL      ║ NULL     ║ SIN MARCA     ║
║ 87654321           ║ María García Torres   ║ 2026-08-01 ║ 08:05:00  ║ 12:00:00 ║ 13:30:00  ║ 17:30:00 ║ ASISTIO       ║
╚════════════════════╩═══════════════════════╩════════════╩═══════════╩══════════╩═══════════╩══════════╩═══════════════╝

NOTAS:
- "Entrada 1" y "Salida 1": Turno de mañana (antes de 13:00)
- "Entrada 2" y "Salida 2": Turno de tarde (después de 13:00)
- Si no hay marcación, muestra NULL
- Estado "SIN MARCA" si no hay ninguna entrada en ese día
- Estado tomado de la primera ENTRADA del día (ASISTIO, TARDE, ASISTIO +5)
*/

