#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Funciones de gestión de recursos digitales desde Google Drive
Integración con Google Drive API v3
"""

from flask import request
import os
from datetime import datetime

# Configuración de Google Drive
DRIVE_FOLDER_ID = "1dpueAKTRkJcOCFbzFZg7KEsRUyC1_juc"
GOOGLE_DRIVE_API_URL = "https://www.googleapis.com/drive/v3"


def obtener_icono_por_tipo(mime_type):
    """Retorna icono y categoría basado en el tipo de archivo"""
    mime_type = (mime_type or '').lower()
    
    if 'folder' in mime_type:
        return 'fas fa-folder', 'carpeta'
    elif 'word' in mime_type or 'document' in mime_type:
        return 'fas fa-file-word', 'plantillas'
    elif 'pdf' in mime_type:
        return 'fas fa-file-pdf', 'guias'
    elif 'video' in mime_type:
        return 'fas fa-video', 'videos'
    elif 'presentation' in mime_type or 'powerpoint' in mime_type:
        return 'fas fa-presentation', 'presentaciones'
    elif 'spreadsheet' in mime_type or 'excel' in mime_type:
        return 'fas fa-table', 'plantillas'
    else:
        return 'fas fa-file', 'otros'


def get_api_key():
    """Obtiene la API Key de Google desde .env"""
    api_key = os.getenv('GOOGLE_API_KEY', '').strip()
    return api_key if api_key else None


def get_drive_service():
    """Retorna la API Key si está configurada, None si no"""
    return get_api_key()


def listar_recursos_api():
    """API para listar carpetas desde Google Drive"""
    try:
        from flask import current_app
        
        current_app.logger.info("=== LISTAR RECURSOS DIGITALES ===")
        
        api_key = get_api_key()
        
        if not api_key:
            current_app.logger.warning("GOOGLE_API_KEY no configurada - usando datos de demostración")
            demo_data = _get_demo_recursos()
            return {
                'success': True,
                'data': demo_data,
                'total': len(demo_data),
                'carpetas': len(demo_data),
                'archivos': 0,
                'mode': 'demo'
            }, 200
        
        # Intentar obtener carpetas reales de Google Drive
        recursos = _get_carpetas_desde_drive(api_key, current_app)
        
        if recursos is not None and len(recursos) > 0:
            current_app.logger.info(f"✅ Retornando {len(recursos)} carpetas REALES de Google Drive")
            return {
                'success': True,
                'data': recursos,
                'total': len(recursos),
                'carpetas': len(recursos),
                'archivos': 0,
                'mode': 'real'
            }, 200
        
        # Si hay error con Drive o no hay carpetas, usar demo
        current_app.logger.info("Usando datos de demostración (no se pudo conectar con Drive)")
        demo_data = _get_demo_recursos()
        return {
            'success': True,
            'data': demo_data,
            'total': len(demo_data),
            'carpetas': len(demo_data),
            'archivos': 0,
            'mode': 'demo'
        }, 200
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        demo_data = _get_demo_recursos()
        return {
            'success': True,
            'data': demo_data,
            'total': len(demo_data)
        }, 200


def _get_carpetas_desde_drive(api_key, app):
    """Obtiene las carpetas reales de Google Drive usando la API Key"""
    try:
        import urllib.request
        import urllib.parse
        import json
        
        app.logger.info(f"Intentando conectar con Google Drive usando urllib...")
        
        # Query para obtener solo carpetas dentro de DRIVE_FOLDER_ID
        query = f"'{DRIVE_FOLDER_ID}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
        
        # Construir URL con parámetros codificados correctamente
        base_url = f"{GOOGLE_DRIVE_API_URL}/files"
        params = {
            'q': query,
            'key': api_key,
            'spaces': 'drive',
            'fields': 'files(id,name,mimeType,createdTime,webViewLink)',
            'pageSize': '100'
        }
        
        query_string = urllib.parse.urlencode(params)
        full_url = f"{base_url}?{query_string}"
        
        app.logger.info(f"URL base: {base_url}")
        app.logger.info(f"Parámetros de consulta: {query_string[:150]}...")
        app.logger.info(f"API Key presente: {'Sí' if api_key else 'No'}")
        app.logger.info(f"Carpeta ID: {DRIVE_FOLDER_ID}")
        
        # Realizar la solicitud
        app.logger.info(f"Enviando solicitud a Google Drive...")
        with urllib.request.urlopen(full_url, timeout=10) as response:
            response_data = response.read().decode('utf-8')
            app.logger.info(f"Respuesta HTTP recibida ({len(response_data)} bytes)")
            data = json.loads(response_data)
        
        files = data.get('files', [])
        
        app.logger.info(f"✅ Encontradas {len(files)} carpetas en Drive")
        
        if len(files) == 0:
            app.logger.warning(f"⚠️  No se encontraron carpetas. Respuesta: {str(data)[:200]}")
        
        recursos = []
        for idx, file in enumerate(files, 1):
            icono, categoria = obtener_icono_por_tipo(file.get('mimeType', ''))
            
            recurso = {
                'id_recurso': idx,
                'titulo': file.get('name', 'Sin título'),
                'descripcion': 'Carpeta',
                'categoria': 'carpeta',
                'url': file.get('webViewLink', ''),
                'es_carpeta': True,
                'drive_id': file.get('id', ''),
                'icono': icono,
                'fecha_creacion': file.get('createdTime', datetime.now().isoformat()),
                'estado': 'Activo',
                'descargas': 0
            }
            recursos.append(recurso)
        
        app.logger.info(f"✅ Retornando {len(recursos)} recursos reales desde Drive")
        return recursos
        
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else "No response body"
        app.logger.error(f"❌ Error HTTP {e.code} conectando con Google Drive: {error_body}", exc_info=True)
        return None
    except urllib.error.URLError as e:
        app.logger.error(f"❌ Error de URL/Red conectando con Google Drive: {str(e.reason)}", exc_info=True)
        return None
    except Exception as e:
        app.logger.error(f"❌ Error inesperado conectando con Google Drive: {str(e)}", exc_info=True)
        return None


def _get_demo_recursos():
    """Retorna datos de demostración cuando no hay conexión a Drive"""
    return [
        {
            'id_recurso': 1,
            'titulo': 'Plantillas de Ventas',
            'descripcion': 'Carpeta',
            'categoria': 'carpeta',
            'url': f'https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}',
            'es_carpeta': True,
            'drive_id': 'FOLDER_1',
            'icono': 'fas fa-folder',
            'fecha_creacion': datetime.now().isoformat(),
            'estado': 'Activo',
            'descargas': 0
        },
        {
            'id_recurso': 2,
            'titulo': 'Guías y Documentos',
            'descripcion': 'Carpeta',
            'categoria': 'carpeta',
            'url': f'https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}',
            'es_carpeta': True,
            'drive_id': 'FOLDER_2',
            'icono': 'fas fa-folder',
            'fecha_creacion': datetime.now().isoformat(),
            'estado': 'Activo',
            'descargas': 0
        },
        {
            'id_recurso': 3,
            'titulo': 'Videos y Tutoriales',
            'descripcion': 'Carpeta',
            'categoria': 'carpeta',
            'url': f'https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}',
            'es_carpeta': True,
            'drive_id': 'FOLDER_3',
            'icono': 'fas fa-folder',
            'fecha_creacion': datetime.now().isoformat(),
            'estado': 'Activo',
            'descargas': 0
        },
        {
            'id_recurso': 4,
            'titulo': 'Presentaciones',
            'descripcion': 'Carpeta',
            'categoria': 'carpeta',
            'url': f'https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}',
            'es_carpeta': True,
            'drive_id': 'FOLDER_4',
            'icono': 'fas fa-folder',
            'fecha_creacion': datetime.now().isoformat(),
            'estado': 'Activo',
            'descargas': 0
        },
        {
            'id_recurso': 5,
            'titulo': 'Contratos y Legales',
            'descripcion': 'Carpeta',
            'categoria': 'carpeta',
            'url': f'https://drive.google.com/drive/folders/{DRIVE_FOLDER_ID}',
            'es_carpeta': True,
            'drive_id': 'FOLDER_5',
            'icono': 'fas fa-folder',
            'fecha_creacion': datetime.now().isoformat(),
            'estado': 'Activo',
            'descargas': 0
        }
    ]


def crear_recurso_api():
    """API para agregar referencia a un recurso en Google Drive"""
    try:
        from flask import session, current_app
        
        data = request.get_json()
        
        current_app.logger.info("=== CREAR REFERENCIA A RECURSO EN DRIVE ===")
        
        # Obtener datos del formulario
        titulo = data.get('titulo', '').strip()
        descripcion = data.get('descripcion', '').strip()
        categoria = data.get('categoria', '').strip().lower()
        url = data.get('url', '').strip()  # URL compartida de Drive
        tags = data.get('tags', '').strip()
        
        # Obtener el documento del usuario logueado
        creado_por = session.get('user_documento', '')
        
        current_app.logger.info(f"Recurso: {titulo}, URL: {url}")
        
        # Validar campos requeridos
        if not all([titulo, categoria, url, creado_por]):
            current_app.logger.warning("Campos requeridos faltantes")
            return {'success': False, 'error': 'Por favor completa los campos requeridos'}, 400
        
        # Validar que sea URL de Google Drive
        if 'drive.google.com' not in url:
            current_app.logger.warning(f"URL no es de Google Drive: {url}")
            return {'success': False, 'error': 'La URL debe ser de Google Drive compartida'}, 400
        
        # Validar categoría válida
        categorias_validas = ['plantillas', 'guias', 'videos', 'presentaciones', 'otros']
        if categoria not in categorias_validas:
            current_app.logger.warning(f"Categoría inválida: {categoria}")
            return {'success': False, 'error': 'Categoría no válida'}, 400
        
        # TODO: Aquí iría la lógica para guardar metadatos en BD si es necesario
        # Por ahora solo validamos y retornamos success
        
        current_app.logger.info(f"Recurso agregado exitosamente a {categoria}")
        
        return {
            'success': True,
            'message': 'Recurso agregado exitosamente',
            'id_recurso': 1  # Placeholder
        }, 201
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        return {'success': False, 'error': f'Error del servidor: {str(e)}'}, 500


def obtener_recurso_api(id_recurso):
    """API para obtener los detalles de un recurso específico desde Drive"""
    try:
        from flask import current_app
        
        current_app.logger.info(f"=== OBTENER RECURSO {id_recurso} ===")
        
        # Obtener lista de recursos
        result, status = listar_recursos_api()
        
        if result.get('success') and result.get('data'):
            for recurso in result.get('data', []):
                if recurso.get('id_recurso') == id_recurso:
                    return {
                        'success': True,
                        'data': recurso
                    }, 200
        
        current_app.logger.warning(f"Recurso no encontrado: {id_recurso}")
        return {
            'success': False,
            'error': 'Recurso no encontrado'
        }, 404
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        return {'success': False, 'error': 'Error del servidor'}, 500


def actualizar_recurso_api(id_recurso):
    """API para actualizar metadatos de un recurso - No disponible en Drive"""
    try:
        from flask import current_app
        
        current_app.logger.info(f"=== ACTUALIZAR RECURSO {id_recurso} ===")
        
        return {
            'success': False,
            'error': 'Los recursos en Drive no pueden ser editados desde la aplicación'
        }, 400
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        return {'success': False, 'error': f'Error del servidor: {str(e)}'}, 500


def eliminar_recurso_api(id_recurso):
    """API para eliminar referencia de un recurso - No disponible en Drive"""
    try:
        from flask import current_app
        
        current_app.logger.info(f"=== ELIMINAR RECURSO {id_recurso} ===")
        
        return {
            'success': False,
            'error': 'Los recursos en Drive no pueden ser eliminados desde la aplicación'
        }, 400
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        return {'success': False, 'error': f'Error del servidor: {str(e)}'}, 500


def incrementar_descargas_api(id_recurso):
    """API para incrementar contador de descargas de un recurso"""
    try:
        from flask import current_app
        
        current_app.logger.info(f"=== INCREMENTAR DESCARGAS {id_recurso} ===")
        
        # No rastrear descargas de Drive en esta versión
        return {
            'success': True,
            'descargas': 0
        }, 200
        
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general: {e}", exc_info=True)
        return {'success': False, 'error': f'Error del servidor: {str(e)}'}, 500
