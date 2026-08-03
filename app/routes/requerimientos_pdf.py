"""
Module: requerimientos_pdf.py
Propósito: Generar PDFs profesionales de requerimientos
Fecha: 3 Agosto 2026
Actualizado: Logo dinámico según empresa + estructura mejorada
"""

from flask import Blueprint, jsonify, request
from functools import wraps
import mysql.connector
from mysql.connector import Error

# Importar reportlab de forma opcional
try:
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
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
requerimientos_pdf_bp = Blueprint('requerimientos_pdf', __name__)


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


@requerimientos_pdf_bp.route('/api/requerimientos/descargar/<int:id_requerimiento>', methods=['GET'])
@login_required
def descargar_requerimiento_pdf(id_requerimiento):
    """Generar y descargar requerimiento en PDF con logo dinámico de empresa"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n[PDF-REQ] Iniciando generación de PDF para requerimiento: {id_requerimiento}")
        
        # Obtener datos del requerimiento CON EMPRESA Y LOGO
        query_requerimiento = """
            SELECT 
                tr.id_requerimiento,
                tr.codigo,
                tr.descripcion,
                tr.observaciones,
                tr.estado,
                tr.fecha_creacion,
                tr.id_presupuesto,
                tr.num_usuario,
                CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as solicitante_nombre,
                e.nombre as nombre_empresa,
                e.logo as empresa_logo,
                pres.numero_presupuesto
            FROM TblRequerimiento tr
            LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
            LEFT JOIN TblPresupuesto pres ON tr.id_presupuesto = pres.id_presupuesto
            LEFT JOIN TblEmpresa e ON pres.id_empresa = e.id_empresa
            WHERE tr.id_requerimiento = %s
        """
        
        cursor.execute(query_requerimiento, (id_requerimiento,))
        requerimiento = cursor.fetchone()
        
        if not requerimiento:
            cursor.close()
            connection.close()
            print(f"[PDF-REQ] ❌ Requerimiento no encontrado: {id_requerimiento}")
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        print(f"[PDF-REQ] ✓ Requerimiento encontrado: {requerimiento['codigo']}")
        
        # Obtener detalles (items) del requerimiento
        query_detalles = """
            SELECT 
                rd.id_detalle,
                rd.tipo_item,
                rd.descripcion,
                rd.cantidad,
                rd.observaciones,
                COALESCE(m.codigo_material, '') as codigo_material,
                COALESCE(um.abreviatura, '') as unidad
            FROM TblRequerimientoDetalle rd
            LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
            LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
            WHERE rd.id_requerimiento = %s
            ORDER BY rd.tipo_item DESC, rd.id_detalle
        """
        
        cursor.execute(query_detalles, (id_requerimiento,))
        detalles = cursor.fetchall()
        
        print(f"[PDF-REQ] ✓ Detalles obtenidos: {len(detalles)} items")
        
        cursor.close()
        connection.close()
        
        # Generar PDF (márgenes mínimos como presupuesto)
        pdf_buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            pdf_buffer,
            pagesize=letter,
            rightMargin=0.35*inch,
            leftMargin=0.35*inch,
            topMargin=0.5*inch,
            bottomMargin=0.5*inch,
            title=f"Requerimiento {requerimiento['codigo']}"
        )
        
        story = []
        styles = getSampleStyleSheet()
        
        # ==================== ESTILOS PERSONALIZADOS CON COLORES QUSKA ====================
        
        # Colores corporativos (igual que presupuesto)
        QUSKA_GREEN = colors.HexColor('#228B22')
        QUSKA_ORANGE = colors.HexColor('#FF8C00')
        QUSKA_DARK_GREEN = colors.HexColor('#1B5E20')
        QUSKA_LIGHT_GREEN = colors.HexColor('#E8F5E8')
        
        header_style = ParagraphStyle(
            'Header',
            parent=styles['Normal'],
            fontSize=24,
            textColor=QUSKA_GREEN,
            fontName='Helvetica-Bold',
            alignment=TA_CENTER,
            spaceAfter=2
        )
        
        # ==================== CONTENIDO DEL PDF ====================
        
        # 1. ENCABEZADO CON LOGO DINÁMICO DE LA EMPRESA (como presupuesto)
        logo_path = None
        
        if requerimiento.get('empresa_logo'):
            try:
                from PIL import Image as PILImage
                
                # Leer el BLOB como imagen
                image_data = requerimiento['empresa_logo']
                image = PILImage.open(io.BytesIO(image_data))
                
                # Convertir a RGB si es necesario
                if image.mode in ('RGBA', 'LA', 'P'):
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
                print(f"[PDF-REQ] ✓ Logo de empresa cargado dinámicamente")
            except Exception as e:
                print(f"[PDF-REQ] ⚠ Error al cargar logo de empresa: {e}")
                logo_path = None
        
        # Si no hay logo de empresa, usar logo por defecto
        if not logo_path:
            default_logo_path = os.path.join(os.path.dirname(__file__), '..', 'static', 'images', 'Logo Kallpa.png')
            if os.path.exists(default_logo_path):
                logo_path = default_logo_path
                print(f"[PDF-REQ] ✓ Logo por defecto cargado")
        
        # Crear tabla con logo
        header_table_data = []
        if logo_path and os.path.exists(logo_path):
            try:
                logo = Image(logo_path, width=1.0*inch, height=0.75*inch)
                company_name = requerimiento.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    logo,
                    Paragraph(
                        f"<b>{company_name}</b><br/><font size=9>Sistema de Gestión de Requerimientos</font>",
                        header_style
                    )
                ])
            except Exception as e:
                print(f"[PDF-REQ] ⚠ Error al insertar logo: {e}")
                company_name = requerimiento.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    Paragraph(f"<b>{company_name}</b><br/><font size=9>Sistema de Gestión</font>", header_style)
                ])
        else:
            company_name = requerimiento.get('nombre_empresa', 'KALLPA')
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
        
        # 2. INFORMACIÓN DEL REQUERIMIENTO - ESTRUCTURA IGUAL A PRESUPUESTO
        fecha_str = requerimiento['fecha_creacion'].strftime('%d/%m/%Y') if requerimiento['fecha_creacion'] else 'N/A'
        
        # Tabla 1: CÓDIGO, ESTADO, FECHA
        info_data_1 = [
            ['CÓDIGO:', requerimiento['codigo'], 'ESTADO:', requerimiento['estado'], 'FECHA:', fecha_str],
        ]
        
        info_table_1 = Table(info_data_1, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
        info_table_1.setStyle(TableStyle([
            # Etiquetas - Verde Quska
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
            # Valores
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (5, 0), (5, 0), colors.HexColor('#333333')),
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
        
        # Tabla 2: SOLICITANTE, PRESUPUESTO, DESCRIPCIÓN
        solicitante = (requerimiento.get('solicitante_nombre') or 'N/A').strip()
        numero_pres = requerimiento.get('numero_presupuesto') or 'N/A'
        descripcion = requerimiento.get('descripcion') or 'N/A'
        
        info_data_2 = [
            ['SOLICITANTE:', solicitante, 'PRESUPUESTO:', numero_pres, 'DESCRIPCIÓN:', descripcion],
        ]
        
        info_table_2 = Table(info_data_2, colWidths=[1.0*inch, 1.80*inch, 1.0*inch, 1.80*inch, 1.0*inch, 1.75*inch])
        info_table_2.setStyle(TableStyle([
            # Etiquetas
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
            # Valores
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (5, 0), (5, 0), colors.HexColor('#333333')),
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
        story.append(Spacer(1, 0.1*inch))
        
        # 4. TABLA DE DETALLES (ITEMS)
        if detalles and len(detalles) > 0:
            # Header de tabla
            header_detalle = [['ITEMS DEL REQUERIMIENTO']]
            header_table = Table(header_detalle, colWidths=[7.35*inch])
            header_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), QUSKA_GREEN),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (0, 0), 11),
                ('ALIGNMENT', (0, 0), (0, 0), 'LEFT'),
                ('LEFTPADDING', (0, 0), (0, 0), 8),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            story.append(header_table)
            
            # Tabla de detalles - NUEVA ESTRUCTURA: #, Tipo, Código, Descripción, Cantidad, Unidad
            table_headers = [['#', 'Tipo', 'Código', 'Descripción', 'Cantidad', 'Unidad']]
            table_data = table_headers + [[
                str(idx + 1),
                item['tipo_item'] or 'ITEM',
                item['codigo_material'] or '',
                item['descripcion'] or '',
                str(item['cantidad'] or 0),
                item['unidad'] or ''
            ] for idx, item in enumerate(detalles)]
            
            details_table = Table(table_data, colWidths=[0.4*inch, 0.8*inch, 0.9*inch, 3.0*inch, 0.8*inch, 0.7*inch])
            details_table.setStyle(TableStyle([
                # Header
                ('BACKGROUND', (0, 0), (-1, 0), QUSKA_DARK_GREEN),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('ALIGNMENT', (0, 0), (-1, 0), 'CENTER'),
                ('VALIGN', (0, 0), (-1, 0), 'MIDDLE'),
                
                # Data rows
                ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#ffffff')),
                ('TEXTCOLOR', (0, 1), (-1, -1), colors.HexColor('#333333')),
                ('FONTSIZE', (0, 1), (-1, -1), 8),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
                ('VALIGN', (0, 1), (-1, -1), 'MIDDLE'),
                ('LEFTPADDING', (0, 0), (-1, -1), 6),
                ('RIGHTPADDING', (0, 0), (-1, -1), 6),
                ('TOPPADDING', (0, 0), (-1, -1), 6),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
                # Alineaciones específicas
                ('ALIGNMENT', (0, 1), (0, -1), 'CENTER'),  # # centrado
                ('ALIGNMENT', (1, 1), (1, -1), 'LEFT'),    # Tipo
                ('ALIGNMENT', (2, 1), (2, -1), 'LEFT'),    # Código
                ('ALIGNMENT', (3, 1), (3, -1), 'LEFT'),    # Descripción
                ('ALIGNMENT', (4, 1), (4, -1), 'CENTER'),  # Cantidad
                ('ALIGNMENT', (5, 1), (5, -1), 'CENTER'),  # Unidad
            ]))
            
            story.append(details_table)
            story.append(Spacer(1, 0.1*inch))
        
        # 5. OBSERVACIONES
        if requerimiento.get('observaciones'):
            obs_header = [['OBSERVACIONES']]
            obs_header_table = Table(obs_header, colWidths=[7.35*inch])
            obs_header_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), QUSKA_DARK_GREEN),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (0, 0), 10),
                ('ALIGNMENT', (0, 0), (0, 0), 'LEFT'),
                ('LEFTPADDING', (0, 0), (0, 0), 8),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            story.append(obs_header_table)
            
            obs_data = [[requerimiento['observaciones']]]
            obs_table = Table(obs_data, colWidths=[7.35*inch])
            obs_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), colors.HexColor('#fffacd')),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.HexColor('#333333')),
                ('FONTSIZE', (0, 0), (0, 0), 9),
                ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
                ('VALIGN', (0, 0), (0, 0), 'TOP'),
                ('LEFTPADDING', (0, 0), (0, 0), 6),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            story.append(obs_table)
            story.append(Spacer(1, 0.1*inch))
        
        # 6. PIE DE PÁGINA
        story.append(Spacer(1, 0.2*inch))
        footer_text = f"Generado el {datetime.now().strftime('%d/%m/%Y a las %H:%M:%S')} | {company_name} - Sistema de Gestión"
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
        
        # Limpiar archivo temporal del logo
        if logo_path and logo_path != default_logo_path and os.path.exists(logo_path):
            try:
                os.unlink(logo_path)
                print(f"[PDF-REQ] ✓ Logo temporal eliminado")
            except Exception as e:
                print(f"[PDF-REQ] ⚠ Error al eliminar logo temporal: {e}")
        
        # Enviar PDF
        pdf_buffer.seek(0)
        filename = f"Requerimiento_{requerimiento['codigo'].replace('/', '_').replace('\\', '_')}.pdf"
        
        print(f"[PDF-REQ] ✅ PDF generado exitosamente: {filename}")
        
        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Error as e:
        import traceback
        print(f"[PDF-REQ] ❌ Error SQL: {e}")
        print(f"[PDF-REQ] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        import traceback
        print(f"[PDF-REQ] ❌ Error general: {e}")
        print(f"[PDF-REQ] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'error': str(e)}), 500
