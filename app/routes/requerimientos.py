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

# Decorador para requerir autenticación
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

@main_bp.route('/requerimiento')
@login_required
def requerimiento():
    """Página de gestión de requerimientos"""
    # Validar que el usuario tenga acceso a Gestión de Requerimientos
    num_documento = session.get('user_documento')
    
    if not validar_acceso_usuario(num_documento, id_menu=2, id_submenu=4):
        flash('No tienes acceso a Gestión de Requerimientos', 'danger')
        return redirect(url_for('main.dashboard'))
    
    return render_template('requerimiento.html')

@main_bp.route('/api/requerimientos/obtener', methods=['GET'])
@login_required
def obtener_requerimientos():
    """Obtener lista de todos los requerimientos con aprobadores usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[REQUERIMIENTOS] [GET] Obteniendo lista de requerimientos con aprobadores...")
        print(f"[REQUERIMIENTOS] Usando SP: sp_ObtenerRequerimientosConAprobadores")
        
        # Llamar al SP que incluye información de aprobadores
        cursor.callproc('sp_ObtenerRequerimientosConAprobadores')
        
        # Obtener resultados
        requerimientos = []
        for result in cursor.stored_results():
            requerimientos = result.fetchall()
            break
        
        # Limpiar datos y formatear
        if requerimientos:
            for req in requerimientos:
                # Limpiar espacios en nombres
                if req.get('solicitante'):
                    req['solicitante'] = ' '.join(req['solicitante'].split())
                if req.get('aprobado_rechazado_por'):
                    req['aprobado_rechazado_por'] = ' '.join(req['aprobado_rechazado_por'].split())
                
                # Formatear fecha
                if req.get('fecha_creacion'):
                    req['fecha_creacion_formatted'] = req['fecha_creacion'].strftime('%d/%m/%Y')
        
        print(f"[REQUERIMIENTOS] ✓ {len(requerimientos) if requerimientos else 0} requerimientos obtenidos")
        print(f"[REQUERIMIENTOS] ✓ Incluye columna 'aprobado_rechazado_por' para el flujo de aprobación")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': requerimientos or []}), 200
    
    except Error as e:
        print(f"[REQUERIMIENTOS] [ERROR] Error al obtener: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/requerimientos/obtener/<int:id_requerimiento>', methods=['GET'])
@login_required
def obtener_requerimiento(id_requerimiento):
    """Obtener datos completos de un requerimiento con todos sus detalles"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_REQUERIMIENTO] Iniciando para ID: {id_requerimiento}")
        print(f"{'='*80}")
        
        # 1. Obtener información del requerimiento CON usuario y presupuesto
        cursor.execute("""
            SELECT 
                tr.id_requerimiento,
                tr.num_usuario,
                tr.codigo,
                tr.descripcion,
                tr.cantidad,
                tr.estado,
                tr.observaciones,
                tr.id_presupuesto,
                tr.id_tipo_documento,
                tr.fecha_creacion,
                tr.fecha_actualizacion,
                CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as usuario_completo,
                pr.numero_presupuesto
            FROM TblRequerimiento tr
            LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
            LEFT JOIN TblPresupuesto pr ON tr.id_presupuesto = pr.id_presupuesto
            WHERE tr.id_requerimiento = %s
        """, (id_requerimiento,))
        requerimiento = cursor.fetchone()
        
        if not requerimiento:
            print(f"[OBTENER_REQUERIMIENTO] [WARN] Requerimiento no encontrado")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        # Limpiar nombres (eliminar espacios extras)
        if requerimiento.get('usuario_completo'):
            requerimiento['usuario_completo'] = ' '.join(requerimiento['usuario_completo'].split())
        
        # 2. Obtener detalles (con unidad via JOIN a TblMateriales y TblUnidadMedida)
        cursor.execute("""
            SELECT 
                rd.id_detalle,
                rd.id_requerimiento,
                rd.id_material,
                rd.tipo_item,
                rd.descripcion,
                rd.cantidad,
                rd.observaciones,
                rd.fecha_creacion,
                COALESCE(m.nombre, '') as material_nombre,
                COALESCE(m.codigo_material, '') as material_codigo,
                COALESCE(um.nombre, '') as unidad_nombre,
                COALESCE(um.abreviatura, '') as unidad_abreviatura
            FROM TblRequerimientoDetalle rd
            LEFT JOIN TblMateriales m ON rd.id_material = m.id_material
            LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
            WHERE rd.id_requerimiento = %s
            ORDER BY rd.tipo_item DESC, rd.id_detalle
        """, (id_requerimiento,))
        
        detalles = cursor.fetchall()
        
        # 3. Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        resumen = {
            'cantidad_items': len(detalles),
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios)
        }
        
        print(f"[OBTENER_REQUERIMIENTO] [OK] Requerimiento encontrado")
        print(f"[OBTENER_REQUERIMIENTO]   Código: {requerimiento.get('codigo')}")
        print(f"[OBTENER_REQUERIMIENTO]   Solicitante: {requerimiento.get('usuario_completo')}")
        print(f"[OBTENER_REQUERIMIENTO]   Presupuesto: {requerimiento.get('numero_presupuesto')}")
        print(f"[OBTENER_REQUERIMIENTO]   Estado: {requerimiento.get('estado')}")
        print(f"[OBTENER_REQUERIMIENTO]   Detalles: {len(detalles)} items")
        print(f"[OBTENER_REQUERIMIENTO]   Resumen: {resumen}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'requerimiento': requerimiento,
                'detalles': detalles,
                'resumen': resumen
            }
        }), 200
    
    except Exception as e:
        print(f"[OBTENER_REQUERIMIENTO] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/requerimientos/obtener-detalles/<int:id_requerimiento>', methods=['GET'])
@login_required
def obtener_requerimiento_detalles(id_requerimiento):
    """Obtener detalles completos de un requerimiento usando SP"""
    print(f"\n{'='*80}")
    print(f"[OBTENER_REQUERIMIENTO_DETALLES] Iniciando para ID: {id_requerimiento}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener información del requerimiento
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] Obteniendo información del requerimiento...")
        cursor.execute("""
            SELECT 
                id_requerimiento,
                codigo,
                descripcion,
                cantidad,
                solicitante,
                estado,
                observaciones,
                fecha_creacion,
                fecha_actualizacion
            FROM TblRequerimiento
            WHERE id_requerimiento = %s
        """, (id_requerimiento,))
        
        requerimiento = cursor.fetchone()
        if not requerimiento:
            print(f"[OBTENER_REQUERIMIENTO_DETALLES] [ERROR] Requerimiento no encontrado")
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] ✓ Requerimiento obtenido")
        
        # 2. Obtener detalles usando SP
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] Obteniendo detalles...")
        cursor.callproc('sp_ObtenerRequerimientoDetalles', [id_requerimiento])
        
        detalles = []
        for result_set in cursor.stored_results():
            detalles = result_set.fetchall()
            break
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] ✓ {len(detalles) if detalles else 0} detalles obtenidos")
        
        # 3. Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        total_items = len(detalles) if detalles else 0
        
        resumen = {
            'cantidad_items': total_items,
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios)
        }
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] ✓ Resumen: {resumen}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'requerimiento': requerimiento,
                'detalles': detalles,
                'resumen': resumen
            }
        }), 200
    
    except Error as e:
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [ERROR] Error MySQL: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [ERROR] Error general: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500

