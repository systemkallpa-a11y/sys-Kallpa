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
    """Guarda cabecera + detalle y descuenta stock en UNA transacción.

    Cada material se descuenta con sp_registrar_movimiento_stock (Parte 5):
    baja stock_actual y deja su SALIDA en el kardex con tipo de documento
    ENTREGA_PERSONAL. Valida stock suficiente con la fila bloqueada, así dos
    entregas simultáneas no pueden dejar el stock negativo.
    Si un material falla, no se guarda nada de la entrega.
    """
    data = request.get_json(silent=True) or {}
    id_personal = data.get('id_personal')
    materiales = data.get('materiales', [])
    observaciones = data.get('observaciones', '')
    creado_por = str(session.get('user_documento', ''))
    try:
        realizado_por = int(session.get('user_documento'))
    except (TypeError, ValueError):
        realizado_por = None

    if not id_personal or not materiales:
        return jsonify({'success': False, 'error': 'Datos incompletos'}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()

        # 1. Cabecera (sp_guardar_entrega_personal no hace COMMIT propio)
        result = cursor.callproc('sp_guardar_entrega_personal',
                                 [id_personal, observaciones, creado_por, 0, '', 0, ''])
        p_success, p_message, p_id_entrega = result[3], result[4], result[5]
        if not p_success:
            connection.rollback()
            return jsonify({'success': False, 'error': p_message}), 400

        cursor.execute("SELECT codigo_entrega FROM TblEntregaPersonal WHERE id_entrega = %s",
                       (p_id_entrega,))
        fila = cursor.fetchone()
        codigo_entrega = fila[0] if fila else str(p_id_entrega)

        # 2. Detalle + salida de stock con su movimiento, por cada material
        for mat in materiales:
            id_inv = int(mat['id_inventario'])
            cantidad = float(mat['cantidad'])

            mov = cursor.callproc('sp_registrar_movimiento_stock', [
                id_inv, 'SALIDA', cantidad,
                None,                         # almacén del ítem
                'ENTREGA_PERSONAL', int(p_id_entrega),
                f'Entrega al personal {codigo_entrega}',
                observaciones or None,
                realizado_por,
                0, '', 0.0, 0                 # OUT: success, message, nuevo_stock, id_movimiento
            ])
            if not mov[9]:
                connection.rollback()
                return jsonify({'success': False, 'error': mov[10]}), 400

            cursor.execute("""
                INSERT INTO TblEntregaPersonalDetalle
                    (id_entrega, id_inventario, cantidad, serie, estado_bien)
                VALUES (%s, %s, %s, %s, %s)
            """, (p_id_entrega, id_inv, cantidad, mat.get('serie') or None,
                  mat.get('estado_bien', 'BUENO')))

        connection.commit()
        cursor.close()

        return jsonify({
            'success': True,
            'message': p_message,
            'id_entrega': int(p_id_entrega)
        }), 201

    except Error as e:
        connection.rollback()
        print(f"[GUARDAR ENTREGA] Error SQL: {e}")
        return jsonify({'success': False, 'error': f'Error de base de datos: {e.msg}'}), 500
    except (KeyError, TypeError, ValueError) as e:
        connection.rollback()
        return jsonify({'success': False, 'error': f'Datos de material inválidos: {e}'}), 400
    finally:
        connection.close()


# ============================================================================
# API: REGISTRAR NUEVA ENTREGA (obsoleto)
# ============================================================================

@entregas_personal_bp.route('/api/entregas-personal/registrar', methods=['POST'])
@login_required
def registrar_entrega():
    """Obsoleto: insertaba en columnas que no existen en TblMovimientoInventario
    (destino, responsable_destino, documento_referencia, creado_por) y siempre
    fallaba. Las entregas se registran con /api/entregas-personal/guardar
    (opción "Asignar materiales"), que sí descuenta stock y deja el kardex."""
    return jsonify({
        'success': False,
        'message': 'Esta opción ya no está disponible. Use "Asignar materiales" para registrar la entrega.'
    }), 410


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
