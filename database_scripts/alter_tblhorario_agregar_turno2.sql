-- ============================================================================
-- ALTER TABLE: TblHorarioTrabajo
-- DESCRIPCIÓN: Agregar campos para segundo turno (entrada2, salida2)
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- Agregar columnas para segundo turno si no existen
ALTER TABLE TblHorarioTrabajo 
ADD COLUMN IF NOT EXISTS hora_entrada2 TIME NULL COMMENT 'Hora de entrada del segundo turno (HH:MM:SS)',
ADD COLUMN IF NOT EXISTS hora_salida2 TIME NULL COMMENT 'Hora de salida del segundo turno (HH:MM:SS)';

-- ============================================================================
-- DESCRIPCIÓN
-- ============================================================================

/*
Nueva estructura de TblHorarioTrabajo:

CAMPOS ORIGINALES:
- id_horario INT (PK, AUTO_INCREMENT)
- num_documento INT (FK)
- dia_semana VARCHAR(20)
- hora_entrada TIME (Turno 1)
- hora_salida TIME (Turno 1)
- es_activo BOOLEAN
- estado VARCHAR(20)
- observacion VARCHAR(255)
- fecha_creacion TIMESTAMP
- fecha_actualizacion TIMESTAMP

CAMPOS NUEVOS:
- hora_entrada2 TIME (Turno 2) - NULLABLE
- hora_salida2 TIME (Turno 2) - NULLABLE

EJEMPLO DE HORARIO CON DOS TURNOS:
- Lunes: 08:30-13:00 y 15:00-19:00
- Martes: 08:30-13:00 y 15:00-19:00
- Domingo: NULL (día libre)

INSERT INTO TblHorarioTrabajo (num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2, es_activo, estado)
VALUES 
(1, 'LUNES', '08:30:00', '13:00:00', '15:00:00', '19:00:00', 1, 'ACTIVO'),
(1, 'MARTES', '08:30:00', '13:00:00', '15:00:00', '19:00:00', 1, 'ACTIVO'),
(1, 'DOMINGO', NULL, NULL, NULL, NULL, 0, 'ACTIVO');
*/

-- ============================================================================
-- FIN DE SCRIPT
-- ============================================================================
