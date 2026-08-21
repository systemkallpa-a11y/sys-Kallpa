"""
Module: empresa_logo.py
Propsito: Manejar carga y descarga de logos de empresa
Fecha: 10 Julio 2026
"""

from flask import Blueprint, jsonify, request, send_file
from functools import wraps
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig
import io
import os

# Blueprint
logo_bp = Blueprint('empresa_logo', __name__)

# Configuracin de carga de archivos
ALLOWED_EXTENSIONS = {'png'}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB


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
    """Decorador para proteger rutas"""
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


def allowed_file(filename):
    """Verificar si el archivo es PNG"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@logo_bp.route('/api/empresa/logo/subir', methods=['POST'])
@login_required
def subir_logo_empresa():
    """Subir logo de empresa (PNG)"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        # Verificar que se proporcion archivo
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No se proporcion archivo'}), 400
        
        file = request.files['file']
        
        if file.filename == '':
            return jsonify({'success': False, 'error': 'El nombre del archivo est vaco'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'success': False, 'error': 'Solo se permiten archivos PNG'}), 400
        
        # Verificar tamao del archivo
        file.seek(0, os.SEEK_END)
        file_size = file.tell()
        file.seek(0)
        
        if file_size > MAX_FILE_SIZE:
            return jsonify({'success': False, 'error': f'Archivo muy grande. Mximo {MAX_FILE_SIZE / (1024*1024):.0f} MB'}), 400
        
        # Leer contenido del archivo
        logo_data = file.read()
        
        # Obtener ID de empresa del formulario
        id_empresa = request.form.get('id_empresa', 1)
        
        cursor = connection.cursor()
        
        # Verificar si la empresa existe
        cursor.execute("SELECT id_empresa FROM TblEmpresa WHERE id_empresa = %s", (id_empresa,))
        if not cursor.fetchone():
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Empresa no encontrada'}), 404
        
        # Actualizar logo
        cursor.execute("""
            UPDATE TblEmpresa 
            SET logo = %s
            WHERE id_empresa = %s
        """, (logo_data, id_empresa))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True, 
            'message': 'Logo subido correctamente',
            'size': file_size
        }), 200
        
    except Error as e:
        print(f"[LOGO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[LOGO] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@logo_bp.route('/api/empresa/logo/descargar/<int:id_empresa>', methods=['GET'])
def descargar_logo_empresa(id_empresa):
    """Descargar logo de empresa"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Obtener logo
        cursor.execute("""
            SELECT logo
            FROM TblEmpresa 
            WHERE id_empresa = %s AND logo IS NOT NULL
        """, (id_empresa,))
        
        resultado = cursor.fetchone()
        cursor.close()
        connection.close()
        
        if not resultado or not resultado['logo']:
            return jsonify({'success': False, 'error': 'Logo no encontrado'}), 404
        
        # Retornar imagen PNG
        return send_file(
            io.BytesIO(resultado['logo']),
            mimetype='image/png',
            as_attachment=False,
            download_name='logo.png'
        )
        
    except Error as e:
        print(f"[LOGO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[LOGO] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@logo_bp.route('/api/empresa/logo/info/<int:id_empresa>', methods=['GET'])
def info_logo_empresa(id_empresa):
    """Obtener informacin del logo"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Obtener informacin
        cursor.execute("""
            SELECT 
                id_empresa,
                LENGTH(logo) as tamanio_bytes,
                CASE WHEN logo IS NOT NULL THEN 'SI' ELSE 'NO' END as tiene_logo
            FROM TblEmpresa 
            WHERE id_empresa = %s
        """, (id_empresa,))
        
        resultado = cursor.fetchone()
        cursor.close()
        connection.close()
        
        if not resultado:
            return jsonify({'success': False, 'error': 'Empresa no encontrada'}), 404
        
        return jsonify({
            'success': True,
            'data': {
                'id_empresa': resultado['id_empresa'],
                'tamanio_kb': round(resultado['tamanio_bytes'] / 1024, 2) if resultado['tamanio_bytes'] else 0,
                'tiene_logo': resultado['tiene_logo']
            }
        }), 200
        
    except Error as e:
        print(f"[LOGO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[LOGO] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@logo_bp.route('/api/empresa/logo/eliminar/<int:id_empresa>', methods=['DELETE'])
@login_required
def eliminar_logo_empresa(id_empresa):
    """Eliminar logo de empresa"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor()
        
        # Verificar si la empresa existe
        cursor.execute("SELECT id_empresa FROM TblEmpresa WHERE id_empresa = %s", (id_empresa,))
        if not cursor.fetchone():
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Empresa no encontrada'}), 404
        
        # Eliminar logo
        cursor.execute("""
            UPDATE TblEmpresa 
            SET logo = NULL
            WHERE id_empresa = %s
        """, (id_empresa,))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True, 
            'message': 'Logo eliminado correctamente'
        }), 200
        
    except Error as e:
        print(f"[LOGO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[LOGO] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
