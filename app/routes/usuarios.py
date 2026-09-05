from flask import render_template, request, jsonify, session, flash, redirect, url_for
from . import main_bp
import mysql.connector
from mysql.connector import Error
import hashlib
from functools import wraps
from app.config import DatabaseConfig
from .main import validar_acceso_usuario

def get_db_connection():
    """Crear conexin a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        cursor = connection.cursor()
        cursor.execute("SET NAMES utf8mb4")
        cursor.close()
        return connection
    except Error as e:
        print(f"Error de conexin: {e}")
        return None

def guardar_horarios_usuario(connection, num_documento, horarios):
    """Guardar o actualizar horarios de trabajo de un usuario (con 2 turnos por da)"""
    try:
        cursor = connection.cursor()
        
        # Primero, eliminar horarios existentes
        print(f"[HORARIOS] [DEL] Eliminando horarios previos para documento {num_documento}")
        cursor.execute("""
            DELETE FROM TblHorarioTrabajo
            WHERE num_documento = %s
        """, (num_documento,))
        
        print(f"[HORARIOS] [OK] Horarios previos eliminados")
        
        # Insertar nuevos horarios
        print(f"[HORARIOS] [ADD] Insertando horarios nuevos")
        for horario in horarios:
            es_activo = horario['es_activo']
            dia_semana = horario['dia_semana']
            
            # Si es da laboral
            if es_activo == 1:
                # Turno 1
                cursor.execute("""
                    INSERT INTO TblHorarioTrabajo (
                        num_documento,
                        dia_semana,
                        hora_entrada,
                        hora_salida,
                        hora_entrada2,
                        hora_salida2,
                        es_activo,
                        estado
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, 'ACTIVO')
                """, (
                    num_documento,
                    dia_semana,
                    horario['hora_entrada'],
                    horario['hora_salida'],
                    horario['hora_entrada2'],
                    horario['hora_salida2'],
                    1
                ))
                print(f"[HORARIOS]   - {dia_semana}: T1={horario['hora_entrada']}-{horario['hora_salida']} T2={horario['hora_entrada2']}-{horario['hora_salida2']}")
            else:
                # Da libre (sin turnos)
                cursor.execute("""
                    INSERT INTO TblHorarioTrabajo (
                        num_documento,
                        dia_semana,
                        hora_entrada,
                        hora_salida,
                        es_activo,
                        estado
                    ) VALUES (%s, %s, %s, %s, %s, 'ACTIVO')
                """, (
                    num_documento,
                    dia_semana,
                    None,
                    None,
                    0
                ))
                print(f"[HORARIOS]   - {dia_semana}: [DIA LIBRE]")
        
        print(f"[HORARIOS] [OK] Todos los horarios guardados")
        cursor.close()
        return True
    
    except Error as e:
        print(f"[HORARIOS] [ERROR] Error al guardar horarios: {e}")
        return False

def hash_password(password):
    """Encriptar contrasea usando SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

