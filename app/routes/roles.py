from flask import render_template, request, jsonify, session, redirect, url_for, flash
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
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

# ============================================================================
# RUTAS PRINCIPALES
# ============================================================================

@main_bp.route('/roles')
@login_required
def roles():
    """Pgina de gestin de roles y accesos de usuarios"""
    # Validar que el usuario tenga acceso a Usuarios y Accesos
    num_documento = session.get('user_documento')
    
    # ID 4 = Configuracin, ID 8 = Rol y Accesos (submen)
    # Permitir si tiene: acceso completo A Configuracin O acceso especfico a Rol y Accesos
    from .main import validar_acceso_usuario
    
    tiene_acceso_completo = validar_acceso_usuario(num_documento, id_menu=4, id_submenu=None)
    tiene_acceso_roles = validar_acceso_usuario(num_documento, id_menu=4, id_submenu=8)
    
    if not (tiene_acceso_completo or tiene_acceso_roles):
        flash('No tienes acceso a Gestin de Accesos', 'danger')
        return redirect(url_for('main.dashboard'))
    
    return render_template('roles.html')

# ============================================================================
# API: OBTENER USUARIOS CON ACCESOS
# ============================================================================

@main_bp.route('/api/usuarios-accesos/obtener', methods=['GET'])
@login_required
def obtener_usuarios_accesos():
    """Obtener lista de usuarios con sus accesos a mens y submens"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("[USUARIOS_ACCESOS] Iniciando obtencin de usuarios y accesos")
        
        # Llamar SP que retorna usuarios con informacin de accesos
        cursor.callproc('sp_ObtenerUsuariosAccesos')
        
        # Obtener resultados del SP
        usuarios = []
        for result in cursor.stored_results():
            usuarios = result.fetchall()
        
        print(f"[USUARIOS_ACCESOS] {len(usuarios)} usuarios obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': usuarios}), 200
    
    except Error as e:
        print(f"[USUARIOS_ACCESOS] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# API: OBTENER ACCESOS DETALLADOS DE UN USUARIO
# ============================================================================

@main_bp.route('/api/usuarios-accesos/<int:num_documento>', methods=['GET'])
@login_required
def obtener_accesos_usuario(num_documento):
    """Obtener accesos detallados de un usuario especfico"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[USUARIO_ACCESOS] Obteniendo accesos para documento: {num_documento}")
        
        # Llamar SP que retorna accesos del usuario
        cursor.callproc('sp_ObtenerAccesosUsuario', (num_documento,))
        
        # Obtener resultados del SP
        accesos = []
        for result in cursor.stored_results():
            accesos = result.fetchall()
        
        print(f"[USUARIO_ACCESOS] {len(accesos)} accesos encontrados")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': accesos}), 200
    
    except Error as e:
        print(f"[USUARIO_ACCESOS] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# API: OBTENER MENS Y SUBMENS
# ============================================================================

@main_bp.route('/api/menus-submenus/obtener', methods=['GET'])
@login_required
def obtener_menus_submenus():
    """Obtener estructura completa de mens y submens"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("[MENUS_SUBMENUS] Obteniendo estructura de mens")
        
        # Obtener mens activos
        cursor.execute("""
            SELECT id_menu, nombre, icono, orden, estado
            FROM TblMenu
            WHERE estado = 'ACTIVO'
            ORDER BY orden
        """)
        
        menus = cursor.fetchall()
        
        # Obtener submens activos
        cursor.execute("""
            SELECT id_submenu, id_menu, nombre, ruta, icono, orden, estado
            FROM TblSubMenu
            WHERE estado = 'ACTIVO'
            ORDER BY id_menu, orden
        """)
        
        submenus = cursor.fetchall()
        
        print(f"[MENUS_SUBMENUS] {len(menus)} mens, {len(submenus)} submens obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': menus,
            'submenus': submenus
        }), 200
    
    except Error as e:
        print(f"[MENUS_SUBMENUS] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# API: GUARDAR ACCESOS DE USUARIO
# ============================================================================

@main_bp.route('/api/usuarios-accesos/guardar', methods=['POST'])
@login_required
def guardar_accesos_usuario():
    """Guardar accesos de un usuario usando SP"""
    try:
        import json
        
        data = request.get_json()
        num_documento = data.get('num_documento')
        accesos = data.get('accesos', [])
        
        if not num_documento:
            return jsonify({'success': False, 'error': 'Documento requerido'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"\n{'='*80}")
            print(f"[GUARDAR_ACCESOS] [*] INICIO DE GUARDADO DE ACCESOS")
            print(f"{'='*80}")
            print(f"[GUARDAR_ACCESOS] Documento: {num_documento}")
            print(f"[GUARDAR_ACCESOS] Total de accesos recibidos: {len(accesos)}")
            print(f"[GUARDAR_ACCESOS] JSON RECIBIDO DEL FRONTEND:")
            for idx, acceso in enumerate(accesos):
                print(f"  Acceso #{idx+1}: {acceso}")
                print(f"    - menu_nombre: {acceso.get('menu_nombre')}")
                print(f"    - submenu_nombre: {acceso.get('submenu_nombre')}")
                print(f"    - Claves: {list(acceso.keys())}")
            
            # Los accesos ya vienen con NOMBRES desde el frontend
            # Solo los pasamos al SP tal como estn
            accesos_con_nombres = []
            for idx, acceso in enumerate(accesos):
                print(f"\n[GUARDAR_ACCESOS] Inspeccionando acceso #{idx+1}:")
                print(f"  - Claves del acceso: {acceso.keys()}")
                print(f"  - Contenido completo: {acceso}")
                
                # VERIFICAR QU TIPO DE DATOS LLEGARON
                if 'menu_nombre' in acceso:
                    menu_nombre = acceso.get('menu_nombre')
                    print(f"  - DETECTADO: menu_nombre = '{menu_nombre}'")
                elif 'id_menu' in acceso:
                    print(f"  - [!] DETECTADO: id_menu = {acceso.get('id_menu')} (LLEG ID, no NOMBRE!)")
                    # Si lleg ID, significa que el frontend SIGUE enviando IDs
                    return jsonify({
                        'success': False, 
                        'error': 'El frontend est enviando IDs, no NOMBRES. Frontend.js no fue actualizado correctamente.'
                    }), 400
                else:
                    print(f"  - [X] ERROR: No hay ni menu_nombre ni id_menu")
                    return jsonify({'success': False, 'error': 'Estructura de accesos incorrecta'}), 400
                
                menu_nombre = acceso.get('menu_nombre')
                submenu_nombre = acceso.get('submenu_nombre')
                
                # Validar que al menos el men tenga nombre
                if not menu_nombre:
                    return jsonify({'success': False, 'error': 'Nombre de men requerido'}), 400
                
                acceso_con_nombre = {
                    'menu_nombre': menu_nombre,
                    'submenu_nombre': submenu_nombre
                }
                accesos_con_nombres.append(acceso_con_nombre)
                
                print(f"[GUARDAR_ACCESOS] Acceso #{len(accesos_con_nombres)}:")
                print(f"  - menu_nombre: {menu_nombre}")
                print(f"  - submenu_nombre: {submenu_nombre}")
            
            # Convertir accesos a JSON para el SP
            accesos_json = json.dumps(accesos_con_nombres)
            print(f"\n[GUARDAR_ACCESOS] JSON STRING con NOMBRES:")
            print(f"  {accesos_json}")
            
            # Llamar al Stored Procedure
            print(f"\n[GUARDAR_ACCESOS]  Ejecutando SP: sp_GuardarAccesosUsuario")
            print(f"[GUARDAR_ACCESOS] Parmetros:")
            print(f"  - p_num_documento: {num_documento}")
            print(f"  - p_accesos_json: {accesos_json}")
            
            cursor.execute("""
                CALL sp_GuardarAccesosUsuario(%s, %s)
            """, (num_documento, accesos_json))
            
            # Obtener el resultado del SP
            result = cursor.fetchone()
            
            print(f"\n[GUARDAR_ACCESOS] [OK] SP retorn resultado:")
            print(f"  - success: {result['success']}")
            print(f"  - message: {result['message']}")
            print(f"  - deleted_rows: {result['deleted_rows']}")
            print(f"  - inserted_rows: {result['inserted_rows']}")
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            # Verificar que se guard correctamente
            print(f"\n[GUARDAR_ACCESOS] [-] Verificando datos en BD:")
            cursor.execute("""
                SELECT id_usuario_acceso, num_documento, id_menu, id_submenu, estado, fecha_creacion
                FROM TblUsuarioAccesos
                WHERE num_documento = %s
                ORDER BY id_menu, id_submenu
            """, (num_documento,))
            
            verificacion = cursor.fetchall()
            print(f"[GUARDAR_ACCESOS] Total de filas guardadas: {len(verificacion)}")
            
            for idx, row in enumerate(verificacion):
                print(f"[GUARDAR_ACCESOS] Fila #{idx+1}:")
                print(f"  - id_usuario_acceso: {row['id_usuario_acceso']}")
                print(f"  - num_documento: {row['num_documento']}")
                print(f"  - id_menu: {row['id_menu']} (tipo: {type(row['id_menu']).__name__})")
                print(f"  - id_submenu: {row['id_submenu']} (tipo: {type(row['id_submenu']).__name__ if row['id_submenu'] is not None else 'NULL'})")
                print(f"  - estado: {row['estado']}")
                print(f"  - fecha_creacion: {row['fecha_creacion']}")
            
            cursor.close()
            connection.close()
            
            print(f"\n{'='*80}")
            print(f"[GUARDAR_ACCESOS] [OK] Operacin completada exitosamente")
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': result['message'],
                'deleted_rows': result['deleted_rows'],
                'inserted_rows': result['inserted_rows']
            }), 200
        
        except Error as e:
            cursor.close()
            connection.close()
            print(f"\n[GUARDAR_ACCESOS] [X][X][X] ERROR SQL: {e}")
            print(f"[GUARDAR_ACCESOS] Tipo de error: {type(e).__name__}")
            import traceback
            traceback.print_exc()
            print()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"\n[GUARDAR_ACCESOS] [X][X][X] ERROR GENERAL: {e}")
        print(f"[GUARDAR_ACCESOS] Tipo de error: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        print()
        return jsonify({'success': False, 'error': str(e)}), 500
