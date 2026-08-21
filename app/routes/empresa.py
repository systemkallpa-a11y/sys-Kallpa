# -*- coding: utf-8 -*-
"""
Routes para gestin de Empresas
Maneja todas las operaciones CRUD de empresas
"""

from flask import render_template, request, jsonify
from . import main_bp
import mysql.connector
from mysql.connector import Error
from functools import wraps
from app.config import DatabaseConfig


def get_db_connection():
    """Crear conexin a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"Error de conexin: {e}")
        return None


# Decorador para requerir autenticacin
def login_required(f):
    """Decorador para proteger rutas que requieren autenticacin"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        from flask import session, redirect, url_for, flash
        # Verificar si est autenticado (puede ser user_email o user_documento)
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesin para acceder a esta pgina', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


@main_bp.route('/empresa')
@login_required
def empresa():
    """Pgina de registro y gestin de empresa"""
    from flask import session, redirect, url_for, flash
    from .main import validar_acceso_usuario
    
    # Validar que el usuario tenga acceso a Configuracin de Empresa
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[EMPRESA_ACCESS] Validando acceso a /empresa")
    print(f"[EMPRESA_ACCESS] Documento: {num_documento}")
    print(f"{'='*80}")
    
    # ID 4 = Configuracin
    # Permitir si tiene: acceso completo A Configuracin O acceso especfico a Empresa
    print(f"[EMPRESA_ACCESS] 1 Validando acceso COMPLETO a men 4 (id_submenu = NULL)...")
    tiene_acceso_completo = validar_acceso_usuario(num_documento, id_menu=4, id_submenu=None)
    print(f"[EMPRESA_ACCESS] Resultado acceso completo: {tiene_acceso_completo}")
    
    print(f"[EMPRESA_ACCESS] 2 Validando acceso especfico a men 4, submen 7 (Empresa)...")
    tiene_acceso_empresa = validar_acceso_usuario(num_documento, id_menu=4, id_submenu=7)
    print(f"[EMPRESA_ACCESS] Resultado acceso Empresa: {tiene_acceso_empresa}")
    
    print(f"[EMPRESA_ACCESS] [OK] Acceso completo: {tiene_acceso_completo}")
    print(f"[EMPRESA_ACCESS] [OK] Acceso Empresa: {tiene_acceso_empresa}")
    print(f"[EMPRESA_ACCESS] [OK] Acceso permitido: {tiene_acceso_completo or tiene_acceso_empresa}")
    
    if not (tiene_acceso_completo or tiene_acceso_empresa):
        print(f"[EMPRESA_ACCESS] [X] ACCESO DENEGADO - Redirigiendo a dashboard")
        print(f"{'='*80}\n")
        flash('No tienes acceso a Gestin de Empresa', 'danger')
        return redirect(url_for('main.dashboard'))
    
    print(f"[EMPRESA_ACCESS] [OK] ACCESO PERMITIDO - Cargando empresa.html")
    print(f"{'='*80}\n")
    return render_template('empresa.html')


@main_bp.route('/api/empresa/obtener', methods=['GET'])
@login_required
def obtener_empresas():
    """API para obtener todas las empresas"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT 
                    id_empresa,
                    ruc,
                    nombre,
                    latitud,
                    longitud,
                    radio_metros,
                    activa
                FROM TblEmpresa
                ORDER BY nombre
            """)
            
            empresas = cursor.fetchall()
            cursor.close()
            
            return jsonify({
                'success': True,
                'data': empresas
            }), 200
        
        except Exception as e:
            from flask import current_app
            current_app.logger.error(f"Error en obtener_empresas: {str(e)}")
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            if connection.is_connected():
                connection.close()
    
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general en obtener_empresas: {str(e)}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