# Decorador para requerir autenticacin
def login_required(f):
    """Decorador para proteger rutas que requieren autenticacin"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesin', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

@main_bp.route('/usuarios')
@login_required
def usuarios():
    """Pgina de gestin de usuarios"""
    # Validar que el usuario tenga acceso a Gestin de Usuarios
    num_documento = session.get('user_documento')
    
    # ID 1 = RR.HH, ID 1 = Usuario (submen especfico)
    if not validar_acceso_usuario(num_documento, id_menu=1, id_submenu=1):
        flash('No tienes acceso a Gestin de Usuarios', 'danger')
        return redirect(url_for('main.dashboard'))
    
    return render_template('usuarios.html')

@main_bp.route('/api/usuarios/obtener', methods=['GET'])
@login_required
def obtener_usuarios():
    """Obtener lista de usuarios usando SP, con filtro opcional por nombre"""
    q = request.args.get('q', '').strip()
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Ejecutar SP con callproc + stored_results
        cursor.callproc('sp_ObtenerUsuarios')
        usuarios = []
        for result in cursor.stored_results():
            usuarios = result.fetchall()
        
        # Filtrar por nombre si se proporciona q
        if q:
            q_lower = q.lower()
            usuarios = [
                u for u in usuarios
                if q_lower in (u.get('nombres') or '').lower()
                or q_lower in (u.get('apellido_paterno') or '').lower()
                or q_lower in (u.get('apellido_materno') or '').lower()
            ]
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': usuarios}), 200
    
    except Error as e:
        print(f"Error al obtener usuarios: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/usuarios/obtener/<int:id_usuario>', methods=['GET'])
@login_required
def obtener_usuario(id_usuario):
    """Obtener datos COMPLETOS de un usuario para el modal Editar"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[SP_OBTENER_USUARIO_COMPLETO] Iniciando para usuario ID: {id_usuario}")
        print(f"{'='*80}")
        
        # Llamar SP con callproc + stored_results (retorna dos result sets: usuario + horarios)
        cursor.callproc('sp_ObtenerUsuarioCompleto', (id_usuario,))
        
        # Obtener todos los result sets
        result_sets = list(cursor.stored_results())
        
        # RESULT SET 1: Datos del usuario
        usuario = result_sets[0].fetchone() if len(result_sets) > 0 else None
        
        print(f"\n[SP_OBTENER_USUARIO_COMPLETO] SP ejecutado correctamente")
        
        if usuario:
            print(f"\n[DATOS DEL USUARIO]:")
            print(f"{'='*80}")
            
            # Mostrar cada campo
            for key, value in usuario.items():
                if value is None:
                    print(f"  [NULL] {key}: <NULL>")
                else:
                    print(f"  [OK] {key}: {value}")
            
            print(f"{'='*80}\n")
        else:
            print(f"[SP_OBTENER_USUARIO_COMPLETO] [WARN] El SP retorno NULL (usuario no encontrado)")
        
        # RESULT SET 2: Horarios de trabajo
        horarios = result_sets[1].fetchall() if len(result_sets) > 1 else []
        
        cursor.close()
        connection.close()
        
        if not usuario:
            print(f"[SP_OBTENER_USUARIO_COMPLETO] [ERROR] Usuario no encontrado")
            return jsonify({'success': False, 'error': 'Usuario no encontrado'}), 404
        
        # Retornar usuario + horarios
        usuario['horarios'] = horarios
        
        # Definir funcin para convertir recursivamente cualquier timedelta a string HH:MM
        def convert_timedelta(obj):
            """Convierte recursivamente timedeltas a strings HH:MM en dicts y listas"""
            if isinstance(obj, dict):
                return {k: convert_timedelta(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_timedelta(item) for item in obj]
            elif obj is not None and hasattr(obj, 'total_seconds'):
                # Es un timedelta, convertir a string HH:MM
                horas = int(obj.total_seconds() // 3600)
                minutos = int((obj.total_seconds() % 3600) // 60)
                return f"{horas:02d}:{minutos:02d}"
            else:
                return obj
        
        # Aplicar conversin recursiva a toda la estructura (usuario + horarios)
        usuario = convert_timedelta(usuario)
        
        # Mostrar horarios en logs despus de la conversin
        print(f"[HORARIOS DE TRABAJO]:")
        print(f"{'='*80}")
        if usuario.get('horarios'):
            for horario in usuario['horarios']:
                print(f"  - {horario.get('dia_semana')}: activo={horario.get('es_activo')}, entrada={horario.get('hora_entrada')}, salida={horario.get('hora_salida')}")
        print(f"{'='*80}\n")
        
        print(f"[SP_OBTENER_USUARIO_COMPLETO] [SEND] Retornando JSON al cliente")
        return jsonify({'success': True, 'data': usuario}), 200
    
    except Error as e:
        print(f"[SP_OBTENER_USUARIO_COMPLETO] [X] Error SQL: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/usuarios/crear', methods=['POST'])
@login_required
def crear_usuario():
    """Crear un nuevo usuario usando SP"""
    try:
        from flask import current_app
        data = request.get_json()
        
        # Validar campos obligatorios
        campos_requeridos = ['documento_numero', 'nombres', 'apellido_paterno', 'email', 'id_empresa']
        for campo in campos_requeridos:
            if not data.get(campo):
                return jsonify({'success': False, 'error': f'Campo requerido: {campo}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Llamar SP - genera usuario y contrasea automticamente + horarios
            # Preparar horarios como parmetros individuales (5 por da: activo, entrada, salida, entrada2, salida2)
            horarios = data.get('horarios', [])
            horarios_params = []
            
            print(f"\n[CREAR_USUARIO] [RECV] Horarios recibidos: {len(horarios)}")
            for i, horario in enumerate(horarios):
                horarios_params.append(horario['es_activo'])
                horarios_params.append(horario['hora_entrada'] if horario['es_activo'] == 1 else None)
                horarios_params.append(horario['hora_salida'] if horario['es_activo'] == 1 else None)
                horarios_params.append(horario.get('hora_entrada2') if horario['es_activo'] == 1 else None)
                horarios_params.append(horario.get('hora_salida2') if horario['es_activo'] == 1 else None)
                print(f"  [{i}] {horario['dia_semana']}: T1={horario['hora_entrada']}-{horario['hora_salida']} T2={horario.get('hora_entrada2')}-{horario.get('hora_salida2')} activo={horario['es_activo']}")
            
            # Crear lista de parmetros completa: usuario + 5*7 horarios
            all_params = [
                data['documento_numero'],
                data.get('tipo_documento', 'DNI'),
                data['nombres'],
                data['apellido_paterno'],
                data.get('apellido_materno', ''),
                data['email'],
                data.get('celular', ''),
                data.get('celular_referencia', ''),
                data.get('fecha_nacimiento') or None,
                data.get('genero') or None,
                data.get('direccion') or None,
                data.get('id_distrito') or None,
                data.get('id_cargo') or None,
                data['id_empresa'],
            ] + horarios_params
            
            print(f"[CREAR_USUARIO] [TOTAL] Total de parmetros: {len(all_params)}")
            print(f"[CREAR_USUARIO] [DESG] Desglose: 14 (usuario) + {len(horarios_params)} (horarios 5x7) = {len(all_params)}")
            
            # Construir dinmicamente el CALL con los parmetros correctos
            # 14 parmetros de usuario + 35 de horarios (5 * 7 das) = 49 IN params
            placeholders = ', '.join(['%s'] * len(all_params))
            
            cursor.execute(f"""
                CALL sp_CrearUsuarioCompleto(
                    {placeholders},
                    @p_num_usuario, @p_mensaje
                )
            """, tuple(all_params))
            
            # Obtener los OUT parameters
            cursor.execute("SELECT @p_num_usuario as num_usuario, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            connection.commit()
            cursor.close()
            connection.close()
            
            if resultado and resultado['num_usuario'] > 0:
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'num_usuario': resultado['num_usuario']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': resultado['mensaje'] if resultado else 'Error al crear usuario'
                }), 400
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al crear usuario: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/usuarios/actualizar/<int:id_usuario>', methods=['PUT'])
@login_required
def actualizar_usuario(id_usuario):
    """Actualizar datos completos de un usuario usando SP"""
    try:
        from flask import current_app
        data = request.get_json()
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            print(f"\n{'='*80}")
            print(f"[ACTUALIZAR_USUARIO] [INIT] Iniciando para usuario ID: {id_usuario}")
            print(f"{'='*80}")
            print(f"[ACTUALIZAR_USUARIO] [DATA] Datos recibidos:")
            for key, value in data.items():
                print(f"  - {key}: {value}")
            
            # Llamar SP_ActualizarUsuarioCompleto
            cursor.execute("""
                CALL sp_ActualizarUsuarioCompleto(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    @p_mensaje
                )
            """, (
                id_usuario,
                data.get('tipo_documento', ''),
                data.get('nombres', ''),
                data.get('apellido_paterno', ''),
                data.get('apellido_materno', ''),
                data.get('email', ''),
                data.get('celular', ''),
                data.get('celular_referencia', ''),
                data.get('fecha_nacimiento') or None,
                data.get('genero') or None,
                data.get('direccion') or None,
                data.get('id_distrito') or None,
                data.get('id_cargo') or None,
                data.get('id_empresa') or None,
            ))
            
            # Obtener el mensaje
            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            print(f"\n[ACTUALIZAR_USUARIO] [OK] SP ejecutado correctamente")
            print(f"[ACTUALIZAR_USUARIO] [RESP] Mensaje: {resultado['mensaje'] if resultado else 'Sin mensaje'}")
            
            # Guardar horarios si fueron enviados
            if data.get('horarios'):
                print(f"[ACTUALIZAR_USUARIO] [HOR] Guardando horarios")
                # Obtener num_documento para guardar horarios
                cursor.execute("""
                    SELECT num_documento FROM TblUsuario WHERE num_usuario = %s
                """, (id_usuario,))
                usuario_data = cursor.fetchone()
                if usuario_data:
                    guardar_horarios_usuario(connection, usuario_data['num_documento'], data['horarios'])
            
            print(f"{'='*80}\n")
            
            connection.commit()
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Usuario actualizado exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ACTUALIZAR_USUARIO] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ACTUALIZAR_USUARIO] [ERROR] Error general: {e}", exc_info=True)
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/usuarios/eliminar/<int:id_usuario>', methods=['DELETE'])
@login_required
def eliminar_usuario(id_usuario):
    """Eliminar un usuario usando SP"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor()
        
        try:
            # Llamar SP
            cursor.execute("""
                CALL sp_EliminarUsuario(%s, @p_mensaje)
            """, (id_usuario,))
            
            # Obtener el mensaje
            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            connection.commit()
            cursor.close()
            connection.close()
            
            return jsonify({'success': True, 'message': 'Usuario eliminado exitosamente'}), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al eliminar usuario: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/cargos/obtener', methods=['GET'])
@login_required
def obtener_cargos():
    """Obtener lista de cargos disponibles usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.callproc('sp_ObtenerAreas')
        cargos = []
        for result in cursor.stored_results():
            cargos = result.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': cargos}), 200
    
    except Error as e:
        print(f"Error al obtener cargos: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/areas/obtener', methods=['GET'])
@login_required
def obtener_areas():
    """Obtener lista de reas disponibles usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("[BACKEND] [INIT] obtener_areas() iniciado")
        
        cursor.callproc('sp_ObtenerAreas')
        areas = []
        for result in cursor.stored_results():
            areas = result.fetchall()
        
        print(f"[BACKEND] [OK] reas obtenidas: {len(areas)} registros")
        if areas:
            for a in areas[:3]:
                print(f"[BACKEND]   - {a}")
        
        cursor.close()
        connection.close()
        
        print(f"[BACKEND] [SEND] Retornando: success=True, data={len(areas)} reas")
        return jsonify({'success': True, 'data': areas}), 200
    
    except Error as e:
        print(f"[BACKEND] [ERROR] Error al obtener reas: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/cargos/por-area/<int:id_area>', methods=['GET'])
@login_required
def obtener_cargos_por_area(id_area):
    """Obtener cargos de un rea especfica usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[BACKEND] [INIT] obtener_cargos_por_area({id_area}) iniciado")
        
        cursor.callproc('sp_ObtenerCargosPorArea', (id_area,))
        cargos = []
        for result in cursor.stored_results():
            cargos = result.fetchall()
        
        print(f"[BACKEND] [OK] Cargos obtenidos: {len(cargos)} registros para rea {id_area}")
        if cargos:
            for c in cargos[:3]:
                print(f"[BACKEND]   - {c}")
        
        cursor.close()
        connection.close()
        
        print(f"[BACKEND] [SEND] Retornando: success=True, data={len(cargos)} cargos")
        return jsonify({'success': True, 'data': cargos}), 200
    
    except Error as e:
        print(f"[BACKEND] [ERROR] Error al obtener cargos por rea: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/empresas/listar', methods=['GET'])
@login_required
def obtener_empresas_modal():
    """Obtener lista de empresas disponibles para el modal usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print("[BACKEND] [INIT] obtener_empresas_modal() iniciado")
        
        # Ejecutar SP con callproc + stored_results
        cursor.callproc('sp_ObtenerEmpresas')
        empresas = []
        for result in cursor.stored_results():
            empresas = result.fetchall()
        
        print(f"[BACKEND] [OK] Empresas obtenidas: {len(empresas)} registros")
        if empresas:
            for e in empresas[:3]:
                print(f"[BACKEND]   - {e}")
        
        cursor.close()
        connection.close()
        
        print(f"[BACKEND] [SEND] Retornando: success=True, data={len(empresas)} empresas")
        return jsonify({'success': True, 'data': empresas}), 200
    
    except Error as e:
        print(f"[BACKEND] [ERROR] Error al obtener empresas: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicacion/departamentos', methods=['GET'])
@login_required
def obtener_departamentos():
    """Obtener lista de departamentos"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT id_departamento, nombre 
            FROM TblDepartamento 
            WHERE estado = 'Activo'
            ORDER BY nombre
        """)
        departamentos = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': departamentos}), 200
    
    except Error as e:
        print(f"Error al obtener departamentos: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicacion/provincias/<int:id_departamento>', methods=['GET'])
@login_required
def obtener_provincias(id_departamento):
    """Obtener provincias de un departamento especfico"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT id_provincia, nombre 
            FROM TblProvincia 
            WHERE id_departamento = %s AND estado = 'Activo'
            ORDER BY nombre
        """, (id_departamento,))
        provincias = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': provincias}), 200
    
    except Error as e:
        print(f"Error al obtener provincias: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicacion/distritos/<int:id_provincia>', methods=['GET'])
@login_required
def obtener_distritos(id_provincia):
    """Obtener distritos de una provincia especfica"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT id_distrito, nombre 
            FROM TblDistrito 
            WHERE id_provincia = %s AND estado = 'Activo'
            ORDER BY nombre
        """, (id_provincia,))
        distritos = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': distritos}), 200
    
    except Error as e:
        print(f"Error al obtener distritos: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: GESTIN DE UBICACIONES DE MARCACIN (CON STORED PROCEDURES)
# ============================================================================

@main_bp.route('/api/ubicaciones/obtener/<int:num_documento>', methods=['GET'])
@login_required
def obtener_ubicaciones_usuario(num_documento):
    """Obtener todas las ubicaciones de marcacin de un usuario usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[UBICACIONES] Obteniendo ubicaciones para documento: {num_documento}")
        
        # Llamar SP
        cursor.callproc('sp_ObtenerUbicacionesUsuario', (num_documento,))
        
        # Obtener resultados
        ubicaciones = []
        for result in cursor.stored_results():
            ubicaciones = result.fetchall()
        
        print(f"[UBICACIONES] {len(ubicaciones)} ubicaciones encontradas")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': ubicaciones}), 200
    
    except Error as e:
        print(f"[UBICACIONES] Error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicaciones/crear', methods=['POST'])
@login_required
def crear_ubicacion_marcacion():
    """Crear nueva ubicacin de marcacin usando SP"""
    try:
        data = request.get_json()
        
        # Validar campos obligatorios
        if not data.get('num_documento') or not data.get('nombre_zona'):
            return jsonify({'success': False, 'error': 'Datos incompletos'}), 400
        
        if not data.get('latitud_centro') or not data.get('longitud_centro'):
            return jsonify({'success': False, 'error': 'Coordenadas GPS requeridas'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Obtener usuario actual
            creado_por = session.get('user_documento')
            
            print(f"[UBICACIONES] Creando ubicacin para documento: {data['num_documento']}")
            print(f"[UBICACIONES] Nombre: {data['nombre_zona']}")
            print(f"[UBICACIONES] Centro: ({data['latitud_centro']}, {data['longitud_centro']})")
            print(f"[UBICACIONES] Radio: {data.get('radio_metros', 100)}m")
            
            # Llamar SP
            cursor.execute("""
                CALL sp_CrearUbicacionMarcacion(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    @p_id_ubicacion, @p_mensaje
                )
            """, (
                data['num_documento'],
                data['nombre_zona'],
                data['latitud_centro'],
                data['longitud_centro'],
                data.get('radio_metros', 100),
                data.get('direccion_referencia'),
                data.get('tipo_zona', 'OFICINA'),
                data.get('descripcion'),
                data.get('estado', 'ACTIVO'),
                creado_por
            ))
            
            # Obtener resultado
            cursor.execute("SELECT @p_id_ubicacion as id_ubicacion, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            print(f"[UBICACIONES] Resultado: {resultado['mensaje']}")
            
            if resultado and resultado['id_ubicacion'] > 0:
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_ubicacion': resultado['id_ubicacion']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': resultado['mensaje'] if resultado else 'Error al crear ubicacin'
                }), 400
        
        except Error as e:
            cursor.close()
            connection.close()
            print(f"[UBICACIONES] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[UBICACIONES] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicaciones/actualizar/<int:id_ubicacion>', methods=['PUT'])
@login_required
def actualizar_ubicacion_marcacion(id_ubicacion):
    """Actualizar ubicacin de marcacin usando SP"""
    try:
        data = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[UBICACIONES] Actualizando ubicacin ID: {id_ubicacion}")
            print(f"[UBICACIONES] Nombre: {data['nombre_zona']}")
            
            # Llamar SP
            cursor.execute("""
                CALL sp_ActualizarUbicacionMarcacion(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    @p_mensaje
                )
            """, (
                id_ubicacion,
                data['nombre_zona'],
                data['latitud_centro'],
                data['longitud_centro'],
                data.get('radio_metros', 100),
                data.get('direccion_referencia'),
                data.get('tipo_zona', 'OFICINA'),
                data.get('descripcion'),
                data.get('estado', 'ACTIVO')
            ))
            
            # Obtener resultado
            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            print(f"[UBICACIONES] Resultado: {resultado['mensaje']}")
            
            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Ubicacin actualizada exitosamente'
            }), 200
        
        except Error as e:
            cursor.close()
            connection.close()
            print(f"[UBICACIONES] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[UBICACIONES] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ubicaciones/eliminar/<int:id_ubicacion>', methods=['DELETE'])
@login_required
def eliminar_ubicacion_marcacion(id_ubicacion):
    """Eliminar ubicacin de marcacin usando SP"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[UBICACIONES] Eliminando ubicacin ID: {id_ubicacion}")
            
            # Llamar SP
            cursor.execute("""
                CALL sp_EliminarUbicacionMarcacion(%s, @p_mensaje)
            """, (id_ubicacion,))
            
            # Obtener resultado
            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            print(f"[UBICACIONES] Resultado: {resultado['mensaje']}")
            
            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Ubicacin eliminada exitosamente'
            }), 200
        
        except Error as e:
            cursor.close()
            connection.close()
            print(f"[UBICACIONES] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[UBICACIONES] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
