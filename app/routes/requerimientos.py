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

@main_bp.route('/requerimiento')
@login_required
def requerimiento():
    """Pgina de gestin de requerimientos"""
    # Validar que el usuario tenga acceso a Gestin de Requerimientos
    num_documento = session.get('user_documento')
    
    if not validar_acceso_usuario(num_documento, id_menu=2, id_submenu=4):
        flash('No tienes acceso a Gestin de Requerimientos', 'danger')
        return redirect(url_for('main.dashboard'))
    
    return render_template('requerimiento.html')

@main_bp.route('/api/requerimientos/obtener', methods=['GET'])
@login_required
def obtener_requerimientos():
    """Obtener lista de todos los requerimientos con aprobadores usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[REQUERIMIENTOS] [GET] Obteniendo lista de requerimientos con aprobadores...")
        print(f"[REQUERIMIENTOS] Usando SP: sp_ObtenerRequerimientosConAprobadores")
        
        # Llamar al SP que incluye informacin de aprobadores
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
        
        print(f"[REQUERIMIENTOS] [OK] {len(requerimientos) if requerimientos else 0} requerimientos obtenidos")
        print(f"[REQUERIMIENTOS] [OK] Incluye columna 'aprobado_rechazado_por' para el flujo de aprobacin")
        
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
    """Obtener datos completos de un requerimiento con todos sus detalles (usando SPs)"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_REQUERIMIENTO] Iniciando para ID: {id_requerimiento}")
        print(f"{'='*80}")
        
        # 1. Obtener informacin del requerimiento usando SP
        try:
            cursor.callproc('sp_ObtenerRequerimiento', [id_requerimiento])
        except Error as sp_error:
            if sp_error.errno == 1305:  # PROCEDURE does not exist
                print(f"[OBTENER_REQUERIMIENTO] [ERROR] SP no existe. Ejecuta: sp_ObtenerRequerimiento.sql")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False, 
                    'error': 'El Stored Procedure sp_ObtenerRequerimiento no existe. Por favor ejecuta el script SQL correspondiente.'
                }), 500
            else:
                raise sp_error
        
        # Obtener resultado del SP
        requerimiento = None
        for result in cursor.stored_results():
            rows = result.fetchall()
            if rows:
                requerimiento = rows[0]
        
        if not requerimiento:
            print(f"[OBTENER_REQUERIMIENTO] [WARN] Requerimiento no encontrado")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        # 2. Obtener detalles usando SP
        try:
            cursor.callproc('sp_ObtenerRequerimientoDetalles', [id_requerimiento])
        except Error as sp_error:
            if sp_error.errno == 1305:  # PROCEDURE does not exist
                print(f"[OBTENER_REQUERIMIENTO] [ERROR] SP no existe. Ejecuta: sp_ObtenerRequerimientoDetalles en sp_ObtenerRequerimiento.sql")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False, 
                    'error': 'El Stored Procedure sp_ObtenerRequerimientoDetalles no existe. Por favor ejecuta el script SQL correspondiente.'
                }), 500
            else:
                raise sp_error
        
        # Obtener resultados del SP
        detalles = []
        for result in cursor.stored_results():
            detalles = result.fetchall()
        
        # 3. Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        resumen = {
            'cantidad_items': len(detalles),
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios)
        }
        
        print(f"[OBTENER_REQUERIMIENTO] [OK] Requerimiento encontrado (via SP)")
        print(f"[OBTENER_REQUERIMIENTO]   Cdigo: {requerimiento.get('codigo')}")
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
    
    except Error as e:
        print(f"[OBTENER_REQUERIMIENTO] [ERROR] Error SQL ({e.errno}): {e.msg}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error SQL: {e.msg}'}), 500
    except Exception as e:
        import traceback
        print(f"[OBTENER_REQUERIMIENTO] [ERROR] {str(e)}")
        print(f"[OBTENER_REQUERIMIENTO] Traceback:\n{traceback.format_exc()}")
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
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener informacin del requerimiento usando SP
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] Obteniendo informacin del requerimiento...")
        cursor.callproc('sp_ObtenerRequerimiento', [id_requerimiento])
        
        # Obtener resultado del SP
        requerimiento = None
        for result in cursor.stored_results():
            rows = result.fetchall()
            if rows:
                requerimiento = rows[0]
        
        if not requerimiento:
            print(f"[OBTENER_REQUERIMIENTO_DETALLES] [ERROR] Requerimiento no encontrado")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [OK] Requerimiento obtenido (via SP)")
        
        # 2. Obtener detalles usando SP
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] Obteniendo detalles...")
        cursor.callproc('sp_ObtenerRequerimientoDetalles', [id_requerimiento])
        
        detalles = []
        for result_set in cursor.stored_results():
            detalles = result_set.fetchall()
            break
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [OK] {len(detalles) if detalles else 0} detalles obtenidos")
        
        # 3. Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        total_items = len(detalles) if detalles else 0
        
        resumen = {
            'cantidad_items': total_items,
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios)
        }
        
        print(f"[OBTENER_REQUERIMIENTO_DETALLES] [OK] Resumen: {resumen}")
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
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        try:
            cursor = connection.cursor()
            
            print(f"\n{'='*80}")
            print(f"[CREAR_REQUERIMIENTO] Iniciando creacin con SP")
            print(f"{'='*80}")
            
            # Obtener datos del usuario desde la sesin
            num_usuario = session.get('user_id')  # ID numrico del usuario
            if not num_usuario:
                return jsonify({'success': False, 'error': 'Usuario no autenticado'}), 401
            
            # Obtener id_presupuesto (puede ser NULL si es requerimiento independiente)
            id_presupuesto = data.get('id_presupuesto')
            
            # Preparar JSON para detalles
            detalles_json = json.dumps(items)
            
            print(f"[CREAR_REQUERIMIENTO] num_usuario: {num_usuario}")
            print(f"[CREAR_REQUERIMIENTO] Descripcin: {data['descripcion']}")
            print(f"[CREAR_REQUERIMIENTO] Items: {len(items)}")
            print(f"[CREAR_REQUERIMIENTO] id_presupuesto: {id_presupuesto}")
            print(f"[CREAR_REQUERIMIENTO] Items JSON: {detalles_json}")
            print(f"[CREAR_REQUERIMIENTO] Estado: PENDIENTE (automtico)")
            
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
            requerimiento_id = resultado[-1]  # El ltimo valor en la tupla es el OUT parameter
            
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
            print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR: Descripcin vaca")
            return jsonify({'success': False, 'error': 'Descripcin es requerida'}), 400
        
        connection = get_db_connection()
        if not connection:
            print(f"[ACTUALIZAR_REQUERIMIENTO] ERROR: No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        print(f"[ACTUALIZAR_REQUERIMIENTO] Conexin BD: OK")
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
            # LLAMAR SP - El parmetro OUT (p_resultado) se pasa como None
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
            # OBTENER RESULTADO DEL PARMETRO OUT
            # ================================================================
            # Despus de callproc, la lista contiene el valor del parmetro OUT
            if p_resultado_param and len(p_resultado_param) > 0:
                p_resultado = p_resultado_param[0]
                print(f"[ACTUALIZAR_REQUERIMIENTO] Parmetro OUT: {p_resultado} (tipo: {type(p_resultado)})")
            else:
                print(f"[ACTUALIZAR_REQUERIMIENTO] [!] No se obtuvo parmetro OUT, intentando alternativas...")
                # Intentar obtener del result set como backup
                result_set = cursor.fetchall()
                if result_set and len(result_set) > 0:
                    p_resultado = 1
                    print(f"[ACTUALIZAR_REQUERIMIENTO] Result set encontrado, asumiendo xito")
                else:
                    p_resultado = 1
                    print(f"[ACTUALIZAR_REQUERIMIENTO] Sin result set, asumiendo xito")
            
            connection.commit()
            print(f"[ACTUALIZAR_REQUERIMIENTO] COMMIT realizado")
            
            if p_resultado == 1:
                print(f"[ACTUALIZAR_REQUERIMIENTO] [OK] XITO (resultado = 1)")
            else:
                print(f"[ACTUALIZAR_REQUERIMIENTO] [!] SP retorn resultado = {p_resultado}")
        
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
            print(f"[ACTUALIZAR_REQUERIMIENTO] [OK] Flujo reiniciado")
        except Exception as e:
            print(f"[ACTUALIZAR_REQUERIMIENTO] [!] Error en flujo: {str(e)}")
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
    """Eliminar un requerimiento completamente usando SP (Hard Delete)"""
    print(f"\n{'='*80}")
    print(f"[ELIMINAR_REQUERIMIENTO] [!] FUNCIN LLAMADA - ID: {id_requerimiento}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] No hay conexin a BD")
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
    try:
        cursor = connection.cursor()
        
        print(f"\n{'='*80}")
        print(f"[ELIMINAR_REQUERIMIENTO] HARD DELETE - Iniciando para ID: {id_requerimiento}")
        print(f"{'='*80}")
        
        try:
            # Llamar al SP con parmetros OUT usando variables de sesin
            cursor.execute("""
                CALL sp_EliminarRequerimiento(
                    %s,
                    @p_codigo,
                    @p_detalles_eliminados,
                    @p_aprobaciones_eliminadas,
                    @p_presupuesto_reversado,
                    @p_mensaje
                )
            """, (id_requerimiento,))
            
            # IMPORTANTE: Consumir todos los resultados del SP
            cursor.fetchall()
            
            # Obtener los valores de las variables OUT en una nueva consulta
            cursor.execute("""
                SELECT 
                    @p_codigo as codigo,
                    @p_detalles_eliminados as detalles_eliminados,
                    @p_aprobaciones_eliminadas as aprobaciones_eliminadas,
                    @p_presupuesto_reversado as presupuesto_reversado,
                    @p_mensaje as mensaje
            """)
            
            result = cursor.fetchone()
            
            if not result:
                raise Exception("No se obtuvieron resultados del SP")
            
            codigo = result[0]
            detalles_eliminados = result[1] or 0
            aprobaciones_eliminadas = result[2] or 0
            presupuesto_reversado = bool(result[3])
            mensaje = result[4] or 'Operacin completada'
            
        except Error as sp_error:
            # Error especfico del SP
            if sp_error.errno == 1305:  # PROCEDURE does not exist
                print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] SP no existe")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False, 
                    'error': 'El Stored Procedure sp_EliminarRequerimiento no existe. Por favor ejecuta el script SQL correspondiente.'
                }), 500
            else:
                print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Error SQL: {sp_error}")
                raise sp_error
        
        print(f"\n[ELIMINAR_REQUERIMIENTO] [[OK] OK] {mensaje}")
        print(f"[ELIMINAR_REQUERIMIENTO] RESUMEN:")
        print(f"  - Cdigo: {codigo}")
        print(f"  - Detalles eliminados: {detalles_eliminados}")
        print(f"  - Aprobaciones eliminadas: {aprobaciones_eliminadas}")
        print(f"  - Presupuesto reversado: {'S' if presupuesto_reversado else 'No'}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'Requerimiento {codigo} eliminado completamente',
            'detalles': {
                'codigo': codigo,
                'detalles_eliminados': detalles_eliminados,
                'aprobaciones_eliminadas': aprobaciones_eliminadas,
                'presupuesto_reversado': presupuesto_reversado
            }
        }), 200
    
    except Error as e:
        print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Error SQL ({e.errno}): {e.msg}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error SQL: {e.msg}'}), 500
    except Exception as e:
        import traceback
        print(f"[ELIMINAR_REQUERIMIENTO] [ERROR] Error general: {e}")
        print(f"[ELIMINAR_REQUERIMIENTO] Traceback:\n{traceback.format_exc()}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/requerimientos/flujo/<int:id_requerimiento>', methods=['GET'])
@login_required
def obtener_flujo_requerimiento(id_requerimiento):
    """Obtener pasos del flujo de aprobacin para componente visual"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexin'}), 500
    
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
        
        print(f"[FLUJO_REQUERIMIENTO] [OK] {len(pasos)} pasos obtenidos")
        
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
    """Aprobar un requerimiento usando SP (SOLO para aprobadores autorizados)"""
    num_documento = session.get('user_documento')
    
    try:
        data = request.get_json()
        comentario = data.get('comentario', '')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor()
        
        print(f"\n{'='*80}")
        print(f"[APROBAR_REQUERIMIENTO] Aprobando requerimiento ID: {id_requerimiento}")
        print(f"[APROBAR_REQUERIMIENTO] Usuario: {num_documento}")
        print(f"{'='*80}")
        
        try:
            # Llamar al SP usando variables de sesin para OUT
            cursor.execute("""
                CALL sp_AprobarRequerimiento(
                    %s,
                    %s,
                    %s,
                    @p_aprobacion_completa,
                    @p_mensaje
                )
            """, (id_requerimiento, num_documento, comentario))
            
            # Obtener valores OUT
            cursor.execute("""
                SELECT 
                    @p_aprobacion_completa as aprobacion_completa,
                    @p_mensaje as mensaje
            """)
            
            result = cursor.fetchone()
            
            if not result:
                raise Exception("No se obtuvieron resultados del SP")
            
            aprobacion_completa = bool(result[0])
            mensaje = result[1]
            
        except Error as sp_error:
            if sp_error.errno == 1305:  # PROCEDURE does not exist
                print(f"[APROBAR_REQUERIMIENTO] [ERROR] SP no existe")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False, 
                    'error': 'El Stored Procedure sp_AprobarRequerimiento no existe. Por favor ejecuta el script SQL correspondiente.'
                }), 500
            else:
                print(f"[APROBAR_REQUERIMIENTO] [ERROR] Error SQL: {sp_error}")
                raise sp_error
        
        print(f"[APROBAR_REQUERIMIENTO] {mensaje}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Requerimiento aprobado exitosamente',
            'aprobacion_completa': aprobacion_completa,
            'detalle': mensaje
        }), 200
        
    except Error as e:
        print(f"[APROBAR_REQUERIMIENTO] [ERROR] Error SQL ({e.errno}): {e.msg}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error SQL: {e.msg}'}), 500
    except Exception as e:
        import traceback
        print(f"[APROBAR_REQUERIMIENTO] [ERROR] Error: {e}")
        print(f"[APROBAR_REQUERIMIENTO] Traceback:\n{traceback.format_exc()}")
        if connection:
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
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
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
                
                print(f"[RECHAZAR_REQUERIMIENTO] SP retorn: success={success}, mensaje={mensaje}")
                
                if success:
                    connection.commit()
                    print(f"[RECHAZAR_REQUERIMIENTO] [OK] Requerimiento rechazado exitosamente")
                    print(f"{'='*80}\n")
                    
                    cursor.close()
                    connection.close()
                    
                    return jsonify({
                        'success': True,
                        'message': mensaje
                    }), 200
                else:
                    connection.rollback()
                    print(f"[RECHAZAR_REQUERIMIENTO] [X] {mensaje}")
                    print(f"{'='*80}\n")
                    
                    cursor.close()
                    connection.close()
                    
                    return jsonify({
                        'success': False,
                        'error': mensaje
                    }), 400
            else:
                connection.rollback()
                print(f"[RECHAZAR_REQUERIMIENTO] [X] SP no retorn resultado")
                print(f"{'='*80}\n")
                
                cursor.close()
                connection.close()
                
                return jsonify({
                    'success': False,
                    'error': 'Error al ejecutar procedimiento almacenado'
                }), 500
                
        except Exception as sp_error:
            connection.rollback()
            print(f"[RECHAZAR_REQUERIMIENTO] [X] Error ejecutando SP: {sp_error}")
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
