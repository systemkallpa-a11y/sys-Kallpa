"""
Module: pdf_helpers.py
Propósito: Funciones auxiliares para generar PDFs estructurados
Fecha: 20 Julio 2026
Descripción: Proporciona funciones modulares para crear secciones del PDF
"""

from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from datetime import datetime
import os


# ============================================================================
# CLASE: PDFStyles - Gestión centralizada de estilos y colores
# ============================================================================

class PDFStyles:
    """
    Clase que centraliza todos los estilos y colores del PDF.
    Facilita cambios globales y mantiene consistencia visual.
    """
    
    # ====== COLORES ======
    PRIMARY_COLOR = colors.HexColor('#1a472a')      # Verde oscuro Kallpa
    SECONDARY_COLOR = colors.HexColor('#2c5f2d')    # Verde medio
    ACCENT_COLOR = colors.HexColor('#ff9800')       # Naranja
    LIGHT_GREEN = colors.HexColor('#e8f5e9')        # Verde claro (fondo)
    LIGHT_ACCENT = colors.HexColor('#fff3e0')       # Naranja claro (fondo)
    BORDER_COLOR = colors.HexColor('#d0d0d0')       # Gris claro
    HEADER_DARK = colors.HexColor('#34495e')        # Gris oscuro tablas
    TEXT_DARK = colors.HexColor('#333333')          # Texto principal
    TEXT_LIGHT = colors.HexColor('#666666')         # Texto secundario
    
    @staticmethod
    def get_styles():
        """Retorna diccionario con todos los estilos ParagraphStyle configurados"""
        return {
            'header': ParagraphStyle(
                'Header',
                fontSize=24,
                textColor=PDFStyles.PRIMARY_COLOR,
                fontName='Helvetica-Bold',
                alignment=TA_CENTER,
                spaceAfter=2
            ),
            'title_section': ParagraphStyle(
                'TitleSection',
                fontSize=11,
                textColor=colors.white,
                fontName='Helvetica-Bold',
                spaceAfter=0,
                spaceBefore=0
            ),
            'label': ParagraphStyle(
                'Label',
                fontSize=8.5,
                textColor=PDFStyles.PRIMARY_COLOR,
                fontName='Helvetica-Bold'
            ),
            'value': ParagraphStyle(
                'Value',
                fontSize=9,
                textColor=PDFStyles.TEXT_DARK,
                fontName='Helvetica'
            ),
            'normal': ParagraphStyle(
                'Normal',
                fontSize=9,
                textColor=PDFStyles.TEXT_DARK,
                fontName='Helvetica'
            ),
            'small': ParagraphStyle(
                'Small',
                fontSize=8,
                textColor=PDFStyles.TEXT_LIGHT,
                fontName='Helvetica'
            ),
            'footer': ParagraphStyle(
                'Footer',
                fontSize=7,
                textColor=colors.HexColor('#999999'),
                alignment=TA_CENTER,
                fontName='Helvetica'
            )
        }


# ============================================================================
# FUNCIÓN: Crear Encabezado con Logo
# ============================================================================

def crear_encabezado(logo_path, styles):
    """
    Crea tabla de encabezado con logo + título
    
    Args:
        logo_path (str): Ruta al archivo de logo
        styles (dict): Diccionario de estilos
        
    Returns:
        Table: Tabla formateada con logo y título
    """
    header_data = []
    
    if os.path.exists(logo_path):
        try:
            logo = Image(logo_path, width=1.0*inch, height=0.75*inch)
            header_data.append([
                logo,
                Paragraph(
                    "<b>KALLPA</b><br/><font size=9>Sistema de Gestión de Presupuestos</font>",
                    styles['header']
                )
            ])
        except:
            header_data.append([
                Paragraph("<b>KALLPA</b><br/><font size=9>Sistema de Gestión</font>", styles['header'])
            ])
    else:
        header_data.append([
            Paragraph("<b>KALLPA</b><br/><font size=9>Sistema de Gestión</font>", styles['header'])
        ])
    
    header_table = Table(header_data, colWidths=[1.2*inch, 6.15*inch])
    header_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
    ]))
    
    return header_table


