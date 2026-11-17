-- ============================================================
-- VISTA: vw_casillas_marcacion   (v2)
-- ============================================================
-- v2: las columnas calculadas 'casilla' y 'estado_marca' se fijan en
--     utf8mb4_unicode_ci (la collation de las tablas y de la app). En v1
--     heredaban la collation de la sesion que creo la vista
--     (utf8mb4_0900_ai_ci) y una comparacion desde la app, p. ej.
--     WHERE estado_marca = 'EXTRA', fallaba con "Illegal mix of collations".
--     La regla no cambia. Se aplica con CREATE OR REPLACE: los SP no se tocan.
-- ============================================================
-- REGLA UNICA que decide a que casilla del dia (E1, S1, E2, S2)
-- pertenece cada marcacion. La usan TODAS las pantallas:
--   * Reportes > Control de Asistencia (sp_reporte_asistencia_automatica v15)
--     y sus exportaciones (Exportar, Tardanzas, Horas, SUNAFIL).
--   * Marcacion > Detalle del dia, Editar horas del dia
--     (sp_ObtenerIdsMarcacion v5), Registrar marca faltante y
--     Exportar a Excel.
-- Asi lo que el administrador ve y edita es lo que se calcula.
--
-- Una fila por marcacion, con:
--   turno         1 = mañana, 2 = tarde (NULL si la marca se ignora)
--   casilla       'E1','S1','E2','S2' = la marca usada en esa casilla;
--                 NULL = no se usa (extra o ignorada)
--   estado_marca  'USADA' | 'EXTRA' | 'DOBLE_CLIC' | 'REPETIDA'
--
-- Regla (en orden):
--   1. Marcas del dia ordenadas por hora.
--   2. Doble clic (menos de 1 minuto):
--        - SALIDA justo despues de una ENTRADA  => se ignora la salida.
--        - ENTRADA repetida                      => vale la primera.
--        - SALIDA repetida                       => vale la ultima.
--        - SALIDA seguida de ENTRADA no se toca (son dos marcas validas).
--   3. ENTRADA: hasta la salida programada de la mañana => mañana;
--      despues => tarde. Sin turno tarde en el horario => tarde
--      (se mostrara SIN HORARIO). Sin horario => corte 14:00.
--   4. SALIDA: va al turno de su ultima entrada anterior. Excepcion
--      (dia con solo marcas de mañana): si viene de una entrada de
--      mañana, es posterior al inicio programado de la tarde y ese
--      dia no hubo ninguna entrada de tarde => es salida de la tarde
--      (ambos turnos quedan INCOMPLETO para que se registre el
--      refrigerio). Salida sin entrada previa => turno con la salida
--      programada mas cercana.
--   5. En cada turno: primera ENTRADA y ultima SALIDA. Ninguna marca
--      se mueve a otro turno para llenar una casilla vacia.
--
-- Horario del dia: el vigente en esa fecha; si hubiera dos vigentes
-- (dia de cambio de horario), se usa el mas reciente.
--
-- Para quitarla: DROP VIEW IF EXISTS vw_casillas_marcacion;
-- ============================================================

