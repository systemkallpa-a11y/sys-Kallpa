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
        
        # Generar PDF
        pdf_buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            pdf_buffer,
            pagesize=letter,
            rightMargin=0.75*inch,
            leftMargin=0.75*inch,
            topMargin=0.75*inch,
            bottomMargin=0.75*inch
        )
        
        story = []
        styles = getSampleStyleSheet()
        
        # Estilos personalizados
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=14,
            textColor=colors.HexColor('#c00000'),
            fontName='Helvetica-Bold',
            alignment=TA_CENTER,
            spaceAfter=20,
            spaceBefore=10
        )
        
        bold_style = ParagraphStyle(
            'Bold',
            parent=styles['Normal'],
            fontName='Helvetica-Bold',
            fontSize=11
        )
        
        body_style = ParagraphStyle(
            'Body',
            parent=styles['Normal'],
            fontSize=11,
            alignment=TA_JUSTIFY,
            leading=16
        )
        
        # Obtener textos desde la BD (no del diccionario)
        textos = {
            'titulo': tipo_memo_data['titulo'],
            'motivo': tipo_memo_data['nombre'],
            'descripcion': tipo_memo_data['descripcion'],
            'consecuencias': tipo_memo_data['consecuencias']
        }
        
        # Convertir fecha_incidente a formato legible
        from datetime import datetime as dt
        fecha_obj = dt.strptime(fecha_incidente, '%Y-%m-%d')
        fecha_formateada = fecha_obj.strftime('%d de %B de %Y')
        meses_espanol = {
            'January': 'enero', 'February': 'febrero', 'March': 'marzo',
            'April': 'abril', 'May': 'mayo', 'June': 'junio',
            'July': 'julio', 'August': 'agosto', 'September': 'septiembre',
            'October': 'octubre', 'November': 'noviembre', 'December': 'diciembre'
        }
        for ing, esp in meses_espanol.items():
            fecha_formateada = fecha_formateada.replace(ing, esp)
        
        # ========== ENCABEZADO ==========
        story.append(Paragraph("KALLPA", title_style))
        story.append(Paragraph(textos['titulo'], title_style))
        story.append(Spacer(1, 0.3*inch))
        
        # Fecha del incidente
        fecha_paragraph = Paragraph(f"<b>FECHA DEL INCIDENTE:</b> {fecha_formateada}", bold_style)
        story.append(fecha_paragraph)
        story.append(Spacer(1, 0.2*inch))
        
        # Datos del empleado en tabla
        nombre_completo_bd = empleado.get('nombre_completo', nombre_completo)
        
        datos_empleado = [
            ['DE:', 'Gerencia de Recursos Humanos'],
            ['PARA:', nombre_completo_bd],
            ['CARGO:', empleado.get('cargo', 'N/A')],
            ['REA:', empleado.get('area', 'N/A')],
            ['ASUNTO:', textos['motivo'].upper()]
        ]
        
        table_empleado = Table(datos_empleado, colWidths=[1.5*inch, 5*inch])
        table_empleado.setStyle(TableStyle([
            ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
            ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
            ('FONTSIZE', (0, 0), (-1, -1), 11),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('TOPPADDING', (0, 0), (-1, -1), 4),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ]))
        
        story.append(table_empleado)
        story.append(Spacer(1, 0.3*inch))
        
        # ========== CUERPO DEL MEMO ==========
        story.append(Paragraph("<b>Estimado(a) colaborador(a):</b>", body_style))
        story.append(Spacer(1, 0.1*inch))
        
        story.append(Paragraph(textos['descripcion'], body_style))
        story.append(Spacer(1, 0.15*inch))
        
        # Consecuencias
        story.append(Paragraph("<b>ADVERTENCIA:</b>", bold_style))
        story.append(Spacer(1, 0.05*inch))
        story.append(Paragraph(textos['consecuencias'], body_style))
        story.append(Spacer(1, 0.2*inch))
        
        # Cierre
        story.append(Paragraph("Se le exhorta a corregir esta situacin de inmediato y a cumplir con las disposiciones laborales establecidas.", body_style))
        story.append(Spacer(1, 0.3*inch))
        
        # Firma
        story.append(Paragraph("Atentamente,", body_style))
        story.append(Spacer(1, 0.5*inch))
        
        firma_data = [
            ['_' * 40],
            ['Gerencia de Recursos Humanos'],
            ['KALLPA']
        ]
        
        table_firma = Table(firma_data, colWidths=[3.5*inch])
        table_firma.setStyle(TableStyle([
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTSIZE', (0, 0), (-1, -1), 10),
            ('FONTNAME', (0, 1), (0, 2), 'Helvetica-Bold'),
        ]))
        
        story.append(table_firma)
        story.append(Spacer(1, 0.3*inch))
        
        # Nota de recepcin
        story.append(Paragraph("<i>He recibido copia del presente memorando y tomo conocimiento de su contenido.</i>", 
                               ParagraphStyle('Italic', parent=styles['Normal'], fontSize=9, textColor=colors.grey)))
        story.append(Spacer(1, 0.2*inch))
        
        recepcion_data = [
            ['Firma del colaborador:', '_' * 30, 'Fecha:', '_' * 20]
        ]
        
        table_recepcion = Table(recepcion_data, colWidths=[1.5*inch, 2.5*inch, 0.8*inch, 1.7*inch])
        table_recepcion.setStyle(TableStyle([
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ]))
        
        story.append(table_recepcion)
        
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
