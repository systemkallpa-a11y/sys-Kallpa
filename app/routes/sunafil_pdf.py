"""
Module: sunafil_pdf.py
Propsito: Exportar PDF SUNAFIL desde la plantilla HTML plantillaSunafil.html
          con datos reales (empresa + SP de asistencia + horarios)
Fecha: 07 Octubre 2026
"""

from flask import Blueprint, request
from functools import wraps
from datetime import datetime
import base64
import io
import os

import mysql.connector
from mysql.connector import Error
from jinja2 import Template

from app.config import DatabaseConfig

try:
    from xhtml2pdf import pisa
    XHTML2PDF_AVAILABLE = True
except ImportError:
    XHTML2PDF_AVAILABLE = False
    print("[!] Warning: xhtml2pdf no disponible - la exportacin SUNAFIL no funcionar")

# Blueprint
sunafil_pdf_bp = Blueprint('sunafil_pdf', __name__)

# Ruta de la plantilla: app/platillas de documento/plantillaSunafil.html
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLANTILLA_SUNAFIL = os.path.join(BASE_DIR, 'platillas de documento', 'plantillaSunafil.html')

FILAS_POR_PAGINA = 20


def login_required(f):
    """Decorador para proteger rutas que requieren autenticacin"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        from flask import session, redirect, url_for, flash
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesin', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


def get_db_connection():
    """Crear conexin a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        return mysql.connector.connect(**params)
    except Error as e:
        print(f"[SUNAFIL_PDF] [X] Error de conexin: {e}")
        return None


def _cargar_plantilla():
    """Leer la plantilla HTML de SUNAFIL"""
    with open(PLANTILLA_SUNAFIL, 'r', encoding='utf-8') as f:
        return f.read()


def _a_segundos(valor):
    """'04:31:19' | '04:31' | '-' | None -> segundos (0 si no hay dato)"""
    if not valor:
        return 0
    partes = str(valor).strip().split(':')
    if len(partes) < 2:
        return 0
    try:
        horas = int(partes[0])
        minutos = int(partes[1])
        segundos = int(partes[2]) if len(partes) > 2 and partes[2] else 0
        return horas * 3600 + minutos * 60 + segundos
    except ValueError:
        return 0


