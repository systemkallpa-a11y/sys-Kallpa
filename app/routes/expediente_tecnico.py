"""
Rutas para Expediente Técnico
Módulo para gestionar expedientes técnicos de las OT
"""

from flask import render_template, jsonify, request, session
from functools import wraps
import mysql.connector
from mysql.connector import Error
from app.routes import main_bp
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

# ============================================================================
# DECORADOR: Login Required
# ============================================================================
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'success': False, 'error': 'No autorizado'}), 401
        return f(*args, **kwargs)
    return decorated_function


# ============================================================================
# RUTA: Vista Principal de Expediente Técnico
# ============================================================================
@main_bp.route('/expediente-tecnico')
@login_required
def expediente_tecnico():
    """Página principal de expedientes técnicos"""
    user_name = session.get('user_name', 'Usuario')
    user_role = session.get('user_role', 'Rol')
    user_empresa = session.get('user_empresa', 'Empresa')
    
    return render_template('expediente_tecnico.html',
                         user_name=user_name,
                         user_role=user_role,
                         user_empresa=user_empresa)


# ============================================================================
# API: Obtener Lista de Expedientes Técnicos
# ============================================================================
@main_bp.route('/api/expediente-tecnico/obtener', methods=['GET'])
@login_required
def obtener_expedientes():
    """Obtener todos los expedientes técnicos"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Query para obtener expedientes con información de OT
        cursor.execute("""
            SELECT 
                et.id_expediente,
                et.id_ot,
                ot.codigo_ot,
                ot.descripcion as descripcion_ot,
                o.nombre as nombre_obra,
                p.nombre as nombre_proyecto,
                et.fecha_inicio,
                et.fecha_fin,
                et.estado,
                et.presupuesto_aprobado,
                et.observaciones,
                et.fecha_creacion,
                CONCAT(per.nombre, ' ', per.apellido_paterno) as creado_por
            FROM TblExpedienteTecnico et
            JOIN TblOT ot ON et.id_ot = ot.id_ot
            JOIN TblObra o ON ot.id_obra = o.id_obra
            JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            LEFT JOIN TblPersona per ON et.creado_por = per.num_documento
            WHERE et.estado != 'ELIMINADO'
            ORDER BY et.fecha_creacion DESC
        """)
        
        expedientes = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'expedientes': expedientes}), 200
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[EXPEDIENTE_TECNICO] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Obtener Expediente por ID
# ============================================================================
@main_bp.route('/api/expediente-tecnico/obtener/<int:id_expediente>', methods=['GET'])
@login_required
def obtener_expediente(id_expediente):
    """Obtener detalles de un expediente técnico específico"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                et.*,
                ot.codigo_ot,
                ot.descripcion as descripcion_ot,
                o.nombre as nombre_obra,
                p.nombre as nombre_proyecto,
                CONCAT(per.nombre, ' ', per.apellido_paterno) as creado_por
            FROM TblExpedienteTecnico et
            JOIN TblOT ot ON et.id_ot = ot.id_ot
            JOIN TblObra o ON ot.id_obra = o.id_obra
            JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            LEFT JOIN TblPersona per ON et.creado_por = per.num_documento
            WHERE et.id_expediente = %s
        """, (id_expediente,))
        
        expediente = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if not expediente:
            return jsonify({'success': False, 'error': 'Expediente no encontrado'}), 404
        
        return jsonify({'success': True, 'expediente': expediente}), 200
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Crear Expediente Técnico
# ============================================================================
@main_bp.route('/api/expediente-tecnico/crear', methods=['POST'])
@login_required
def crear_expediente():
    """Crear un nuevo expediente técnico"""
    try:
        data = request.get_json()
        user_documento = session.get('user_documento')
        
        # Validar datos requeridos
        required_fields = ['id_ot', 'fecha_inicio', 'presupuesto_aprobado']
        for field in required_fields:
            if field not in data:
                return jsonify({'success': False, 'error': f'Campo requerido: {field}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        cursor.execute("""
            INSERT INTO TblExpedienteTecnico (
                id_ot,
                fecha_inicio,
                fecha_fin,
                presupuesto_aprobado,
                observaciones,
                estado,
                creado_por,
                fecha_creacion
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
        """, (
            data['id_ot'],
            data['fecha_inicio'],
            data.get('fecha_fin'),
            data['presupuesto_aprobado'],
            data.get('observaciones', ''),
            'ACTIVO',
            user_documento
        ))
        
        connection.commit()
        id_expediente = cursor.lastrowid
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Expediente técnico creado exitosamente',
            'id_expediente': id_expediente
        }), 201
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Actualizar Expediente Técnico
# ============================================================================
@main_bp.route('/api/expediente-tecnico/actualizar/<int:id_expediente>', methods=['PUT'])
@login_required
def actualizar_expediente(id_expediente):
    """Actualizar un expediente técnico existente"""
    try:
        data = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        cursor.execute("""
            UPDATE TblExpedienteTecnico
            SET fecha_inicio = %s,
                fecha_fin = %s,
                presupuesto_aprobado = %s,
                observaciones = %s,
                estado = %s,
                fecha_actualizacion = NOW()
            WHERE id_expediente = %s
        """, (
            data.get('fecha_inicio'),
            data.get('fecha_fin'),
            data.get('presupuesto_aprobado'),
            data.get('observaciones', ''),
            data.get('estado', 'ACTIVO'),
            id_expediente
        ))
        
        connection.commit()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Expediente técnico actualizado exitosamente'
        }), 200
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Eliminar Expediente Técnico (Soft Delete)
# ============================================================================
@main_bp.route('/api/expediente-tecnico/eliminar/<int:id_expediente>', methods=['DELETE'])
@login_required
def eliminar_expediente(id_expediente):
    """Eliminar (soft delete) un expediente técnico"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        cursor.execute("""
            UPDATE TblExpedienteTecnico
            SET estado = 'ELIMINADO',
                fecha_actualizacion = NOW()
            WHERE id_expediente = %s
        """, (id_expediente,))
        
        connection.commit()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Expediente técnico eliminado exitosamente'
        }), 200
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Obtener OTs sin Expediente Técnico
# ============================================================================
@main_bp.route('/api/expediente-tecnico/ots-disponibles', methods=['GET'])
@login_required
def obtener_ots_disponibles():
    """Obtener OTs que no tienen expediente técnico asignado"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                ot.id_ot,
                ot.codigo_ot,
                ot.descripcion,
                o.nombre as nombre_obra,
                p.nombre as nombre_proyecto
            FROM TblOT ot
            JOIN TblObra o ON ot.id_obra = o.id_obra
            JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            LEFT JOIN TblExpedienteTecnico et ON ot.id_ot = et.id_ot 
                AND et.estado != 'ELIMINADO'
            WHERE ot.estado = 'ACTIVO' 
                AND et.id_expediente IS NULL
            ORDER BY ot.fecha_creacion DESC
        """)
        
        ots = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'ots': ots}), 200
        
    except Error as e:
        print(f"[EXPEDIENTE_TECNICO] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
