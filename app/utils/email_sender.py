"""
Módulo para envío de emails
"""
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import os

def enviar_email_con_adjunto(
    destinatario_email,
    destinatario_nombre,
    asunto,
    cuerpo_html,
    archivo_pdf_bytes,
    nombre_archivo_pdf,
    smtp_server='smtp.gmail.com',
    smtp_port=587,
    smtp_user=None,
    smtp_password=None
):
    """
    Enviar email con archivo PDF adjunto
    
    Args:
        destinatario_email: Email del destinatario
        destinatario_nombre: Nombre del destinatario
        asunto: Asunto del email
        cuerpo_html: Contenido HTML del email
        archivo_pdf_bytes: Bytes del PDF
        nombre_archivo_pdf: Nombre del archivo PDF
        smtp_server: Servidor SMTP
        smtp_port: Puerto SMTP
        smtp_user: Usuario SMTP
        smtp_password: Contraseña SMTP
    
    Returns:
        tuple: (success: bool, message: str)
    """
    
    # Validar email
    if not destinatario_email:
        return False, "Email del destinatario no proporcionado"
    
    # Obtener credenciales de variables de entorno si no se proporcionan
    if not smtp_user:
        smtp_user = os.getenv('SMTP_USER', '')
    if not smtp_password:
        smtp_password = os.getenv('SMTP_PASSWORD', '')
    
    if not smtp_user or not smtp_password:
        return False, "Credenciales SMTP no configuradas"
    
    try:
        # Crear mensaje
        msg = MIMEMultipart('alternative')
        msg['From'] = f"KALLPA Sistema <{smtp_user}>"
        msg['To'] = f"{destinatario_nombre} <{destinatario_email}>"
        msg['Subject'] = asunto
        
        # Agregar cuerpo HTML
        part_html = MIMEText(cuerpo_html, 'html', 'utf-8')
        msg.attach(part_html)
        
        # Agregar PDF adjunto
        part_pdf = MIMEBase('application', 'pdf')
        part_pdf.set_payload(archivo_pdf_bytes)
        encoders.encode_base64(part_pdf)
        part_pdf.add_header(
            'Content-Disposition',
            f'attachment; filename="{nombre_archivo_pdf}"'
        )
        msg.attach(part_pdf)
        
        # Conectar y enviar
        server = smtplib.SMTP(smtp_server, smtp_port)
        server.starttls()
        server.login(smtp_user, smtp_password)
        
        server.send_message(msg)
        server.quit()
        
        return True, "Email enviado exitosamente"
        
    except smtplib.SMTPAuthenticationError:
        return False, "Error de autenticación SMTP - Verifica las credenciales"
    except smtplib.SMTPException as e:
        return False, f"Error SMTP: {str(e)}"
    except Exception as e:
        return False, f"Error al enviar email: {str(e)}"


def generar_html_memo(nombre_empleado, tipo_memo, fecha_incidente):
    """Generar HTML para el email del memo"""
    
    tipos_texto = {
        'TARDANZA': 'Tardanza',
        'INASISTENCIA': 'Inasistencia',
        'FALTA': 'Inasistencia',
        'UNIFORME': 'Incumplimiento de Uniforme'
    }
    
    tipo_texto = tipos_texto.get(tipo_memo, tipo_memo)
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <style>
            body {{
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
            }}
            .header {{
                background: linear-gradient(135deg, #c00000 0%, #8b0000 100%);
                color: white;
                padding: 30px;
                text-align: center;
                border-radius: 8px 8px 0 0;
            }}
            .content {{
                background: #f9f9f9;
                padding: 30px;
                border: 1px solid #ddd;
                border-top: none;
                border-radius: 0 0 8px 8px;
            }}
            .warning-box {{
                background: #fff3cd;
                border-left: 4px solid #ff9800;
                padding: 15px;
                margin: 20px 0;
            }}
            .footer {{
                text-align: center;
                margin-top: 20px;
                padding-top: 20px;
                border-top: 1px solid #ddd;
                font-size: 12px;
                color: #666;
            }}
            .button {{
                display: inline-block;
                background: #c00000;
                color: white;
                padding: 12px 30px;
                text-decoration: none;
                border-radius: 5px;
                margin-top: 20px;
            }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1 style="margin: 0; font-size: 24px;">⚠️ MEMORANDO DE AMONESTACIÓN</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Sistema KALLPA</p>
        </div>
        
        <div class="content">
            <p><strong>Estimado(a) {nombre_empleado},</strong></p>
            
            <p>Por medio del presente, se le notifica que se ha generado un <strong>Memorando de Amonestación</strong> por:</p>
            
            <div class="warning-box">
                <strong>Motivo:</strong> {tipo_texto}<br>
                <strong>Fecha del Incidente:</strong> {fecha_incidente}
            </div>
            
            <p>Adjunto a este correo encontrará el documento oficial con los detalles completos de la amonestación.</p>
            
            <p><strong>Importante:</strong></p>
            <ul>
                <li>Este documento forma parte de su expediente laboral</li>
                <li>Debe firmar el acuse de recibo del memorando</li>
                <li>Tiene derecho a presentar sus descargos por escrito</li>
            </ul>
            
            <p>Para cualquier consulta o aclaración, por favor contacte al Departamento de Recursos Humanos.</p>
            
            <div class="footer">
                <p><strong>KALLPA</strong><br>
                Gerencia de Recursos Humanos<br>
                Este es un correo automático, por favor no responder a esta dirección.</p>
            </div>
        </div>
    </body>
    </html>
    """
    
    return html
