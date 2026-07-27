-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerUsuariosAccesos
-- DESCRIPCIÓN: Obtiene lista de usuarios con todos sus accesos a menús/submenús
-- Retorna información de cada usuario y sus accesos asociados
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerUsuariosAccesos //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ObtenerUsuariosAccesos()
BEGIN
    -- RESULT SET 1: Lista de usuarios con información básica
    -- NOTA: Nueva lógica - SOLO se guardan submenús específicos (sin NULL)
    SELECT DISTINCT
        u.num_usuario,
        u.num_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', COALESCE(p.apellido_materno, '')) as nombre_completo,
        u.usuario,
        u.estado,
        c.nombre as cargo_nombre,
        e.nombre as empresa_nombre,
        COUNT(DISTINCT ua.id_menu) as total_menus_acceso,
        COUNT(DISTINCT ua.id_submenu) as total_submenus_acceso
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblUsuarioAccesos ua ON u.num_documento = ua.num_documento AND ua.estado = 'ACTIVO' AND ua.id_submenu IS NOT NULL
    WHERE u.estado = 'ACTIVO'
    GROUP BY u.num_usuario, u.num_documento, p.nombres, p.apellido_paterno, p.apellido_materno, u.usuario, u.estado, c.nombre, e.nombre
    ORDER BY p.nombres, p.apellido_paterno;
    
END //

DELIMITER ;

-- ============================================================================
-- SEGUNDO SP: Obtener accesos detallados de un usuario específico
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerAccesosUsuario //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ObtenerAccesosUsuario(
    IN p_num_documento INT
)
BEGIN
    -- RESULT SET: Accesos del usuario con detalles de menú y submenú
    SELECT 
        ua.id_usuario_acceso,
        ua.num_documento,
        ua.id_menu,
        m.nombre as menu_nombre,
        m.icono as menu_icono,
        ua.id_submenu,
        sm.nombre as submenu_nombre,
        sm.icono as submenu_icono,
        sm.ruta as submenu_ruta,
        ua.estado,
        ua.fecha_creacion,
        CASE 
            WHEN ua.id_submenu IS NULL THEN 'Menú Completo'
            ELSE 'Submenú Específico'
        END as tipo_acceso
    FROM TblUsuarioAccesos ua
    JOIN TblMenu m ON ua.id_menu = m.id_menu
    LEFT JOIN TblSubMenu sm ON ua.id_submenu = sm.id_submenu AND ua.id_menu = sm.id_menu
    WHERE ua.num_documento = p_num_documento AND ua.estado = 'ACTIVO'
    ORDER BY m.orden, COALESCE(sm.orden, 0);
    
END //

DELIMITER ;

-- ============================================================================
-- VERIFICACIÓN: Ejecutar los SPs
-- ============================================================================

-- CALL sp_ObtenerUsuariosAccesos();
-- CALL sp_ObtenerAccesosUsuario(1);

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
