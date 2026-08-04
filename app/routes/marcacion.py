"""
Rutas para el sistema de marcación de asistencia
"""
from flask import Blueprint, render_template, request, session, jsonify
from functools import wraps
from mysql.connector import Error
from app.config import DatabaseConfig
from datetime import datetime
import mysql.connector

# Crear blueprint para marcación
marcacion_bp = Blueprint('marcacion', __name__)

# ============================================================================
# UTILIDADES
# ============================================================================

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
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            from flask import redirect, url_for, flash
            flash('Debes iniciar sesión para acceder a esta página', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


# ============================================================================
# RUTA: PÁGINA DE MARCACIÓN
# ============================================================================

@marcacion_bp.route('/marcacion-kallpa')
@login_required
def marcacion_kallpa():
    """Página de marcación de Kallpa (móvil)"""
    return render_template('marcacion_kallpa.html')


# ============================================================================
# API: REGISTRAR MARCACIÓN
# ============================================================================

@marcacion_bp.route('/api/marcacion/registrar', methods=['POST'])
@login_required
def registrar_marcacion():
    """Registrar marcación (entrada/salida) con GPS y foto"""
    from flask import current_app
    
    try:
        data = request.get_json()
        num_documento = session.get('user_documento')
        tipo_marcacion = data.get('tipo_marcacion')  # 'ENTRADA' o 'SALIDA'
        latitud = data.get('latitud')
        longitud = data.get('longitud')
        precision = data.get('precision')
        foto_base64 = data.get('foto_base64')
        
        print(f"[MARCACION] 🔄 Intentando registrar: documento={num_documento}, tipo={tipo_marcacion}")
        print(f"[MARCACION] 📍 GPS: lat={latitud}, lon={longitud}, precisión={precision}")
        print(f"[MARCACION] 📷 Foto: {'Sí' if foto_base64 else 'No'}")
        
        if not num_documento or not tipo_marcacion:
            print(f"[MARCACION] ❌ Datos incompletos")
            return jsonify({'success': False, 'error': 'Datos incompletos'}), 400
        
        connection = get_db_connection()
        if not connection:
            print(f"[MARCACION] ❌ Error de conexión a BD")
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[MARCACION] 📞 Llamando a SP con GPS y foto")
            
            # Llamar SP para registrar marcación con GPS y foto
            cursor.execute("""
                CALL sp_RegistrarMarcacionCompleta(
                    %s,  -- p_num_documento
                    %s,  -- p_tipo_marcacion
                    %s,  -- p_latitud
                    %s,  -- p_longitud
                    %s,  -- p_precision
                    %s,  -- p_foto_base64
                    @p_id_marcacion,
                    @p_mensaje
                );
                
                SELECT 
                    @p_id_marcacion as id_marcacion,
                    @p_mensaje as mensaje
            """, (num_documento, tipo_marcacion, latitud, longitud, precision, foto_base64))
            
            cursor.nextset()
            result = cursor.fetchone()
            
            print(f"[MARCACION] 📊 Resultado SP: {result}")
            
            # ✅ COMMIT CRÍTICO: Guardar cambios en la BD
            connection.commit()
            print(f"[MARCACION] 💾 COMMIT realizado")
            
            cursor.close()
            connection.close()
            
            if result and result.get('id_marcacion', 0) > 0:
                print(f"[MARCACION] ✅ Éxito: ID={result['id_marcacion']}, Mensaje={result.get('mensaje')}")
                return jsonify({
                    'success': True,
                    'message': result.get('mensaje', 'Marcación registrada exitosamente'),
                    'id_marcacion': result['id_marcacion']
                }), 201
            else:
                print(f"[MARCACION] ⚠️ SP retornó ID=0 o NULL")
                return jsonify({
                    'success': False,
                    'error': result.get('mensaje', 'Error al registrar marcación')
                }), 400
        
        except Error as e:
            print(f"[MARCACION] ❌ Error SQL: {str(e)}")
            current_app.logger.error(f"Error SQL en marcación: {str(e)}")
            return jsonify({'success': False, 'error': f'Error en la base de datos: {str(e)}'}), 500
    
    except Exception as e:
        print(f"[MARCACION] ❌ Error general: {str(e)}")
        current_app.logger.error(f"Error general en marcación: {str(e)}", exc_info=True)
        return jsonify({'success': False, 'error': 'Error en el servidor'}), 500


# ============================================================================
# API: OBTENER ESTADO DE MARCACIÓN
# ============================================================================

@marcacion_bp.route('/api/marcacion/estado', methods=['GET'])
@login_required
def obtener_estado_marcacion():
    """Obtener el estado actual de marcación del usuario (última entrada sin salida)"""
    from flask import current_app
    
    try:
        num_documento = session.get('user_documento')
        
        if not num_documento:
            return jsonify({'success': False, 'error': 'Usuario no identificado'}), 401
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Obtener la última marcación del día
            cursor.execute("""
                SELECT 
                    id_marcacion,
                    tipo_marcacion,
                    fecha_marcacion
                FROM TblMarcacion
                WHERE num_documento = %s
                    AND DATE(fecha_marcacion) = CURDATE()
                ORDER BY fecha_marcacion DESC
                LIMIT 1
            """, (num_documento,))
            
            ultima_marcacion = cursor.fetchone()
            
            cursor.close()
            connection.close()
            
            # Determinar el estado según la última marcación
            if ultima_marcacion:
                if ultima_marcacion['tipo_marcacion'] == 'ENTRADA':
                    estado = 'DENTRO'
                else:
                    estado = 'FUERA'
                
                # Convertir fecha_marcacion a string para extraer la hora
                fecha_hora = ultima_marcacion['fecha_marcacion']
                hora_str = fecha_hora.strftime('%H:%M:%S') if isinstance(fecha_hora, datetime) else str(fecha_hora).split()[1] if ' ' in str(fecha_hora) else str(fecha_hora)
                
                return jsonify({
                    'success': True,
                    'estado': estado,
                    'ultima_marcacion': ultima_marcacion['tipo_marcacion'],
                    'hora': hora_str
                }), 200
            else:
                return jsonify({
                    'success': True,
                    'estado': 'FUERA',
                    'ultima_marcacion': None,
                    'hora': None
                }), 200
        
        except Error as e:
            current_app.logger.error(f"Error SQL en estado marcación: {str(e)}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        current_app.logger.error(f"Error general en estado marcación: {str(e)}", exc_info=True)
        return jsonify({'success': False, 'error': 'Error en el servidor'}), 500


# ============================================================================
# API: OBTENER HISTORIAL DE MARCACIÓN
# ============================================================================

@marcacion_bp.route('/api/marcacion/historial', methods=['GET'])
@login_required
def obtener_historial_marcacion():
    """Obtener historial de marcaciones del usuario"""
    try:
        num_documento = session.get('user_documento')
        dias = request.args.get('dias', 7, type=int)
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[HISTORIAL] 🔄 Obteniendo historial para documento {num_documento}, últimos {dias} días")
            
            # Obtener historial de marcaciones desde TblMarcacion
            query = """
                SELECT 
                    id_marcacion,
                    num_documento,
                    tipo_marcacion,
                    fecha_marcacion
                FROM TblMarcacion
                WHERE num_documento = %s
                AND DATE(fecha_marcacion) >= DATE(NOW() - INTERVAL %s DAY)
                ORDER BY fecha_marcacion DESC
                LIMIT 100
            """
            cursor.execute(query, (num_documento, dias))
            marcaciones = cursor.fetchall()
            
            print(f"[HISTORIAL] ✅ {len(marcaciones)} marcaciones encontradas")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': marcaciones
            }), 200
        
        except Error as e:
            print(f"[HISTORIAL] ❌ Error SQL: {e}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        print(f"[HISTORIAL] ❌ Error general: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500
