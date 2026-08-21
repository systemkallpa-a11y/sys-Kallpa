"""
Module: requerimientos_pdf.py
Propsito: Generar PDFs profesionales de requerimientos
Fecha: 3 Agosto 2026
Actualizado: Logo dinmico segn empresa + estructura mejorada
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
    print("[!] Warning: reportlab not available - PDF generation will not work")

from datetime import datetime
from app.config import DatabaseConfig
import io
import os
import tempfile

# Blueprint
requerimientos_pdf_bp = Blueprint('requerimientos_pdf', __name__)


def get_db_connection():
    """Crear conexin a la base de datos Kallpa"""
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


@requerimientos_pdf_bp.route('/api/requerimientos/descargar/<int:id_requerimiento>', methods=['GET'])
@login_required
def descargar_requerimiento_pdf(id_requerimiento):
    """Generar y descargar requerimiento en PDF con logo dinmico de empresa"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n[PDF-REQ] Iniciando generacin de PDF para requerimiento: {id_requerimiento}")
        
        # Obtener datos del requerimiento usando SP (incluye solicitante)
        print(f"[PDF-REQ] Llamando a sp_ObtenerRequerimiento({id_requerimiento})")
        cursor.callproc('sp_ObtenerRequerimiento', [id_requerimiento])
        
        # Obtener resultado del SP
        requerimiento = None
        result_count = 0
        for result in cursor.stored_results():
            result_count += 1
            print(f"[PDF-REQ] Procesando resultado #{result_count} del SP")
            requerimiento = result.fetchone()
            print(f"[PDF-REQ] DEBUG Requerimiento completo: {requerimiento}")
            if requerimiento:
                print(f"[PDF-REQ] DEBUG Keys disponibles: {list(requerimiento.keys())}")
                print(f"[PDF-REQ] DEBUG usuario_completo en dict: {'usuario_completo' in requerimiento}")
                if 'usuario_completo' in requerimiento:
                    print(f"[PDF-REQ] DEBUG Valor de usuario_completo: '{requerimiento['usuario_completo']}'")
                    print(f"[PDF-REQ] DEBUG Tipo de usuario_completo: {type(requerimiento['usuario_completo'])}")
            break
        
        print(f"[PDF-REQ] Total de resultados procesados: {result_count}")
        
        if not requerimiento:
            cursor.close()
            connection.close()
            print(f"[PDF-REQ] [X] Requerimiento no encontrado: {id_requerimiento}")
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        print(f"[PDF-REQ] [OK] Requerimiento encontrado: {requerimiento['codigo']}")
        print(f"[PDF-REQ] [OK] Solicitante: {requerimiento.get('usuario_completo', 'N/A')}")
        
        # Obtener datos de empresa y logo (si tiene presupuesto asociado)
        nombre_empresa = 'KALLPA'
        empresa_logo = None
        
        if requerimiento.get('id_presupuesto'):
            query_empresa = """
                SELECT 
                    e.nombre as nombre_empresa,
                    e.logo as empresa_logo
                FROM TblPresupuesto pres
                LEFT JOIN TblEmpresa e ON pres.id_empresa = e.id_empresa
                WHERE pres.id_presupuesto = %s
            """
            cursor.execute(query_empresa, (requerimiento['id_presupuesto'],))
            empresa_data = cursor.fetchone()
            
            if empresa_data:
                nombre_empresa = empresa_data.get('nombre_empresa') or 'KALLPA'
                empresa_logo = empresa_data.get('empresa_logo')
                print(f"[PDF-REQ] [OK] Empresa: {nombre_empresa}")
        
        # Agregar datos de empresa al dict de requerimiento
        requerimiento['nombre_empresa'] = nombre_empresa
        requerimiento['empresa_logo'] = empresa_logo
        
        # Obtener detalles (items) del requerimiento usando SP
        cursor.callproc('sp_ObtenerRequerimientoDetalles', [id_requerimiento])
        
        detalles = []
        for result in cursor.stored_results():
            detalles = result.fetchall()
            break
        
        print(f"[PDF-REQ] [OK] Detalles obtenidos: {len(detalles)} items")
        
        cursor.close()
        connection.close()
        
        # Generar PDF (mrgenes mnimos como presupuesto)
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
        
        # 1. ENCABEZADO CON LOGO DINMICO DE LA EMPRESA (como presupuesto)
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
                print(f"[PDF-REQ] [OK] Logo de empresa cargado dinmicamente")
            except Exception as e:
                print(f"[PDF-REQ] [!] Error al cargar logo de empresa: {e}")
                logo_path = None
        
        # Si no hay logo de empresa, usar logo por defecto
        if not logo_path:
            default_logo_path = os.path.join(os.path.dirname(__file__), '..', 'static', 'images', 'Logo Kallpa.png')
            if os.path.exists(default_logo_path):
                logo_path = default_logo_path
                print(f"[PDF-REQ] [OK] Logo por defecto cargado")
        
        # Crear tabla con logo
        header_table_data = []
        if logo_path and os.path.exists(logo_path):
            try:
                logo = Image(logo_path, width=1.0*inch, height=0.75*inch)
                company_name = requerimiento.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    logo,
                    Paragraph(
                        f"<b>{company_name}</b><br/><font size=9>Sistema de Gestin de Requerimientos</font>",
                        header_style
                    )
                ])
            except Exception as e:
                print(f"[PDF-REQ] [!] Error al insertar logo: {e}")
                company_name = requerimiento.get('nombre_empresa', 'KALLPA')
                header_table_data.append([
                    Paragraph(f"<b>{company_name}</b><br/><font size=9>Sistema de Gestin</font>", header_style)
                ])
        else:
            company_name = requerimiento.get('nombre_empresa', 'KALLPA')
            header_table_data.append([
                Paragraph(f"<b>{company_name}</b><br/><font size=9>Sistema de Gestin</font>", header_style)
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
        
        # Lnea separadora con colores Quska
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
        
        # 2. INFORMACIN DEL REQUERIMIENTO Y RESPONSABLE - USAR FUNCIONES HELPER
        from .pdf_helpers import PDFStyles, crear_tabla_materiales, crear_tabla_servicios, crear_observaciones
        
        # Obtener estilos centralizados
        pdf_styles = PDFStyles.get_styles()
        
        # Crear info del requerimiento (similar a presupuesto pero adaptado)
        fecha_str = requerimiento['fecha_creacion'].strftime('%d/%m/%Y') if requerimiento['fecha_creacion'] else 'N/A'
        numero_pres = requerimiento.get('numero_presupuesto') or 'N/A'
        
        # Tabla 1: CDIGO, ESTADO, FECHA (ancho total: 8.0 inches - ALINEADO CON MATERIALES)
        info_data_1 = [
            ['CDIGO:', requerimiento['codigo'], 'ESTADO:', requerimiento['estado'], 'FECHA:', fecha_str],
        ]
        
        # Total: 0.7 + 2.3 + 0.7 + 2.3 + 0.6 + 1.4 = 8.0"
        info_table_1 = Table(info_data_1, colWidths=[0.7*inch, 2.3*inch, 0.7*inch, 2.3*inch, 0.6*inch, 1.4*inch])
        info_table_1.setStyle(TableStyle([
            # Etiquetas - Verde Quska
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (4, 0), (4, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTNAME', (4, 0), (4, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (0, 0), 7),
            ('FONTSIZE', (2, 0), (2, 0), 7),
            ('FONTSIZE', (4, 0), (4, 0), 7),
            # Valores
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (5, 0), (5, 0), colors.HexColor('#333333')),
            ('FONTSIZE', (1, 0), (1, 0), 7),
            ('FONTSIZE', (3, 0), (3, 0), 7),
            ('FONTSIZE', (5, 0), (5, 0), 7),
            # Estilos generales
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))
        
        story.append(info_table_1)
        story.append(Spacer(1, 0.05*inch))
        
        # Tabla 2: SOLICITANTE y PRESUPUESTO (ancho total: 8.0 inches - ALINEADO CON MATERIALES)
        usuario_completo_raw = requerimiento.get('usuario_completo')
        solicitante = (usuario_completo_raw or 'N/A').strip() if usuario_completo_raw else 'N/A'
        
        info_data_2 = [
            ['SOLICITANTE:', solicitante, 'PRESUPUESTO:', numero_pres],
        ]
        
        # Total: 1.05 + 4.35 + 1.25 + 1.35 = 8.0"
        info_table_2 = Table(info_data_2, colWidths=[1.05*inch, 4.35*inch, 1.25*inch, 1.35*inch])
        info_table_2.setStyle(TableStyle([
            # Etiquetas
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('TEXTCOLOR', (2, 0), (2, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTNAME', (2, 0), (2, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (0, 0), 7),
            ('FONTSIZE', (2, 0), (2, 0), 7),
            # Valores
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('TEXTCOLOR', (3, 0), (3, 0), colors.HexColor('#333333')),
            ('FONTSIZE', (1, 0), (1, 0), 7),
            ('FONTSIZE', (3, 0), (3, 0), 7),
            # Estilos generales
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))
        
        story.append(info_table_2)
        story.append(Spacer(1, 0.05*inch))
        
        # Tabla 3: DESCRIPCIN (ancho total: 8.0 inches - ALINEADO CON MATERIALES)
        descripcion = requerimiento.get('descripcion') or 'N/A'
        
        info_data_3 = [
            ['DESCRIPCIN:', descripcion],
        ]
        
        # Total: 1.05 + 6.95 = 8.0"
        info_table_3 = Table(info_data_3, colWidths=[1.05*inch, 6.95*inch])
        info_table_3.setStyle(TableStyle([
            # Etiqueta
            ('TEXTCOLOR', (0, 0), (0, 0), QUSKA_DARK_GREEN),
            ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (0, 0), 7),
            # Valor
            ('TEXTCOLOR', (1, 0), (1, 0), colors.HexColor('#333333')),
            ('FONTSIZE', (1, 0), (1, 0), 7),
            # Estilos generales
            ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#d0d0d0')),
            ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
            ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
            ('LEFTPADDING', (0, 0), (-1, -1), 5),
            ('RIGHTPADDING', (0, 0), (-1, -1), 5),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ]))
        
        story.append(info_table_3)
        story.append(Spacer(1, 0.1*inch))
        
        # 3. TABLAS DE MATERIALES Y SERVICIOS - USAR FUNCIONES HELPER
        if detalles and len(detalles) > 0:
            # Separar materiales y servicios
            materiales = [item for item in detalles if item.get('tipo_item') == 'MATERIAL']
            servicios = [item for item in detalles if item.get('tipo_item') == 'SERVICIO']
            
            # ==================== MATERIALES ====================
            if materiales:
                # Convertir detalles de requerimiento a formato de materiales de presupuesto
                materiales_formato = []
                for idx, item in enumerate(materiales):
                    materiales_formato.append({
                        'material_codigo': item.get('material_codigo') or '-',
                        'material_nombre': item.get('descripcion') or '',
                        'cantidad': item.get('cantidad') or 0,
                        'unidad_abreviatura': item.get('unidad_abreviatura') or 'und',
                        'precio_unitario': 0,  # No hay precios en requerimientos
                        'subtotal': 0
                    })
                
                header_mat, table_mat = crear_tabla_materiales(materiales_formato, pdf_styles)
                if header_mat and table_mat:
                    story.append(header_mat)
                    story.append(table_mat)
                    story.append(Spacer(1, 0.1*inch))
            
            # ==================== SERVICIOS ====================
            if servicios:
                # Convertir detalles de requerimiento a formato de servicios de presupuesto
                servicios_formato = []
                for idx, item in enumerate(servicios):
                    servicios_formato.append({
                        'descripcion': item.get('descripcion') or '',
                        'cantidad': item.get('cantidad') or 0,
                        'unidad_abreviatura': item.get('unidad_abreviatura') or 'und',
                        'precio_unitario': 0,  # No hay precios en requerimientos
                        'subtotal': 0
                    })
                
                header_svc, table_svc = crear_tabla_servicios(servicios_formato, pdf_styles)
                if header_svc and table_svc:
                    story.append(header_svc)
                    story.append(table_svc)
                    story.append(Spacer(1, 0.1*inch))
        
        # 4. OBSERVACIONES - USAR FUNCIN HELPER
        # Crear un diccionario simulando presupuesto para reusar la funcin
        req_obs = {'observaciones': requerimiento.get('observaciones')}
        header_obs, table_obs = crear_observaciones(req_obs, pdf_styles)
        if header_obs and table_obs:
            story.append(header_obs)
            story.append(table_obs)
            story.append(Spacer(1, 0.1*inch))
        
        # 5. PIE DE PGINA
        story.append(Spacer(1, 0.2*inch))
        footer_text = f"Generado el {datetime.now().strftime('%d/%m/%Y a las %H:%M:%S')} | {company_name} - Sistema de Gestin"
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
                print(f"[PDF-REQ] [OK] Logo temporal eliminado")
            except Exception as e:
                print(f"[PDF-REQ] [!] Error al eliminar logo temporal: {e}")
        
        # Enviar PDF
        pdf_buffer.seek(0)
        filename = f"Requerimiento_{requerimiento['codigo'].replace('/', '_').replace('\\', '_')}.pdf"
        
        print(f"[PDF-REQ] [OK] PDF generado exitosamente: {filename}")
        
        return pdf_buffer.getvalue(), 200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': f'attachment; filename="{filename}"'
        }
        
    except Error as e:
        import traceback
        print(f"[PDF-REQ] [X] Error SQL: {e}")
        print(f"[PDF-REQ] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        import traceback
        print(f"[PDF-REQ] [X] Error general: {e}")
        print(f"[PDF-REQ] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'error': str(e)}), 500
