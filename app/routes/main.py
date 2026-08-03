from flask import render_template, redirect, url_for, session, request, flash, jsonify
from . import main_bp
import mysql.connector
from mysql.connector import Error
import hashlib
from functools import wraps
from app.config import DatabaseConfig

def get_db_connection():
    """Crear conexión a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"Error de conexión: {e}")
        return None

def hash_password(password):
    """Encriptar contraseña usando SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

# Decorador para requerir autenticación
def login_required(f):
    """Decorador para proteger rutas que requieren autenticación"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Verificar si está autenticado (puede ser user_email o user_documento)
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesión para acceder a esta página', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

# ============================================================================
# FUNCIÓN: VALIDAR ACCESO A MENÚ/SUBMENÚ
# ============================================================================

def validar_acceso_usuario(num_documento, id_menu, id_submenu=None):
    """
    Valida si un usuario tiene acceso a un menú o submenú específico
    
    Args:
        num_documento: Documento del usuario
        id_menu: ID del menú
        id_submenu: ID del submenú (None si es solo menú)
    
    Returns:
        Boolean: True si tiene acceso, False si no
    """
    connection = get_db_connection()
    if not connection:
        print(f"[VALIDAR_ACCESO] ❌ Error: No se pudo conectar a la BD")
        return False
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[VALIDAR_ACCESO] Validando: documento={num_documento}, menu={id_menu}, submenu={id_submenu}")
        
        # Verificar si el usuario tiene acceso completo al menú
        cursor.execute("""
            SELECT COUNT(*) as count
            FROM TblUsuarioAccesos
            WHERE num_documento = %s 
                AND id_menu = %s 
                AND id_submenu IS NULL 
                AND estado = 'ACTIVO'
        """, (num_documento, id_menu))
        
        result = cursor.fetchone()
        count_completo = result['count']
        
        print(f"[VALIDAR_ACCESO]   → Acceso completo (id_submenu IS NULL): {count_completo}")
        
        # Si tiene acceso completo al menú, permitir
        if count_completo > 0:
            print(f"[VALIDAR_ACCESO]   ✅ PERMITIDO (acceso completo)")
            cursor.close()
            connection.close()
            return True
        
        # Si se especifica un submenú, verificar acceso específico
        if id_submenu is not None:
            cursor.execute("""
                SELECT COUNT(*) as count
                FROM TblUsuarioAccesos
                WHERE num_documento = %s 
                    AND id_menu = %s 
                    AND id_submenu = %s 
                    AND estado = 'ACTIVO'
            """, (num_documento, id_menu, id_submenu))
            
            result = cursor.fetchone()
            count_especifico = result['count']
            
            print(f"[VALIDAR_ACCESO]   → Acceso específico (id_submenu={id_submenu}): {count_especifico}")
            
            cursor.close()
            connection.close()
            
            if count_especifico > 0:
                print(f"[VALIDAR_ACCESO]   ✅ PERMITIDO (acceso específico)")
                return True
            else:
                print(f"[VALIDAR_ACCESO]   ❌ DENEGADO (sin acceso)")
                return False
        
        print(f"[VALIDAR_ACCESO]   ❌ DENEGADO (sin acceso completo ni específico)")
        cursor.close()
        connection.close()
        return False
    
    except Error as e:
        print(f"[VALIDAR_ACCESO] ❌ Error SQL: {e}")
        if connection:
            connection.close()
        return False

@main_bp.route('/')
def index():
    """Ruta raíz - SIEMPRE va a welcome"""
    # IMPORTANTE: Siempre redirige a welcome, no importa si hay sesión
    # La sesión se verifica en welcome o login, no en la ruta raíz
    return redirect(url_for('auth.show_welcome'))

@main_bp.route('/marcacion-kallpa')
@login_required
def marcacion_kallpa():
    """Página de marcación de Kallpa"""
    return render_template('marcacion_kallpa.html')

@main_bp.route('/dashboard')
@login_required
def dashboard():
    """Dashboard con estadísticas y reportes"""
    return render_template('dashboard.html')


@main_bp.route('/api/marcacion/registrar', methods=['POST'])
@login_required
def registrar_marcacion():
    """Registrar marcación (entrada/salida)"""
    from flask import current_app
    
    try:
        data = request.get_json()
        num_documento = session.get('user_documento')
        tipo_marcacion = data.get('tipo_marcacion')  # 'ENTRADA' o 'SALIDA'
        
        if not num_documento or not tipo_marcacion:
            return jsonify({'success': False, 'error': 'Datos incompletos'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Llamar SP para registrar marcación
            cursor.execute("""
                CALL sp_RegistrarMarcacion(
                    %s,  -- p_num_documento
                    %s,  -- p_tipo_marcacion
                    @p_id_marcacion,
                    @p_mensaje
                );
                
                SELECT 
                    @p_id_marcacion as id_marcacion,
                    @p_mensaje as mensaje
            """, (num_documento, tipo_marcacion))
            
            cursor.nextset()
            result = cursor.fetchone()
            
            cursor.close()
            connection.close()
            
            if result and result.get('id_marcacion', 0) > 0:
                return jsonify({
                    'success': True,
                    'message': result.get('mensaje', 'Marcación registrada exitosamente'),
                    'id_marcacion': result['id_marcacion']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': result.get('mensaje', 'Error al registrar marcación')
                }), 400
        
        except Error as e:
            current_app.logger.error(f"Error SQL en marcación: {str(e)}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        current_app.logger.error(f"Error general en marcación: {str(e)}", exc_info=True)
        return jsonify({'success': False, 'error': 'Error en el servidor'}), 500


@main_bp.route('/api/marcacion/estado', methods=['GET'])
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
                    fecha_hora,
                    DATE_FORMAT(fecha_hora, '%H:%i:%s') as hora_marcacion
                FROM TblMarcacion
                WHERE num_documento = %s
                    AND DATE(fecha_hora) = CURDATE()
                ORDER BY fecha_hora DESC
                LIMIT 1
            """, (num_documento,))
            
            ultima_marcacion = cursor.fetchone()
            
            cursor.close()
            connection.close()
            
            if ultima_marcacion:
                return jsonify({
                    'success': True,
                    'tiene_marcacion': True,
                    'ultima_marcacion': ultima_marcacion['tipo_marcacion'],
                    'hora': ultima_marcacion['hora_marcacion'],
                    'puede_marcar_entrada': ultima_marcacion['tipo_marcacion'] == 'SALIDA',
                    'puede_marcar_salida': ultima_marcacion['tipo_marcacion'] == 'ENTRADA'
                }), 200
            else:
                return jsonify({
                    'success': True,
                    'tiene_marcacion': False,
                    'ultima_marcacion': None,
                    'puede_marcar_entrada': True,
                    'puede_marcar_salida': False
                }), 200
        
        except Error as e:
            current_app.logger.error(f"Error SQL en estado marcación: {str(e)}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        current_app.logger.error(f"Error general en estado marcación: {str(e)}", exc_info=True)
        return jsonify({'success': False, 'error': 'Error en el servidor'}), 500
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500

@main_bp.route('/api/marcacion/historial', methods=['GET'])
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

# ============================================================================
# API: OBTENER ACCESOS DEL USUARIO ACTUAL
# ============================================================================

@main_bp.route('/api/mi-acceso/obtener', methods=['GET'])
@login_required
def obtener_mi_acceso():
    """Obtener menús y submenús a los que tiene acceso el usuario actual"""
    num_documento = session.get('user_documento')
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[MI_ACCESO] Obteniendo accesos para documento: {num_documento}")
        
        # Obtener menús accesibles
        cursor.execute("""
            SELECT DISTINCT
                m.id_menu,
                m.nombre,
                m.icono,
                m.orden
            FROM TblMenu m
            JOIN TblUsuarioAccesos ua ON m.id_menu = ua.id_menu
            WHERE ua.num_documento = %s 
                AND ua.estado = 'ACTIVO'
                AND m.estado = 'ACTIVO'
            ORDER BY m.orden
        """, (num_documento,))
        
        menus = cursor.fetchall()
        
        # Obtener submenús accesibles (específicos solamente)
        cursor.execute("""
            SELECT 
                sm.id_submenu,
                sm.id_menu,
                sm.nombre,
                sm.ruta,
                sm.icono,
                sm.orden
            FROM TblSubMenu sm
            JOIN TblUsuarioAccesos ua ON sm.id_submenu = ua.id_submenu
            WHERE ua.num_documento = %s 
                AND ua.id_submenu IS NOT NULL
                AND ua.estado = 'ACTIVO'
                AND sm.estado = 'ACTIVO'
            ORDER BY sm.id_menu, sm.orden
        """, (num_documento,))
        
        submenus_especificos = cursor.fetchall()
        
        # Obtener menús con acceso COMPLETO (id_submenu = NULL)
        cursor.execute("""
            SELECT DISTINCT id_menu
            FROM TblUsuarioAccesos
            WHERE num_documento = %s 
                AND id_submenu IS NULL 
                AND estado = 'ACTIVO'
        """, (num_documento,))
        
        menus_completos = [row['id_menu'] for row in cursor.fetchall()]
        
        print(f"[MI_ACCESO] {len(menus)} menús, {len(submenus_especificos)} submenús específicos, {len(menus_completos)} menús completos")
        print(f"[MI_ACCESO] Menús con acceso completo: {menus_completos}")
        
        # Para menús con acceso COMPLETO, obtener TODOS sus submenús
        submenus = list(submenus_especificos)  # Copiar submenús específicos
        
        for id_menu_completo in menus_completos:
            print(f"[MI_ACCESO] Obteniendo todos los submenús para menú completo: {id_menu_completo}")
            
            cursor.execute("""
                SELECT 
                    sm.id_submenu,
                    sm.id_menu,
                    sm.nombre,
                    sm.ruta,
                    sm.icono,
                    sm.orden
                FROM TblSubMenu sm
                WHERE sm.id_menu = %s 
                    AND sm.estado = 'ACTIVO'
                ORDER BY sm.orden
            """, (id_menu_completo,))
            
            submenus_menu_completo = cursor.fetchall()
            print(f"[MI_ACCESO] Se agregaron {len(submenus_menu_completo)} submenús para menú {id_menu_completo}")
            submenus.extend(submenus_menu_completo)
        
        print(f"[MI_ACCESO] Total de submenús a mostrar: {len(submenus)}")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'menus': menus,
            'submenus': submenus,
            'menus_completos': menus_completos
        }), 200
    
    except Error as e:
        print(f"[MI_ACCESO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
