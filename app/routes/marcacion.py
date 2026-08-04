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
# RUTA: PÁGINA DE REPORTE DE ASISTENCIA (ADMIN)
# ============================================================================

@marcacion_bp.route('/marcacion')
@login_required
def reporte_asistencia():
    """Página de reporte de asistencia de todos los usuarios (vista administrativa)"""
    return render_template('reporte_asistencia.html')


# ============================================================================
# RUTA: PÁGINA DE MARCACIÓN INDIVIDUAL
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
    """Obtener historial de marcaciones del usuario con estados de asistencia"""
    try:
        num_documento = session.get('user_documento')
        dias = request.args.get('dias', 7, type=int)
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[HISTORIAL] 🔄 Obteniendo historial CON ESTADOS para documento {num_documento}, últimos {dias} días")
            
            # Llamar SP que calcula estados de asistencia
            cursor.callproc('sp_ObtenerHistorialConEstados', (num_documento, dias))
            
            # Obtener resultados
            marcaciones = []
            for result in cursor.stored_results():
                marcaciones = result.fetchall()
            
            print(f"[HISTORIAL] ✅ {len(marcaciones)} marcaciones encontradas con estados")
            
            # 🔧 Serializar datos para JSON (convertir datetime, date, timedelta, etc.)
            import datetime as dt_module
            for marcacion in marcaciones:
                for key, value in marcacion.items():
                    # Convertir datetime a ISO string
                    if isinstance(value, datetime):
                        marcacion[key] = value.isoformat()
                    # Convertir date a string YYYY-MM-DD
                    elif isinstance(value, dt_module.date):
                        marcacion[key] = value.strftime('%Y-%m-%d')
                    # Convertir timedelta a string
                    elif hasattr(value, 'total_seconds'):  # timedelta
                        marcacion[key] = str(value)
                    # Asegurar que cualquier fecha sea string
                    elif hasattr(value, 'strftime'):
                        marcacion[key] = value.strftime('%Y-%m-%d')
            
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
# API: OBTENER REPORTE DE ASISTENCIA DE TODOS LOS USUARIOS
# ============================================================================