# ============================================================================
# FUNCIÓN: Crear Información del Presupuesto
# ============================================================================

def crear_info_presupuesto(presupuesto, styles):
    """
    Crea tabla con información general del presupuesto
    
    Args:
        presupuesto (dict): Datos del presupuesto
        styles (dict): Diccionario de estilos
        
    Returns:
        Table: Tabla con información estructurada en 3 columnas x 2 filas
    """
    info_data = [
        [
            f"<b>NÚMERO:</b>",
            f"{presupuesto['numero_presupuesto']}",
            f"<b>ESTADO:</b>",
            f"{presupuesto['estado']}",
            f"<b>FECHA:</b>",
            f"{presupuesto['fecha_creacion'].strftime('%d/%m/%Y') if presupuesto['fecha_creacion'] else 'N/A'}"
        ],
        [
            f"<b>PROYECTO:</b>",
            f"{presupuesto.get('nombre_proyecto', 'N/A')}",
            f"<b>OBRA:</b>",
            f"{presupuesto.get('nombre_obra', 'N/A')}",
            f"<b>MONEDA:</b>",
            f"S/. (Soles)"
        ],
    ]
    
    info_table = Table(info_data, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
    info_table.setStyle(TableStyle([
        # Etiquetas (columnas pares: 0, 2, 4)
        ('TEXTCOLOR', (0, 0), (0, -1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (2, 0), (2, -1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (4, 0), (4, -1), PDFStyles.PRIMARY_COLOR),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
        ('FONTNAME', (4, 0), (4, -1), 'Helvetica-Bold'),
        
        # Valores (columnas impares: 1, 3, 5)
        ('TEXTCOLOR', (1, 0), (1, -1), PDFStyles.TEXT_DARK),
        ('TEXTCOLOR', (3, 0), (3, -1), PDFStyles.TEXT_DARK),
        ('TEXTCOLOR', (5, 0), (5, -1), PDFStyles.TEXT_DARK),
        
        # Estilos generales
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
        ('GRID', (0, 0), (-1, -1), 0.5, PDFStyles.BORDER_COLOR),
        ('ALIGNMENT', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    return info_table


# ============================================================================
# FUNCIÓN: Crear Información del Responsable
# ============================================================================

def crear_responsable(presupuesto, styles):
    """
    Crea tabla con información del usuario responsable
    
    Args:
        presupuesto (dict): Datos del presupuesto
        styles (dict): Diccionario de estilos
        
    Returns:
        tuple: (header_table, resp_table)
    """
    # Encabezado
    header_data = [['RESPONSABLE']]
    header_table = Table(header_data, colWidths=[7.35*inch])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 11),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 6),
        ('BOTTOMPADDING', (0, 0), (0, 0), 6),
    ]))
    
    # Datos responsable
    nombre_completo = f"{presupuesto.get('usuario_nombres', '')} {presupuesto.get('usuario_apellido', '')}".strip()
    
    resp_data = [[
        f"<b>Nombre:</b>",
        nombre_completo or 'N/A',
        f"<b>Email:</b>",
        presupuesto.get('usuario_email', 'N/A'),
        f"<b>Teléfono:</b>",
        presupuesto.get('usuario_celular', 'N/A'),
    ]]
    
    resp_table = Table(resp_data, colWidths=[0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch, 0.85*inch, 1.95*inch])
    resp_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#f5f5f5')),
        ('TEXTCOLOR', (0, 0), (0, -1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (2, 0), (2, -1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (4, 0), (4, -1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (1, 0), (-1, -1), PDFStyles.TEXT_DARK),
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (2, 0), (2, -1), 'Helvetica-Bold'),
        ('FONTNAME', (4, 0), (4, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 9),
        ('GRID', (0, 0), (-1, -1), 0.5, PDFStyles.BORDER_COLOR),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    return header_table, resp_table


# ============================================================================
# FUNCIÓN: Crear Tabla de Materiales
# ============================================================================

def crear_tabla_materiales(materiales, styles):
    """
    Crea tabla con detalles de materiales
    
    Args:
        materiales (list): Lista de materiales
        styles (dict): Diccionario de estilos
        
    Returns:
        tuple: (header_table, materiales_table) o (None, None) si está vacía
    """
    if not materiales:
        return None, None
    
    # Encabezado
    header_data = [['DETALLE DE MATERIALES']]
    header_table = Table(header_data, colWidths=[7.35*inch])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 11),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 6),
        ('BOTTOMPADDING', (0, 0), (0, 0), 6),
    ]))
    
    # Tabla de materiales
    mat_data = [['#', 'Material', 'Categoría', 'Unidad', 'Cantidad', 'P. Unit.', 'Subtotal']]
    
    for idx, material in enumerate(materiales, 1):
        mat_data.append([
            str(idx),
            material.get('material_nombre', 'N/A'),
            material.get('categoria', 'N/A'),
            material.get('unidad_medida', 'und'),
            f"{material.get('cantidad', 0):.2f}",
            f"S/. {material.get('precio_unitario', 0):.2f}",
            f"S/. {material.get('subtotal', 0):.2f}",
        ])
    
    mat_table = Table(mat_data, colWidths=[0.45*inch, 1.75*inch, 1.3*inch, 0.8*inch, 1.0*inch, 1.15*inch, 1.0*inch])
    mat_table.setStyle(TableStyle([
        # Encabezado
        ('BACKGROUND', (0, 0), (-1, 0), PDFStyles.HEADER_DARK),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('TOPPADDING', (0, 0), (-1, 0), 7),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 7),
        
        # Filas de datos
        ('TEXTCOLOR', (0, 1), (-1, -1), PDFStyles.TEXT_DARK),
        ('FONTNAME', (0, 1), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8),
        
        # Alineación
        ('ALIGN', (0, 1), (0, -1), 'CENTER'),
        ('ALIGN', (1, 1), (3, -1), 'LEFT'),
        ('ALIGN', (4, 1), (-1, -1), 'RIGHT'),
        
        # Filas alternas (Zebra striping)
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9f9f9')]),
        
        # Bordes
        ('GRID', (0, 0), (-1, -1), 0.5, PDFStyles.BORDER_COLOR),
        
        # Espaciado
        ('TOPPADDING', (0, 1), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 1), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    return header_table, mat_table


# ============================================================================
# FUNCIÓN: Crear Tabla de Servicios
# ============================================================================

def crear_tabla_servicios(servicios, styles):
    """
    Crea tabla con detalles de servicios
    
    Args:
        servicios (list): Lista de servicios
        styles (dict): Diccionario de estilos
        
    Returns:
        tuple: (header_table, servicios_table) o (None, None) si está vacía
    """
    if not servicios:
        return None, None
    
    # Encabezado
    header_data = [['DETALLE DE SERVICIOS']]
    header_table = Table(header_data, colWidths=[7.35*inch])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PDFStyles.SECONDARY_COLOR),
        ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 11),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 6),
        ('BOTTOMPADDING', (0, 0), (0, 0), 6),
    ]))
    
    # Tabla de servicios
    svc_data = [['#', 'Descripción', 'Cantidad', 'P. Unit.', 'Subtotal']]
    
    for idx, servicio in enumerate(servicios, 1):
        svc_data.append([
            str(idx),
            servicio.get('servicio_nombre', 'N/A'),
            f"{servicio.get('cantidad', 0):.2f}",
            f"S/. {servicio.get('precio_unitario', 0):.2f}",
            f"S/. {servicio.get('subtotal', 0):.2f}",
        ])
    
    svc_table = Table(svc_data, colWidths=[0.45*inch, 3.6*inch, 1.0*inch, 1.15*inch, 1.15*inch])
    svc_table.setStyle(TableStyle([
        # Encabezado
        ('BACKGROUND', (0, 0), (-1, 0), PDFStyles.HEADER_DARK),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('TOPPADDING', (0, 0), (-1, 0), 7),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 7),
        
        # Filas de datos
        ('TEXTCOLOR', (0, 1), (-1, -1), PDFStyles.TEXT_DARK),
        ('FONTNAME', (0, 1), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, -1), 8),
        
        # Alineación
        ('ALIGN', (0, 1), (0, -1), 'CENTER'),
        ('ALIGN', (1, 1), (1, -1), 'LEFT'),
        ('ALIGN', (2, 1), (-1, -1), 'RIGHT'),
        
        # Filas alternas
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#f9f9f9')]),
        
        # Bordes
        ('GRID', (0, 0), (-1, -1), 0.5, PDFStyles.BORDER_COLOR),
        
        # Espaciado
        ('TOPPADDING', (0, 1), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 1), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
    ]))
    
    return header_table, svc_table


