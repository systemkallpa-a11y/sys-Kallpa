from flask import render_template, request, redirect, url_for, session, flash
from . import auth_bp
import mysql.connector
from mysql.connector import Error
import hashlib
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

def validate_user_kallpa(usuario, password):
    """Validar credenciales de usuario Kallpa"""
    connection = get_db_connection()
    if not connection:
        print(f"[DEBUG] No se pudo conectar a la BD")
        return {'error': 'No se pudo conectar a la base de datos'}
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Encriptar la contraseña
        password_hash = hash_password(password)
        print(f"[DEBUG] Usuario: {usuario}, Password hash: {password_hash}")
        
        # Primero verificar si existe el usuario
        simple_query = "SELECT usuario, password_hash, estado FROM TblUsuario WHERE usuario = %s"
        cursor.execute(simple_query, (usuario,))
        simple_result = cursor.fetchone()
        print(f"[DEBUG] Usuario encontrado: {simple_result}")
        
        if simple_result:
            print(f"[DEBUG] Password en BD: {simple_result['password_hash']}")
            print(f"[DEBUG] Password calculado: {password_hash}")
            print(f"[DEBUG] Passwords coinciden: {simple_result['password_hash'] == password_hash}")
            print(f"[DEBUG] Estado: {simple_result['estado']}")
        
        # Query: JOINear TblUsuario con TblPersona, TblCargo y TblArea
        query = """
            SELECT 
                u.num_usuario,
                u.num_documento,
                u.usuario,
                p.nombres,
                p.apellido_paterno,
                p.apellido_materno,
                p.email,
                u.id_cargo,
                c.nombre as cargo,
                a.nombre as area,
                u.estado
            FROM TblUsuario u
            JOIN TblPersona p ON u.num_documento = p.num_documento
            LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
            LEFT JOIN TblArea a ON c.id_area = a.id_area
            WHERE u.usuario = %s AND u.password_hash = %s AND u.estado IN ('Activo', 'ACTIVO')
            LIMIT 1
        """
        
        cursor.execute(query, (usuario, password_hash))
        user_result = cursor.fetchone()
        print(f"[DEBUG] Resultado final: {user_result}")
        
        if not user_result:
            return {'error': 'Usuario o contraseña incorrectos'}
        
        # Autenticación exitosa
        return {
            'num_usuario': user_result['num_usuario'],
            'num_documento': user_result['num_documento'],
            'usuario': usuario,
            'nombres': user_result['nombres'],
            'apellido_paterno': user_result['apellido_paterno'],
            'apellido_materno': user_result['apellido_materno'],
            'email': user_result['email'],
            'id_cargo': user_result['id_cargo'],
            'cargo': user_result['cargo'],
            'area': user_result['area'],
            'estado': user_result['estado']
        }
        
    except Error as e:
        print(f"[DEBUG] Error en validación: {e}")
        return {'error': f'Error en la validación: {str(e)}'}
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()


@auth_bp.route('/welcome')
def show_welcome():
    """Página de bienvenida"""
    return render_template('welcome.html')

@auth_bp.route('/check-session', methods=['GET'])
def check_session():
    """API para verificar si hay sesión activa"""
    from flask import jsonify
    
    authenticated = 'user_documento' in session or 'user_email' in session
    
    return jsonify({
        'authenticated': authenticated,
        'user': {
            'name': session.get('user_name', ''),
            'documento': session.get('user_documento', '')
        } if authenticated else {}
    })

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    """Página de login para Kallpa"""
    from flask import current_app
    
    if request.method == 'POST':
        usuario = request.form.get('email')
        password = request.form.get('password')
        remember = request.form.get('remember')
        redirect_to = request.form.get('redirect_to', 'marcacion')  # Por defecto a marcación
        
        current_app.logger.info(f"[LOGIN KALLPA] Intentando login con usuario: {usuario}")
        
        if not usuario or not password:
            current_app.logger.warning(f"[LOGIN KALLPA] ERROR: Campos vacíos")
            flash('Por favor completa todos los campos', 'error')
            return render_template('login_kallpa.html', redirect_to=redirect_to)
        
        # Validar credenciales
        current_app.logger.info(f"[LOGIN KALLPA] Validando credenciales...")
        result = validate_user_kallpa(usuario, password)
        
        if 'error' in result:
            current_app.logger.error(f"[LOGIN KALLPA] ERROR de autenticación: {result['error']}")
            flash(result['error'], 'error')
            return render_template('login_kallpa.html', redirect_to=redirect_to)
        
        # Login exitoso - guardar datos en sesión
        current_app.logger.info(f"[LOGIN KALLPA] Login exitoso! Guardando sesión...")
        session['user_documento'] = result['num_documento']
        session['user_id'] = result['num_usuario']
        session['user_name'] = f"{result['nombres']} {result['apellido_paterno']}"
        session['user_email'] = result['email']
        session['user_id_cargo'] = result['id_cargo']
        session['user_cargo'] = result['cargo'] or 'N/A'
        session['user_area'] = result['area'] or 'N/A'
        session['user_db'] = 'kallpa'
        
        if remember:
            session.permanent = True
        
        flash(f"¡Bienvenido {result['nombres']}!", 'success')
        current_app.logger.info(f"[LOGIN KALLPA] Redirigiendo a {redirect_to}...")
        
        # Redirigir según el parámetro
        if redirect_to == 'dashboard':
            return redirect(url_for('main.dashboard'))
        else:  # marcacion es el default
            return redirect(url_for('marcacion.marcacion_kallpa'))
    
    # GET request
    redirect_to = request.args.get('redirect', 'marcacion')
    return render_template('login_kallpa.html', redirect_to=redirect_to)

