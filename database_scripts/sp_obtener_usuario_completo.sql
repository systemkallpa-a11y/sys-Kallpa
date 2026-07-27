-- ============================================================================
-- STORED PROCEDURE: sp_ObtenerUsuarioCompleto
-- DESCRIPCIÓN: Obtiene TODOS los datos de un usuario para el modal Editar
-- SOLO TRAE NOMBRES (no IDs de relaciones)
-- Retorna 2 result sets: Usuario + Horarios
-- PARÁMETRO:
--   - p_num_usuario: ID del usuario a obtener
-- ============================================================================

USE kallgwkn_kallpa_bd;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_ObtenerUsuarioCompleto //

CREATE DEFINER=`kallgwkn_user`@`localhost` PROCEDURE sp_ObtenerUsuarioCompleto(
    IN p_num_usuario INT
)
BEGIN
    -- Obtener num_documento del usuario
    DECLARE v_num_documento INT;
    
    SELECT num_documento INTO v_num_documento
    FROM TblUsuario
    WHERE num_usuario = p_num_usuario
    LIMIT 1;
    
    -- RESULT SET 1: Datos del usuario
    SELECT 
        -- DATOS DE USUARIO (IDs necesarios para formulario)
        u.num_usuario,
        u.num_documento,
        u.usuario,
        u.id_cargo,
        u.id_empresa,
        u.estado as usuario_estado,
        
        -- DATOS DE PERSONA
        p.documento_numero,
        p.tipo_documento,
        p.nombres,
        p.apellido_paterno,
        p.apellido_materno,
        p.email,
        p.celular,
        p.celular_referencia,
        p.id_distrito,
        p.fecha_nacimiento,
        p.genero,
        p.direccion,
        
        -- NOMBRES DE RELACIONES (para mostrar en modal)
        c.nombre as cargo_nombre,
        e.nombre as empresa_nombre,
        a.nombre as area_nombre,
        d.nombre as distrito_nombre,
        pr.nombre as provincia_nombre,
        dept.nombre as departamento_nombre,
        
        -- DATOS DE ESTADO
        p.estado as persona_estado,
        p.fecha_creacion
    FROM TblUsuario u
    JOIN TblPersona p ON u.num_documento = p.num_documento
    LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
    LEFT JOIN TblArea a ON c.id_area = a.id_area
    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
    LEFT JOIN TblDistrito d ON p.id_distrito = d.id_distrito
    LEFT JOIN TblProvincia pr ON d.id_provincia = pr.id_provincia
    LEFT JOIN TblDepartamento dept ON pr.id_departamento = dept.id_departamento
    WHERE u.num_usuario = p_num_usuario;
    
    -- RESULT SET 2: Horarios de trabajo (7 días con posibilidad de 2 turnos)
    SELECT 
        id_horario,
        num_documento,
        dia_semana,
        hora_entrada,
        hora_salida,
        hora_entrada2,
        hora_salida2,
        es_activo,
        estado,
        observacion,
        fecha_creacion
    FROM TblHorarioTrabajo
    WHERE num_documento = v_num_documento
    ORDER BY 
        CASE dia_semana
            WHEN 'LUNES' THEN 1
            WHEN 'MARTES' THEN 2
            WHEN 'MIÉRCOLES' THEN 3
            WHEN 'JUEVES' THEN 4
            WHEN 'VIERNES' THEN 5
            WHEN 'SÁBADO' THEN 6
            WHEN 'DOMINGO' THEN 7
        END;
    
END //

DELIMITER ;

-- ============================================================================
-- DESCRIPCIÓN DE CAMPOS RETORNADOS
-- ============================================================================

/*
DATOS DE USUARIO (IDs):
- num_usuario: ID del usuario
- num_documento: FK a TblPersona
- usuario: Nombre de usuario
- id_cargo: ID del cargo (para seleccionar en dropdown)
- id_empresa: ID de la empresa (para seleccionar en dropdown)
- usuario_estado: Estado

DATOS DE PERSONA (con IDs necesarios):
- documento_numero: Número del documento
- tipo_documento: Tipo de documento
- nombres, apellido_paterno, apellido_materno: Nombres
- email, celular, celular_referencia: Contacto
- id_distrito: ID del distrito (para cascada)

NOMBRES DE RELACIONES (para mostrar):
- cargo_nombre: Nombre del cargo (mostrar en campo)
- empresa_nombre: Nombre de la empresa (mostrar en campo)
- area_nombre: Nombre del área (mostrar en campo)
- distrito_nombre: Nombre del distrito (mostrar en campo)
- provincia_nombre: Nombre de la provincia (mostrar en campo)
- departamento_nombre: Nombre del departamento (mostrar en campo)

DATOS DE ESTADO:
- persona_estado: Estado de la persona
- fecha_creacion: Fecha de creación
*/

-- ============================================================================
-- VERIFICACIÓN: Ejecutar el SP
-- ============================================================================

-- CALL sp_ObtenerUsuarioCompleto(1);

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