# ============================================================================
# FUNCIÓN: Crear Desglose Financiero Mejorado con Estructura Completa
# ============================================================================

def crear_desglose_financiero(presupuesto, materiales, servicios, styles):
    """
    Crea tabla estructurada con desglose financiero completo
    
    Estructura:
    - COSTOS DIRECTOS (Materiales + Servicios)
    - Gastos Generales
    - Utilidad
    - SUB TOTAL (Costos Directos + GG + Utilidad)
    - IGV
    - Supervisión Obra
    - PRESUPUESTO DE EJECUCIÓN (SubTotal + IGV + Supervisión)
    
    Args:
        presupuesto (dict): Datos del presupuesto con campos desglose
        materiales (list): Lista de materiales
        servicios (list): Lista de servicios
        styles (dict): Diccionario de estilos
        
    Returns:
        tuple: (header_table, desglose_table)
    """
    # Calcular costos directos (suma de materiales y servicios)
    total_materiales = sum(m.get('subtotal', 0) for m in (materiales or []))
    total_servicios = sum(s.get('subtotal', 0) for s in (servicios or []))
    costos_directos = total_materiales + total_servicios
    
    # Obtener campos del presupuesto
    gastos_generales = presupuesto.get('gastos_generales', 0)
    utilidad = presupuesto.get('utilidad', 0)
    igv = presupuesto.get('igv', 0)
    supervision_obra = presupuesto.get('supervision_obra', 0)
    
    # Calcular subtotales
    subtotal = costos_directos + gastos_generales + utilidad
    presupuesto_ejecucion = subtotal + igv + supervision_obra
    
    # ====== ENCABEZADO ======
    header_data = [['DESGLOSE FINANCIERO']]
    header_table = Table(header_data, colWidths=[7.35*inch])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PDFStyles.ACCENT_COLOR),
        ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 11),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 6),
        ('BOTTOMPADDING', (0, 0), (0, 0), 6),
    ]))
    
    # ====== TABLA DE DESGLOSE ======
    desglose_data = [
        ['Concepto', 'Porcentaje', 'Monto'],
        # Costos Directos (sin detalle de materiales/servicios)
        ['COSTOS DIRECTOS', '-', f"S/. {costos_directos:,.2f}"],
        # Gastos Generales
        ['Gastos Generales', '10%', f"S/. {gastos_generales:,.2f}"],
        # Utilidad
        ['Utilidad', '15%', f"S/. {utilidad:,.2f}"],
        # Subtotal
        ['SUB TOTAL', '-', f"S/. {subtotal:,.2f}"],
        # IGV
        ['IGV', '18%', f"S/. {igv:,.2f}"],
        # Supervisión
        ['Supervisión de Obra', '5%', f"S/. {supervision_obra:,.2f}"],
        # Presupuesto de Ejecución
        ['PRESUPUESTO DE EJECUCIÓN DE OBRA', '-', f"S/. {presupuesto_ejecucion:,.2f}"],
    ]
    
    desglose_table = Table(desglose_data, colWidths=[3.5*inch, 1.5*inch, 2.35*inch])
    
    desglose_table.setStyle(TableStyle([
        # ====== ENCABEZADO DE TABLA ======
        ('BACKGROUND', (0, 0), (-1, 0), PDFStyles.HEADER_DARK),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
        ('ALIGN', (0, 0), (-1, 0), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 9),
        ('TOPPADDING', (0, 0), (-1, 0), 7),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 7),
        
        # ====== FILA 1: COSTOS DIRECTOS (Verde oscuro header) ======
        ('BACKGROUND', (0, 1), (-1, 1), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (0, 1), (-1, 1), colors.white),
        ('FONTNAME', (0, 1), (-1, 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 1), (-1, 1), 10),
        
        # ====== FILAS 2-3: GG y Utilidad (Naranja claro) ======
        ('BACKGROUND', (0, 2), (-1, 3), PDFStyles.LIGHT_ACCENT),
        ('FONTNAME', (0, 2), (-1, 3), 'Helvetica'),
        
        # ====== FILA 4: SUB TOTAL (Azul claro) ======
        ('BACKGROUND', (0, 4), (-1, 4), colors.HexColor('#e3f2fd')),
        ('FONTNAME', (0, 4), (-1, 4), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 4), (-1, 4), 10),
        
        # ====== FILAS 5-6: IGV y Supervisión (Naranja claro) ======
        ('BACKGROUND', (0, 5), (-1, 6), PDFStyles.LIGHT_ACCENT),
        ('FONTNAME', (0, 5), (-1, 6), 'Helvetica'),
        
        # ====== FILA 7: PRESUPUESTO DE EJECUCIÓN (Verde oscuro) ======
        ('BACKGROUND', (0, 7), (-1, 7), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (0, 7), (-1, 7), colors.white),
        ('FONTNAME', (0, 7), (-1, 7), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 7), (-1, 7), 11),
        
        # ====== ALINEACIÓN ======
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),           # Concepto izquierda
        ('ALIGN', (1, 0), (1, -1), 'CENTER'),         # Porcentaje centro
        ('ALIGN', (2, 0), (2, -1), 'RIGHT'),          # Monto derecha
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        
        # ====== BORDES ======
        ('GRID', (0, 0), (-1, -1), 0.5, PDFStyles.BORDER_COLOR),
        
        # ====== ESPACIADO ======
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        
        # ====== FUENTE ======
        ('FONTSIZE', (0, 0), (-1, -1), 9),
    ]))
    
    return header_table, desglose_table