@auth_bp.route('/api/cambiar-contrasena', methods=['POST'])
def cambiar_contrasena():
    """API para cambiar la contraseña del usuario usando SP"""
    from flask import jsonify, current_app
    
    # Verificar que el usuario esté autenticado
    if 'user_documento' not in session and 'user_email' not in session:
        return jsonify({'success': False, 'message': 'No autenticado'}), 401
    
    try:
        data = request.get_json()
        
        contrasena_actual = data.get('contrasena_actual')
        contrasena_nueva = data.get('contrasena_nueva')
        
        if not contrasena_actual or not contrasena_nueva:
            return jsonify({'success': False, 'message': 'Todos los campos son obligatorios'}), 400
        
        if len(contrasena_nueva) < 6:
            return jsonify({'success': False, 'message': 'La nueva contraseña debe tener al menos 6 caracteres'}), 400
        
        num_documento = session.get('user_documento')
        
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Usuario: {num_documento}")
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Error de conexión a la base de datos'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Generar hashes
        password_hash_actual = hash_password(contrasena_actual)
        password_hash_nueva = hash_password(contrasena_nueva)
        
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Llamando a SP sp_CambiarContrasena")
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Hash actual (primeros 10): {password_hash_actual[:10]}...")
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Hash nueva (primeros 10): {password_hash_nueva[:10]}...")
        
        # Llamar al SP para cambiar contraseña
        cursor.callproc('sp_CambiarContrasena', [
            num_documento,
            password_hash_actual,
            password_hash_nueva
        ])
        
        # Obtener resultado del SP
        result = None
        for resultado in cursor.stored_results():
            result = resultado.fetchone()
            break
        
        # ⚠️ IMPORTANTE: Hacer commit después del SP
        connection.commit()
        
        cursor.close()
        connection.close()
        
        if not result:
            current_app.logger.error(f"[CAMBIAR_CONTRASEÑA] SP no retornó resultado")
            return jsonify({'success': False, 'message': 'Error al cambiar la contraseña'}), 500
        
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Resultado SP: {result}")
        current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] Success: {result.get('success')}")
        
        # El SP retorna: success (bool), message (string), usuario (string - opcional)
        if result.get('success'):
            current_app.logger.info(f"[CAMBIAR_CONTRASEÑA] ✅ Contraseña cambiada exitosamente")
            return jsonify({
                'success': True,
                'message': result.get('message', 'Contraseña actualizada exitosamente')
            }), 200
        else:
            current_app.logger.warning(f"[CAMBIAR_CONTRASEÑA] ❌ {result.get('message')}")
            return jsonify({
                'success': False,
                'message': result.get('message', 'Error al cambiar la contraseña')
            }), 400
        
    except Exception as e:
        current_app.logger.error(f"[CAMBIAR_CONTRASEÑA] Error: {e}")
        import traceback
        current_app.logger.error(f"[CAMBIAR_CONTRASEÑA] Traceback: {traceback.format_exc()}")
        return jsonify({'success': False, 'message': f'Error al cambiar la contraseña: {str(e)}'}), 500


@auth_bp.route('/logout')
def logout():
    """Cerrar sesión"""
    session.clear()
    flash('Sesión cerrada', 'info')
    return redirect(url_for('auth.show_welcome'))

@auth_bp.route('/clear-session')
def clear_session():
    """Ruta para limpiar sesión (DEBUG)"""
    session.clear()
    return '''
    <!DOCTYPE html>
    <html>
    <head><title>Sesión Limpiada</title></head>
    <body style="font-family: Arial; text-align: center; padding: 40px;">
        <h1>✓ Sesión Limpiada</h1>
        <p>Las cookies de sesión han sido eliminadas.</p>
        <p><a href="/">Ir al inicio</a></p>
    </body>
    </html>
    '''
