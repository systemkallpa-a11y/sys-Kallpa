"""
Module: presupuesto_pdf.py
Propósito: Generar PDFs profesionales de presupuestos
Fecha: 10 Julio 2026
"""

from flask import Blueprint, jsonify, request
from functools import wraps
import mysql.connector
from mysql.connector import Error

# Importar reportlab de forma opcional
try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch, cm
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak, Image
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_RIGHT, TA_CENTER, TA_LEFT, TA_JUSTIFY
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False
    print("⚠️ Warning: reportlab not available - PDF generation will not work")

from datetime import datetime
from app.config import DatabaseConfig
import io
import os
import tempfile

# Blueprint
pdf_bp = Blueprint('presupuesto_pdf', __name__)


def get_db_connection():
    """Crear conexión a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"Error de conexión: {e}")
        return None


def login_required(f):
    """Decorador para proteger rutas que requieren autenticación"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        from flask import session, redirect, url_for, flash
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesión', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


@pdf_bp.route('/api/presupuestos/descargar/<int:id_presupuesto>', methods=['GET'])
@login_required
def descargar_presupuesto_pdf(id_presupuesto):
    """Generar y descargar presupuesto en PDF usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n[PDF] Iniciando generación de PDF para presupuesto: {id_presupuesto}")
        
        # Llamar SP para obtener datos
        print(f"[PDF] Ejecutando SP: sp_ObtenerPresupuestoPDF({id_presupuesto})")
        cursor.callproc('sp_ObtenerPresupuestoPDF', [id_presupuesto])
        
        # Convertir stored_results() a lista para acceder a múltiples result sets
        results_list = list(cursor.stored_results())
        
        if not results_list or len(results_list) < 2:
            cursor.close()
            connection.close()
            print(f"[PDF] ❌ No se obtuvieron suficientes result sets del SP")
            return jsonify({'success': False, 'error': 'Error al ejecutar SP'}), 500
        
        # Result Set 1: Información del Presupuesto
        presupuesto = None
        presupuesto_result = results_list[0]
        presupuesto = presupuesto_result.fetchone()
        
        if not presupuesto:
            cursor.close()
            connection.close()
            print(f"[PDF] ❌ Presupuesto no encontrado: {id_presupuesto}")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        print(f"[PDF] ✓ Presupuesto encontrado: {presupuesto['numero_presupuesto']}")
        
        # Result Set 2: Detalles de Materiales
        materiales = []
        if len(results_list) > 1:
            materiales_result = results_list[1]
            materiales = materiales_result.fetchall()
        
        print(f"[PDF] ✓ Materiales obtenidos: {len(materiales)} items")
        
        # Result Set 3: Detalles de Servicios
        servicios = []
        if len(results_list) > 2:
            servicios_result = results_list[2]
            servicios = servicios_result.fetchall()
        
        print(f"[PDF] ✓ Servicios obtenidos: {len(servicios)} items")
        
        cursor.close()
        connection.close()
        
        # Generar PDF (márgenes mínimos para usar todo el ancho)
        pdf_buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            pdf_buffer,
            pagesize=letter,
            rightMargin=0.35*inch,
            leftMargin=0.35*inch,
            topMargin=0.5*inch,
            bottomMargin=0.5*inch,
            title=f"Presupuesto {presupuesto['numero_presupuesto']}"
        )
        
        story = []
        styles = getSampleStyleSheet()
        
        # ==================== ESTILOS PERSONALIZADOS CON COLORES QUSKA ====================
        
        # Colores corporativos de Quska (basados en el logo)
        QUSKA_GREEN = colors.HexColor('#228B22')  # Verde principal del logo
        QUSKA_ORANGE = colors.HexColor('#FF8C00')  # Naranja del logo  
        QUSKA_DARK_GREEN = colors.HexColor('#1B5E20')  # Verde oscuro para contraste
        QUSKA_LIGHT_GREEN = colors.HexColor('#E8F5E8')  # Verde claro para fondos
        
        # Encabezado
        header_style = ParagraphStyle(
            'Header',
            parent=styles['Normal'],
            fontSize=24,
            textColor=QUSKA_GREEN,
            fontName='Helvetica-Bold',
            alignment=TA_CENTER,
            spaceAfter=2
        )
        
        subtitle_style = ParagraphStyle(
            'Subtitle',
            parent=styles['Normal'],
            fontSize=11,
            textColor=colors.HexColor('#555555'),
            fontName='Helvetica',
            alignment=TA_CENTER,
            spaceAfter=0
        )
        
        section_title_style = ParagraphStyle(
            'SectionTitle',
            parent=styles['Heading2'],
            fontSize=12,
            textColor=colors.HexColor('#FFFFFF'),
            fontName='Helvetica-Bold',
            spaceAfter=0,
            spaceBefore=0
        )
        
        normal_style = ParagraphStyle(
            'Normal',
            parent=styles['Normal'],
            fontSize=9,
            textColor=colors.HexColor('#333333'),
            fontName='Helvetica'
        )
        
        # ==================== CONTENIDO DEL PDF ====================
        
        # 1. ENCABEZADO CON LOGO DINÁMICO DE LA EMPRESA
        # Intentar obtener logo de empresa desde base de datos
        logo_path = None
        
        if presupuesto.get('empresa_logo'):
            try:
                from PIL import Image as PILImage
                
                # Leer el BLOB como imagen
                image_data = presupuesto['empresa_logo']
                image = PILImage.open(io.BytesIO(image_data))
                
                # Convertir a RGB si es necesario (elimina canal alpha)
                if image.mode in ('RGBA', 'LA', 'P'):
                    # Crear fondo blanco
                    background = PILImage.new('RGB', image.size, (255, 255, 255))
                    if image.mode == 'P':
                        image = image.convert('RGBA')
                    background.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
                    image = background
                elif image.mode != 'RGB':
                    image = image.convert('RGB')
                
                # Guardar como PNG temporal
                temp_logo = tempfile.NamedTemporaryFile(delete=False, suffix='.png')
                image.save(temp_logo.name, 'PNG')
                temp_logo.close()
                logo_path = temp_logo.name
                print(f"[PDF] ✓ Logo de empresa cargado y convertido dinámicamente")
            except Exception as e:
                print(f"[PDF] ⚠ Error al cargar logo de empresa: {e}")
                import traceback
                print(f"[PDF] ⚠ Traceback: {traceback.format_exc()}")
                logo_path = None
        
        # Si no hay logo de empresa, usar logo por defecto
        if not logo_path:
            default_logo_path = os.path.join(os.path.dirname(__file__), '..', 'static', 'images', 'Logo Kallpa.png')
            if os.path.exists(default_logo_path):
                logo_path = default_logo_path
                print(f"[PDF] ✓ Logo por defecto cargado")
        
        # Crear tabla con logo (ahora dinámico)
        header_table_data = []
        if logo_path and os.path.exists(logo_path):
            try:
                logo = Image(logo_path, width=1.0*inch, height=0.75*inch)
                company_name = presupuesto.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    logo,
                    Paragraph(
                        f"<b>{company_name}</b><br/><font size=9>Sistema de Gestión de Presupuestos</font>",
                        header_style
                    )
                ])
            except Exception as e:
                print(f"[PDF] ⚠ Error al insertar logo: {e}")
                company_name = presupuesto.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    Paragraph(f"<b>{company_name}</b><br/><font size=9>Sistema de Gestión</font>", header_style)
                ])
        else:
            company_name = presupuesto.get('nombre_empresa', 'KALLPA')
            header_table_data.append([
                Paragraph(f"<b>{company_name}</b><br/><font size=9>Sistema de Gestión</font>", header_style)
            ])
        
        header_table = Table(header_table_data, colWidths=[1.2*inch, 6.15*inch])
        header_table.setStyle(TableStyle([
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 0),
            ('RIGHTPADDING', (0, 0), (-1, -1), 0),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
            ('TOPPADDING', (0, 0), (-1, -1), 0),
        ]))
        
        story.append(header_table)
        story.append(Spacer(1, 0.05*inch))
        
        # Línea separadora con colores Quska
        sep_data = [['_' * 120]]
        sep_table = Table(sep_data, colWidths=[7.35*inch])
        sep_table.setStyle(TableStyle([
            ('ALIGN', (0, 0), (0, 0), 'CENTER'),
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (0, 0), 11),
            ('BOTTOMPADDING', (0, 0), (0, 0), 0),
            ('TOPPADDING', (0, 0), (0, 0), 2),
        ]))
        story.append(sep_table)
        story.append(Spacer(1, 0.08*inch))
        
        # 2. INFORMACIÓN DEL PRESUPUESTO - CONSERVANDO ESTRUCTURA ORIGINAL
        # Tabla 1: NÚMERO, ESTADO, FECHA
        info_data_1 = [
            ['NÚMERO:', presupuesto['numero_presupuesto'], 'ESTADO:', presupuesto['estado'], 'FECHA:', presupuesto['fecha_creacion'].strftime('%d/%m/%Y') if presupuesto['fecha_creacion'] else 'N/A'],
        ]
        
        info_table_1 = Table(info_data_1, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
        info_table_1.setStyle(TableStyle([
            # Etiquetas (columnas 0, 2, 4) - Verde Quska
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
            
            # Valores (columnas 1, 3, 5)
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (5, 0), (5, 0), colors.HexColor('#333333')),
            ('FONTNAME', (1, 0), (1, 0), 'Helvetica'),
            ('FONTNAME', (3, 0), (3, 0), 'Helvetica'),
            ('FONTNAME', (5, 0), (5, 0), 'Helvetica'),
            
            # Estilos generales
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ]))
        
        story.append(info_table_1)
        
        # Tabla 2: PROYECTO, OBRA, MONEDA
        info_data_2 = [
            ['PROYECTO:', presupuesto['nombre_proyecto'], 'OBRA:', presupuesto['nombre_obra'], 'MONEDA:', 'S/. (Soles)'],
        ]
        
        info_table_2 = Table(info_data_2, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
        info_table_2.setStyle(TableStyle([
            # Etiquetas (columnas 0, 2, 4) - Verde Quska
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
            
            # Valores (columnas 1, 3, 5)
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (5, 0), (5, 0), colors.HexColor('#333333')),
            ('FONTNAME', (1, 0), (1, 0), 'Helvetica'),
            ('FONTNAME', (3, 0), (3, 0), 'Helvetica'),
            ('FONTNAME', (5, 0), (5, 0), 'Helvetica'),
            
            # Estilos generales
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ]))
        
        story.append(info_table_2)
        
        # Tabla 3: RESPONSABLE - con colores Quska pero estructura original
        responsable_nombre = f"{presupuesto.get('usuario_nombres', '') or 'N/A'} {presupuesto.get('usuario_apellido', '') or ''}".strip()
        responsable_email = presupuesto.get('usuario_email', 'N/A')
        responsable_telefono = presupuesto.get('usuario_celular', 'N/A')
        
        info_data_3 = [
            ['RESPONSABLE:', '', '', '', '', ''],
            [responsable_nombre, '', responsable_email, '', responsable_telefono, ''],
        ]
        
        info_table_3 = Table(info_data_3, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
        info_table_3.setStyle(TableStyle([
            # Fila 1: Label RESPONSABLE - Verde Quska
            ('BACKGROUND', (0, 0), (-1, 0), QUSKA_GREEN),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('ALIGNMENT', (0, 0), (0, 0), 'LEFT'),
            ('ALIGNMENT', (1, 0), (-1, 0), 'LEFT'),
            ('VALIGN', (0, 0), (-1, 0), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, 0), 6),
            ('RIGHTPADDING', (0, 0), (-1, 0), 6),
            ('TOPPADDING', (0, 0), (-1, 0), 8),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            
            # Fila 2: Datos (nombre, email, teléfono)
            ('BACKGROUND', (0, 1), (-1, 1), colors.HexColor('#fffacd')),
            ('TEXTCOLOR', (0, 1), (-1, 1), colors.HexColor('#333333')),
            ('FONTNAME', (0, 1), (-1, 1), 'Helvetica'),
            ('FONTSIZE', (0, 1), (-1, 1), 9),
            ('ALIGNMENT', (0, 1), (0, 1), 'LEFT'),
            ('ALIGNMENT', (2, 1), (2, 1), 'LEFT'),
            ('ALIGNMENT', (4, 1), (4, 1), 'LEFT'),
            ('ALIGNMENT', (1, 1), (1, 1), 'LEFT'),
            ('ALIGNMENT', (3, 1), (3, 1), 'LEFT'),
            ('ALIGNMENT', (5, 1), (5, 1), 'LEFT'),
            ('VALIGN', (0, 1), (-1, 1), 'MIDDLE'),
            ('LEFTPADDING', (0, 1), (-1, 1), 6),
            ('RIGHTPADDING', (0, 1), (-1, 1), 6),
            ('TOPPADDING', (0, 1), (-1, 1), 10),
            ('BOTTOMPADDING', (0, 1), (-1, 1), 10),
            
            # Grid: Solo bordes externos, no internos en las columnas vacías
            ('LINEABOVE', (0, 0), (0, 0), 0.5, colors.HexColor('#d0d0d0')),
            ('LINEBELOW', (0, 1), (0, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINELEFT', (0, 0), (0, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINERIGHT', (-1, 0), (-1, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINEBELOW', (0, 0), (-1, 0), 0.5, colors.HexColor('#d0d0d0')),
            ('LINEBELOW', (0, 1), (-1, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINERIGHT', (0, 1), (0, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINERIGHT', (2, 1), (2, 1), 0.5, colors.HexColor('#d0d0d0')),
            ('LINERIGHT', (4, 1), (4, 1), 0.5, colors.HexColor('#d0d0d0')),
        ]))
        
        story.append(info_table_3)
        story.append(Spacer(1, 0.1*inch))
        
        # 4. TABLA DE MATERIALES - USAR FUNCIÓN HELPER PARA ESTRUCTURA CONSISTENTE
        from .pdf_helpers import PDFStyles, crear_tabla_materiales, crear_tabla_servicios, crear_desglose_financiero, crear_observaciones
        
        # Obtener estilos centralizados
        pdf_styles = PDFStyles.get_styles()
        
        # Crear tabla de materiales usando helper
        if materiales:
            header_mat, table_mat = crear_tabla_materiales(materiales, pdf_styles)
            if header_mat and table_mat:
                # Personalizar colores Quska en el header
                header_mat.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (0, 0), QUSKA_GREEN),
                    ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                    ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (0, 0), 12),
                    ('LEFTPADDING', (0, 0), (0, 0), 8),
                    ('TOPPADDING', (0, 0), (0, 0), 6),
                    ('BOTTOMPADDING', (0, 0), (0, 0), 6),
                ]))
                
                story.append(header_mat)
                story.append(table_mat)
                story.append(Spacer(1, 0.1*inch))
        
        # 5. TABLA DE SERVICIOS - USAR FUNCIÓN HELPER
        if servicios:
            header_svc, table_svc = crear_tabla_servicios(servicios, pdf_styles)
            if header_svc and table_svc:
                # Personalizar colores Quska en el header
                header_svc.setStyle(TableStyle([
                    ('BACKGROUND', (0, 0), (0, 0), QUSKA_DARK_GREEN),
                    ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                    ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                    ('FONTSIZE', (0, 0), (0, 0), 11),
                    ('LEFTPADDING', (0, 0), (0, 0), 8),
                    ('TOPPADDING', (0, 0), (0, 0), 6),
                    ('BOTTOMPADDING', (0, 0), (0, 0), 6),
                ]))
                
                story.append(header_svc)
                story.append(table_svc)
                story.append(Spacer(1, 0.08*inch))
        
        # 6. DESGLOSE FINANCIERO - USAR FUNCIÓN HELPER CON COLORES QUSKA
        header_desglose, table_desglose = crear_desglose_financiero(presupuesto, materiales, servicios, pdf_styles)
        if header_desglose and table_desglose:
            # Personalizar header del desglose con colores Quska
            header_desglose.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), QUSKA_ORANGE),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (0, 0), 12),
                ('LEFTPADDING', (0, 0), (0, 0), 8),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            
            story.append(header_desglose)
            story.append(table_desglose)
            story.append(Spacer(1, 0.08*inch))
        
        # 7. OBSERVACIONES - USAR FUNCIÓN HELPER
        header_obs, table_obs = crear_observaciones(presupuesto, pdf_styles)
        if header_obs and table_obs:
            # Personalizar header con colores Quska
            header_obs.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), QUSKA_DARK_GREEN),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (0, 0), 11),
                ('LEFTPADDING', (0, 0), (0, 0), 8),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            
            story.append(header_obs)
            story.append(table_obs)
            story.append(Spacer(1, 0.1*inch))
        
        # 8. PIE DE PÁGINA
        story.append(Spacer(1, 0.2*inch))
        footer_text = f"Generado el {datetime.now().strftime('%d/%m/%Y a las %H:%M:%S')} | KALLPA Sistema de Gestión"
        footer_paragraph = Paragraph(footer_text, ParagraphStyle(
            'Footer',
            parent=styles['Normal'],
            fontSize=7,
            textColor=colors.HexColor('#999999'),
            alignment=TA_CENTER,
            fontName='Helvetica'
        ))
        story.append(footer_paragraph)
        
        # Construir PDF
        doc.build(story)
        
        # Enviar PDF
        pdf_buffer.seek(0)
        filename = f"Presupuesto_{presupuesto['numero_presupuesto'].replace('-', '_')}.pdf"
        
        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Error as e:
        print(f"[PDF] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[PDF] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
