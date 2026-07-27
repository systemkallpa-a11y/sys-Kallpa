-- ============================================================================
-- CREATE TABLE: TblHorarioTrabajo
-- DESCRIPCIÓN: Registra el horario de trabajo semanal de cada usuario
-- Relación: FK con TblUsuario (num_documento)
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Crear tabla TblHorarioTrabajo
CREATE TABLE IF NOT EXISTS TblHorarioTrabajo (
    id_horario INT PRIMARY KEY AUTO_INCREMENT COMMENT 'ID único del horario',
    num_documento INT NOT NULL COMMENT 'FK a TblUsuario.num_documento',
    dia_semana VARCHAR(20) NOT NULL COMMENT 'Día de la semana (LUNES, MARTES, MIÉRCOLES, JUEVES, VIERNES, SÁBADO, DOMINGO)',
    hora_entrada TIME NOT NULL COMMENT 'Hora de entrada (HH:MM:SS)',
    hora_salida TIME NOT NULL COMMENT 'Hora de salida (HH:MM:SS)',
    es_activo BOOLEAN DEFAULT 1 COMMENT '1 = día laboral, 0 = día libre',
    estado VARCHAR(20) DEFAULT 'ACTIVO' COMMENT 'Estado del registro (ACTIVO, INACTIVO)',
    observacion VARCHAR(255) NULL COMMENT 'Notas adicionales',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha de creación',
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha de última actualización',
    
    -- Índices
    INDEX idx_num_documento (num_documento),
    INDEX idx_dia_semana (dia_semana),
    INDEX idx_estado (estado),
    
    -- Foreign Key
    CONSTRAINT fk_tblhorario_tblusuario FOREIGN KEY (num_documento) 
        REFERENCES TblUsuario(num_documento) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
COMMENT='Tabla de horarios de trabajo por usuario y día de la semana';

-- ============================================================================
-- DESCRIPCIÓN DE CAMPOS
-- ============================================================================

/*
id_horario (INT, PK, AUTO_INCREMENT):
  - ID único de cada registro de horario
  - Se incrementa automáticamente

num_documento (INT, FK, NOT NULL):
  - Referencia a TblUsuario.num_documento
  - Identifica al usuario
  - Tiene restricción CASCADE (si se borra usuario, se borran sus horarios)

dia_semana (VARCHAR(20), NOT NULL):
  - Día de la semana en mayúscula: LUNES, MARTES, MIÉRCOLES, JUEVES, VIERNES, SÁBADO, DOMINGO
  - Se usa para agrupar y buscar horarios por día

hora_entrada (TIME, NOT NULL):
  - Hora de entrada en formato HH:MM:SS
  - Ejemplo: 09:00:00, 08:30:00

hora_salida (TIME, NOT NULL):
  - Hora de salida en formato HH:MM:SS
  - Ejemplo: 17:00:00, 18:30:00

es_activo (BOOLEAN, DEFAULT 1):
  - 1 = día laboral (usuario trabaja)
  - 0 = día libre (usuario no trabaja)

estado (VARCHAR(20), DEFAULT 'ACTIVO'):
  - ACTIVO: El horario está vigente
  - INACTIVO: El horario fue desactivado

observacion (VARCHAR(255), NULL):
  - Notas adicionales sobre el horario
  - Puede ser vacío

fecha_creacion (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP):
  - Se registra automáticamente al crear

fecha_actualizacion (TIMESTAMP, DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP):
  - Se actualiza automáticamente al modificar

ÍNDICES:
  - idx_num_documento: Búsqueda rápida por usuario
  - idx_dia_semana: Búsqueda rápida por día
  - idx_estado: Búsqueda rápida por estado

FOREIGN KEY:
  - fk_tblhorario_tblusuario: Relación con TblUsuario
  - ON DELETE CASCADE: Si se borra un usuario, se borran sus horarios
  - ON UPDATE CASCADE: Si cambia num_documento en TblUsuario, se actualiza en TblHorarioTrabajo
*/

-- ============================================================================
-- EJEMPLO: Insertar horarios de trabajo para un usuario
-- ============================================================================

/*
-- Usuario trabaja de lunes a viernes de 09:00 a 17:00
-- Sábado y domingo libres

INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, es_activo, estado, observacion)
VALUES
(1, 'LUNES',     '09:00:00', '17:00:00', 1, 'ACTIVO', 'Horario normal'),
(1, 'MARTES',    '09:00:00', '17:00:00', 1, 'ACTIVO', 'Horario normal'),
(1, 'MIÉRCOLES', '09:00:00', '17:00:00', 1, 'ACTIVO', 'Horario normal'),
(1, 'JUEVES',    '09:00:00', '17:00:00', 1, 'ACTIVO', 'Horario normal'),
(1, 'VIERNES',   '09:00:00', '17:00:00', 1, 'ACTIVO', 'Horario normal'),
(1, 'SÁBADO',    '09:00:00', '13:00:00', 1, 'ACTIVO', 'Media jornada'),
(1, 'DOMINGO',   NULL,       NULL,       0, 'ACTIVO', 'Día libre');

-- Consultar horarios de un usuario
SELECT * FROM TblHorarioTrabajo WHERE num_documento = 1 ORDER BY 
  CASE dia_semana
    WHEN 'LUNES' THEN 1
    WHEN 'MARTES' THEN 2
    WHEN 'MIÉRCOLES' THEN 3
    WHEN 'JUEVES' THEN 4
    WHEN 'VIERNES' THEN 5
    WHEN 'SÁBADO' THEN 6
    WHEN 'DOMINGO' THEN 7
  END;
*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
