"""
Rutas para gestión de entregas de materiales a personal
"""
from flask import Blueprint, render_template, jsonify, request, session
from app.funciones.funGeneral import login_required
from app.config import DatabaseConfig
from mysql.connector import Error
import mysql.connector

entregas_personal_bp = Blueprint('entregas_personal', __name__)

def get_db_connection():
    """Conexión local — mismo patrón que inventario.py y proveedores.py"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"[ENTREGAS] Error de conexión: {e}")
        return None

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
    """Listar personal activo con métricas de entrega usando SP"""
    try:
        busqueda = request.args.get('busqueda', '') or None

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        try:
            cursor = connection.cursor(dictionary=True)
            print(f"[LISTAR PERSONAL] Llamando sp_listar_entrega_personal con busqueda={busqueda!r}")
            cursor.callproc('sp_listar_entrega_personal', [busqueda])

            personal = []
            for result in cursor.stored_results():
                personal = result.fetchall()

            print(f"[LISTAR PERSONAL] SP devolvió {len(personal)} filas")
            cursor.close()
            connection.close()

            # Serializar Decimal y datetime
            from decimal import Decimal
            import datetime
            def serial(v):
                if isinstance(v, Decimal): return float(v)
                if isinstance(v, (datetime.datetime, datetime.date)): return v.isoformat()
                return v

            personal = [{k: serial(v) for k, v in row.items()} for row in personal]

            return jsonify({'success': True, 'data': personal}), 200

        except Error as e:
            print(f"[LISTAR PERSONAL] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        import traceback
        print(f"[LISTAR PERSONAL] Error general: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: HISTORIAL DE ENTREGAS POR PERSONA
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/asignados/<id_personal>', methods=['GET'])
@login_required
def obtener_asignados(id_personal):
    """Materiales ya asignados a un trabajador"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.callproc('sp_obtener_asignados_personal', [id_personal])
            items = []
            for result in cursor.stored_results():
                items = result.fetchall()
            cursor.close()
            connection.close()

            from decimal import Decimal
            import datetime
            def serial(v):
                if isinstance(v, Decimal): return float(v)
                if isinstance(v, (datetime.datetime, datetime.date)): return v.isoformat()
                return v
            items = [{k: serial(v) for k, v in row.items()} for row in items]
            return jsonify({'success': True, 'data': items}), 200
        except Error as e:
            print(f"[ASIGNADOS] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@entregas_personal_bp.route('/api/entregas-personal/guardar', methods=['POST'])
@login_required
def guardar_entrega():
    """Guarda cabecera + detalle y descuenta stock en una transacción"""
    try:
        data        = request.get_json()
        id_personal = data.get('id_personal')
        materiales  = data.get('materiales', [])
        observaciones = data.get('observaciones', '')
        creado_por  = str(session.get('user_documento', ''))

        if not id_personal or not materiales:
            return jsonify({'success': False, 'error': 'Datos incompletos'}), 400

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        try:
            cursor = connection.cursor()

            # 1. Crear cabecera via SP
            args = [id_personal, observaciones, creado_por, 0, '', 0, '']
            result = cursor.callproc('sp_guardar_entrega_personal', args)
            p_success    = result[3]
            p_message    = result[4]
            p_id_entrega = result[5]

            if not p_success:
                connection.rollback()
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': p_message}), 400

            # 2. Insertar detalle y descontar stock por cada material
            for mat in materiales:
                id_inv   = int(mat['id_inventario'])
                cantidad = float(mat['cantidad'])
                serie    = mat.get('serie') or None
                estado_b = mat.get('estado_bien', 'BUENO')

                # Verificar stock suficiente
                cursor.execute(
                    "SELECT stock_actual FROM TblInventario WHERE id_inventario = %s",
                    (id_inv,)
                )
                row = cursor.fetchone()
                if not row or float(row[0]) < cantidad:
                    connection.rollback()
                    cursor.close()
                    connection.close()
                    return jsonify({
                        'success': False,
                        'error': f'Stock insuficiente para el material id={id_inv}'
                    }), 400

                # Insertar detalle
                cursor.execute("""
                    INSERT INTO TblEntregaPersonalDetalle
                        (id_entrega, id_inventario, cantidad, serie, estado_bien)
                    VALUES (%s, %s, %s, %s, %s)
                """, (p_id_entrega, id_inv, cantidad, serie, estado_b))

                # Descontar stock
                cursor.execute("""
                    UPDATE TblInventario
                    SET stock_actual = stock_actual - %s,
                        fecha_actualizacion = NOW()
                    WHERE id_inventario = %s
                """, (cantidad, id_inv))

            connection.commit()
            cursor.close()
            connection.close()

            return jsonify({
                'success': True,
                'message': p_message,
                'id_entrega': int(p_id_entrega)
            }), 201

        except Error as e:
            connection.rollback()
            print(f"[GUARDAR ENTREGA] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"[GUARDAR ENTREGA] Error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
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


# ============================================================================
# API: KARDEX DE UN TRABAJADOR
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/kardex/<id_personal>', methods=['GET'])
@login_required
def kardex_personal(id_personal):
    """Ficha + historial completo de materiales asignados a un trabajador"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        try:
            cursor = connection.cursor(dictionary=True)
            cursor.callproc('sp_kardex_personal', [id_personal])

            resultados = []
            for result in cursor.stored_results():
                resultados.append(result.fetchall())

            cursor.close()
            connection.close()

            from decimal import Decimal
            import datetime
            def serial(v):
                if isinstance(v, Decimal): return float(v)
                if isinstance(v, (datetime.datetime, datetime.date)): return v.isoformat()
                return v

            ficha     = {k: serial(v) for k, v in resultados[0][0].items()} if resultados and resultados[0] else {}
            historial = [{k: serial(v) for k, v in row.items()} for row in (resultados[1] if len(resultados) > 1 else [])]

            return jsonify({'success': True, 'ficha': ficha, 'historial': historial}), 200

        except Error as e:
            print(f"[KARDEX] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"[KARDEX] Error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
