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
               NULL AS tipo_ubi_t2_ent, NULL AS tipo_ubi_t2_sal,
               NULL AS just_t1_ent, NULL AS just_t1_sal,
               NULL AS just_t2_ent, NULL AS just_t2_sal;
    ELSE
        SELECT 
            -- ===== IDs (existentes) =====
            (SELECT id_marcacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS id_t1_entrada,
            
            (SELECT id_marcacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS id_t1_salida,
            
            (SELECT id_marcacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) >= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS id_t2_entrada,
            
            (SELECT id_marcacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) > '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS id_t2_salida,
            
            -- ===== TIPO UBICACION =====
            (SELECT tipo_ubicacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t1_ent,
            
            (SELECT tipo_ubicacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t1_sal,
            
            (SELECT tipo_ubicacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) >= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS tipo_ubi_t2_ent,
            
            (SELECT tipo_ubicacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) > '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS tipo_ubi_t2_sal,
            
            -- ===== JUSTIFICACIONES (4 NUEVAS) =====
            (SELECT justificacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS just_t1_ent,
            
            (SELECT justificacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) <= '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS just_t1_sal,
            
            (SELECT justificacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'ENTRADA' AND TIME(fecha_marcacion) >= '14:00:00'
             ORDER BY fecha_marcacion ASC LIMIT 1) AS just_t2_ent,
            
            (SELECT justificacion FROM TblMarcacion 
             WHERE num_documento = v_num_documento AND DATE(fecha_marcacion) = p_fecha
               AND tipo_marcacion = 'SALIDA' AND TIME(fecha_marcacion) > '14:00:00'
             ORDER BY fecha_marcacion DESC LIMIT 1) AS just_t2_sal;
    END IF;
END