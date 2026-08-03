"""
Module: requerimientos_pdf.py
Propósito: Generar PDFs profesionales de requerimientos
Fecha: 30 Julio 2026
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
    from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    REPORTLAB_AVAILABLE = True
except ImportError:
    REPORTLAB_AVAILABLE = False
    print("⚠️ Warning: reportlab not available - PDF generation will not work")

from datetime import datetime
from app.config import DatabaseConfig
import io

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
    """Generar y descargar requerimiento en PDF"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n[PDF-REQ] Iniciando generación de PDF para requerimiento: {id_requerimiento}")
        
        # Obtener datos del requerimiento
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
                CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, '')) as solicitante_nombres
            FROM TblRequerimiento tr
            LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
            LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
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
                id_detalle,
                tipo_item,
                descripcion,
                cantidad,
                observaciones
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = %s
            ORDER BY id_detalle
        """
        
        cursor.execute(query_detalles, (id_requerimiento,))
        detalles = cursor.fetchall()
        
        print(f"[PDF-REQ] ✓ Detalles obtenidos: {len(detalles)} items")
        
        cursor.close()
        connection.close()
        
        # Generar PDF
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
        
        # ==================== ESTILOS PERSONALIZADOS ====================
        KALLPA_GREEN = colors.HexColor('#228B22')
        KALLPA_DARK_GREEN = colors.HexColor('#1B5E20')
        
        header_style = ParagraphStyle(
            'Header',
            parent=styles['Normal'],
            fontSize=20,
            textColor=KALLPA_GREEN,
            fontName='Helvetica-Bold',
            alignment=TA_CENTER,
            spaceAfter=2
        )
        
        # ==================== CONTENIDO DEL PDF ====================
        
        # 1. ENCABEZADO
        header_text = f"<b>REQUERIMIENTO</b><br/><font size=9>Sistema de Gestión de Requerimientos KALLPA</font>"
        story.append(Paragraph(header_text, header_style))
        story.append(Spacer(1, 0.05*inch))
        
        # Línea separadora
        sep_data = [['_' * 120]]
        sep_table = Table(sep_data, colWidths=[7.35*inch])
        sep_table.setStyle(TableStyle([
            ('ALIGN', (0, 0), (0, 0), 'CENTER'),
            ('TEXTCOLOR', (0, 0), (0, 0), KALLPA_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (0, 0), 11),
            ('BOTTOMPADDING', (0, 0), (0, 0), 0),
            ('TOPPADDING', (0, 0), (0, 0), 2),
        ]))
        story.append(sep_table)
        story.append(Spacer(1, 0.08*inch))
        
        # 2. INFORMACIÓN DEL REQUERIMIENTO
        fecha_str = requerimiento['fecha_creacion'].strftime('%d/%m/%Y') if requerimiento['fecha_creacion'] else 'N/A'
        info_data = [
            ['CÓDIGO:', requerimiento['codigo'], 'ESTADO:', requerimiento['estado'], 'FECHA:', fecha_str],
        ]
        
        info_table = Table(info_data, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
        info_table.setStyle(TableStyle([
            ('TEXTCOLOR', (0, 0), (0, 0), KALLPA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), KALLPA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), KALLPA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
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
        
        story.append(info_table)
        story.append(Spacer(1, 0.08*inch))
        
        # 3. DESCRIPCIÓN Y SOLICITANTE
        solicitante = requerimiento.get('solicitante_nombres', 'N/A')
        if solicitante:
            solicitante = solicitante.strip()
        
        desc_data = [
            ['DESCRIPCIÓN:', requerimiento.get('descripcion', 'N/A'), 'SOLICITANTE:', solicitante],
        ]
        
        desc_table = Table(desc_data, colWidths=[1.0*inch, 2.8*inch, 1.0*inch, 2.55*inch])
        desc_table.setStyle(TableStyle([
            ('TEXTCOLOR', (0, 0), (0, 0), KALLPA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), KALLPA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, -1), 9),
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('LEFTPADDING', (0, 0), (-1, -1), 6),
            ('RIGHTPADDING', (0, 0), (-1, -1), 6),
            ('TOPPADDING', (0, 0), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
        ]))
        
        story.append(desc_table)
        story.append(Spacer(1, 0.1*inch))
        
        # 4. TABLA DE DETALLES (ITEMS)
        if detalles and len(detalles) > 0:
            # Header de tabla
            header_detalle = [['ITEMS DEL REQUERIMIENTO']]
            header_table = Table(header_detalle, colWidths=[7.35*inch])
            header_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), KALLPA_GREEN),
                ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
                ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (0, 0), 11),
                ('ALIGNMENT', (0, 0), (0, 0), 'LEFT'),
                ('LEFTPADDING', (0, 0), (0, 0), 8),
                ('TOPPADDING', (0, 0), (0, 0), 6),
                ('BOTTOMPADDING', (0, 0), (0, 0), 6),
            ]))
            story.append(header_table)
            
            # Tabla de detalles
            table_headers = [['Tipo', 'Descripción', 'Cantidad', 'Observaciones']]
            table_data = table_headers + [[
                item['tipo_item'] or 'ITEM',
                item['descripcion'] or '',
                str(item['cantidad'] or 0),
                item['observaciones'] or ''
            ] for item in detalles]
            
            details_table = Table(table_data, colWidths=[1.0*inch, 2.8*inch, 1.2*inch, 2.35*inch])
            details_table.setStyle(TableStyle([
                # Header
                ('BACKGROUND', (0, 0), (-1, 0), KALLPA_DARK_GREEN),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 9),
                ('ALIGNMENT', (0, 0), (-1, 0), 'LEFT'),
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
                ('ALIGNMENT', (2, 1), (2, -1), 'CENTER'),
            ]))
            
            story.append(details_table)
            story.append(Spacer(1, 0.1*inch))
        
        # 5. OBSERVACIONES
        if requerimiento.get('observaciones'):
            obs_header = [['OBSERVACIONES']]
            obs_header_table = Table(obs_header, colWidths=[7.35*inch])
            obs_header_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, 0), KALLPA_DARK_GREEN),
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
        footer_text = f"Generado el {datetime.now().strftime('%d/%m/%Y a las %H:%M:%S')} | KALLPA Sistema de Gestión de Requerimientos"
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
        filename = f"Requerimiento_{requerimiento['codigo'].replace('/', '_').replace('\\', '_')}.pdf"
        
        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Error as e:
        print(f"[PDF-REQ] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[PDF-REQ] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
