"""
Module: memo_pdf.py
Propsito: Generar PDFs de memorandos/amonestaciones
Fecha: 16 Agosto 2026
"""

from flask import Blueprint, jsonify, request
from functools import wraps
import mysql.connector
from mysql.connector import Error

# Importar reportlab
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False
    print("[!] Warning: reportlab not available - PDF generation will not work")

from datetime import datetime
from app.config import DatabaseConfig
import io

# Blueprint
memo_pdf_bp = Blueprint('memo_pdf', __name__)


def get_db_connection():
    """Crear conexin a la base de datos"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"Error de conexin: {e}")
        return None


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


# Textos de amonestacin segn tipo
TEXTOS_MEMO = {
    'TARDANZA': {
        'titulo': 'MEMORANDO DE AMONESTACIN POR TARDANZA',
        'motivo': 'tardanzas reiteradas',
        'descripcion': '''Por medio del presente, se le hace de su conocimiento que ha sido observado(a) llegando tarde a su puesto de trabajo en reiteradas ocasiones, lo cual contraviene las normas laborales establecidas por la empresa y afecta el normal desarrollo de las actividades.

La puntualidad es un valor fundamental en nuestra organizacin y es responsabilidad de cada colaborador cumplir con los horarios establecidos.''',
        'consecuencias': '''De persistir esta conducta, se proceder con las sanciones correspondientes segn el Reglamento Interno de Trabajo, pudiendo llegar hasta la terminacin del contrato laboral.'''
    },
    'FALTA': {
        'titulo': 'MEMORANDO DE AMONESTACIN POR INASISTENCIA',
        'motivo': 'inasistencia injustificada',
        'descripcion': '''Por medio del presente, se le hace de su conocimiento que ha incurrido en inasistencia injustificada a su puesto de trabajo, lo cual constituye una falta grave segn el Reglamento Interno de Trabajo y las disposiciones laborales vigentes.

La asistencia regular es esencial para el cumplimiento de sus responsabilidades y el funcionamiento adecuado de la empresa.''',
        'consecuencias': '''De reincidir en esta conducta, se proceder con la aplicacin de sanciones progresivas, pudiendo llegar hasta la suspensin o trmino de su contrato laboral, segn corresponda.'''
    },
    'UNIFORME': {
        'titulo': 'MEMORANDO DE AMONESTACIN POR INCUMPLIMIENTO DE NORMAS DE PRESENTACIN',
        'motivo': 'no portar el uniforme reglamentario',
        'descripcion': '''Por medio del presente, se le hace de su conocimiento que ha sido observado(a) asistiendo a su puesto de trabajo sin portar el uniforme reglamentario de la empresa o presentando una imagen personal que no se ajusta a las normas establecidas.

El uso del uniforme es obligatorio para todos los colaboradores y forma parte de la imagen corporativa de nuestra organizacin.''',
        'consecuencias': '''De persistir en el incumplimiento de esta disposicin, se aplicarn las sanciones correspondientes segn el Reglamento Interno de Trabajo, pudiendo escalar a medidas disciplinarias ms severas.'''
    }
}


@memo_pdf_bp.route('/api/marcacion/tipos-memo', methods=['GET'])
@login_required
def obtener_tipos_memo():
    """Obtener todos los tipos de memo activos"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin a BD'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Obtener tipos de memo activos
        query = """
            SELECT 
                id_tipo_memo,
                codigo,
                nombre,
                titulo,
                descripcion,
                consecuencias
            FROM TblTipoMemo
            WHERE activo = 1
            ORDER BY codigo
        """
        
        cursor.execute(query)
        tipos = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': tipos}), 200
        
    except Exception as e:
        print(f"[MEMO_PDF] Error al obtener tipos: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@memo_pdf_bp.route('/api/marcacion/generar-memo', methods=['POST'])
@login_required
def generar_memo():
    """Generar PDF de memorando de amonestacin"""
    if not REPORTLAB_AVAILABLE:
        return jsonify({'success': False, 'error': 'reportlab no est disponible'}), 500
    
    try:
        data = request.get_json()
        
        num_documento = data.get('num_documento')
        nombre_completo = data.get('nombre_completo')
        email = data.get('email')
        tipo_memo = data.get('tipo_memo')  # TARDANZA, FALTA, UNIFORME
        fecha_incidente = data.get('fecha_incidente')  # Fecha del incidente
        
        # Validar datos requeridos
        if not num_documento or not tipo_memo or not fecha_incidente:
            print(f"[MEMO_PDF] [X] Faltan datos: num_documento={num_documento}, tipo_memo={tipo_memo}, fecha_incidente={fecha_incidente}")
            return jsonify({'success': False, 'error': 'Faltan datos requeridos'}), 400
        
        # Convertir num_documento a INT
        try:
            num_documento = int(num_documento)
        except (ValueError, TypeError):
            print(f"[MEMO_PDF] [X] num_documento invlido: {num_documento}")
            return jsonify({'success': False, 'error': 'Nmero de documento invlido'}), 400
        
        # Validar tipo de memo
        if not tipo_memo:
            print(f"[MEMO_PDF] [X] Tipo invlido: {tipo_memo}")
            return jsonify({'success': False, 'error': f'Tipo de memo invlido'}), 400
        
        print(f"[MEMO_PDF] Generando memo {tipo_memo} para {nombre_completo} ({num_documento})")
        
        # Obtener datos del empleado y tipo de memo usando SPs
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin a BD'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # 1. Obtener datos del empleado
            cursor.callproc('sp_ObtenerDatosEmpleadoMemo', [num_documento])
            
            empleado = None
            for result in cursor.stored_results():
                empleado = result.fetchone()
                break
            
            if not empleado:
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': 'Empleado no encontrado'}), 404
            
            # 2. Obtener tipo de memo directamente de la tabla
            query_tipo = """
                SELECT id_tipo_memo, codigo, nombre, titulo, descripcion, consecuencias
                FROM TblTipoMemo
                WHERE codigo = %s AND activo = 1
                LIMIT 1
            """
            cursor.execute(query_tipo, (tipo_memo,))
            tipo_memo_data = cursor.fetchone()
            
            if not tipo_memo_data:
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': f'Tipo de memo "{tipo_memo}" no encontrado'}), 404
                
        except Exception as e:
            print(f"[MEMO_PDF] Error al ejecutar consultas: {e}")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': f'Error al obtener datos: {str(e)}'}), 500
        
        finally:
            cursor.close()
            connection.close()
        
        # Obtener datos de la empresa (RUC y logo)
        empresa_nombre = empleado.get('empresa', '')
        empresa_ruc = ''
        empresa_logo_bytes = None
        empresa_id = None
        
        try:
            conn_empresa = get_db_connection()
            if conn_empresa:
                cur_empresa = conn_empresa.cursor(dictionary=True)
                cur_empresa.execute('SELECT id_empresa, nombre, ruc, logo FROM TblEmpresa WHERE nombre = %s LIMIT 1', (empresa_nombre,))
                emp_data = cur_empresa.fetchone()
                if emp_data:
                    empresa_id = emp_data['id_empresa']
                    empresa_ruc = emp_data['ruc'] or ''
                    empresa_logo_bytes = emp_data['logo']
                cur_empresa.close()
                conn_empresa.close()
        except Exception as e:
            print(f"[MEMO_PDF] [!] Error al obtener datos de empresa: {e}")
        
        # Convertir fecha_incidente a formato legible
        from datetime import datetime as dt
        fecha_obj = dt.strptime(fecha_incidente, '%Y-%m-%d')
        fecha_formateada = fecha_obj.strftime('%d de %B de %Y')
        mes_espanol = fecha_obj.strftime('%B')
        meses_espanol = {
            'January': 'enero', 'February': 'febrero', 'March': 'marzo',
            'April': 'abril', 'May': 'mayo', 'June': 'junio',
            'July': 'julio', 'August': 'agosto', 'September': 'septiembre',
            'October': 'octubre', 'November': 'noviembre', 'December': 'diciembre'
        }
        for ing, esp in meses_espanol.items():
            fecha_formateada = fecha_formateada.replace(ing, esp)
        
        # Obtener nombre del firmante (Gerente de RRHH de la empresa)
        nombre_firmante = 'GERENCIA DE RECURSOS HUMANOS'
        try:
            conn_firm = get_db_connection()
            if conn_firm:
                cur_firm = conn_firm.cursor(dictionary=True)
                cur_firm.execute('''
                    SELECT CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', IFNULL(p.apellido_materno, '')) AS nombre_completo
                    FROM TblUsuario u
                    JOIN TblPersona p ON u.num_documento = p.num_documento
                    JOIN TblCargo c ON u.id_cargo = c.id_cargo
                    WHERE c.nombre LIKE '%Gerente%RRHH%' OR c.nombre LIKE '%Gerente%Recursos%'
                    LIMIT 1
                ''')
                firm = cur_firm.fetchone()
                if firm:
                    nombre_firmante = firm['nombre_completo'].upper()
                cur_firm.close()
                conn_firm.close()
        except Exception as e:
            print(f"[MEMO_PDF] [!] Error al obtener firmante: {e}")
        
        nombre_completo_bd = empleado.get('nombre_completo', nombre_completo)
        cargo_empleado = empleado.get('cargo', 'N/A')
        
        # Generar PDF
        pdf_buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            pdf_buffer,
            pagesize=letter,
            rightMargin=0.6*inch,
            leftMargin=0.6*inch,
            topMargin=0.5*inch,
            bottomMargin=0.5*inch
        )
        
        story = []
        styles = getSampleStyleSheet()
        
        # Estilos personalizados - formato exacto de las plantillas
        header_style = ParagraphStyle(
            'MemoHeader',
            parent=styles['Normal'],
            fontSize=13,
            fontName='Helvetica-Bold',
            alignment=TA_CENTER,
            spaceAfter=6,
            spaceBefore=0,
            underline=True
        )
        
        field_label_style = ParagraphStyle(
            'FieldLabel',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=11,
            leading=14
        )
        
        field_value_style = ParagraphStyle(
            'FieldValue',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=11,
            leading=14
        )
        
        body_style = ParagraphStyle(
            'Body',
            parent=styles['Normal'],
            fontSize=11,
            alignment=TA_JUSTIFY,
            leading=14,
            spaceBefore=2,
            spaceAfter=2
        )
        
        # ========== OBTENER NÚMERO SECUENCIAL DEL MEMO ==========
        num_secuencial = 1
        try:
            conn_num = get_db_connection()
            if conn_num:
                cur_num = conn_num.cursor(dictionary=True)
                # Obtener el último número de memo del año actual
                from datetime import datetime as _dt
                anio_actual = _dt.now().year
                cur_num.execute('''
                    SELECT COUNT(*) as total FROM TblMemo 
                    WHERE YEAR(fecha_generacion) = %s
                ''', (anio_actual,))
                result = cur_num.fetchone()
                if result:
                    num_secuencial = result['total'] + 1
                cur_num.close()
                conn_num.close()
        except Exception as e:
            print(f"[MEMO_PDF] [!] Error al obtener número secuencial: {e}")
        
        num_memorando = f"{num_secuencial:03d}"
        
        # ========== ENCABEZADO ==========
        empresa_code = empresa_nombre.upper().replace(' ', '').replace('.', '').replace(',', '')[:20]
        header_text = f"MEMORANDUM N\u00b0 {num_memorando} - 2026-{empresa_code}"
        header_style2 = ParagraphStyle(
            'MemoHeader2',
            parent=header_style,
            underline=True
        )
        story.append(Paragraph(f"<u>{header_text}</u>", header_style2))
        story.append(Spacer(1, 0.15*inch))
        
        # ========== CAMPOS DEL MEMO (sin tabla, formato libre) ==========
        # PARA        : [Nombre]
        story.append(Paragraph(f"<b>PARA</b>\t\t\t: {nombre_completo_bd}", field_label_style))
        # CARGO       : [Cargo]
        story.append(Paragraph(f"<b>CARGO</b>\t\t\t: {cargo_empleado}", field_label_style))
        # DE          : [Empresa]
        story.append(Paragraph(f"<b>DE</b>\t\t\t: {empresa_nombre}", field_label_style))
        # ASUNTO      : [Tipo]
        asunto_texto = tipo_memo_data['nombre']
        story.append(Paragraph(f"<b>ASUNTO</b>\t\t\t: {asunto_texto}", field_label_style))
        # FECHA       : [Fecha]
        story.append(Paragraph(f"<b>FECHA</b>\t\t\t: {fecha_formateada}", field_label_style))
        story.append(Spacer(1, 0.1*inch))
        
        # ========== CUERPO DEL MEMO (texto de las plantillas) ==========
        story.append(Paragraph("De nuestra consideraci\u00f3n:", body_style))
        story.append(Spacer(1, 0.03*inch))
        
        # Texto espec\u00edfico seg\u00fan tipo de memo
        if tipo_memo == 'TARDANZA':
            # Obtener datos reales de horario y marcaci\u00f3n
            hora_ingreso_real = None
            hora_horario_prog = None
            minutos_tardanza = None
            
            try:
                conn_marc = get_db_connection()
                if conn_marc:
                    cur_marc = conn_marc.cursor(dictionary=True)
                    
                    # 1. Obtener hora de entrada real del empleado en esa fecha
                    cur_marc.execute('''
                        SELECT hora_marcacion FROM tbl_marcaciones 
                        WHERE num_documento = %s AND tipo_marcacion = 'ENTRADA' 
                        AND DATE(fecha_marcacion) = %s 
                        LIMIT 1
                    ''', (num_documento, fecha_incidente))
                    marc = cur_marc.fetchone()
                    if marc and marc.get('hora_marcacion'):
                        hora_ingreso_real = marc['hora_marcacion']
                    
                    # 2. Obtener horario programado del empleado para ese d\u00eda de la semana
                    from datetime import datetime as dt
                    fecha_obj_temp = dt.strptime(fecha_incidente, '%Y-%m-%d')
                    dias_semana = ['LUNES','MARTES','MI\u00c9RCOLES','JUEVES','VIERNES','S\u00c1BADO','DOMINGO']
                    dia_semana = dias_semana[fecha_obj_temp.weekday()]
                    
                    cur_marc.execute('''
                        SELECT hora_entrada FROM TblHorarioTrabajo 
                        WHERE num_documento = %s AND dia_semana = %s AND es_activo = 1
                        LIMIT 1
                    ''', (num_documento, dia_semana))
                    horario = cur_marc.fetchone()
                    if horario and horario.get('hora_entrada'):
                        hora_horario_prog = horario['hora_entrada']
                    
                    cur_marc.close()
                    conn_marc.close()
                    
                    # 3. Calcular minutos de tardanza si tenemos ambos datos
                    if hora_ingreso_real and hora_horario_prog:
                        from datetime import timedelta
                        tolerancia = timedelta(minutes=5)
                        diff = (hora_ingreso_real - hora_horario_prog) - tolerancia
                        if diff.total_seconds() > 0:
                            minutos_tardanza = int(diff.total_seconds() / 60)
                        else:
                            minutos_tardanza = 0
            except Exception as e:
                print(f"[MEMO_PDF] [!] Error al obtener datos de marcaci\u00f3n: {e}")
            
            # Formatear horas para el texto
            if hora_ingreso_real:
                h_real = str(hora_ingreso_real)[:5]
            else:
                h_real = 'N/D'
            
            if hora_horario_prog:
                # Convertir timedelta a hora legible
                total_seg = int(hora_horario_prog.total_seconds())
                h_prog = f"{total_seg // 3600:02d}:{(total_seg % 3600) // 60:02d}"
                h_prog_legible = f"{total_seg // 3600}:" + f"{(total_seg % 3600) // 60:02d}".replace(':00','') + " a. m." if total_seg // 3600 < 12 else f"{total_seg // 3600 - 12}:" + f"{(total_seg % 3600) // 60:02d}".replace(':00','') + " p. m."
                # Simplificar a formato legible
                h_horas = total_seg // 3600
                h_min = (total_seg % 3600) // 60
                if h_horas < 12:
                    h_prog_legible = f"{h_horas}:{h_min:02d} a. m."
                elif h_horas == 12:
                    h_prog_legible = f"12:{h_min:02d} p. m."
                else:
                    h_prog_legible = f"{h_horas - 12}:{h_min:02d} p. m."
                
                # Hora l\u00edmite de tolerancia (programada + 5 min)
                h_limite_total = total_seg + 300  # 5 min en segundos
                h_lim_h = h_limite_total // 3600
                h_lim_m = (h_limite_total % 3600) // 60
                if h_lim_h < 12:
                    hora_tolerancia = f"{h_lim_h}:{h_lim_m:02d} a. m."
                elif h_lim_h == 12:
                    hora_tolerancia = f"12:{h_lim_m:02d} p. m."
                else:
                    hora_tolerancia = f"{h_lim_h - 12}:{h_lim_m:02d} p. m."
            else:
                h_prog_legible = 'N/D'
                hora_tolerancia = 'N/D'
            
            body_text = (
                f"Por medio del presente, se deja constancia que el d\u00eda <b>{fecha_formateada}</b>, "
                f"usted registr\u00f3 su ingreso a las <b>{h_real}</b>."
            )
            story.append(Paragraph(body_text, body_style))
            
            body_text2 = (
                f"Se recuerda que el horario establecido de ingreso a labores es a las <b>{h_prog_legible}</b>, "
                f"contando el personal con una <b>tolerancia m\u00e1xima de cinco (05) minutos</b>, "
                f"hasta las <b>{hora_tolerancia}</b>. En consecuencia, "
                f"<b>todo ingreso registrado a partir de las {hora_tolerancia} ser\u00e1 considerado tardanza</b>."
            )
            story.append(Paragraph(body_text2, body_style))
            
            min_texto = str(minutos_tardanza) if minutos_tardanza is not None else 'N/D'
            body_text3 = (
                f"En el presente caso, usted registr\u00f3 una tardanza de <b>{min_texto} minutos</b>, "
                f"incumpliendo con las disposiciones internas relacionadas con el horario, puntualidad y asistencia del personal."
            )
            story.append(Paragraph(body_text3, body_style))
            
            story.append(Paragraph(
                "La puntualidad constituye una obligaci\u00f3n del trabajador y resulta necesaria para garantizar "
                "el normal desarrollo, coordinaci\u00f3n y organizaci\u00f3n de las actividades de la empresa.",
                body_style))
            
            story.append(Paragraph(
                f"En ese sentido, la conducta se\u00f1alada constituye un <b>cumplimiento de las disposiciones establecidas "
                f"en el Reglamento Interno de Trabajo y de las normas internas de {empresa_nombre}</b> "
                f"relacionadas con el horario, puntualidad y asistencia del personal.",
                body_style))
            
            story.append(Paragraph(
                f"Por lo expuesto, mediante el presente se le <b>exhorta a cumplir estrictamente con el horario de "
                f"ingreso establecido</b>, adoptando las medidas necesarias para evitar que esta situaci\u00f3n vuelva a "
                f"repetirse.",
                body_style))
            
            story.append(Paragraph(
                f"Asimismo, se deja constancia de que la <b>reiteraci\u00f3n de tardanzas podr\u00e1 dar lugar a la "
                f"aplicaci\u00f3n de las medidas disciplinarias correspondientes</b>, de conformidad con el Reglamento "
                f"Interno de Trabajo y las disposiciones laborales aplicables.",
                body_style))
            
            story.append(Paragraph(
                "Sin otro particular, esperamos el cumplimiento de las disposiciones se\u00f1aladas.",
                body_style))
        
        elif tipo_memo == 'INASISTENCIA':
            body_text = (
                f"Por medio del presente, se deja constancia que el d\u00eda <b>{fecha_formateada}</b>, "
                f"usted no se present\u00f3 a cumplir con su jornada laboral, sin haber comunicado oportunamente "
                f"su ausencia a la Gerencia y/o a su jefe inmediato."
            )
            story.append(Paragraph(body_text, body_style))
            
            story.append(Paragraph(
                "Se recuerda que todo trabajador tiene la obligaci\u00f3n de cumplir con su jornada laboral y asistir "
                "regularmente a su centro de trabajo. En caso de presentarse alguna circunstancia que imposibilite "
                "su asistencia, deber\u00e1 comunicar oportunamente a la empresa y presentar la justificaci\u00f3n "
                "o documentaci\u00f3n correspondiente.",
                body_style))
            
            story.append(Paragraph(
                "La falta de comunicaci\u00f3n respecto de una inasistencia afecta directamente la organizaci\u00f3n "
                "de las actividades, la distribuci\u00f3n de funciones y el normal desarrollo de las operaciones de "
                "la empresa.",
                body_style))
            
            story.append(Paragraph(
                f"En ese sentido, la conducta se\u00f1alada constituye un incumplimiento de las disposiciones establecidas "
                f"en el Reglamento Interno de Trabajo y de las normas internas de <b>{empresa_nombre}</b> "
                f"relacionadas con la asistencia, responsabilidad y comunicaci\u00f3n del personal.",
                body_style))
            
            story.append(Paragraph(
                f"Por lo expuesto, mediante el presente se le <b>exhorta a cumplir con su jornada laboral y a "
                f"comunicar oportunamente cualquier situaci\u00f3n que le impida asistir a sus labores</b>, "
                f"utilizando los canales establecidos por la empresa.",
                body_style))
            
            story.append(Paragraph(
                f"Asimismo, se deja constancia de que la reiteraci\u00f3n de esta conducta y/o el incumplimiento "
                f"reiterado de las disposiciones establecidas en el Reglamento Interno de Trabajo podr\u00e1 dar lugar "
                f"a la aplicaci\u00f3n de medidas disciplinarias de mayor gravedad, incluida la suspensi\u00f3n y, "
                f"de configurarse una falta grave conforme a la normativa laboral vigente, el despido.",
                body_style))
            
            story.append(Paragraph(
                "Sin otro particular, esperamos el cumplimiento de las disposiciones se\u00f1aladas.",
                body_style))
        
        elif tipo_memo == 'UNIFORME':
            body_text = (
                f"Por medio del presente, se deja constancia que el d\u00eda <b>{fecha_formateada}</b> "
                f"usted se present\u00f3 a laborar sin cumplir con la uniformidad establecida por la empresa."
            )
            story.append(Paragraph(body_text, body_style))
            
            story.append(Paragraph(
                "Se recuerda que el uso correcto del uniforme y la adecuada presentaci\u00f3n personal constituyen "
                "disposiciones internas de cumplimiento obligatorio durante la jornada laboral.",
                body_style))
            
            story.append(Paragraph(
                "La uniformidad establecida por la empresa es la siguiente:",
                body_style))
            
            # Lista de uniformes (con vi\u00f1etas)
            bullet_style = ParagraphStyle(
                'Bullet',
                parent=body_style,
                leftIndent=20,
                bulletIndent=5,
                spaceBefore=4,
                spaceAfter=4
            )
            
            story.append(Paragraph(
                "\u2022  De lunes a jueves: casaca verde institucional, camisa blanca, zapato de vestir negro y fotocheck.",
                bullet_style))
            
            story.append(Paragraph(
                "\u2022  Viernes, s\u00e1bado y domingo: buzo institucional de la empresa con zapatillas de color "
                "blanco o negro y fotocheck.",
                bullet_style))
            
            story.append(Paragraph(
                "\u2022  En caso de utilizar prendas adicionales, estas deber\u00e1n ser \u00fanicamente de color negro, "
                "a fin de mantener la uniformidad e imagen institucional.",
                bullet_style))
            
            story.append(Paragraph(
                "El incumplimiento de estas disposiciones constituye una falta a las normas internas y al "
                "Reglamento Interno de Trabajo.",
                body_style))
            
            story.append(Paragraph(
                f"Por lo expuesto, se le exhorta a cumplir correctamente con la uniformidad establecida. "
                f"Asimismo, se deja constancia de que la reiteraci\u00f3n de esta conducta y/o el incumplimiento "
                f"reiterado de las disposiciones internas podr\u00e1 dar lugar a la aplicaci\u00f3n de medidas "
                f"disciplinarias de mayor gravedad, incluida la suspensi\u00f3n y, de configurarse una falta grave "
                f"conforme a la normativa laboral vigente, el despido.",
                body_style))
            
            story.append(Paragraph(
                "Sin otro particular, esperamos el cumplimiento de las disposiciones se\u00f1aladas.",
                body_style))
        
        story.append(Spacer(1, 0.08*inch))
        
        # ========== FIRMA ==========
        story.append(Paragraph("Atentamente,", body_style))
        story.append(Spacer(1, 0.2*inch))
        
        # Logo de empresa como sello (si existe) - mantener proporcionales
        if empresa_logo_bytes:
            try:
                from reportlab.platypus import Image as RLImage
                from io import BytesIO
                
                logo_buffer = BytesIO(empresa_logo_bytes)
                logo_img = RLImage(logo_buffer)
                # Mantener proporcion: usar solo ancho max, altura se calcula solas
                logo_max_width = 1.6*inch
                logo_max_height = 1.0*inch
                # Calcular escala manteniendo aspect ratio
                ratio = min(logo_max_width / logo_img.drawWidth, logo_max_height / logo_img.drawHeight)
                logo_img.drawWidth = logo_img.drawWidth * ratio
                logo_img.drawHeight = logo_img.drawHeight * ratio
                logo_img.hAlign = 'CENTER'
                story.append(logo_img)
            except Exception as e:
                print(f"[MEMO_PDF] [!] Error al insertar logo: {e}")
                story.append(Spacer(1, 0.15*inch))
        else:
            story.append(Spacer(1, 0.15*inch))
        
        # Imagen de firma y sello (busca en platillas de documento/Firmas/)
        import os as _os
        
        firmas_dir = _os.path.join(_os.path.dirname(_os.path.dirname(__file__)), 'platillas de documento', 'Firmas')
        firma_path = None
        
        if _os.path.exists(firmas_dir):
            # Buscar archivo exacto por nombre de empresa
            for ext in ['.png', '.jpg', '.jpeg']:
                candidato = _os.path.join(firmas_dir, empresa_nombre + ext)
                if _os.path.exists(candidato):
                    firma_path = candidato
                    print(f"[MEMO_PDF] [OK] Firma encontrada: {empresa_nombre}{ext}")
                    break
            
            # Si no encontró exacto, buscar por nombre parcial
            if not firma_path:
                for archivo in _os.listdir(firmas_dir):
                    if archivo.lower().endswith(('.png', '.jpg', '.jpeg')):
                        nombre_arch = archivo.rsplit('.', 1)[0].upper()
                        if empresa_nombre.upper() in nombre_arch or nombre_arch in empresa_nombre.upper():
                            firma_path = _os.path.join(firmas_dir, archivo)
                            print(f"[MEMO_PDF] [OK] Firma encontrada (parcial): {archivo}")
                            break
        
        if firma_path and _os.path.exists(firma_path):
            try:
                from reportlab.platypus import Image as RLImage
                firma_img = RLImage(firma_path)
                # Mantener proporcion: usar solo ancho max, altura se calcula solas
                firma_max_width = 2.2*inch
                firma_max_height = 1.4*inch
                ratio = min(firma_max_width / firma_img.drawWidth, firma_max_height / firma_img.drawHeight)
                firma_img.drawWidth = firma_img.drawWidth * ratio
                firma_img.drawHeight = firma_img.drawHeight * ratio
                firma_img.hAlign = 'CENTER'
                story.append(Spacer(1, 0.05*inch))
                story.append(firma_img)
            except Exception as e:
                print(f"[MEMO_PDF] [!] Error al insertar firma: {e}")
        else:
            print(f"[MEMO_PDF] [!] No se encontr\u00f3 imagen de firma para: {empresa_nombre}")
        
        # Construir PDF
        doc.build(story)
        
        # Preparar nombre del archivo
        pdf_buffer.seek(0)
        filename = f"Memo_{tipo_memo}_{nombre_completo.replace(' ', '_')}_{datetime.now().strftime('%Y%m%d')}.pdf"
        
        # Registrar el memo en la base de datos
        try:
            from flask import session
            user_documento = session.get('user_documento')  # Usuario que gener el memo
            
            print(f"[MEMO_PDF] [...] Registrando memo en BD: num_doc={num_documento}, tipo={tipo_memo}, generado_por={user_documento}, fecha={fecha_incidente}")
            
            connection2 = get_db_connection()
            if connection2:
                cursor2 = connection2.cursor(dictionary=True)
                
                # Llamar al SP para registrar el memo
                cursor2.callproc('sp_RegistrarMemo', [
                    num_documento,           # p_num_documento
                    tipo_memo,               # p_codigo_tipo_memo
                    user_documento,          # p_generado_por
                    filename,                # p_archivo_pdf
                    None,                    # p_observaciones
                    fecha_incidente          # p_fecha_incidente
                ])
                
                # Obtener el ID del memo generado
                id_memo = None
                for result in cursor2.stored_results():
                    row = result.fetchone()
                    if row:
                        id_memo = row.get('id_memo')
                    break
                
                connection2.commit()
                cursor2.close()
                connection2.close()
                
                print(f"[MEMO_PDF] [OK] Memo registrado en BD con ID: {id_memo}")
                
                # Enviar email al empleado con el PDF adjunto
                try:
                    from app.utils.email_sender import enviar_email_con_adjunto, generar_html_memo
                    import os
                    
                    email_empleado = empleado.get('email')
                    if email_empleado:
                        print(f"[MEMO_PDF]  Enviando email a: {email_empleado}")
                        
                        # Generar HTML del email
                        html_email = generar_html_memo(
                            nombre_completo_bd,
                            tipo_memo,
                            fecha_incidente
                        )
                        
                        # Enviar email
                        success, message = enviar_email_con_adjunto(
                            destinatario_email=email_empleado,
                            destinatario_nombre=nombre_completo_bd,
                            asunto=f"Memorando de Amonestacin - {tipo_memo_data['nombre']}",
                            cuerpo_html=html_email,
                            archivo_pdf_bytes=pdf_buffer.getvalue(),
                            nombre_archivo_pdf=filename,
                            smtp_server=os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
                            smtp_port=int(os.getenv('SMTP_PORT', '587')),
                            smtp_user=os.getenv('SMTP_USER'),
                            smtp_password=os.getenv('SMTP_PASSWORD')
                        )
                        
                        if success:
                            print(f"[MEMO_PDF] [OK] Email enviado exitosamente a {email_empleado}")
                        else:
                            print(f"[MEMO_PDF] [!] Error al enviar email: {message}")
                    else:
                        print(f"[MEMO_PDF] [!] El empleado no tiene email registrado")
                        
                except Exception as email_error:
                    import traceback
                    print(f"[MEMO_PDF] [!] Error al enviar email: {email_error}")
                    print(f"[MEMO_PDF] Traceback: {traceback.format_exc()}")
                    # No detener el proceso
            else:
                print(f"[MEMO_PDF] [!] No se pudo registrar el memo en BD (sin conexin)")
                
        except Exception as reg_error:
            import traceback
            print(f"[MEMO_PDF] [!] Error al registrar memo en BD: {reg_error}")
            print(f"[MEMO_PDF] Traceback: {traceback.format_exc()}")
            # No detener el proceso, el PDF ya se gener
        
        # Enviar PDF
        print(f"[MEMO_PDF] [OK] PDF generado exitosamente: {filename}")
        
        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Exception as e:
        import traceback
        print(f"[MEMO_PDF] [X] Error: {e}")
        print(f"[MEMO_PDF] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'error': str(e)}), 500
