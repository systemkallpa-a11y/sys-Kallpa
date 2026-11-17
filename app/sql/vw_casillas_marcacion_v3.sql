-- ============================================================
-- VISTA: vw_casillas_marcacion   (v3)
-- ============================================================
-- REGLA UNICA que decide a que casilla del dia (E1, S1, E2, S2)
-- pertenece cada marcacion. La usan TODAS las pantallas:
--   * Reportes > Control de Asistencia (sp_reporte_asistencia_automatica)
--     y sus exportaciones (Exportar, Tardanzas, Horas, SUNAFIL).
--   * Marcacion > Detalle del dia, Editar horas del dia
--     (sp_ObtenerIdsMarcacion), Registrar marca faltante, Exportar a Excel.
--   * Historial del trabajador (sp_ObtenerHistorialConEstados v2).
--
-- Cambios v3 (reemplaza a v2):
--   La persona elige ENTRADA o SALIDA en la pantalla (con foto y GPS),
--   asi que cada marca vale como lo que eligio. Las casillas se llenan
--   POR ORDEN, no por la hora:
--     * Ya no hay filtro de "doble clic": ninguna marca se descarta.
--     * Ya no se decide mañana/tarde por la hora de cada marca.
--
-- Regla (cada dia empieza de cero):
--   1. Marcas del dia ordenadas por hora.
--   2. Inicio del dia: si la PRIMERA ENTRADA es posterior a la hora de
--      corte, el dia empieza en la tarde (E2); si no, en la mañana (E1).
--      Hora de corte = salida de la mañana del horario de ese dia.
--        - Horario sin turno mañana => el dia empieza en la tarde.
--        - Sin horario ese dia      => corte 14:00.
--   3. ENTRADAS por orden: la 1.a va a la casilla de inicio, la 2.a a la
--      siguiente. Las que no caben quedan como EXTRA.
--   4. SALIDAS por orden: la 1.a cierra el turno de inicio, la 2.a el
--      siguiente. Si hay mas salidas que turnos, la SALIDA FINAL del dia
--      es la ultima que marco (las intermedias quedan como EXTRA).
--      Si el dia empieza en la tarde, una salida marcada antes de la
--      primera entrada se toma como salida de la mañana (S1).
--   5. Dia sin ninguna entrada: las salidas van por orden desde S1.
--
-- Columnas: las mismas de v2 (los SP y la app no cambian) mas el
-- horario del dia (he1, hs1, he2, hs2), que usa el historial.
--   turno         1 = mañana, 2 = tarde (NULL si la marca no cabe)
--   casilla       'E1','S1','E2','S2'; NULL = no se usa
--   estado_marca  'USADA' | 'EXTRA'
--
-- Horario del dia: el vigente en esa fecha; si hubiera dos vigentes
-- (dia de cambio de horario), se usa el mas reciente.
--
-- Para revertir: volver a aplicar app/sql/vw_casillas_marcacion_v2.sql
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
           -- Paso 2: hora de corte
           CASE
               WHEN hd.he1 IS NULL AND hd.he2 IS NULL THEN CAST('14:00:00' AS TIME)
               WHEN hd.he1 IS NULL OR hd.hs1 IS NULL  THEN CAST('00:00:00' AS TIME)
               ELSE hd.hs1
           END AS corte,
           MIN(CASE WHEN m.tipo_marcacion = 'ENTRADA' THEN m.fecha_marcacion END)
               OVER (PARTITION BY m.num_documento, DATE(m.fecha_marcacion)) AS primera_ent
    FROM TblMarcacion m
    JOIN horario_dia hd
      ON hd.num_documento = m.num_documento
     AND hd.fecha = DATE(m.fecha_marcacion)
     AND hd.rn = 1
),
con_inicio AS (
    SELECT mk.*,
           CASE WHEN mk.primera_ent IS NOT NULL AND TIME(mk.primera_ent) > mk.corte
                THEN 2 ELSE 1 END AS inicio,
           CASE WHEN mk.tipo_marcacion = 'SALIDA' AND mk.primera_ent IS NOT NULL
                     AND mk.fecha_marcacion < mk.primera_ent
                THEN 1 ELSE 0 END AS antes_ent
    FROM marcas mk
),
numerada AS (
    SELECT c.*,
           ROW_NUMBER() OVER (
               PARTITION BY c.num_documento, c.fecha, c.tipo_marcacion
               ORDER BY c.fecha_marcacion, c.id_marcacion
           ) AS n_tipo,
           ROW_NUMBER() OVER (
               PARTITION BY c.num_documento, c.fecha, c.tipo_marcacion, c.antes_ent
               ORDER BY c.fecha_marcacion, c.id_marcacion
           ) AS n_grupo
    FROM con_inicio c
),
con_slot AS (
    SELECT n.*,
           CASE
               -- Paso 3: entradas por orden desde la casilla de inicio
               WHEN n.tipo_marcacion = 'ENTRADA' THEN n.inicio + n.n_tipo - 1
               -- Paso 4: salidas por orden; la ultima ocupa la salida final (2)
               WHEN n.inicio = 1    THEN LEAST(n.n_tipo, 2)
               WHEN n.antes_ent = 1 THEN LEAST(n.n_grupo, 2)
               ELSE 2
           END AS slot
    FROM numerada n
),
ranking AS (
    SELECT s.*,
           ROW_NUMBER() OVER (
               PARTITION BY s.num_documento, s.fecha, s.tipo_marcacion, s.slot
               ORDER BY CASE WHEN s.tipo_marcacion = 'SALIDA' AND s.slot = 2
                             THEN -TIME_TO_SEC(s.hora) ELSE TIME_TO_SEC(s.hora) END,
                        s.id_marcacion
           ) AS rn
    FROM con_slot s
)
SELECT r.id_marcacion, r.num_documento, r.fecha, r.hora, r.fecha_marcacion,
       r.tipo_marcacion, r.tipo_ubicacion, r.justificacion,
       CASE WHEN r.slot <= 2 THEN r.slot END AS turno,
       CAST(CASE WHEN r.slot <= 2 AND r.rn = 1
                 THEN CONCAT(CASE WHEN r.tipo_marcacion = 'ENTRADA' THEN 'E' ELSE 'S' END, r.slot)
            END AS CHAR(2)) COLLATE utf8mb4_unicode_ci AS casilla,
       CAST(CASE WHEN r.slot <= 2 AND r.rn = 1 THEN 'USADA' ELSE 'EXTRA' END
            AS CHAR(10)) COLLATE utf8mb4_unicode_ci AS estado_marca,
       r.he1, r.hs1, r.he2, r.hs2
FROM ranking r;
