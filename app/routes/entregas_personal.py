"""
Rutas para gestión de entregas de materiales a personal
"""
from flask import Blueprint, render_template, jsonify, request, session
from app.funciones.funGeneral import get_db_connection, login_required
from mysql.connector import Error

entregas_personal_bp = Blueprint('entregas_personal', __name__)

# ============================================================================
# PÁGINA PRINCIPAL
# ============================================================================

@entregas_personal_bp.route('/entregas-personal')
@login_required
def entregas_personal():
    """Página principal de entregas a personal"""
    return render_template('entregas_personal.html')


# ============================================================================
# API: LISTAR PERSONAL CON ENTREGAS
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/listar', methods=['GET'])
@login_required
def listar_personal_entregas():
    """Listar personal con materiales entregados"""
    try:
        busqueda = request.args.get('busqueda', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            query = """
                SELECT 
                    u.num_documento,
                    CONCAT(u.primer_nombre, ' ', u.apellido_paterno, ' ', u.apellido_materno) AS nombre_completo,
                    u.email,
                    u.telefono,
                    g.nombre_gerencia AS area,
                    COUNT(DISTINCT m.id_movimiento) AS total_entregas,
                    COALESCE(SUM(m.cantidad), 0) AS total_items,
                    MAX(m.fecha_movimiento) AS ultima_entrega
                FROM TblUsuarios u
                LEFT JOIN TblGerencias g ON u.id_gerencia = g.id_gerencia
                LEFT JOIN TblMovimientoInventario m ON u.num_documento = m.responsable_destino 
                    AND m.tipo_movimiento = 'SALIDA'
                WHERE u.estado = 'ACTIVO'
            """
            
            params = []
            if busqueda:
                query += """ AND (
                    u.num_documento LIKE %s OR
                    u.primer_nombre LIKE %s OR
                    u.apellido_paterno LIKE %s OR
                    u.apellido_materno LIKE %s OR
                    u.email LIKE %s
                )"""
                search_param = f'%{busqueda}%'
                params.extend([search_param] * 5)
            
            query += " GROUP BY u.num_documento ORDER BY nombre_completo ASC"
            
            cursor.execute(query, params)
            personal = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': personal
            }), 200
        
        except Error as e:
            print(f"[LISTAR PERSONAL] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[LISTAR PERSONAL] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: HISTORIAL DE ENTREGAS POR PERSONA
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/historial/<num_documento>', methods=['GET'])
@login_required
def historial_entregas(num_documento):
    """Obtener historial de entregas de una persona"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Información del personal
            cursor.execute("""
                SELECT 
                    num_documento,
                    CONCAT(primer_nombre, ' ', apellido_paterno, ' ', apellido_materno) AS nombre_completo,
                    email,
                    telefono,
                    g.nombre_gerencia AS area
                FROM TblUsuarios u
                LEFT JOIN TblGerencias g ON u.id_gerencia = g.id_gerencia
                WHERE num_documento = %s
            """, (num_documento,))
            
            personal = cursor.fetchone()
            
            if not personal:
                return jsonify({'success': False, 'message': 'Personal no encontrado'}), 404
            
            # Historial de entregas
            cursor.execute("""
                SELECT 
                    m.id_movimiento,
                    m.codigo_movimiento,
                    m.fecha_movimiento,
                    i.codigo AS codigo_material,
                    i.nombre AS material,
                    m.cantidad,
                    u.abreviatura AS unidad,
                    m.destino,
                    m.documento_referencia,
                    m.observaciones,
                    CONCAT(entregador.primer_nombre, ' ', entregador.apellido_paterno) AS entregado_por
                FROM TblMovimientoInventario m
                INNER JOIN TblInventario i ON m.id_inventario = i.id_inventario
                LEFT JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
                LEFT JOIN TblUsuarios entregador ON m.creado_por = entregador.num_documento
                WHERE m.responsable_destino = %s
                    AND m.tipo_movimiento = 'SALIDA'
                ORDER BY m.fecha_movimiento DESC
            """, (num_documento,))
            
            entregas = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': {
                    'personal': personal,
                    'entregas': entregas
                }
            }), 200
        
        except Error as e:
            print(f"[HISTORIAL] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[HISTORIAL] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: REGISTRAR NUEVA ENTREGA
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/registrar', methods=['POST'])
@login_required
def registrar_entrega():
    """Registrar una nueva entrega de material a personal"""
    try:
        data = request.get_json()
        
        # Validar campos requeridos
        required_fields = ['num_documento_personal', 'id_inventario', 'cantidad', 'destino']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Obtener usuario actual
            creado_por = session.get('user_documento')
            
            # Generar código de movimiento
            cursor.execute("""
                SELECT CONCAT('ENT-', LPAD(COALESCE(MAX(CAST(SUBSTRING(codigo_movimiento, 5) AS UNSIGNED)), 0) + 1, 6, '0')) AS codigo
                FROM TblMovimientoInventario
                WHERE codigo_movimiento LIKE 'ENT-%'
            """)
            
            result = cursor.fetchone()
            codigo_movimiento = result['codigo'] if result else 'ENT-000001'
            
            # Registrar movimiento de salida
            cursor.execute("""
                INSERT INTO TblMovimientoInventario (
                    codigo_movimiento,
                    id_inventario,
                    tipo_movimiento,
                    cantidad,
                    destino,
                    responsable_destino,
                    documento_referencia,
                    observaciones,
                    fecha_movimiento,
                    creado_por
                ) VALUES (%s, %s, 'SALIDA', %s, %s, %s, %s, %s, NOW(), %s)
            """, (
                codigo_movimiento,
                int(data['id_inventario']),
                float(data['cantidad']),
                data['destino'],
                data['num_documento_personal'],
                data.get('documento_referencia', ''),
                data.get('observaciones', ''),
                creado_por
            ))
            
            # Actualizar stock
            cursor.execute("""
                UPDATE TblInventario
                SET stock_actual = stock_actual - %s
                WHERE id_inventario = %s
            """, (float(data['cantidad']), int(data['id_inventario'])))
            
            connection.commit()
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Entrega registrada correctamente',
                'codigo': codigo_movimiento
            }), 201
        
        except Error as e:
            connection.rollback()
            print(f"[REGISTRAR ENTREGA] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[REGISTRAR ENTREGA] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: BUSCAR PERSONAL
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/buscar-personal', methods=['GET'])
@login_required
def buscar_personal():
    """Buscar personal para autocompletado"""
    try:
        query = request.args.get('q', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            cursor.execute("""
                SELECT 
                    num_documento,
                    CONCAT(primer_nombre, ' ', apellido_paterno, ' ', apellido_materno) AS nombre_completo,
                    email,
                    g.nombre_gerencia AS area
                FROM TblUsuarios u
                LEFT JOIN TblGerencias g ON u.id_gerencia = g.id_gerencia
                WHERE u.estado = 'ACTIVO'
                    AND (
                        u.num_documento LIKE %s OR
                        u.primer_nombre LIKE %s OR
                        u.apellido_paterno LIKE %s OR
                        u.apellido_materno LIKE %s
                    )
                ORDER BY nombre_completo ASC
                LIMIT 10
            """, tuple([f'%{query}%'] * 4))
            
            personal = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': personal
            }), 200
        
        except Error as e:
            print(f"[BUSCAR PERSONAL] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[BUSCAR PERSONAL] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500
