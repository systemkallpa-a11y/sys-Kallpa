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
        return None
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Encriptar la contraseña
        password_hash = hash_password(password)
        
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
            WHERE u.usuario = %s AND u.password = %s AND u.estado = 'Activo'
            LIMIT 1
        """
        
        cursor.execute(query, (usuario, password_hash))
        user_result = cursor.fetchone()
        cursor.close()
        
        if not user_result:
            return None
        
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
        print(f"Error en validación: {e}")
        return None
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
        
        if result is None:
            current_app.logger.error(f"[LOGIN KALLPA] ERROR: validate_user_kallpa retornó None")
            flash('Error de conexión con la base de datos', 'error')
            return render_template('login_kallpa.html', redirect_to=redirect_to)
        
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
            return redirect(url_for('main.marcacion_kallpa'))
    
    # GET request
    redirect_to = request.args.get('redirect', 'marcacion')
    return render_template('login_kallpa.html', redirect_to=redirect_to)

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