@main_bp.route('/api/empresa/obtener/<int:id_empresa>', methods=['GET'])
@login_required
def obtener_empresa(id_empresa):
    """API para obtener una empresa por ID"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT 
                    id_empresa,
                    ruc,
                    nombre,
                    latitud,
                    longitud,
                    radio_metros,
                    activa
                FROM TblEmpresa
                WHERE id_empresa = %s
            """, (id_empresa,))
            
            empresa = cursor.fetchone()
            cursor.close()
            
            if not empresa:
                return jsonify({'success': False, 'error': 'Empresa no encontrada'}), 404
            
            return jsonify({
                'success': True,
                'data': empresa
            }), 200
        
        except Exception as e:
            from flask import current_app
            current_app.logger.error(f"Error en obtener_empresa: {str(e)}")
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            if connection.is_connected():
                connection.close()
    
    except Exception as e:
        from flask import current_app
        current_app.logger.error(f"Error general en obtener_empresa: {str(e)}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


@main_bp.route('/api/empresa/crear', methods=['POST'])
@login_required
def crear_empresa():
    """API para crear una nueva empresa (llama SP con soporte logo)"""
    from flask import current_app
    
    try:
        data = request.get_json()
        
        ruc = data.get('ruc', '').strip()
        nombre = data.get('nombre', '').strip()
        latitud = data.get('latitud')
        longitud = data.get('longitud')
        radio_metros = data.get('radio_metros')
        
        # Validaciones bsicas
        if not ruc:
            return jsonify({'success': False, 'error': 'El RUC es requerido'}), 400
        
        if len(ruc) != 11 or not ruc.isdigit():
            return jsonify({'success': False, 'error': 'El RUC debe tener exactamente 11 dgitos'}), 400
        
        if not nombre:
            return jsonify({'success': False, 'error': 'El nombre es requerido'}), 400
        
        # Validar latitud y longitud
        if latitud is None or longitud is None:
            return jsonify({'success': False, 'error': 'Latitud y longitud son requeridas'}), 400
        
        try:
            lat_float = float(latitud)
            lon_float = float(longitud)
        except (ValueError, TypeError):
            return jsonify({'success': False, 'error': 'Latitud y longitud deben ser nmeros vlidos'}), 400
        
        # Validar rangos de coordenadas geogrficas
        if lat_float < -90 or lat_float > 90:
            return jsonify({'success': False, 'error': 'La latitud debe estar entre -90 y 90'}), 400
        
        if lon_float < -180 or lon_float > 180:
            return jsonify({'success': False, 'error': 'La longitud debe estar entre -180 y 180'}), 400
        
        if not radio_metros or int(radio_metros) <= 0:
            return jsonify({'success': False, 'error': 'El radio debe ser mayor a 0'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin a BD'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Llamar SP sp_CrearEmpresa con logo = NULL (se cargar luego si es necesario)
            cursor.execute("""
                CALL sp_CrearEmpresa(%s, %s, %s, %s, %s, %s)
            """, (
                ruc,
                nombre,
                lat_float,
                lon_float,
                int(radio_metros),
                None  # logo = NULL
            ))
            
            connection.commit()
            
            # Obtener ID de la empresa recin creada
            cursor.execute("SELECT LAST_INSERT_ID() as id_empresa")
            result = cursor.fetchone()
            id_empresa = result[0] if result else None
            
            cursor.close()
            
            return jsonify({
                'success': True,
                'id_empresa': id_empresa,
                'mensaje': f'Empresa "{nombre}" creada exitosamente'
            }), 201
        
        except Exception as e:
            current_app.logger.error(f"Error al crear empresa: {str(e)}")
            error_msg = str(e)
            if 'Ya existe' in error_msg:
                return jsonify({'success': False, 'error': error_msg}), 400
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            if connection.is_connected():
                connection.close()
    
    except Exception as e:
        current_app.logger.error(f"Error general: {str(e)}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


@main_bp.route('/api/empresa/actualizar/<int:id_empresa>', methods=['PUT'])
@login_required
def actualizar_empresa(id_empresa):
    """API para actualizar una empresa (llama SP con soporte logo)"""
    from flask import current_app
    
    try:
        data = request.get_json()
        
        ruc = data.get('ruc', '').strip()
        nombre = data.get('nombre', '').strip()
        latitud = data.get('latitud')
        longitud = data.get('longitud')
        radio_metros = data.get('radio_metros')
        
        # Validaciones bsicas
        if not ruc:
            return jsonify({'success': False, 'error': 'El RUC es requerido'}), 400
        
        if len(ruc) != 11 or not ruc.isdigit():
            return jsonify({'success': False, 'error': 'El RUC debe tener exactamente 11 dgitos'}), 400
        
        if not nombre:
            return jsonify({'success': False, 'error': 'El nombre es requerido'}), 400
        
        # Validar latitud y longitud
        if latitud is None or longitud is None:
            return jsonify({'success': False, 'error': 'Latitud y longitud son requeridas'}), 400
        
        try:
            lat_float = float(latitud)
            lon_float = float(longitud)
        except (ValueError, TypeError):
            return jsonify({'success': False, 'error': 'Latitud y longitud deben ser nmeros vlidos'}), 400
        
        # Validar rangos de coordenadas geogrficas
        if lat_float < -90 or lat_float > 90:
            return jsonify({'success': False, 'error': 'La latitud debe estar entre -90 y 90'}), 400
        
        if lon_float < -180 or lon_float > 180:
            return jsonify({'success': False, 'error': 'La longitud debe estar entre -180 y 180'}), 400
        
        if not radio_metros or int(radio_metros) <= 0:
            return jsonify({'success': False, 'error': 'El radio debe ser mayor a 0'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin a BD'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Llamar SP sp_ActualizarEmpresa con logo = NULL (no se actualiza logo, se hace por separado)
            cursor.execute("""
                CALL sp_ActualizarEmpresa(%s, %s, %s, %s, %s, %s, %s)
            """, (
                id_empresa,
                ruc,
                nombre,
                lat_float,
                lon_float,
                int(radio_metros),
                None  # logo = NULL (se actualiza por separado)
            ))
            
            connection.commit()
            cursor.close()
            
            return jsonify({
                'success': True,
                'mensaje': f'Empresa "{nombre}" actualizada exitosamente'
            }), 200
        
        except Exception as e:
            current_app.logger.error(f"Error al actualizar empresa: {str(e)}")
            error_msg = str(e)
            if 'Ya existe' in error_msg:
                return jsonify({'success': False, 'error': error_msg}), 400
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            if connection.is_connected():
                connection.close()
    
    except Exception as e:
        current_app.logger.error(f"Error general: {str(e)}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


@main_bp.route('/api/empresa/eliminar/<int:id_empresa>', methods=['DELETE'])
@login_required
def eliminar_empresa(id_empresa):
    """API para eliminar una empresa"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Verificar que la empresa existe
            cursor.execute("SELECT id_empresa FROM TblEmpresa WHERE id_empresa = %s", (id_empresa,))
            if not cursor.fetchone():
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': 'Empresa no encontrada'}), 404
            
            # Eliminar empresa
            cursor.execute("DELETE FROM TblEmpresa WHERE id_empresa = %s", (id_empresa,))
            connection.commit()
            cursor.close()
            
            return jsonify({
                'success': True,
                'mensaje': 'Empresa eliminada exitosamente'
            }), 200
        
        except Exception as e:
            from flask import current_app
            current_app.logger.error(f"Error al eliminar empresa: {str(e)}")
            return jsonify({'success': False, 'error': str(e)}), 500
        finally:
            if connection.is_connected():
                connection.close()
    
    except Exception as e:
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500