@marcacion_bp.route('/api/marcacion/reporte-todos', methods=['GET'])
@login_required
def obtener_reporte_todos():
    """Obtener reporte de asistencia de todos los usuarios"""
    try:
        # Parámetros de filtro
        fecha_desde = request.args.get('fecha_desde')
        fecha_hasta = request.args.get('fecha_hasta')
        num_documento = request.args.get('num_documento')  # Filtro opcional por usuario
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[REPORTE_TODOS] 🔄 Obteniendo reporte de asistencia")
            print(f"[REPORTE_TODOS] 📅 Fechas: desde={fecha_desde}, hasta={fecha_hasta}")
            
            # Query base para obtener todas las marcaciones con información del usuario
            query = """
                SELECT 
                    m.id_marcacion,
                    m.num_documento,
                    CONCAT(
                        COALESCE(p.nombres, ''),
                        ' ',
                        COALESCE(p.apellido_paterno, ''),
                        ' ',
                        COALESCE(p.apellido_materno, '')
                    ) as nombre_completo,
                    p.email,
                    m.tipo_marcacion,
                    m.fecha_marcacion,
                    DATE(m.fecha_marcacion) as fecha,
                    TIME(m.fecha_marcacion) as hora,
                    m.latitud,
                    m.longitud,
                    m.precision,
                    m.dispositivo,
                    m.observacion,
                    CASE WHEN m.foto_base64 IS NOT NULL AND m.foto_base64 != '' THEN 1 ELSE 0 END as tiene_foto
                FROM TblMarcacion m
                INNER JOIN TblUsuario u ON m.num_documento = u.num_documento
                INNER JOIN TblPersona p ON u.num_documento = p.num_documento
                WHERE 1=1
            """
            
            params = []
            
            # Filtro por rango de fechas
            if fecha_desde:
                query += " AND DATE(m.fecha_marcacion) >= %s"
                params.append(fecha_desde)
            
            if fecha_hasta:
                query += " AND DATE(m.fecha_marcacion) <= %s"
                params.append(fecha_hasta)
            
            # Filtro por usuario específico
            if num_documento:
                query += " AND m.num_documento = %s"
                params.append(num_documento)
            
            query += " ORDER BY m.fecha_marcacion DESC"
            
            cursor.execute(query, tuple(params))
            marcaciones = cursor.fetchall()
            
            print(f"[REPORTE_TODOS] ✅ {len(marcaciones)} marcaciones encontradas")
            
            # Serializar datos para JSON
            import datetime as dt_module
            for marcacion in marcaciones:
                for key, value in marcacion.items():
                    if isinstance(value, datetime):
                        marcacion[key] = value.isoformat()
                    elif isinstance(value, dt_module.date):
                        marcacion[key] = value.strftime('%Y-%m-%d')
                    elif isinstance(value, dt_module.time):
                        marcacion[key] = value.strftime('%H:%M:%S')
                    elif hasattr(value, 'total_seconds'):
                        marcacion[key] = str(value)
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': marcaciones
            }), 200
        
        except Error as e:
            print(f"[REPORTE_TODOS] ❌ Error SQL: {e}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        print(f"[REPORTE_TODOS] ❌ Error general: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: OBTENER RESUMEN DE ASISTENCIA POR USUARIO
# ============================================================================

@marcacion_bp.route('/api/marcacion/resumen-usuarios', methods=['GET'])
@login_required
def obtener_resumen_usuarios():
    """Obtener resumen de asistencia por usuario (días trabajados, puntualidad, etc.)"""
    try:
        fecha_desde = request.args.get('fecha_desde')
        fecha_hasta = request.args.get('fecha_hasta')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[RESUMEN_USUARIOS] 🔄 Obteniendo resumen de usuarios")
            
            query = """
                SELECT 
                    u.num_documento,
                    CONCAT(
                        COALESCE(p.nombres, ''),
                        ' ',
                        COALESCE(p.apellido_paterno, ''),
                        ' ',
                        COALESCE(p.apellido_materno, '')
                    ) as nombre_completo,
                    p.email,
                    COUNT(DISTINCT DATE(m.fecha_marcacion)) as dias_asistidos,
                    SUM(CASE WHEN m.tipo_marcacion = 'ENTRADA' THEN 1 ELSE 0 END) as total_entradas,
                    SUM(CASE WHEN m.tipo_marcacion = 'SALIDA' THEN 1 ELSE 0 END) as total_salidas,
                    MIN(m.fecha_marcacion) as primera_marcacion,
                    MAX(m.fecha_marcacion) as ultima_marcacion
                FROM TblUsuario u
                INNER JOIN TblPersona p ON u.num_documento = p.num_documento
                LEFT JOIN TblMarcacion m ON u.num_documento = m.num_documento
            """
            
            params = []
            conditions = []
            
            if fecha_desde:
                conditions.append("DATE(m.fecha_marcacion) >= %s")
                params.append(fecha_desde)
            
            if fecha_hasta:
                conditions.append("DATE(m.fecha_marcacion) <= %s")
                params.append(fecha_hasta)
            
            if conditions:
                query += " WHERE " + " AND ".join(conditions)
            
            query += " GROUP BY u.num_documento, p.nombres, p.apellido_paterno, p.apellido_materno, p.email"
            query += " ORDER BY nombre_completo"
            
            cursor.execute(query, tuple(params))
            resumen = cursor.fetchall()
            
            print(f"[RESUMEN_USUARIOS] ✅ {len(resumen)} usuarios en el resumen")
            
            # Serializar datos
            import datetime as dt_module
            for item in resumen:
                for key, value in item.items():
                    if isinstance(value, datetime):
                        item[key] = value.isoformat()
                    elif isinstance(value, dt_module.date):
                        item[key] = value.strftime('%Y-%m-%d')
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': resumen
            }), 200
        
        except Error as e:
            print(f"[RESUMEN_USUARIOS] ❌ Error SQL: {e}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        print(f"[RESUMEN_USUARIOS] ❌ Error general: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: OBTENER DETALLE DE MARCACIONES DE UN DÍA ESPECÍFICO
# ============================================================================

@marcacion_bp.route('/api/marcacion/detalle-dia', methods=['GET'])
@login_required
def obtener_detalle_dia():
    """Obtener todas las marcaciones de un usuario en un día específico con fotos y GPS"""
    try:
        num_documento = request.args.get('num_documento')
        fecha = request.args.get('fecha')
        
        if not num_documento or not fecha:
            return jsonify({'success': False, 'error': 'Faltan parámetros requeridos'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[DETALLE_DIA] 🔄 Obteniendo detalle para documento={num_documento}, fecha={fecha}")
            
            # Obtener información del usuario
            cursor.execute("""
                SELECT 
                    u.num_documento,
                    CONCAT(
                        COALESCE(p.nombres, ''),
                        ' ',
                        COALESCE(p.apellido_paterno, ''),
                        ' ',
                        COALESCE(p.apellido_materno, '')
                    ) as nombre_completo,
                    p.email
                FROM TblUsuario u
                INNER JOIN TblPersona p ON u.num_documento = p.num_documento
                WHERE u.num_documento = %s
            """, (num_documento,))
            
            usuario = cursor.fetchone()
            
            if not usuario:
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': 'Usuario no encontrado'}), 404
            
            # Obtener todas las marcaciones del día con fotos
            cursor.execute("""
                SELECT 
                    m.id_marcacion,
                    m.tipo_marcacion,
                    m.fecha_marcacion,
                    TIME(m.fecha_marcacion) as hora,
                    m.latitud,
                    m.longitud,
                    m.precision,
                    m.foto_base64,
                    m.dispositivo,
                    m.observacion
                FROM TblMarcacion m
                WHERE m.num_documento = %s
                    AND DATE(m.fecha_marcacion) = %s
                ORDER BY m.fecha_marcacion ASC
            """, (num_documento, fecha))
            
            marcaciones = cursor.fetchall()
            
            print(f"[DETALLE_DIA] ✅ {len(marcaciones)} marcaciones encontradas")
            
            # Serializar datos
            import datetime as dt_module
            for marcacion in marcaciones:
                for key, value in marcacion.items():
                    if isinstance(value, datetime):
                        marcacion[key] = value.isoformat()
                    elif isinstance(value, dt_module.time):
                        marcacion[key] = value.strftime('%H:%M:%S')
                    elif isinstance(value, dt_module.date):
                        marcacion[key] = value.strftime('%Y-%m-%d')
                    elif isinstance(value, dt_module.timedelta):
                        # Convertir timedelta a string de tiempo HH:MM:SS
                        total_seconds = int(value.total_seconds())
                        hours = total_seconds // 3600
                        minutes = (total_seconds % 3600) // 60
                        seconds = total_seconds % 60
                        marcacion[key] = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'usuario': usuario,
                'fecha': fecha,
                'marcaciones': marcaciones,
                'total_marcaciones': len(marcaciones)
            }), 200
        
        except Error as e:
            print(f"[DETALLE_DIA] ❌ Error SQL: {e}")
            return jsonify({'success': False, 'error': 'Error en la base de datos'}), 500
    
    except Exception as e:
        print(f"[DETALLE_DIA] ❌ Error general: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500
