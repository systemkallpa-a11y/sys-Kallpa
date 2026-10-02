"""
Rutas para el módulo de Inventario
"""
from flask import Blueprint, render_template, request, session, jsonify
from functools import wraps
from mysql.connector import Error
from app.config import DatabaseConfig
import mysql.connector

# Crear blueprint para inventario
inventario_bp = Blueprint('inventario', __name__)

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
# RUTA: PÁGINA DE INVENTARIO
# ============================================================================

@inventario_bp.route('/inventario')
@login_required
def inventario():
    """Página principal de gestión de inventario"""
    return render_template('inventario.html')


# ============================================================================
# API: LISTAR MATERIALES DEL INVENTARIO
# ============================================================================

@inventario_bp.route('/api/inventario/listar', methods=['GET'])
@login_required
def listar_inventario():
    """Obtener lista de items en inventario con stock (usando SP)"""
    try:
        # Parámetros de filtro opcionales
        busqueda = request.args.get('busqueda', '')
        categoria = request.args.get('categoria', '')
        estado = request.args.get('estado', 'ACTIVO')
        tipo = request.args.get('tipo', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Llamar al stored procedure
            cursor.callproc('sp_listar_inventario', [
                busqueda or None,
                categoria or None,
                tipo or None,
                estado or None
            ])
            
            # Obtener resultados
            items = []
            for result in cursor.stored_results():
                items = result.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': items
            }), 200
        
        except Error as e:
            print(f"[INVENTARIO] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[INVENTARIO] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: OBTENER CATEGORÍAS
# ============================================================================

@inventario_bp.route('/api/inventario/categorias', methods=['GET'])
@login_required
def obtener_categorias():
    """Obtener lista de categorías de inventario (nuevo sistema)"""
    try:
        tipo = request.args.get('tipo', '')  # Filtro opcional por tipo
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            query = """
                SELECT id_categoria, codigo, nombre, descripcion, nivel, tipo_aplicable
                FROM TblCategoriaInventario
                WHERE estado = 'ACTIVO'
            """
            
            params = []
            if tipo:
                query += " AND tipo_aplicable = %s"
                params.append(tipo)
            
            query += " ORDER BY nivel, orden ASC"
            
            cursor.execute(query, params)
            categorias = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': categorias
            }), 200
        
        except Error as e:
            print(f"[CATEGORIAS] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CATEGORIAS] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: ESTADÍSTICAS DEL INVENTARIO
# ============================================================================

@inventario_bp.route('/api/inventario/estadisticas', methods=['GET'])
@login_required
def obtener_estadisticas():
    """Obtener estadísticas del inventario (usando SP)"""
    try:
        tipo = request.args.get('tipo', '')  # Filtro opcional por tipo
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Llamar al stored procedure
            cursor.callproc('sp_estadisticas_inventario', [tipo or None])
            
            # Obtener resultados
            estadisticas = None
            for result in cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    estadisticas = rows[0]
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': estadisticas
            }), 200
        
        except Error as e:
            print(f"[ESTADISTICAS] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ESTADISTICAS] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: OBTENER UNIDADES DE MEDIDA
# ============================================================================

@inventario_bp.route('/api/inventario/unidades', methods=['GET'])
@login_required
def obtener_unidades():
    """Obtener lista de unidades de medida"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            cursor.execute("""
                SELECT id_unidad, codigo, nombre, abreviatura
                FROM TblUnidadMedida
                WHERE estado = 'ACTIVO'
                ORDER BY nombre ASC
            """)
            
            unidades = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': unidades
            }), 200
        
        except Error as e:
            print(f"[UNIDADES] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[UNIDADES] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: OBTENER ALMACENES
# ============================================================================

@inventario_bp.route('/api/inventario/almacenes', methods=['GET'])
@login_required
def obtener_almacenes():
    """Obtener lista de almacenes"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            cursor.execute("""
                SELECT id_almacen, codigo, nombre, tipo, direccion
                FROM TblAlmacen
                WHERE estado = 'ACTIVO'
                ORDER BY nombre ASC
            """)
            
            almacenes = cursor.fetchall()
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'data': almacenes
            }), 200
        
        except Error as e:
            print(f"[ALMACENES] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ALMACENES] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: CREAR NUEVO ITEM
# ============================================================================

@inventario_bp.route('/api/inventario/crear', methods=['POST'])
@login_required
def crear_item():
    """Crear nuevo item de inventario con código automático (usando SP)"""
    try:
        data = request.get_json()
        
        # Validar campos requeridos (código ya NO es requerido)
        required_fields = ['nombre', 'tipo_inventario', 'id_categoria', 'id_unidad']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Obtener usuario actual (debe ser INT)
            num_usuario = session.get('user_documento')
            if num_usuario:
                try:
                    num_usuario = int(num_usuario)
                except:
                    num_usuario = 0
            else:
                num_usuario = 0
            
            # Preparar parámetros para el SP
            args = [
                data['nombre'],
                data.get('descripcion', ''),
                data['tipo_inventario'],
                int(data['id_categoria']),
                int(data.get('id_subcategoria')) if data.get('id_subcategoria') else None,
                int(data['id_unidad']),
                float(data.get('stock_minimo', 0)),
                float(data.get('stock_maximo', 0)),
                float(data.get('precio_compra', 0)),
                int(data.get('id_almacen')) if data.get('id_almacen') else None,
                data.get('ubicacion_fisica', ''),
                None,  # atributos_json (se procesarán después)
                num_usuario,
                0,  # @p_success OUT
                '',  # @p_message OUT
                0,  # @p_id_inventario OUT
                ''   # @p_codigo OUT
            ]
            
            print(f"[DEBUG] Llamando a sp_crear_inventario con args: {args[:13]}")
            
            # Llamar al SP
            result = cursor.callproc('sp_crear_inventario', args)
            
            print(f"[DEBUG] Resultado del SP: {result}")
            
            # Obtener valores OUT
            p_success = result[13]  # índice 13 = p_success
            p_message = result[14]  # índice 14 = p_message
            p_id_inventario = result[15]  # índice 15 = p_id_inventario
            p_codigo = result[16]  # índice 16 = p_codigo
            
            print(f"[DEBUG] success={p_success}, message={p_message}, id={p_id_inventario}, codigo={p_codigo}")
            
            if p_success:
                # Insertar atributos dinámicos
                atributos = data.get('atributos', {})
                if atributos and p_id_inventario:
                    for nombre, valor in atributos.items():
                        if valor:  # Solo insertar si tiene valor
                            cursor.execute("""
                                INSERT INTO TblInventarioAtributos (id_inventario, nombre_atributo, valor_atributo, tipo_dato)
                                VALUES (%s, %s, %s, 'TEXTO')
                            """, (p_id_inventario, nombre, valor))
                
                connection.commit()
                cursor.close()
                connection.close()
                
                return jsonify({
                    'success': True,
                    'message': p_message,
                    'id_inventario': int(p_id_inventario),
                    'codigo': p_codigo
                }), 201
            else:
                connection.rollback()
                cursor.close()
                connection.close()
                
                return jsonify({
                    'success': False,
                    'message': p_message
                }), 400
        
        except Error as e:
            connection.rollback()
            print(f"[CREAR ITEM] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR ITEM] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: DETALLE DEL ITEM
# ============================================================================

@inventario_bp.route('/api/inventario/detalle/<int:id_inventario>', methods=['GET'])
@login_required
def detalle_item(id_inventario):
    """Obtener detalle completo de un item con sus atributos (usando SP)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Llamar al stored procedure
            cursor.callproc('sp_detalle_inventario', [id_inventario])
            
            # Obtener resultados (2 result sets)
            item = None
            atributos = []
            
            for idx, result in enumerate(cursor.stored_results()):
                if idx == 0:
                    # Primer result set: datos del item
                    rows = result.fetchall()
                    if rows:
                        item = rows[0]
                elif idx == 1:
                    # Segundo result set: atributos
                    atributos = result.fetchall()
            
            cursor.close()
            connection.close()
            
            if not item:
                return jsonify({'success': False, 'message': 'Item no encontrado'}), 404
            
            # Agregar atributos al item
            item['atributos'] = atributos
            
            return jsonify({
                'success': True,
                'data': item
            }), 200
        
        except Error as e:
            print(f"[DETALLE ITEM] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[DETALLE ITEM] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: REGISTRAR MOVIMIENTO DE INVENTARIO
# ============================================================================

@inventario_bp.route('/api/inventario/movimiento', methods=['POST'])
@login_required
def registrar_movimiento():
    """Registrar movimiento de inventario (entrada/salida/ajuste) usando SP"""
    try:
        data = request.get_json()
        
        # Validar campos
        required_fields = ['id_inventario', 'tipo_movimiento', 'cantidad', 'motivo']
        for field in required_fields:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor()
            
            # Obtener el usuario actual
            num_usuario = session.get('user_documento') or session.get('user_email')
            
            # Preparar parámetros para el SP
            id_inventario = int(data['id_inventario'])
            tipo_movimiento = data['tipo_movimiento']
            cantidad = float(data['cantidad'])
            motivo = data['motivo']
            documento_ref = data.get('documento_referencia', '')
            
            # Llamar al stored procedure con parámetros OUT
            args = [
                id_inventario,
                tipo_movimiento,
                cantidad,
                motivo,
                documento_ref,
                num_usuario,
                0,  # @p_success OUT
                '',  # @p_message OUT
                0.0  # @p_nuevo_stock OUT
            ]
            
            result = cursor.callproc('sp_ajustar_stock', args)
            
            # Obtener los valores OUT
            p_success = result[6]  # índice 6 = p_success
            p_message = result[7]  # índice 7 = p_message
            p_nuevo_stock = result[8]  # índice 8 = p_nuevo_stock
            
            connection.commit()
            cursor.close()
            connection.close()
            
            # Retornar respuesta
            if p_success:
                return jsonify({
                    'success': True,
                    'message': p_message,
                    'nuevo_stock': float(p_nuevo_stock)
                }), 200
            else:
                return jsonify({
                    'success': False,
                    'message': p_message
                }), 400
        
        except Error as e:
            connection.rollback()
            print(f"[MOVIMIENTO] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[MOVIMIENTO] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500
