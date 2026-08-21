from flask import render_template, request, jsonify, session, flash, redirect, url_for
from . import main_bp
import mysql.connector
from mysql.connector import Error
from functools import wraps
from app.config import DatabaseConfig
from .main import validar_acceso_usuario
from datetime import datetime

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
            flash('Debes iniciar sesin', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function

@main_bp.route('/ot')
@login_required
def ot():
    """Pgina principal de gestin de O.T (rdenes de Trabajo)"""
    num_documento = session.get('user_documento')
    
    # ID 5 = O.T (rdenes de Trabajo)
    # No requiere validar submen en ruta principal
    
    return render_template('ot.html')

@main_bp.route('/api/ot/obtener', methods=['GET'])
@login_required
def obtener_ots():
    """Obtener lista de todas las O.T"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[OT] [GET] Obteniendo lista de O.T")
        
        # Obtener O.T
        cursor.execute("""
            SELECT 
                id_ot,
                numero_ot,
                descripcion,
                proyecto,
                estado,
                monto_presupuestado,
                monto_gastado,
                obs_presupuesto,
                observaciones,
                fecha_creacion,
                fecha_actualizacion
            FROM TblOT
            WHERE estado != 'ELIMINADA'
            ORDER BY fecha_creacion DESC
        """)
        
        ots = cursor.fetchall()
        
        print(f"[OT] [OK] {len(ots)} O.T obtenidas")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': ots}), 200
    
    except Error as e:
        print(f"[OT] [ERROR] Error al obtener: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ot/obtener/<int:id_ot>', methods=['GET'])
@login_required
def obtener_ot(id_ot):
    """Obtener datos de una O.T especfica"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_OT] Iniciando para ID: {id_ot}")
        print(f"{'='*80}")
        
        cursor.execute("""
            SELECT 
                id_ot,
                numero_ot,
                descripcion,
                proyecto,
                estado,
                monto_presupuestado,
                monto_gastado,
                obs_presupuesto,
                observaciones,
                fecha_creacion,
                fecha_actualizacion
            FROM TblOT
            WHERE id_ot = %s
        """, (id_ot,))
        
        ot = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if not ot:
            print(f"[OBTENER_OT] [WARN] O.T no encontrada")
            return jsonify({'success': False, 'error': 'O.T no encontrada'}), 404
        
        print(f"[OBTENER_OT] [OK] O.T encontrada")
        print(f"{'='*80}\n")
        
        return jsonify({'success': True, 'data': ot}), 200
    
    except Error as e:
        print(f"[OBTENER_OT] [ERROR] Error SQL: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ot/crear', methods=['POST'])
@login_required
def crear_ot():
    """Crear una nueva O.T"""
    try:
        data = request.get_json()
        
        # Validar campos obligatorios
        campos_requeridos = ['numero_ot', 'descripcion', 'proyecto', 'estado', 'monto_presupuestado']
        for campo in campos_requeridos:
            if not data.get(campo):
                return jsonify({'success': False, 'error': f'Campo requerido: {campo}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor()
            
            print(f"\n{'='*80}")
            print(f"[CREAR_OT] Iniciando creacin")
            print(f"{'='*80}")
            print(f"[CREAR_OT] Datos:")
            for key, value in data.items():
                print(f"  - {key}: {value}")
            
            # Verificar que el nmero de O.T no exista
            cursor.execute("SELECT COUNT(*) as count FROM TblOT WHERE numero_ot = %s", (data['numero_ot'],))
            result = cursor.fetchone()
            
            if result[0] > 0:
                print(f"[CREAR_OT] [ERROR] El nmero de O.T ya existe")
                return jsonify({'success': False, 'error': 'El nmero de O.T ya existe'}), 400
            
            # Insertar la O.T
            cursor.execute("""
                INSERT INTO TblOT (
                    numero_ot,
                    descripcion,
                    proyecto,
                    estado,
                    monto_presupuestado,
                    monto_gastado,
                    obs_presupuesto,
                    observaciones,
                    fecha_creacion
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
            """, (
                data['numero_ot'],
                data['descripcion'],
                data['proyecto'],
                data['estado'],
                data['monto_presupuestado'],
                data.get('monto_gastado', 0),
                data.get('obs_presupuesto', ''),
                data.get('observaciones', '')
            ))
            
            ot_id = cursor.lastrowid
            
            print(f"[CREAR_OT] [OK] O.T creada con ID: {ot_id}")
            
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': 'O.T creada exitosamente',
                'id': ot_id
            }), 201
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[CREAR_OT] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_OT] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ot/actualizar/<int:id_ot>', methods=['PUT'])
@login_required
def actualizar_ot(id_ot):
    """Actualizar datos de una O.T"""
    try:
        data = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor()
        
        try:
            print(f"\n{'='*80}")
            print(f"[ACTUALIZAR_OT] Iniciando para ID: {id_ot}")
            print(f"{'='*80}")
            print(f"[ACTUALIZAR_OT] Datos:")
            for key, value in data.items():
                print(f"  - {key}: {value}")
            
            # Actualizar la O.T
            cursor.execute("""
                UPDATE TblOT
                SET
                    numero_ot = %s,
                    descripcion = %s,
                    proyecto = %s,
                    estado = %s,
                    monto_presupuestado = %s,
                    monto_gastado = %s,
                    obs_presupuesto = %s,
                    observaciones = %s,
                    fecha_actualizacion = NOW()
                WHERE id_ot = %s
            """, (
                data.get('numero_ot', ''),
                data.get('descripcion', ''),
                data.get('proyecto', ''),
                data.get('estado', ''),
                data.get('monto_presupuestado', 0),
                data.get('monto_gastado', 0),
                data.get('obs_presupuesto', ''),
                data.get('observaciones', ''),
                id_ot
            ))
            
            print(f"[ACTUALIZAR_OT] [OK] O.T actualizada")
            
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': 'O.T actualizada exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ACTUALIZAR_OT] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ACTUALIZAR_OT] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/ot/eliminar/<int:id_ot>', methods=['DELETE'])
@login_required
def eliminar_ot(id_ot):
    """Eliminar una O.T (soft delete)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor()
        
        try:
            print(f"\n{'='*80}")
            print(f"[ELIMINAR_OT] Iniciando para ID: {id_ot}")
            print(f"{'='*80}")
            
            # Soft delete: marcar como ELIMINADA en lugar de borrar
            cursor.execute("""
                UPDATE TblOT
                SET estado = 'ELIMINADA',
                    fecha_actualizacion = NOW()
                WHERE id_ot = %s
            """, (id_ot,))
            
            print(f"[ELIMINAR_OT] [OK] O.T marcada como eliminada")
            
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': 'O.T eliminada exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ELIMINAR_OT] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ELIMINAR_OT] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500
