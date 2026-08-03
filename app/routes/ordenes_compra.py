"""
Module: ordenes_compra.py
Propósito: Gestión de Órdenes de Compra
Fecha: 30 Julio 2026
"""

from flask import render_template, request, jsonify, session, flash, redirect, url_for
from . import main_bp
import mysql.connector
from mysql.connector import Error
from functools import wraps
from app.config import DatabaseConfig
from .main import validar_acceso_usuario
from datetime import datetime
import json


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
            flash('Debes iniciar sesión', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


@main_bp.route('/ordenes-compra')
@login_required
def ordenes_compra():
    """Página de gestión de órdenes de compra"""
    num_documento = session.get('user_documento')
    
    # Validar acceso a Órdenes de Compra (Menu 2, SubMenu 5)
    if not validar_acceso_usuario(num_documento, id_menu=2, id_submenu=5):
        flash('No tienes acceso a Gestión de Órdenes de Compra', 'danger')
        return redirect(url_for('main.dashboard'))
    
    return render_template('ordenes_compra.html')


@main_bp.route('/api/ordenes-compra/requerimientos-aprobados', methods=['GET'])
@login_required
def obtener_requerimientos_aprobados():
    """Obtener requerimientos aprobados para crear órdenes de compra"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[ORDENES_COMPRA] Obteniendo requerimientos aprobados...")
        
        # Llamar al SP para obtener requerimientos aprobados
        cursor.callproc('sp_ObtenerRequerimientosAprobados')
        
        # Obtener resultados
        requerimientos = []
        for result in cursor.stored_results():
            requerimientos = result.fetchall()
            break
        
        print(f"[ORDENES_COMPRA] ✓ {len(requerimientos) if requerimientos else 0} requerimientos aprobados obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': requerimientos or []}), 200
    
    except Exception as e:
        print(f"[ORDENES_COMPRA] [ERROR] Error al obtener requerimientos aprobados: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500
@login_required
def obtener_ordenes_compra():
    """Obtener lista de todas las órdenes de compra"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[ORDENES_COMPRA] [GET] Obteniendo lista de órdenes de compra...")
        
        # Obtener órdenes de compra con información del requerimiento
        query = """
            SELECT 
                oc.id_orden_compra,
                oc.numero_oc,
                oc.estado,
                oc.monto_total,
                oc.fecha_creacion,
                oc.id_requerimiento,
                tr.codigo as requerimiento_codigo,
                tr.descripcion as requerimiento_descripcion,
                CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, '')) as creado_por
            FROM TblOrdenCompra oc
            LEFT JOIN TblRequerimiento tr ON oc.id_requerimiento = tr.id_requerimiento
            LEFT JOIN TblUsuario u ON oc.num_usuario = u.num_documento
            LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
            ORDER BY oc.fecha_creacion DESC
        """
        
        cursor.execute(query)
        ordenes = cursor.fetchall()
        
        # Limpiar espacios en nombres
        if ordenes:
            for orden in ordenes:
                if orden.get('creado_por'):
                    orden['creado_por'] = ' '.join(orden['creado_por'].split())
                if orden.get('fecha_creacion'):
                    orden['fecha_creacion_formatted'] = orden['fecha_creacion'].strftime('%d/%m/%Y')
        
        print(f"[ORDENES_COMPRA] ✓ {len(ordenes) if ordenes else 0} órdenes de compra obtenidas")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': ordenes or []}), 200
    
    except Error as e:
        print(f"[ORDENES_COMPRA] [ERROR] Error al obtener: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/ordenes-compra/obtener/<int:id_orden_compra>', methods=['GET'])
@login_required
def obtener_orden_compra(id_orden_compra):
    """Obtener datos completos de una orden de compra"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_ORDEN_COMPRA] Iniciando para ID: {id_orden_compra}")
        print(f"{'='*80}")
        
        # 1. Obtener información de la orden de compra
        cursor.execute("""
            SELECT 
                oc.id_orden_compra,
                oc.numero_oc,
                oc.estado,
                oc.monto_total,
                oc.fecha_creacion,
                oc.observaciones,
                oc.id_requerimiento,
                tr.codigo as requerimiento_codigo,
                tr.descripcion as requerimiento_descripcion,
                CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, '')) as creado_por
            FROM TblOrdenCompra oc
            LEFT JOIN TblRequerimiento tr ON oc.id_requerimiento = tr.id_requerimiento
            LEFT JOIN TblUsuario u ON oc.num_usuario = u.num_documento
            LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
            WHERE oc.id_orden_compra = %s
        """, (id_orden_compra,))
        
        orden_compra = cursor.fetchone()
        
        if not orden_compra:
            print(f"[OBTENER_ORDEN_COMPRA] [WARN] Orden de compra no encontrada")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Orden de compra no encontrada'}), 404
        
        # Limpiar nombres
        if orden_compra.get('creado_por'):
            orden_compra['creado_por'] = ' '.join(orden_compra['creado_por'].split())
        
        # 2. Obtener detalles de la orden de compra
        cursor.execute("""
            SELECT 
                ocd.id_detalle,
                ocd.id_material,
                ocd.descripcion,
                ocd.cantidad,
                ocd.precio_unitario,
                ocd.subtotal,
                ocd.observaciones,
                m.nombre as material_nombre,
                m.codigo_material
            FROM TblOrdenCompraDetalle ocd
            LEFT JOIN TblMateriales m ON ocd.id_material = m.id_material
            WHERE ocd.id_orden_compra = %s
            ORDER BY ocd.id_detalle
        """, (id_orden_compra,))
        
        detalles = cursor.fetchall()
        
        # 3. Calcular resumen
        cantidad_items = len(detalles) if detalles else 0
        
        resumen = {
            'cantidad_items': cantidad_items,
            'monto_total': float(orden_compra.get('monto_total', 0))
        }
        
        print(f"[OBTENER_ORDEN_COMPRA] [OK] Orden encontrada")
        print(f"[OBTENER_ORDEN_COMPRA]   Número: {orden_compra.get('numero_oc')}")
        print(f"[OBTENER_ORDEN_COMPRA]   Estado: {orden_compra.get('estado')}")
        print(f"[OBTENER_ORDEN_COMPRA]   Detalles: {len(detalles)} items")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'orden_compra': orden_compra,
                'detalles': detalles,
                'resumen': resumen
            }
        }), 200
    
    except Exception as e:
        print(f"[OBTENER_ORDEN_COMPRA] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/ordenes-compra/crear', methods=['POST'])
@login_required
def crear_orden_compra():
    """Crear una nueva orden de compra"""
    try:
        data = request.get_json()
        
        # Validar campos obligatorios
        if not data.get('id_requerimiento'):
            return jsonify({'success': False, 'error': 'Requerimiento es obligatorio'}), 400
        
        if not data.get('detalles') or len(data['detalles']) == 0:
            return jsonify({'success': False, 'error': 'Debe agregar al menos un item'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor()
            
            print(f"\n{'='*80}")
            print(f"[CREAR_ORDEN_COMPRA] Iniciando creación")
            print(f"{'='*80}")
            
            num_usuario = session.get('user_id')
            if not num_usuario:
                num_usuario = session.get('user_documento')
            
            id_requerimiento = data.get('id_requerimiento')
            observaciones = data.get('observaciones', '')
            detalles = data.get('detalles', [])
            
            # Calcular monto total
            monto_total = sum([float(d.get('subtotal', 0)) for d in detalles])
            
            print(f"[CREAR_ORDEN_COMPRA] ID Requerimiento: {id_requerimiento}")
            print(f"[CREAR_ORDEN_COMPRA] Items: {len(detalles)}")
            print(f"[CREAR_ORDEN_COMPRA] Monto Total: {monto_total}")
            
            # 1. Insertar orden de compra principal
            cursor.execute("""
                INSERT INTO TblOrdenCompra 
                (numero_oc, id_requerimiento, num_usuario, estado, monto_total, observaciones, fecha_creacion)
                VALUES (%s, %s, %s, %s, %s, %s, NOW())
            """, (
                f"OC-{datetime.now().strftime('%Y%m%d%H%M%S')}",
                id_requerimiento,
                num_usuario,
                'PENDIENTE',
                monto_total,
                observaciones
            ))
            
            id_orden_compra = cursor.lastrowid
            print(f"[CREAR_ORDEN_COMPRA] ✓ Orden creada con ID: {id_orden_compra}")
            
            # 2. Insertar detalles de la orden
            for detalle in detalles:
                cursor.execute("""
                    INSERT INTO TblOrdenCompraDetalle
                    (id_orden_compra, id_material, descripcion, cantidad, precio_unitario, subtotal, observaciones)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (
                    id_orden_compra,
                    detalle.get('id_material'),
                    detalle.get('descripcion', ''),
                    detalle.get('cantidad', 1),
                    detalle.get('precio_unitario', 0),
                    detalle.get('subtotal', 0),
                    detalle.get('observaciones', '')
                ))
            
            print(f"[CREAR_ORDEN_COMPRA] ✓ {len(detalles)} detalles insertados")
            
            connection.commit()
            
            print(f"[CREAR_ORDEN_COMPRA] [OK] Orden de compra creada exitosamente")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Orden de compra creada exitosamente',
                'id': id_orden_compra,
                'numero_oc': f"OC-{datetime.now().strftime('%Y%m%d%H%M%S')}"
            }), 201
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[CREAR_ORDEN_COMPRA] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_ORDEN_COMPRA] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/ordenes-compra/actualizar/<int:id_orden_compra>', methods=['PUT'])
@login_required
def actualizar_orden_compra(id_orden_compra):
    """Actualizar datos de una orden de compra"""
    try:
        data = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        try:
            print(f"\n{'='*80}")
            print(f"[ACTUALIZAR_ORDEN_COMPRA] Iniciando para ID: {id_orden_compra}")
            print(f"{'='*80}")
            
            observaciones = data.get('observaciones', '')
            detalles = data.get('detalles', [])
            
            print(f"[ACTUALIZAR_ORDEN_COMPRA] Observaciones: {observaciones}")
            print(f"[ACTUALIZAR_ORDEN_COMPRA] Detalles a actualizar: {len(detalles)}")
            
            # 1. Actualizar orden principal
            cursor.execute("""
                UPDATE TblOrdenCompra
                SET observaciones = %s,
                    fecha_actualizacion = NOW()
                WHERE id_orden_compra = %s
            """, (observaciones, id_orden_compra))
            
            # 2. Actualizar detalles
            for detalle in detalles:
                if detalle.get('id_detalle'):
                    cursor.execute("""
                        UPDATE TblOrdenCompraDetalle
                        SET descripcion = %s,
                            cantidad = %s,
                            precio_unitario = %s,
                            subtotal = %s,
                            observaciones = %s
                        WHERE id_detalle = %s AND id_orden_compra = %s
                    """, (
                        detalle.get('descripcion', ''),
                        detalle.get('cantidad', 1),
                        detalle.get('precio_unitario', 0),
                        detalle.get('subtotal', 0),
                        detalle.get('observaciones', ''),
                        detalle.get('id_detalle'),
                        id_orden_compra
                    ))
            
            # 3. Recalcular monto total
            cursor.execute("""
                UPDATE TblOrdenCompra
                SET monto_total = (
                    SELECT COALESCE(SUM(subtotal), 0)
                    FROM TblOrdenCompraDetalle
                    WHERE id_orden_compra = %s
                )
                WHERE id_orden_compra = %s
            """, (id_orden_compra, id_orden_compra))
            
            connection.commit()
            
            print(f"[ACTUALIZAR_ORDEN_COMPRA] [OK] Orden actualizada")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Orden de compra actualizada exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ACTUALIZAR_ORDEN_COMPRA] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ACTUALIZAR_ORDEN_COMPRA] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/ordenes-compra/eliminar/<int:id_orden_compra>', methods=['DELETE'])