@main_bp.route('/api/requerimientos/crear', methods=['POST'])
@login_required
def crear_requerimiento():
    """Crear un nuevo requerimiento con items usando SP"""
    try:
        data = request.get_json()
        
        # Validar campos obligatorios
        campos_requeridos = ['descripcion']
        for campo in campos_requeridos:
            if not data.get(campo):
                return jsonify({'success': False, 'error': f'Campo requerido: {campo}'}), 400
        
        # Validar que haya items
        items = data.get('items', [])
        if not items or len(items) == 0:
            return jsonify({'success': False, 'error': 'Debe agregar al menos un item'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor()
            
            print(f"\n{'='*80}")
            print(f"[CREAR_REQUERIMIENTO] Iniciando creación con SP")
            print(f"{'='*80}")
            
            # Obtener datos del usuario desde la sesión
            num_usuario = session.get('user_id')  # ID numérico del usuario
            if not num_usuario:
                return jsonify({'success': False, 'error': 'Usuario no autenticado'}), 401
            
            # Obtener id_presupuesto (puede ser NULL si es requerimiento independiente)
            id_presupuesto = data.get('id_presupuesto')
            
            # Preparar JSON para detalles
            detalles_json = json.dumps(items)
            
            print(f"[CREAR_REQUERIMIENTO] num_usuario: {num_usuario}")
            print(f"[CREAR_REQUERIMIENTO] Descripción: {data['descripcion']}")
            print(f"[CREAR_REQUERIMIENTO] Items: {len(items)}")
            print(f"[CREAR_REQUERIMIENTO] id_presupuesto: {id_presupuesto}")
            print(f"[CREAR_REQUERIMIENTO] Items JSON: {detalles_json}")
            print(f"[CREAR_REQUERIMIENTO] Estado: PENDIENTE (automático)")
            
            # Llamar SP CON id_presupuesto
            resultado = cursor.callproc('sp_CrearRequerimientoCompleto', [
                num_usuario,
                data['descripcion'],
                data.get('observaciones', ''),
                detalles_json,
                id_presupuesto,  # NUEVO: id_presupuesto
                0  # OUT parameter - id_requerimiento_created
            ])
            
            # Obtener el ID del requerimiento creado desde el OUT parameter
            requerimiento_id = resultado[-1]  # El último valor en la tupla es el OUT parameter
            
            connection.commit()
            
            print(f"[CREAR_REQUERIMIENTO] [OK] Requerimiento creado con ID: {requerimiento_id}")
            print(f"[CREAR_REQUERIMIENTO] Items guardados: {len(items)}")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Requerimiento creado exitosamente',
                'codigo': f'REQ-{str(requerimiento_id).zfill(5)}',
                'id': requerimiento_id
            }), 201
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[CREAR_REQUERIMIENTO] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_REQUERIMIENTO] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/requerimientos/actualizar/<int:id_requerimiento>', methods=['PUT'])
@login_required
def actualizar_requerimiento(id_requerimiento):
    """Actualizar datos de un requerimiento y sus detalles usando SP"""
    print(f"\n{'='*80}")
    print(f"[ACTUALIZAR_REQUERIMIENTO] === INICIANDO ===")
    print(f"{'='*80}")
    
    try:
        data = request.get_json()
        print(f"[ACTUALIZAR_REQUERIMIENTO] Request recibido")
        
        # Validar campos obligatorios
        if not data.get('descripcion'):
            print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR: Descripción vacía")
            return jsonify({'success': False, 'error': 'Descripción es requerida'}), 400
        
        connection = get_db_connection()
        if not connection:
            print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR: No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        print(f"[ACTUALIZAR_REQUERIMIENTO] Conexión BD: OK")
        cursor = connection.cursor(dictionary=True)
        
        # Obtener detalles del request
        descripcion = data['descripcion']
        observaciones = data.get('observaciones', '')
        detalles = data.get('detalles', [])
        
        print(f"[ACTUALIZAR_REQUERIMIENTO] ID: {id_requerimiento}")
        print(f"[ACTUALIZAR_REQUERIMIENTO] Desc: {descripcion[:50]}...")
        print(f"[ACTUALIZAR_REQUERIMIENTO] Detalles: {len(detalles)} items")
        
        # Convertir detalles a JSON
        detalles_json = json.dumps(detalles) if detalles else '[]'
        
        # ================================================================
        # LLAMAR SP
        # ================================================================
        print(f"[ACTUALIZAR_REQUERIMIENTO] Llamando SP...")
        
        try:
            # ================================================================
            # LLAMAR SP - El parámetro OUT (p_resultado) se pasa como None
            # ================================================================
            p_resultado_param = [None]  # OUT parameter - pasado como None
            cursor.callproc('sp_ActualizarRequerimiento', [
                id_requerimiento,
                descripcion,
                observaciones,
                detalles_json,
                p_resultado_param
            ])
            
            print(f"[ACTUALIZAR_REQUERIMIENTO] SP llamado exitosamente")
            
            # ================================================================
            # OBTENER RESULTADO DEL PARÁMETRO OUT
            # ================================================================
            # Después de callproc, la lista contiene el valor del parámetro OUT
            if p_resultado_param and len(p_resultado_param) > 0:
                p_resultado = p_resultado_param[0]
                print(f"[ACTUALIZAR_REQUERIMIENTO] Parámetro OUT: {p_resultado} (tipo: {type(p_resultado)})")
            else:
                print(f"[ACTUALIZAR_REQUERIMIENTO] ⚠️ No se obtuvo parámetro OUT, intentando alternativas...")
                # Intentar obtener del result set como backup
                result_set = cursor.fetchall()
                if result_set and len(result_set) > 0:
                    p_resultado = 1
                    print(f"[ACTUALIZAR_REQUERIMIENTO] Result set encontrado, asumiendo éxito")
                else:
                    p_resultado = 1
                    print(f"[ACTUALIZAR_REQUERIMIENTO] Sin result set, asumiendo éxito")
            
            connection.commit()
            print(f"[ACTUALIZAR_REQUERIMIENTO] COMMIT realizado")
            
            if p_resultado == 1:
                print(f"[ACTUALIZAR_REQUERIMIENTO] ✓ ÉXITO (resultado = 1)")
            else:
                print(f"[ACTUALIZAR_REQUERIMIENTO] ⚠️ SP retornó resultado = {p_resultado}")
        
        except Exception as e:
            print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR en SP: {type(e).__name__}: {str(e)}")
            import traceback
            print(f"[ACTUALIZAR_REQUERIMIENTO] Traceback: {traceback.format_exc()}")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': f'Error SQL: {str(e)}'}), 500
        
        # Reiniciar flujo (sin fallar si hay error)
        try:
            print(f"[ACTUALIZAR_REQUERIMIENTO] Reiniciando flujo...")
            cursor2 = connection.cursor()
            cursor2.callproc('sp_ReiniciarFlujoAprobacion', [2, id_requerimiento])
            cursor2.fetchall()
            connection.commit()
            cursor2.close()
            print(f"[ACTUALIZAR_REQUERIMIENTO] ✓ Flujo reiniciado")
        except Exception as e:
            print(f"[ACTUALIZAR_REQUERIMIENTO] ⚠️ Error en flujo: {str(e)}")
            try:
                connection.rollback()
            except:
                pass
        
        print(f"[ACTUALIZAR_REQUERIMIENTO] === FINALIZADO ===")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Requerimiento actualizado exitosamente',
            'items_procesados': len(detalles)
        }), 200
    
    except Exception as e:
        print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR GENERAL: {type(e).__name__}: {str(e)}")
        import traceback
        print(f"[ACTUALIZAR_REQUERIMIENTO] Traceback: {traceback.format_exc()}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500

@main_bp.route('/api/requerimientos/eliminar/<int:id_requerimiento>', methods=['DELETE'])
@login_required
def eliminar_requerimiento(id_requerimiento):
    """Eliminar un requerimiento completamente (Hard Delete)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            print(f"\n{'='*80}")
            print(f"[ELIMINAR_REQUERIMIENTO] HARD DELETE - Iniciando para ID: {id_requerimiento}")
            print(f"{'='*80}")
            
            # Verificar que el requerimiento existe
            cursor.execute("""
                SELECT 
                    id_requerimiento,
                    codigo,
                    id_presupuesto,
                    (SELECT COUNT(*) FROM TblRequerimientoDetalle WHERE id_requerimiento = %s) as num_detalles
                FROM TblRequerimiento
                WHERE id_requerimiento = %s
            """, (id_requerimiento, id_requerimiento))
            
            req = cursor.fetchone()
            if not req:
                print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Requerimiento no encontrado")
                cursor.close()
                connection.close()
                return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
            
            print(f"[ELIMINAR_REQUERIMIENTO] Requerimiento encontrado: {req['codigo']}")
            print(f"  - ID: {req['id_requerimiento']}")
            print(f"  - Presupuesto: {req['id_presupuesto']}")
            print(f"  - Detalles: {req['num_detalles']}")
            
            # Obtener información del presupuesto si está vinculado
            cantidad_requerimiento = 0
            if req['id_presupuesto']:
                cursor.execute("""
                    SELECT COALESCE(SUM(cantidad), 0) as total_cantidad
                    FROM TblRequerimientoDetalle
                    WHERE id_requerimiento = %s
                """, (id_requerimiento,))
                
                result = cursor.fetchone()
                cantidad_requerimiento = result['total_cantidad'] if result else 0
                print(f"[ELIMINAR_REQUERIMIENTO] Cantidad total a reversar en presupuesto: {cantidad_requerimiento}")
            
            # PASO 1: Eliminar detalles del requerimiento
            print(f"\n[ELIMINAR_REQUERIMIENTO] PASO 1: Eliminando detalles...")
            cursor.execute("""
                DELETE FROM TblRequerimientoDetalle
                WHERE id_requerimiento = %s
            """, (id_requerimiento,))
            detalles_eliminados = cursor.rowcount
            print(f"  ✓ Eliminados {detalles_eliminados} detalles")
            
            # PASO 2: Eliminar registros de aprobación
            print(f"\n[ELIMINAR_REQUERIMIENTO] PASO 2: Eliminando registros de aprobación...")
            cursor.execute("""
                DELETE FROM TblRegistroAprobacion
                WHERE id_documento_referencia = %s
                  AND id_tipo_documento = 2
            """, (id_requerimiento,))
            aprobaciones_eliminadas = cursor.rowcount
            print(f"  ✓ Eliminadas {aprobaciones_eliminadas} aprobaciones")
            
            # PASO 3: Eliminar el requerimiento principal
            print(f"\n[ELIMINAR_REQUERIMIENTO] PASO 3: Eliminando requerimiento...")
            cursor.execute("""
                DELETE FROM TblRequerimiento
                WHERE id_requerimiento = %s
            """, (id_requerimiento,))
            requerimientos_eliminados = cursor.rowcount
            print(f"  ✓ Requerimiento eliminado")
            
            # PASO 4: Reversar cambios en presupuesto si está vinculado
            if req['id_presupuesto'] and cantidad_requerimiento > 0:
                print(f"\n[ELIMINAR_REQUERIMIENTO] PASO 4: Reversando cambios en presupuesto...")
                print(f"  Cantidad total a reversar: {cantidad_requerimiento}")
                
                # 4A: Actualizar totales en TblPresupuesto
                print(f"  4A. Actualizando TblPresupuesto...")
                cursor.execute("""
                    UPDATE TblPresupuesto
                    SET 
                        cantidad_consumida = GREATEST(0, cantidad_consumida - %s),
                        cantidad_saldo = cantidad_saldo + %s,
                        monto_gastado = GREATEST(0, monto_gastado - %s),
                        fecha_actualizacion = NOW()
                    WHERE id_presupuesto = %s
                """, (cantidad_requerimiento, cantidad_requerimiento, cantidad_requerimiento, req['id_presupuesto']))
                
                print(f"    ✓ cantidad_consumida -= {cantidad_requerimiento}")
                print(f"    ✓ cantidad_saldo += {cantidad_requerimiento}")
                print(f"    ✓ monto_gastado -= {cantidad_requerimiento}")
                
                # 4B: Actualizar detalles en TblPresupuestoDetalle
                # Revert PASO 7: restar la cantidad que fue consumida de cada detalle
                print(f"  4B. Actualizando TblPresupuestoDetalle...")
                
                # Obtener los detalles del requerimiento para reversar
                cursor.execute("""
                    SELECT descripcion, SUM(cantidad) as total_cantidad
                    FROM TblRequerimientoDetalle
                    WHERE id_requerimiento = %s
                    GROUP BY LOWER(TRIM(descripcion))
                """, (id_requerimiento,))
                
                detalles_req = cursor.fetchall()
                
                for detalle in detalles_req:
                    descripcion = detalle['descripcion']
                    cantidad_detalle = detalle['total_cantidad']
                    
                    # Restar la cantidad consumida (reversar PASO 7)
                    cursor.execute("""
                        UPDATE TblPresupuestoDetalle pd
                        SET 
                            pd.cantidad_consumida = GREATEST(0, pd.cantidad_consumida - %s),
                            pd.cantidad_saldo = pd.cantidad - GREATEST(0, pd.cantidad_consumida - %s),
                            pd.fecha_actualizacion = NOW()
                        WHERE pd.id_presupuesto = %s
                          AND LOWER(TRIM(pd.descripcion)) = LOWER(TRIM(%s))
                    """, (cantidad_detalle, cantidad_detalle, req['id_presupuesto'], descripcion))
                    
                    updated = cursor.rowcount
                    if updated > 0:
                        print(f"    ✓ '{descripcion}': cantidad_saldo += {cantidad_detalle}")
                
                print(f"  ✓ TblPresupuestoDetalle actualizado")
            
            connection.commit()
            
            print(f"\n[ELIMINAR_REQUERIMIENTO] [✅ OK] Requerimiento eliminado completamente")
            print(f"[ELIMINAR_REQUERIMIENTO] RESUMEN:")
            print(f"  - Código: {req['codigo']}")
            print(f"  - Detalles eliminados: {detalles_eliminados}")
            print(f"  - Aprobaciones eliminadas: {aprobaciones_eliminadas}")
            print(f"  - Presupuesto reversado: {'Sí' if req['id_presupuesto'] else 'No'}")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': f'Requerimiento {req["codigo"]} eliminado completamente',
                'detalles': {
                    'codigo': req['codigo'],
                    'detalles_eliminados': detalles_eliminados,
                    'aprobaciones_eliminadas': aprobaciones_eliminadas
                }
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500
@main_bp.route('/api/requerimientos/flujo/<int:id_requerimiento>', methods=['GET'])
@login_required
def obtener_flujo_requerimiento(id_requerimiento):
    """Obtener pasos del flujo de aprobación para componente visual"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[FLUJO_REQUERIMIENTO] Obteniendo pasos del flujo para ID: {id_requerimiento}")
        
        # Llamar al SP que obtiene los pasos del flujo
        cursor.callproc('sp_ObtenerPasosFlujoRequerimiento', [id_requerimiento])
        
        # Obtener resultados
        pasos = []
        for result in cursor.stored_results():
            pasos = result.fetchall()
            break
        
        # Limpiar nombres
        if pasos:
            for paso in pasos:
                if paso.get('nombre_aprobador'):
                    paso['nombre_aprobador'] = ' '.join(paso['nombre_aprobador'].split())
        
        print(f"[FLUJO_REQUERIMIENTO] ✓ {len(pasos)} pasos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': pasos}), 200
    
    except Error as e:
        print(f"[FLUJO_REQUERIMIENTO] [ERROR] Error SQL: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# NUEVOS ENDPOINTS: APROBAR Y RECHAZAR REQUERIMIENTOS
# ============================================================================

@main_bp.route('/api/requerimientos/puede-aprobar/<int:id_requerimiento>', methods=['GET'])
@login_required
def puede_aprobar_requerimiento(id_requerimiento):
    """Verificar si el usuario actual puede aprobar este requerimiento"""
    num_documento = session.get('user_documento')
    
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'puede_aprobar': False}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener cargo del usuario
        cursor.execute("""
            SELECT id_cargo FROM TblUsuario 
            WHERE num_documento = %s AND estado = 'Activo'
            LIMIT 1
        """, (num_documento,))
        
        cargo_result = cursor.fetchone()
        if not cargo_result:
            cursor.close()
            connection.close()
            return jsonify({'puede_aprobar': False}), 200
        
        id_cargo = cargo_result['id_cargo']
        
        # 2. Verificar si existe un registro PENDIENTE para este usuario en este requerimiento
        cursor.execute("""
            SELECT COUNT(*) as total FROM TblRegistroAprobacion ra
            WHERE ra.id_tipo_documento = 2 
              AND ra.id_documento_referencia = %s
              AND ra.id_cargo_aprobador = %s
              AND ra.estado_aprobacion = 'PENDIENTE'
        """, (id_requerimiento, id_cargo))
        
        registro = cursor.fetchone()
        puede_aprobar = registro['total'] > 0
        
        cursor.close()
        connection.close()
        
        return jsonify({'puede_aprobar': puede_aprobar}), 200
        
    except Exception as e:
        print(f"[PUEDE_APROBAR] Error: {e}")
        return jsonify({'puede_aprobar': False}), 500

@main_bp.route('/api/requerimientos/aprobar/<int:id_requerimiento>', methods=['PUT'])
@login_required
def aprobar_requerimiento(id_requerimiento):
    """Aprobar un requerimiento (SOLO para aprobadores autorizados)"""
    num_documento = session.get('user_documento')
    
    try:
        data = request.get_json()
        comentario = data.get('comentario', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[APROBAR_REQUERIMIENTO] Aprobando requerimiento ID: {id_requerimiento}")
        print(f"[APROBAR_REQUERIMIENTO] Usuario: {num_documento}")
        print(f"{'='*80}")
        
        # 1. Verificar que el usuario es aprobador para ESTE requerimiento
        cursor.execute("""
            SELECT id_cargo FROM TblUsuario
            WHERE num_documento = %s AND estado = 'Activo'
            LIMIT 1
        """, (num_documento,))
        
        cargo_result = cursor.fetchone()
        if not cargo_result:
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Usuario no tiene cargo asignado'}), 403
        
        id_cargo = cargo_result['id_cargo']
        
        # 2. Verificar que existe un registro PENDIENTE para este usuario en este requerimiento
        cursor.execute("""
            SELECT ra.id_registro FROM TblRegistroAprobacion ra
            WHERE ra.id_tipo_documento = 2 
              AND ra.id_documento_referencia = %s
              AND ra.id_cargo_aprobador = %s
              AND ra.estado_aprobacion = 'PENDIENTE'
            LIMIT 1
        """, (id_requerimiento, id_cargo))
        
        registro = cursor.fetchone()
        if not registro:
            cursor.close()
            connection.close()
            print(f"[APROBAR_REQUERIMIENTO] ❌ Usuario no es aprobador autorizado para este requerimiento")
            return jsonify({'success': False, 'error': 'No tienes permiso para aprobar este requerimiento'}), 403
        
        # 3. Actualizar registro de aprobación
        cursor.execute("""
            UPDATE TblRegistroAprobacion 
            SET estado_aprobacion = 'APROBADO', 
                num_documento_aprobador = %s,
                comentario = %s,
                fecha_aprobacion = NOW()
            WHERE id_registro = %s
        """, (num_documento, comentario, registro['id_registro']))
        
        # 4. Verificar si TODOS los pasos han sido aprobados
        cursor.execute("""
            SELECT COUNT(*) as total_pasos,
                   SUM(CASE WHEN estado_aprobacion = 'APROBADO' THEN 1 ELSE 0 END) as aprobados
            FROM TblRegistroAprobacion
            WHERE id_tipo_documento = 2 AND id_documento_referencia = %s
        """, (id_requerimiento,))
        
        pasos = cursor.fetchone()
        
        # Si todos están aprobados, cambiar estado a APROBADO
        if pasos and pasos['total_pasos'] == pasos['aprobados']:
            cursor.execute("""
                UPDATE TblRequerimiento 
                SET estado = 'APROBADO', fecha_actualizacion = NOW()
                WHERE id_requerimiento = %s
            """, (id_requerimiento,))
            print(f"[APROBAR_REQUERIMIENTO] ✓ Todos los pasos aprobados - Requerimiento APROBADO")
        
        connection.commit()
        
        print(f"[APROBAR_REQUERIMIENTO] ✓ Aprobación registrada exitosamente")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Requerimiento aprobado exitosamente'
        }), 200
        
    except Exception as e:
        print(f"[APROBAR_REQUERIMIENTO] [ERROR] Error: {e}")
        if connection:
            connection.rollback()
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/requerimientos/rechazar/<int:id_requerimiento>', methods=['PUT'])
@login_required
def rechazar_requerimiento(id_requerimiento):
    """Rechazar un requerimiento (SOLO para aprobadores autorizados) - Usa SP"""
    num_documento = session.get('user_documento')
    
    try:
        data = request.get_json()
        comentario = data.get('comentario', 'Requerimiento rechazado sin especificar motivo')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[RECHAZAR_REQUERIMIENTO] Ejecutando SP para rechazar requerimiento ID: {id_requerimiento}")
        print(f"[RECHAZAR_REQUERIMIENTO] Usuario: {num_documento}")
        print(f"[RECHAZAR_REQUERIMIENTO] Motivo: {comentario[:100]}...")
        print(f"{'='*80}")
        
        # Ejecutar SP
        try:
            cursor.callproc('sp_RechazarRequerimiento', [
                id_requerimiento,
                num_documento,
                comentario,
                None,  # p_success (OUT)
                None   # p_mensaje (OUT)
            ])
            
            # Obtener resultado del SP
            result = None
            for result_set in cursor.stored_results():
                result = result_set.fetchone()
            
            if result:
                success = result.get('success', False)
                mensaje = result.get('mensaje', 'Error desconocido')
                
                print(f"[RECHAZAR_REQUERIMIENTO] SP retornó: success={success}, mensaje={mensaje}")
                
                if success:
                    connection.commit()
                    print(f"[RECHAZAR_REQUERIMIENTO] ✓ Requerimiento rechazado exitosamente")
                    print(f"{'='*80}\n")
                    
                    cursor.close()
                    connection.close()
                    
                    return jsonify({
                        'success': True,
                        'message': mensaje
                    }), 200
                else:
                    connection.rollback()
                    print(f"[RECHAZAR_REQUERIMIENTO] ❌ {mensaje}")
                    print(f"{'='*80}\n")
                    
                    cursor.close()
                    connection.close()
                    
                    return jsonify({
                        'success': False,
                        'error': mensaje
                    }), 400
            else:
                connection.rollback()
                print(f"[RECHAZAR_REQUERIMIENTO] ❌ SP no retornó resultado")
                print(f"{'='*80}\n")
                
                cursor.close()
                connection.close()
                
                return jsonify({
                    'success': False,
                    'error': 'Error al ejecutar procedimiento almacenado'
                }), 500
                
        except Exception as sp_error:
            connection.rollback()
            print(f"[RECHAZAR_REQUERIMIENTO] ❌ Error ejecutando SP: {sp_error}")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': False,
                'error': f'Error al ejecutar procedimiento: {str(sp_error)}'
            }), 500
        
    except Exception as e:
        print(f"[RECHAZAR_REQUERIMIENTO] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': False,
            'error': f'Error: {str(e)}'
        }), 500
        if connection:
            connection.rollback()
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500