def _horas_minutos(segundos):
    """Segundos -> 'H:MM' ('' si es cero)"""
    if segundos <= 0:
        return ''
    return '%d:%02d' % (segundos // 3600, (segundos % 3600) // 60)


def _lista_horas(valor):
    """GROUP_CONCAT '08:30:55, 09:01:02' -> lista de horas validas"""
    if not valor:
        return []
    horas = []
    for parte in str(valor).split(','):
        parte = parte.strip()
        if parte and parte != '-' and len(parte.split(':')) >= 2:
            horas.append(parte)
    return horas


def _sin_segundos(valor):
    """'08:30:55' -> '08:30' (formato del registro SUNAFIL)"""
    return str(valor)[:5] if valor else ''


def _fila_vacia(nro):
    """Fila de relleno para completar la hoja de 20 registros"""
    return {
        'nro': nro,
        'dni': '',
        'nombre': '',
        'cargo': '',
        'ingreso': '',
        'ref_inicio': '',
        'ref_fin': '',
        'salida': '',
        'extras': '',
    }


def _construir_fila(registro, nro, horario):
    """Armado de 1 fila del registro SUNAFIL a partir del SP + horario"""
    entradas = []
    salidas = []
    for campo in ('H_ENTRADA_OFI_T1', 'H_ENTRADA_CMP_T1', 'H_ENTRADA_OFI_T2', 'H_ENTRADA_CMP_T2'):
        entradas.extend(_lista_horas(registro.get(campo)))
    for campo in ('H_SALIDA_OFI_T1', 'H_SALIDA_CMP_T1', 'H_SALIDA_OFI_T2', 'H_SALIDA_CMP_T2'):
        salidas.extend(_lista_horas(registro.get(campo)))

    # Inicio de refrigerio: ultima salida del turno 1
    salidas_t1 = []
    for campo in ('H_SALIDA_OFI_T1', 'H_SALIDA_CMP_T1'):
        salidas_t1.extend(_lista_horas(registro.get(campo)))
    # Fin de refrigerio: primera entrada del turno 2
    entradas_t2 = []
    for campo in ('H_ENTRADA_OFI_T2', 'H_ENTRADA_CMP_T2'):
        entradas_t2.extend(_lista_horas(registro.get(campo)))

    trabajadas = (_a_segundos(registro.get('HORAS_LABORADAS_T1'))
                  + _a_segundos(registro.get('HORAS_LABORADAS_T2')))

    jornada = 0
    if horario:
        jornada = horario['jornada']

    extras_seg = trabajadas - jornada if jornada > 0 else 0

    return {
        'nro': nro,
        'dni': str(registro.get('DNI_CE') or ''),
        'nombre': str(registro.get('NOMBRES') or ''),
        'cargo': str(registro.get('CARGO') or ''),
        'ingreso': _sin_segundos(min(entradas)) if entradas else '',
        'ref_inicio': _sin_segundos(max(salidas_t1)) if (salidas_t1 and entradas_t2) else '',
        'ref_fin': _sin_segundos(min(entradas_t2)) if (salidas_t1 and entradas_t2) else '',
        'salida': _sin_segundos(max(salidas)) if salidas else '',
        'extras': '0' if extras_seg <= 0 else _horas_minutos(extras_seg),
    }


def _paginar(filas):
    """Divide las filas en hojas de 20 registros (rellena con filas vacias)"""
    total = len(filas)
    paginas = []
    for inicio in range(0, max(total, 1), FILAS_POR_PAGINA):
        pagina = []
        for posicion in range(FILAS_POR_PAGINA):
            indice = inicio + posicion
            if indice < total:
                pagina.append(filas[indice])
            else:
                pagina.append(_fila_vacia(indice + 1))
        paginas.append(pagina)
    return paginas


def _fecha_legible(fecha_inicio, fecha_fin):
    if fecha_inicio == fecha_fin:
        return fecha_inicio.strftime('%d/%m/%Y')
    return '%s al %s' % (fecha_inicio.strftime('%d/%m/%Y'), fecha_fin.strftime('%d/%m/%Y'))


# ============================================================================
# LOGO DE LA EMPRESA (TblEmpresa.logo) PARA EL ENCABEZADO DEL PDF
# ============================================================================

PNG_FIRMA = b'\x89PNG\r\n\x1a\n'


def _detectar_imagen(datos):
    """Devuelve el MIME de un BLOB de imagen o None si no se reconoce."""
    if datos[:8] == PNG_FIRMA:
        return 'image/png'
    if datos[:3] == b'\xff\xd8\xff':
        return 'image/jpeg'
    if datos[:6] in (b'GIF87a', b'GIF89a'):
        return 'image/gif'
    return None


def _reparar_logo_cp850(datos):
    """Algunos logos quedaron guardados como texto cp850 re-codificado a UTF-8
    (el PNG 89 50 4E 47... aparece como c3 ab 50 4e 47...). Se revierte."""
    tabla = {}
    for byte in range(256):
        tabla[bytes([byte]).decode('cp850')] = byte
    reparado = bytearray()
    for caracter in datos.decode('utf-8'):
        if caracter not in tabla:
            return None
        reparado.append(tabla[caracter])
    return bytes(reparado)


def _logo_data_uri(logo):
    """BLOB del logo -> 'data:image/png;base64,...' (vacio si no hay logo)."""
    if not logo:
        return ''
    datos = bytes(logo)
    mime = _detectar_imagen(datos)
    if mime is None:
        try:
            datos = _reparar_logo_cp850(datos)
        except Exception:
            datos = None
        mime = _detectar_imagen(datos) if datos else None
    if mime is None:
        print('[SUNAFIL_PDF] [!] Logo de empresa no reconocido, se omite del encabezado')
        return ''
    return 'data:%s;base64,%s' % (mime, base64.b64encode(datos).decode('ascii'))


# ============================================================================
# RUTA: PDF SUNAFIL - REGISTRO DE CONTROL DE ASISTENCIA Y DE SALIDA
# ============================================================================

@sunafil_pdf_bp.route('/api/reportes/sunafil-pdf', methods=['GET'])
@login_required
def exportar_sunafil_pdf():
    """Exporta el PDF SUNAFIL con los datos de la empresa elegida"""
    try:
        if not XHTML2PDF_AVAILABLE:
            return 'xhtml2pdf no est disponible en el servidor', 500

        if not os.path.exists(PLANTILLA_SUNAFIL):
            return 'No se encontr la plantilla SUNAFIL', 404

        empresa = (request.args.get('empresa') or '').strip()
        if not empresa:
            return 'Debe seleccionar una empresa para generar el PDF SUNAFIL', 400

        hoy = datetime.now().date()
        try:
            fecha_inicio = datetime.strptime(request.args.get('fecha_inicio') or hoy.strftime('%Y-%m-%d'), '%Y-%m-%d').date()
            fecha_fin = datetime.strptime(request.args.get('fecha_fin') or hoy.strftime('%Y-%m-%d'), '%Y-%m-%d').date()
        except ValueError:
            return 'Fechas invalidas (formato esperado YYYY-MM-DD)', 400

        if fecha_inicio > fecha_fin:
            fecha_inicio, fecha_fin = fecha_fin, fecha_inicio

        connection = get_db_connection()
        if not connection:
            return 'Error de conexion a BD', 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute(
                "SELECT nombre, ruc, logo FROM TblEmpresa WHERE activa = 1 AND nombre = %s",
                (empresa,)
            )
            datos_empresa = cursor.fetchone()
            if not datos_empresa:
                return 'Empresa no encontrada: %s' % empresa, 404

            cursor.callproc('sp_reporte_asistencia_automatica', [
                fecha_inicio.isoformat(),
                fecha_fin.isoformat(),
                None
            ])
            registros = []
            for result in cursor.stored_results():
                registros = result.fetchall()

            registros = [r for r in registros if str(r.get('EMPRESA') or '') == datos_empresa['nombre']]

            cursor.execute("""
                SELECT p.documento_numero,
                       UPPER(h.dia_semana) AS dia_semana,
                       h.hora_entrada, h.hora_salida,
                       h.hora_entrada2, h.hora_salida2
                  FROM TblHorarioTrabajo h
                 INNER JOIN TblPersona p ON p.num_documento = h.num_documento
                 WHERE h.es_activo = 1
            """)
            horarios = {}
            for horario in cursor.fetchall():
                entrada = horario.get('hora_entrada')
                salida = horario.get('hora_salida')
                entrada2 = horario.get('hora_entrada2')
                salida2 = horario.get('hora_salida2')
                jornada = 0
                if entrada is not None and salida is not None:
                    jornada += int((salida - entrada).total_seconds())
                if entrada2 is not None and salida2 is not None:
                    jornada += int((salida2 - entrada2).total_seconds())
                horarios[(str(horario.get('documento_numero') or '').strip(),
                          str(horario.get('dia_semana') or '').strip())] = {'jornada': max(jornada, 0)}

            cursor.close()

            filas = []
            for indice, registro in enumerate(registros, start=1):
                clave = (str(registro.get('DNI_CE') or '').strip(),
                         str(registro.get('DIA_SEMANA') or '').strip().upper())
                filas.append(_construir_fila(registro, indice, horarios.get(clave)))

            print(f"[SUNAFIL_PDF] [OK] empresa={datos_empresa['nombre']} "
                  f"rango={fecha_inicio}..{fecha_fin} filas={len(filas)}")

        except Error as e:
            print(f"[SUNAFIL_PDF] [X] Error SQL: {e}")
            return f'Error al consultar la BD: {e}', 500
        finally:
            if connection.is_connected():
                connection.close()

        contexto = {
            'EMPRESA_RAZON_SOCIAL': datos_empresa['nombre'],
            'EMPRESA_RUC': str(datos_empresa['ruc'] or ''),
            'EMPRESA_LOGO': _logo_data_uri(datos_empresa.get('logo')),
            'FECHA_REGISTRO': _fecha_legible(fecha_inicio, fecha_fin),
            'paginas': _paginar(filas),
        }

        html_render = Template(_cargar_plantilla()).render(**contexto)

        pdf_buffer = io.BytesIO()
        resultado = pisa.CreatePDF(io.StringIO(html_render), dest=pdf_buffer)

        if resultado.err:
            print(f"[SUNAFIL_PDF] [X] Errores al generar PDF: {resultado.err}")
            return 'Error al generar el PDF SUNAFIL', 500

        filename = "Registro_Control_Asistencia_SUNAFIL_%s.pdf" % datos_empresa['nombre'].replace(' ', '_')[:40]
        print(f"[SUNAFIL_PDF] [OK] PDF generado: {filename}")

        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }

    except Exception as e:
        import traceback
        print(f"[SUNAFIL_PDF] [X] Error: {e}")
        print(f"[SUNAFIL_PDF] Traceback: {traceback.format_exc()}")
        return f'Error al generar el PDF SUNAFIL: {e}', 500
