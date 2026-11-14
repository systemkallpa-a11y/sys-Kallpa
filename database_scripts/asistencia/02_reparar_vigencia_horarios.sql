-- ============================================================
-- Reparación de vigencias en TblHorarioTrabajo
-- Fecha: 14/11/2026
-- ============================================================
-- Corrige los datos que dejaron:
--   * el alta de usuario sin inicio de vigencia (arreglado en
--     01_sp_CrearUsuarioCompleto_vigencia.sql)
--   * versiones de horario guardadas el mismo día (solapes). Nota: al
--     editar un horario, usuarios.py cierra el anterior con fin = hoy y
--     abre el nuevo con inicio = hoy (comportamiento original, se mantiene
--     por decisión de RR.HH.); los pasos B y C son limpieza opcional.
--
-- Paso A: filas con fecha_vigencia_inicio NULL. Los SP de asistencia
--         nunca veían estas filas ("SIN HORARIO").
--         Estado al 14/11/2026: 14 filas (num_documento 76 y 78,
--         creados el 13/11/2026) -> inicio 14/11/2026 (definido por
--         RR.HH.). Otras filas que aparezcan -> DATE(fecha_creacion).
-- Paso B: versiones solapadas de la misma persona y día de semana ->
--         la versión anterior se cierra el día previo al inicio de la
--         siguiente. Estado al 14/11/2026: 12 filas de num_documento 1
--         (cambio del 08/11/2026 guardado dos veces).
-- Paso C: versiones que quedan con rango vacío (fin < inicio) se
--         eliminan: nunca rigieron un día completo. Estado al
--         14/11/2026: 6 filas (id 1116..1121).
--
-- Idempotente: si se ejecuta de nuevo, los pasos A, B y C no
-- encuentran filas (afectan 0).
--
-- CÓMO EJECUTAR
--   1. Respaldo con datos (fuera del proyecto), por ejemplo:
--        mysqldump ... TblHorarioTrabajo > sistema3/_respaldos_bd/horarios_respaldo_previo_20261114.sql
--      y además la tabla de respaldo del bloque 0 (dentro de la BD).
--   2. Ejecutar los bloques 0 a 4 en orden.
--   3. Revisar el bloque 4 (verificación). Si es correcto: COMMIT.
--      Si no: ROLLBACK (y nada cambia).
-- ============================================================

-- ------------------------------------------------------------
-- 0. Respaldo dentro de la BD (CREATE TABLE hace commit implícito:
--    va ANTES de la transacción). Borrar con mantenimiento/ cuando
--    se verifique.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS respaldo_TblHorarioTrabajo_20261114 AS
SELECT * FROM TblHorarioTrabajo;

SELECT COUNT(*) AS filas_respaldadas FROM respaldo_TblHorarioTrabajo_20261114;

-- ------------------------------------------------------------
-- 1. Diagnóstico previo (solo lectura)
-- ------------------------------------------------------------
SELECT 'inicio_null' AS control, COUNT(*) AS filas
  FROM TblHorarioTrabajo WHERE fecha_vigencia_inicio IS NULL
UNION ALL
SELECT 'solapes', COUNT(*)
  FROM TblHorarioTrabajo a
  JOIN TblHorarioTrabajo b
    ON b.num_documento = a.num_documento
   AND UPPER(b.dia_semana) = UPPER(a.dia_semana)
   AND b.id_horario > a.id_horario
   AND b.fecha_vigencia_inicio >= a.fecha_vigencia_inicio
   AND b.fecha_vigencia_inicio <= IFNULL(a.fecha_vigencia_fin, '9999-12-31');

START TRANSACTION;

-- ------------------------------------------------------------
-- 2. Paso A: inicio de vigencia faltante
-- ------------------------------------------------------------
-- num_documento 76 y 78 (creados el 13/11/2026): RR.HH. definió que su
-- horario rige desde el 14/11/2026, su primer día con marcas.
UPDATE TblHorarioTrabajo
   SET fecha_vigencia_inicio = '2026-11-14'
 WHERE fecha_vigencia_inicio IS NULL
   AND num_documento IN (76, 78);

-- Cualquier otra fila sin inicio: desde su fecha de creación.
UPDATE TblHorarioTrabajo
   SET fecha_vigencia_inicio = DATE(fecha_creacion)
 WHERE fecha_vigencia_inicio IS NULL
   AND fecha_creacion IS NOT NULL;

-- ------------------------------------------------------------
-- 3. Paso B: cerrar la versión anterior el día previo a la siguiente
--    (la tabla derivada se materializa por el GROUP BY, por eso MySQL
--    permite leer y actualizar la misma tabla)
-- ------------------------------------------------------------
UPDATE TblHorarioTrabajo a
  JOIN (
        SELECT x.id_horario,
               MIN(y.fecha_vigencia_inicio) AS inicio_siguiente
          FROM TblHorarioTrabajo x
          JOIN TblHorarioTrabajo y
            ON y.num_documento = x.num_documento
           AND UPPER(y.dia_semana) = UPPER(x.dia_semana)
           AND y.id_horario > x.id_horario
           AND y.fecha_vigencia_inicio >= x.fecha_vigencia_inicio
           AND y.fecha_vigencia_inicio <= IFNULL(x.fecha_vigencia_fin, '9999-12-31')
         GROUP BY x.id_horario
       ) s ON s.id_horario = a.id_horario
   SET a.fecha_vigencia_fin = s.inicio_siguiente - INTERVAL 1 DAY;

-- Paso C: versiones que quedaron sin ningún día de vigencia
DELETE FROM TblHorarioTrabajo
 WHERE fecha_vigencia_fin IS NOT NULL
   AND fecha_vigencia_fin < fecha_vigencia_inicio;

-- ------------------------------------------------------------
-- 4. Verificación (esperado: 0, 0, 0 y el historial limpio)
-- ------------------------------------------------------------
SELECT 'inicio_null' AS control, COUNT(*) AS filas
  FROM TblHorarioTrabajo WHERE fecha_vigencia_inicio IS NULL
UNION ALL
SELECT 'solapes', COUNT(*)
  FROM TblHorarioTrabajo a
  JOIN TblHorarioTrabajo b
    ON b.num_documento = a.num_documento
   AND UPPER(b.dia_semana) = UPPER(a.dia_semana)
   AND b.id_horario > a.id_horario
   AND b.fecha_vigencia_inicio <= IFNULL(a.fecha_vigencia_fin, '9999-12-31')
   AND a.fecha_vigencia_inicio <= IFNULL(b.fecha_vigencia_fin, '9999-12-31')
UNION ALL
SELECT 'rango_vacio', COUNT(*)
  FROM TblHorarioTrabajo WHERE fecha_vigencia_fin < fecha_vigencia_inicio;

-- Historial esperado de num_documento 1: por día, 2024-01-01..2026-11-07
-- (horario anterior) y 2026-11-08..NULL (horario nuevo).
SELECT num_documento, dia_semana, hora_entrada, hora_salida, hora_entrada2, hora_salida2,
       fecha_vigencia_inicio, fecha_vigencia_fin
  FROM TblHorarioTrabajo
 WHERE num_documento IN (1, 76, 78)
 ORDER BY num_documento, dia_semana, fecha_vigencia_inicio;

-- Si todo es correcto:
-- COMMIT;
-- Si algo no cuadra:
-- ROLLBACK;
