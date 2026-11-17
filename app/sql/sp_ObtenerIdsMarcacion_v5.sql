-- ============================================================
-- SP: sp_ObtenerIdsMarcacion   (v5)
-- ============================================================
-- Alimenta el modal "Editar horas del dia" de Marcacion
-- (/api/marcacion/obtener-ids): devuelve el id y la ubicacion de
-- la marca que ocupa cada casilla (E1, S1, E2, S2).
--
-- REQUIERE: vista vw_casillas_marcacion (app/sql/vw_casillas_marcacion_v2.sql).
--
-- Cambios v5:
--   * La casilla de cada marca se lee de vw_casillas_marcacion, la
--     REGLA UNICA que usan el reporte y Marcacion. El modal edita
--     exactamente la marca que el reporte esta usando.
--   * Mismas 8 columnas y mismos parametros que v4 (el front no cambia).
--
-- Para revertir: volver a aplicar app/sql/sp_ObtenerIdsMarcacion_v4.sql
-- IMPORTANTE: MySQL no permite alterar el cuerpo => DROP + CREATE.
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

    -- Si la persona no existe, el WHERE no encuentra filas y el
    -- agregado devuelve una fila con las 8 columnas en NULL (igual que v4).
    SELECT
        MAX(CASE WHEN casilla = 'E1' THEN id_marcacion END)   AS id_t1_entrada,
        MAX(CASE WHEN casilla = 'S1' THEN id_marcacion END)   AS id_t1_salida,
        MAX(CASE WHEN casilla = 'E2' THEN id_marcacion END)   AS id_t2_entrada,
        MAX(CASE WHEN casilla = 'S2' THEN id_marcacion END)   AS id_t2_salida,
        MAX(CASE WHEN casilla = 'E1' THEN tipo_ubicacion END) AS tipo_ubi_t1_ent,
        MAX(CASE WHEN casilla = 'S1' THEN tipo_ubicacion END) AS tipo_ubi_t1_sal,
        MAX(CASE WHEN casilla = 'E2' THEN tipo_ubicacion END) AS tipo_ubi_t2_ent,
        MAX(CASE WHEN casilla = 'S2' THEN tipo_ubicacion END) AS tipo_ubi_t2_sal
    FROM vw_casillas_marcacion
    WHERE num_documento = v_num_documento
      AND fecha = p_fecha;
END$$

DELIMITER ;