# ============================================================================
# FUNCIÓN: Crear Observaciones
# ============================================================================

def crear_observaciones(presupuesto, styles):
    """
    Crea sección de observaciones si existen
    
    Args:
        presupuesto (dict): Datos del presupuesto
        styles (dict): Diccionario de estilos
        
    Returns:
        tuple: (header_table, obs_table) o (None, None)
    """
    if not presupuesto.get('observaciones'):
        return None, None
    
    # Encabezado
    header_data = [['OBSERVACIONES']]
    header_table = Table(header_data, colWidths=[7.35*inch])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), PDFStyles.PRIMARY_COLOR),
        ('TEXTCOLOR', (0, 0), (0, 0), colors.white),
        ('FONTNAME', (0, 0), (0, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (0, 0), 11),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 6),
        ('BOTTOMPADDING', (0, 0), (0, 0), 6),
    ]))
    
    # Contenido
    obs_text = str(presupuesto['observaciones']).replace('\n', '<br/>')
    obs_paragraph = Paragraph(obs_text, styles['normal'])
    
    obs_table = Table([[obs_paragraph]], colWidths=[7.35*inch])
    obs_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (0, 0), colors.HexColor('#f5f5f5')),
        ('LEFTPADDING', (0, 0), (0, 0), 8),
        ('RIGHTPADDING', (0, 0), (0, 0), 8),
        ('TOPPADDING', (0, 0), (0, 0), 8),
        ('BOTTOMPADDING', (0, 0), (0, 0), 8),
        ('GRID', (0, 0), (0, 0), 0.5, PDFStyles.BORDER_COLOR),
    ]))
    
    return header_table, obs_table


# ============================================================================
# FUNCIÓN: Crear Footer
# ============================================================================

def crear_footer(styles):
    """
    Crea pie de página con información de generación
    
    Args:
        styles (dict): Diccionario de estilos
        
    Returns:
        Paragraph: Párrafo con información del footer
    """
    footer_text = f"Generado el {datetime.now().strftime('%d/%m/%Y a las %H:%M:%S')} | KALLPA Sistema de Gestión"
    return Paragraph(footer_text, styles['footer'])


