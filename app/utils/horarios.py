"""
Horario vigente por fecha (TblHorarioTrabajo con fecha_vigencia_inicio/fin).

Misma regla que sp_reporte_asistencia_automatica: para una persona y una
fecha vale la fila con es_activo = 1, del mismo día de semana, con
fecha_vigencia_inicio <= fecha y (fecha_vigencia_fin IS NULL o >= fecha).
Si hubiera más de una (solape), se toma la de inicio más reciente, como
el detalle del día en marcacion.py.

Así los exportables evalúan cada día con el horario que tenía ese día y
no con el horario actual.
"""
from collections import defaultdict

# date.weekday(): 0 = lunes ... 6 = domingo (mismos textos que la BD)
DIAS_BD = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO', 'DOMINGO']


def cargar_horarios(cursor):
    """Lee todas las versiones de horario laborable, agrupadas por DNI.

    cursor debe ser dictionary=True. Devuelve {dni: [fila, ...]} donde cada
    fila trae dia, inicio, fin, hora_entrada, hora_salida, hora_entrada2,
    hora_salida2.
    """
    cursor.execute("""
        SELECT p.documento_numero AS dni,
               UPPER(h.dia_semana) AS dia,
               h.fecha_vigencia_inicio AS inicio,
               h.fecha_vigencia_fin AS fin,
               h.hora_entrada, h.hora_salida,
               h.hora_entrada2, h.hora_salida2
          FROM TblHorarioTrabajo h
         INNER JOIN TblPersona p ON p.num_documento = h.num_documento
         WHERE h.es_activo = 1
           AND h.fecha_vigencia_inicio IS NOT NULL
    """)
    por_dni = defaultdict(list)
    for fila in cursor.fetchall():
        por_dni[str(fila['dni'] or '').strip()].append(fila)
    return por_dni


def horario_en_fecha(horarios, dni, fecha):
    """Fila de horario vigente para ese DNI en esa fecha (date), o None."""
    dia = DIAS_BD[fecha.weekday()]
    vigentes = [h for h in horarios.get(str(dni or '').strip(), [])
                if (h['dia'] or '') == dia
                and h['inicio'] <= fecha
                and (h['fin'] is None or h['fin'] >= fecha)]
    if not vigentes:
        return None
    return max(vigentes, key=lambda h: h['inicio'])


def _hhmm(valor):
    if valor is None:
        return None
    if hasattr(valor, 'total_seconds'):
        total = int(valor.total_seconds())
        return f"{total // 3600:02d}:{(total % 3600) // 60:02d}:{total % 60:02d}"
    return str(valor)


def texto_horario(fila):
    """'08:30:00-13:00:00 / 15:00:00-19:00:00' (mismo formato que el CONCAT de MySQL)."""
    if not fila:
        return ''
    texto = f"{_hhmm(fila['hora_entrada'])}-{_hhmm(fila['hora_salida'])}"
    if fila.get('hora_entrada2') is not None:
        texto += f" / {_hhmm(fila['hora_entrada2'])}-{_hhmm(fila['hora_salida2'])}"
    return texto


def horario_del_periodo(horarios, dni, fecha_inicio, fecha_fin):
    """Horario más frecuente del DNI entre los días del rango (texto).

    Recorre cada día del rango con su horario vigente; si hubo un cambio en
    el rango, gana el que rigió más días (empate: el más reciente).
    """
    from datetime import timedelta
    conteo = {}
    ultimo = {}
    dia = fecha_inicio
    orden = 0
    while dia <= fecha_fin:
        fila = horario_en_fecha(horarios, dni, dia)
        if fila:
            texto = texto_horario(fila)
            conteo[texto] = conteo.get(texto, 0) + 1
            ultimo[texto] = orden
        dia += timedelta(days=1)
        orden += 1
    if not conteo:
        return ''
    return max(conteo, key=lambda t: (conteo[t], ultimo[t]))
