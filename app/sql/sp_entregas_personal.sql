-- ============================================================================
-- MÓDULO: ENTREGAS A PERSONAL
-- Corregido: usa TblUsuario + TblPersona + TblArea (tablas reales del sistema)
-- Patrón idéntico al de vacaciones.py y auth.py
-- ============================================================================

SET NAMES utf8mb4;
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_listar_entrega_personal$$
CREATE PROCEDURE sp_listar_entrega_personal(
    IN p_busqueda VARCHAR(100)
)
BEGIN
    SELECT
        u.num_documento                                                        AS id_personal,
        p.documento_numero                                                     AS DOCUMENTO,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                        AS NOMBRE_COMPLETO,
        COALESCE(c.nombre, 'Sin Cargo')                                        AS CARGO,
        COALESCE(a.nombre, 'Sin Área')                                         AS AREA,
        COUNT(DISTINCT ep.id_entrega)                                          AS TOTAL_ENTREGAS,
        COALESCE(SUM(epd.cantidad), 0)                                         AS TOTAL_ITEMS,
        MAX(ep.fecha_entrega)                                                  AS ULTIMA_ENTREGA
    FROM TblUsuario u
    INNER JOIN TblPersona p  ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c    ON u.id_cargo      = c.id_cargo
    LEFT  JOIN TblArea a     ON c.id_area       = a.id_area
    LEFT  JOIN TblEntregaPersonal ep
               ON u.num_documento = ep.id_personal
               AND ep.estado = 'ACTIVO'
    LEFT  JOIN TblEntregaPersonalDetalle epd
               ON ep.id_entrega = epd.id_entrega
    WHERE u.estado = 'Activo'
      AND (
            p_busqueda IS NULL
            OR p_busqueda = ''
            OR p.documento_numero           LIKE CONCAT('%', p_busqueda, '%')
            OR p.nombres                    LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_paterno           LIKE CONCAT('%', p_busqueda, '%')
            OR p.apellido_materno           LIKE CONCAT('%', p_busqueda, '%')
            OR c.nombre                     LIKE CONCAT('%', p_busqueda, '%')
            OR a.nombre                     LIKE CONCAT('%', p_busqueda, '%')
          )
    GROUP BY u.num_documento, p.documento_numero, p.nombres, p.apellido_paterno,
             p.apellido_materno, c.nombre, a.nombre
    ORDER BY p.apellido_paterno ASC, p.nombres ASC;
END$$

DELIMITER ;

-- ============================================================================
-- SP 2: Obtener materiales ya asignados a un trabajador (carrito inicial)
-- ============================================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_obtener_asignados_personal$$
CREATE PROCEDURE sp_obtener_asignados_personal(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    SELECT
        epd.id_entrega_detalle,
        epd.id_entrega,
        epd.id_inventario,
        i.codigo,
        i.nombre,
        epd.cantidad,
        epd.serie,
        epd.estado_bien,
        u.abreviatura AS unidad,
        ep.codigo_entrega,
        ep.fecha_entrega
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
    WHERE ep.id_personal = p_id_personal
      AND ep.estado = 'ACTIVO'
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

-- ============================================================================
-- SP 3: Guardar nueva entrega (cabecera + detalle + descontar stock)
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_guardar_entrega_personal$$
CREATE PROCEDURE sp_guardar_entrega_personal(
    IN  p_id_personal   VARCHAR(20),
    IN  p_observaciones TEXT,
    IN  p_creado_por    VARCHAR(50),
    OUT p_success       TINYINT(1),
    OUT p_message       VARCHAR(255),
    OUT p_id_entrega    INT,
    OUT p_codigo        VARCHAR(50)
)
sp_body: BEGIN
    DECLARE v_codigo VARCHAR(50);
    DECLARE v_count  INT;

    -- Validar que el personal existe
    IF NOT EXISTS (
        SELECT 1 FROM TblUsuario WHERE num_documento = p_id_personal AND estado = 'Activo'
    ) THEN
        SET p_success = 0;
        SET p_message = 'El personal no existe o está inactivo';
        LEAVE sp_body;
    END IF;

    -- Generar código único VALE-YYYYMMDD-XXXX
    SELECT COUNT(*) + 1 INTO v_count FROM TblEntregaPersonal;
    SET v_codigo = CONCAT('VALE-', DATE_FORMAT(NOW(), '%Y%m%d'), '-', LPAD(v_count, 4, '0'));

    -- Insertar cabecera
    INSERT INTO TblEntregaPersonal (
        codigo_entrega, id_personal, fecha_entrega,
        observaciones, estado, creado_por
    ) VALUES (
        v_codigo, p_id_personal, NOW(),
        p_observaciones, 'ACTIVO', p_creado_por
    );

    SET p_id_entrega = LAST_INSERT_ID();
    SET p_codigo     = v_codigo;
    SET p_success    = 1;
    SET p_message    = 'Entrega creada correctamente';
END sp_body$$

DELIMITER ;

-- ============================================================================
-- SP 4: Kardex de un trabajador
-- Devuelve ficha del trabajador + historial completo de materiales asignados
-- ============================================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_kardex_personal$$
CREATE PROCEDURE sp_kardex_personal(
    IN p_id_personal VARCHAR(20)
)
BEGIN
    -- 1. Ficha del trabajador
    SELECT
        p.documento_numero                                                          AS documento,
        CONCAT(p.nombres, ' ', p.apellido_paterno,
               IF(p.apellido_materno IS NOT NULL AND p.apellido_materno <> '',
                  CONCAT(' ', p.apellido_materno), ''))                             AS nombre_completo,
        COALESCE(c.nombre, 'Sin Cargo')                                             AS cargo,
        COALESCE(a.nombre, 'Sin Área')                                              AS area,
        p.email
    FROM TblUsuario u
    INNER JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT  JOIN TblCargo c   ON u.id_cargo = c.id_cargo
    LEFT  JOIN TblArea a    ON c.id_area  = a.id_area
    WHERE u.num_documento = p_id_personal
    LIMIT 1;

    -- 2. Historial de materiales
    SELECT
        ep.fecha_entrega,
        ep.codigo_entrega,
        i.nombre                AS material,
        i.codigo                AS codigo_material,
        epd.serie,
        epd.cantidad,
        u2.abreviatura          AS unidad,
        epd.estado_bien,
        ep.estado               AS estado_asignacion,
        epd.observaciones
    FROM TblEntregaPersonal ep
    INNER JOIN TblEntregaPersonalDetalle epd ON ep.id_entrega = epd.id_entrega
    INNER JOIN TblInventario i               ON epd.id_inventario = i.id_inventario
    LEFT  JOIN TblUnidadMedida u2            ON i.id_unidad = u2.id_unidad
    WHERE ep.id_personal = p_id_personal
    ORDER BY ep.fecha_entrega DESC, i.nombre ASC;
END$$

DELIMITER ;