@login_required
def eliminar_orden_compra(id_orden_compra):
    """Eliminar una orden de compra (solo si está en PENDIENTE)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            print(f"\n{'='*80}")
            print(f"[ELIMINAR_ORDEN_COMPRA] Iniciando para ID: {id_orden_compra}")
            print(f"{'='*80}")
            
            # Verificar que la orden existe y está en PENDIENTE
            cursor.execute("""
                SELECT id_orden_compra, numero_oc, estado
                FROM TblOrdenCompra
                WHERE id_orden_compra = %s
            """, (id_orden_compra,))
            
            orden = cursor.fetchone()
            if not orden:
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': 'Orden no encontrada'}), 404
            
            if orden['estado'] != 'PENDIENTE':
                cursor.close()
                connection.close()
                print(f"[ELIMINAR_ORDEN_COMPRA] [ERROR] No se puede eliminar orden en estado {orden['estado']}")
                return jsonify({'success': False, 'error': f'No se puede eliminar orden en estado {orden["estado"]}'}), 400
            
            # 1. Eliminar detalles
            cursor.execute("DELETE FROM TblOrdenCompraDetalle WHERE id_orden_compra = %s", (id_orden_compra,))
            
            # 2. Eliminar orden principal
            cursor.execute("DELETE FROM TblOrdenCompra WHERE id_orden_compra = %s", (id_orden_compra,))
            
            connection.commit()
            
            print(f"[ELIMINAR_ORDEN_COMPRA] [OK] Orden eliminada")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Orden de compra eliminada exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ELIMINAR_ORDEN_COMPRA] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ELIMINAR_ORDEN_COMPRA] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/ordenes-compra/cambiar-estado/<int:id_orden_compra>/<nuevo_estado>', methods=['PUT'])
@login_required
def cambiar_estado_orden_compra(id_orden_compra, nuevo_estado):
    """Cambiar estado de una orden de compra"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        try:
            # Validar estado
            estados_validos = ['PENDIENTE', 'ENVIADA', 'RECIBIDA', 'CANCELADA']
            if nuevo_estado not in estados_validos:
                return jsonify({'success': False, 'error': f'Estado inválido: {nuevo_estado}'}), 400
            
            cursor.execute("""
                UPDATE TblOrdenCompra
                SET estado = %s, fecha_actualizacion = NOW()
                WHERE id_orden_compra = %s
            """, (nuevo_estado, id_orden_compra))
            
            connection.commit()
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': f'Estado cambiado a {nuevo_estado}'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
