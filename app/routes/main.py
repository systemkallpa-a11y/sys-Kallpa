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


@main_bp.route('/dashboard')
@login_required
def dashboard():
    """Dashboard con estadísticas y reportes"""
    return render_template('dashboard.html')


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


# ============================================================================
# RUTA: VACACIONES
# ============================================================================

@main_bp.route('/vacaciones')
@login_required
def vacaciones():
    """Vista de gestión de vacaciones"""
    num_documento = session.get('user_documento')
    
    # Validar acceso (Menú RR.HH = 1, asumiendo que Vacaciones será el siguiente submenu)
    # if not validar_acceso_usuario(num_documento, 1, None):  # Ajustar id_submenu cuando se cree en BD
    #     flash('No tienes acceso a este módulo', 'error')
    #     return redirect(url_for('main.dashboard'))
    
    return render_template('vacaciones.html')