CREATE OR REPLACE VIEW vw_casillas_marcacion AS
WITH
dias AS (
    SELECT DISTINCT m.num_documento, DATE(m.fecha_marcacion) AS fecha
    FROM TblMarcacion m
),
horario_dia AS (
    SELECT d.num_documento, d.fecha,
           h.hora_entrada  AS he1, h.hora_salida  AS hs1,
           h.hora_entrada2 AS he2, h.hora_salida2 AS hs2,
           ROW_NUMBER() OVER (
               PARTITION BY d.num_documento, d.fecha
               ORDER BY h.fecha_vigencia_inicio DESC,
                        (h.fecha_vigencia_fin IS NULL) DESC
           ) AS rn
    FROM dias d
    LEFT JOIN TblHorarioTrabajo h
      ON h.num_documento = d.num_documento
     AND UPPER(h.dia_semana) = CASE DAYOFWEEK(d.fecha)
            WHEN 1 THEN 'DOMINGO'
            WHEN 2 THEN 'LUNES'
            WHEN 3 THEN 'MARTES'
            WHEN 4 THEN 'MIÉRCOLES'
            WHEN 5 THEN 'JUEVES'
            WHEN 6 THEN 'VIERNES'
            WHEN 7 THEN 'SÁBADO'
         END
     AND h.es_activo = 1
     AND h.fecha_vigencia_inicio <= d.fecha
     AND (h.fecha_vigencia_fin IS NULL OR h.fecha_vigencia_fin >= d.fecha)
),
marcas AS (
    SELECT m.id_marcacion, m.num_documento,
           DATE(m.fecha_marcacion) AS fecha,
           TIME(m.fecha_marcacion) AS hora,
           m.fecha_marcacion, m.tipo_marcacion, m.tipo_ubicacion, m.justificacion,
           hd.he1, hd.hs1, hd.he2, hd.hs2,
           LAG(m.tipo_marcacion)   OVER w AS prev_tipo,
           LAG(m.fecha_marcacion)  OVER w AS prev_fm,
           LEAD(m.tipo_marcacion)  OVER w AS next_tipo,
           LEAD(m.fecha_marcacion) OVER w AS next_fm
    FROM TblMarcacion m
    JOIN horario_dia hd
      ON hd.num_documento = m.num_documento
     AND hd.fecha = DATE(m.fecha_marcacion)
     AND hd.rn = 1
    WINDOW w AS (PARTITION BY m.num_documento, DATE(m.fecha_marcacion)
                 ORDER BY m.fecha_marcacion, m.id_marcacion)
),
filtro AS (
    -- Paso 2: doble clic (menos de 1 minuto)
    SELECT mk.*,
           CASE
               WHEN mk.tipo_marcacion = 'SALIDA' AND mk.prev_tipo = 'ENTRADA'
                    AND TIMESTAMPDIFF(SECOND, mk.prev_fm, mk.fecha_marcacion) < 60 THEN 'DOBLE_CLIC'
               WHEN mk.tipo_marcacion = 'ENTRADA' AND mk.prev_tipo = 'ENTRADA'
                    AND TIMESTAMPDIFF(SECOND, mk.prev_fm, mk.fecha_marcacion) < 60 THEN 'REPETIDA'
               WHEN mk.tipo_marcacion = 'SALIDA' AND mk.next_tipo = 'SALIDA'
                    AND TIMESTAMPDIFF(SECOND, mk.fecha_marcacion, mk.next_fm) < 60 THEN 'REPETIDA'
           END AS ignorada
    FROM marcas mk
),
validas AS (
    SELECT f.*,
           MAX(CASE WHEN f.tipo_marcacion = 'ENTRADA' THEN f.fecha_marcacion END) OVER (
               PARTITION BY f.num_documento, f.fecha
               ORDER BY f.fecha_marcacion, f.id_marcacion
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS ult_ent
    FROM filtro f
    WHERE f.ignorada IS NULL
),
con_turno AS (
    SELECT v.*,
           CASE
               -- Paso 3: ENTRADA por su propia hora
               WHEN v.tipo_marcacion = 'ENTRADA' THEN
                   CASE
                       WHEN v.he1 IS NULL AND v.he2 IS NULL THEN CASE WHEN v.hora <= '14:00:00' THEN 1 ELSE 2 END
                       WHEN v.he1 IS NULL OR v.hs1 IS NULL THEN 2
                       WHEN v.hora <= v.hs1 THEN 1
                       ELSE 2
                   END
               -- Paso 4: SALIDA sin entrada previa => salida programada mas cercana
               WHEN v.ult_ent IS NULL THEN
                   CASE
                       WHEN v.hs1 IS NOT NULL AND v.hs2 IS NOT NULL THEN
                           CASE WHEN ABS(TIME_TO_SEC(v.hora) - TIME_TO_SEC(v.hs1))
                                     <= ABS(TIME_TO_SEC(v.hora) - TIME_TO_SEC(v.hs2)) THEN 1 ELSE 2 END
                       WHEN v.hs1 IS NOT NULL THEN 1
                       WHEN v.hs2 IS NOT NULL THEN 2
                       ELSE CASE WHEN v.hora <= '14:00:00' THEN 1 ELSE 2 END
                   END
               -- Paso 4: SALIDA => turno de su ultima entrada anterior
               ELSE
                   CASE
                       WHEN v.he1 IS NULL AND v.he2 IS NULL THEN CASE WHEN TIME(v.ult_ent) <= '14:00:00' THEN 1 ELSE 2 END
                       WHEN v.he1 IS NULL OR v.hs1 IS NULL THEN 2
                       WHEN TIME(v.ult_ent) <= v.hs1 THEN 1
                       ELSE 2
                   END
           END AS turno_base
    FROM validas v
),
con_excepcion AS (
    SELECT c.*,
           MAX(CASE WHEN c.tipo_marcacion = 'ENTRADA' AND c.turno_base = 2 THEN 1 ELSE 0 END)
               OVER (PARTITION BY c.num_documento, c.fecha) AS hay_entrada_t2
    FROM con_turno c
),
asignada AS (
    SELECT x.*,
           CASE
               -- Paso 4 (excepcion): dia sin entrada de tarde y salida posterior al inicio de la tarde
               WHEN x.tipo_marcacion = 'SALIDA' AND x.turno_base = 1 AND x.ult_ent IS NOT NULL
                    AND x.he2 IS NOT NULL AND x.hora > x.he2 AND x.hay_entrada_t2 = 0 THEN 2
               ELSE x.turno_base
           END AS turno
    FROM con_excepcion x
),
ranking AS (
    -- Paso 5: primera ENTRADA y ultima SALIDA de cada turno
    SELECT a.*,
           ROW_NUMBER() OVER (
               PARTITION BY a.num_documento, a.fecha, a.turno, a.tipo_marcacion
               ORDER BY CASE WHEN a.tipo_marcacion = 'ENTRADA'
                             THEN TIME_TO_SEC(a.hora) ELSE -TIME_TO_SEC(a.hora) END,
                        a.id_marcacion
           ) AS rn
    FROM asignada a
)
SELECT r.id_marcacion, r.num_documento, r.fecha, r.hora, r.fecha_marcacion,
       r.tipo_marcacion, r.tipo_ubicacion, r.justificacion,
       r.turno,
       CAST(CASE WHEN r.rn = 1
                 THEN CONCAT(CASE WHEN r.tipo_marcacion = 'ENTRADA' THEN 'E' ELSE 'S' END, r.turno)
            END AS CHAR(2)) COLLATE utf8mb4_unicode_ci AS casilla,
       CAST(CASE WHEN r.rn = 1 THEN 'USADA' ELSE 'EXTRA' END AS CHAR(10)) COLLATE utf8mb4_unicode_ci AS estado_marca
FROM ranking r
UNION ALL
SELECT f.id_marcacion, f.num_documento, f.fecha, f.hora, f.fecha_marcacion,
       f.tipo_marcacion, f.tipo_ubicacion, f.justificacion,
       NULL AS turno,
       CAST(NULL AS CHAR(2)) COLLATE utf8mb4_unicode_ci AS casilla,
       CAST(f.ignorada AS CHAR(10)) COLLATE utf8mb4_unicode_ci AS estado_marca
FROM filtro f
WHERE f.ignorada IS NOT NULL;
