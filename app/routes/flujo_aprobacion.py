"""
MÓDULO: Flujo de Aprobación
DESCRIPCIÓN: Gestión de flujos de aprobación para presupuestos, OT, etc.
"""

from flask import render_template, request, jsonify, session, flash, redirect, url_for
from . import main_bp
import mysql.connector
from mysql.connector import Error
from functools import wraps
from app.config import DatabaseConfig
from .main import validar_acceso_usuario
from datetime import datetime

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

# ============================================================================
# RUTA PRINCIPAL: FLUJO DE APROBACIÓN
# ============================================================================

@main_bp.route('/flujo-de-aprobacion')
@login_required
def flujo_aprobacion():
    """Página principal de gestión de flujos de aprobación"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[FLUJO_APROBACION_ACCESS] Validando acceso a /flujo-de-aprobacion")
    print(f"[FLUJO_APROBACION_ACCESS] Documento: {num_documento}")
    print(f"{'='*80}")
    
    # Validar acceso
    # Menú 4 = Configuración, SubMenú 10 = Flujo de Aprobación
    tiene_acceso = validar_acceso_usuario(num_documento, id_menu=4, id_submenu=10)
    
    print(f"[FLUJO_APROBACION_ACCESS] ✅ Acceso permitido: {tiene_acceso}")
    
    if not tiene_acceso:
        print(f"[FLUJO_APROBACION_ACCESS] ❌ ACCESO DENEGADO")
        print(f"{'='*80}\n")
        flash('No tienes acceso a Flujo de Aprobación', 'danger')
        return redirect(url_for('main.dashboard'))
    
    print(f"[FLUJO_APROBACION_ACCESS] ✅ ACCESO PERMITIDO - Cargando flujo_aprobacion.html")
    print(f"{'='*80}\n")
    
    return render_template('flujo_aprobacion.html')


# ============================================================================
# ENDPOINTS API PARA FLUJO DE APROBACIÓN
# ============================================================================

@main_bp.route('/api/flujo-aprobacion/obtener-tipos', methods=['GET'])
@login_required
def obtener_tipos_documentos():
    """Obtener lista de tipos de documentos"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[TIPOS_DOCUMENTO_LIST] Obteniendo tipos de documentos")
        
        # Obtener tipos de documentos activos
        cursor.execute('''
            SELECT 
                id_tipo_documento,
                nombre,
                descripcion,
                icono,
                color,
                requiere_aprobacion,
                orden,
                activo,
                fecha_creacion
            FROM TblTipoDocumentoAprobacion
            WHERE activo = 1
            ORDER BY orden ASC
        ''')
        
        tipos = cursor.fetchall()
        
        print(f"[TIPOS_DOCUMENTO_LIST] [✓ OK] {len(tipos)} tipos de documentos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': tipos}), 200
    
    except Error as e:
        print(f"[TIPOS_DOCUMENTO_LIST] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/obtener-flujos', methods=['GET'])
@login_required
def obtener_flujos_aprobacion():
    """Obtener lista de flujos de aprobación desde TblFlujoAprobacionCargos"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[FLUJO_APROBACION_LIST] Obteniendo flujos de aprobación desde TblFlujoAprobacionCargos")
        
        cursor.execute('''
            SELECT 
                fac.id_flujo_cargo as id_flujo_aprobacion,
                fac.id_tipo_documento,
                fac.numero_paso,
                fac.nombre_paso,
                fac.descripcion,
                fac.es_requerido,
                fac.permite_rechazo,
                fac.fecha_creacion,
                td.nombre as tipo_documento_nombre,
                fac.id_cargo,
                c.nombre as cargo_nombre,
                a.nombre as area_nombre,
                fac.orden_visualizacion
            FROM TblFlujoAprobacionCargos fac
            LEFT JOIN TblTipoDocumentoAprobacion td ON fac.id_tipo_documento = td.id_tipo_documento
            LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
            LEFT JOIN TblArea a ON c.id_area = a.id_area
            WHERE fac.activo = 1
            ORDER BY fac.id_tipo_documento ASC, fac.numero_paso ASC, COALESCE(fac.orden_visualizacion, 0) ASC
        ''')
        
        flujos = cursor.fetchall()
        
        # Convertir booleanos a strings para JSON
        for flujo in flujos:
            flujo['es_requerido'] = bool(flujo['es_requerido'])
            flujo['permite_rechazo'] = bool(flujo['permite_rechazo'])
        
        print(f"[FLUJO_APROBACION_LIST] ✓ OK - {len(flujos)} registros obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': flujos}), 200
    
    except Error as e:
        print(f"[FLUJO_APROBACION_LIST] ERROR: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/obtener-cargos', methods=['GET'])
@login_required
def obtener_cargos_aprobacion():
    """Obtener lista de cargos para asignar en flujos de aprobación"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[CARGOS_APROBACION] Obteniendo cargos")
        
        cursor.execute('''
            SELECT 
                id_cargo,
                nombre
            FROM TblCargo
            WHERE activo = 1
            ORDER BY nombre ASC
        ''')
        
        cargos = cursor.fetchall()
        
        print(f"[CARGOS_APROBACION] [✓ OK] {len(cargos)} cargos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': cargos}), 200
    
    except Error as e:
        print(f"[CARGOS_APROBACION] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/area-para-cargo/<int:id_cargo>', methods=['GET'])
@login_required
def obtener_area_para_cargo(id_cargo):
    """Obtener el área que pertenece un cargo específico"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[AREA_CARGO] Obteniendo área para cargo {id_cargo}")
        
        cursor.execute('''
            SELECT 
                id_area,
                nombre as area_nombre
            FROM TblArea
            WHERE id_area IN (
                SELECT id_area FROM TblCargo WHERE id_cargo = %s
            )
            LIMIT 1
        ''', (id_cargo,))
        
        area = cursor.fetchone()
        
        if area:
            print(f"[AREA_CARGO] [✓ OK] Área encontrada: {area['id_area']} - {area['area_nombre']}")
        else:
            print(f"[AREA_CARGO] [⚠️] No se encontró área para cargo {id_cargo}")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': area}), 200
    
    except Error as e:
        print(f"[AREA_CARGO] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/actualizar-tipo/<int:id_tipo>', methods=['PUT'])
@login_required
def actualizar_tipo_documento(id_tipo):
    """Actualizar tipo de documento"""
    try:
        datos = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        cursor.execute('''
            UPDATE TblTipoDocumentoAprobacion 
            SET nombre = %s, descripcion = %s, icono = %s, color = %s, requiere_aprobacion = %s
            WHERE id_tipo_documento = %s
        ''', (
            datos.get('nombre'),
            datos.get('descripcion'),
            datos.get('icono'),
            datos.get('color'),
            datos.get('requiere_aprobacion', 1),
            id_tipo
        ))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'message': 'Tipo de documento actualizado'}), 200
    
    except Exception as e:
        print(f"[ACTUALIZAR_TIPO] Error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/eliminar-tipo/<int:id_tipo>', methods=['DELETE'])
@login_required
def eliminar_tipo_documento(id_tipo):
    """Eliminar tipo de documento y todos sus flujos y cargos asociados"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        print(f"\n{'='*80}")
        print(f"[ELIMINAR_TIPO_DOCUMENTO] Iniciando eliminación de tipo {id_tipo}")
        print(f"{'='*80}")
        
        # 1. Eliminar directamente de TblFlujoAprobacionCargos
        cursor.execute('''
            DELETE FROM TblFlujoAprobacionCargos 
            WHERE id_tipo_documento = %s
        ''', (id_tipo,))
        
        cargos_eliminados = cursor.rowcount
        print(f"[ELIMINAR_TIPO_DOCUMENTO] ✓ {cargos_eliminados} flujo(s)-cargo eliminado(s)")
        
        print(f"[ELIMINAR_TIPO_DOCUMENTO] ✓ {cargos_eliminados} flujo(s)-cargo eliminado(s)")
        
        # 2. Eliminar el tipo de documento
        cursor.execute('''
            DELETE FROM TblTipoDocumentoAprobacion 
            WHERE id_tipo_documento = %s
        ''', (id_tipo,))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        print(f"[ELIMINAR_TIPO_DOCUMENTO] ✅ Tipo de documento {id_tipo} eliminado")
        print(f"[ELIMINAR_TIPO_DOCUMENTO] Total: 1 tipo + {cargos_eliminados} cargo(s)")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True,
            'message': f'Tipo de documento eliminado (1 tipo + {cargos_eliminados} cargo(s))'
        }), 200
    
    except Exception as e:
        print(f"[ELIMINAR_TIPO] Error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/actualizar-flujo/<int:id_flujo>', methods=['PUT'])
@login_required
def actualizar_flujo_aprobacion(id_flujo):
    """Actualizar flujo de aprobación en TblFlujoAprobacionCargos"""
    try:
        datos = request.get_json()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        cursor.execute('''
            UPDATE TblFlujoAprobacionCargos 
            SET id_tipo_documento = %s, numero_paso = %s, nombre_paso = %s,
                descripcion = %s, es_requerido = %s, permite_rechazo = %s
            WHERE id_flujo_cargo = %s
        ''', (
            datos.get('id_tipo_documento'),
            datos.get('numero_paso'),
            datos.get('nombre_paso'),
            datos.get('descripcion'),
            datos.get('es_requerido', 1),
            datos.get('permite_rechazo', 1),
            id_flujo
        ))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'message': 'Flujo de aprobación actualizado'}), 200
    
    except Exception as e:
        print(f"[ACTUALIZAR_FLUJO] Error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/eliminar-flujo/<int:id_flujo>', methods=['DELETE'])
@login_required
def eliminar_flujo_aprobacion(id_flujo):
    """Eliminar flujo de aprobación usando SP con validaciones"""
    try:
        connection = get_db_connection()
        if not connection:
            print(f"[ELIMINAR_FLUJO] [ERROR] No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[ELIMINAR_FLUJO] Eliminando flujo-cargo ID {id_flujo}")
        print(f"{'='*80}")
        
        # Obtener información del flujo antes de eliminar
        cursor.execute('''
            SELECT id_tipo_documento, numero_paso
            FROM TblFlujoAprobacionCargos
            WHERE id_flujo_cargo = %s
        ''', (id_flujo,))
        
        flujo_info = cursor.fetchone()
        if not flujo_info:
            print(f"[ELIMINAR_FLUJO] [ERROR] Flujo no encontrado")
            return jsonify({'success': False, 'error': 'Flujo no encontrado'}), 404
        
        id_tipo_documento = flujo_info['id_tipo_documento']
        
        print(f"[ELIMINAR_FLUJO] Flujo encontrado: tipo_doc={id_tipo_documento}, paso={flujo_info['numero_paso']}")
        
        # Llamar al SP
        print(f"[ELIMINAR_FLUJO] Llamando SP: sp_EliminarFlujoAprobacion({id_flujo}, {id_tipo_documento}, ...)")
        
        cursor.callproc('sp_EliminarFlujoAprobacion', [
            id_flujo,
            id_tipo_documento,
            '',  # OUT p_resultado
            ''   # OUT p_mensaje
        ])
        
        # Obtener resultado del SP
        resultado = None
        for result in cursor.stored_results():
            rows = result.fetchall()
            if rows:
                resultado = rows[0]
                break
        
        print(f"[ELIMINAR_FLUJO] Resultado SP: {resultado}")
        
        connection.commit()
        cursor.close()
        connection.close()
        
        if resultado and resultado.get('resultado') == 'OK':
            print(f"[ELIMINAR_FLUJO] ✅ Flujo {id_flujo} eliminado exitosamente")
            print(f"[ELIMINAR_FLUJO] Mensaje: {resultado.get('mensaje')}")
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': resultado.get('mensaje', 'Flujo eliminado exitosamente')
            }), 200
        else:
            resultado_tipo = resultado.get('resultado', 'ERROR') if resultado else 'ERROR'
            error_msg = resultado.get('mensaje', 'Error desconocido') if resultado else 'Error desconocido'
            print(f"[ELIMINAR_FLUJO] [{resultado_tipo}] {error_msg}")
            print(f"{'='*80}\n")
            
            # ADVERTENCIA es una respuesta válida (no error HTTP), success=false pero status 200
            # ERROR es un error real, devolver success=false con status 400
            status_code = 200 if resultado_tipo == 'ADVERTENCIA' else 400
            
            return jsonify({
                'success': False,
                'error': error_msg,
                'type': resultado_tipo
            }), status_code
    
    except Exception as e:
        print(f"[ELIMINAR_FLUJO] [ERROR] Exception: {str(e)}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/guardar-cambios-flujo', methods=['POST'])
@login_required
def guardar_cambios_flujo_endpoint():
    """Guardar múltiples cambios en un flujo (agregar/eliminar cargos)"""
    from .guardar_cambios_flujo import guardar_cambios_flujo
    return guardar_cambios_flujo()


@main_bp.route('/api/flujo-aprobacion/crear-tipo', methods=['POST'])
@login_required
def crear_tipo_documento():
    """Crear nuevo tipo de documento"""
    print(f"\n{'='*80}")
    print(f"[CREAR_TIPO_DOCUMENTO] Iniciando...")
    print(f"{'='*80}")
    
    try:
        datos = request.get_json()
        print(f"[CREAR_TIPO_DOCUMENTO] Datos recibidos: {datos}")
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Insertar tipo de documento
        cursor.execute('''
            INSERT INTO TblTipoDocumentoAprobacion 
            (nombre, descripcion, icono, color, requiere_aprobacion, activo)
            VALUES (%s, %s, %s, %s, %s, 1)
        ''', (
            datos.get('nombre'),
            datos.get('descripcion'),
            datos.get('icono'),
            datos.get('color'),
            datos.get('requiere_aprobacion', 1)
        ))
        
        connection.commit()
        
        print(f"[CREAR_TIPO_DOCUMENTO] ✓ Tipo de documento creado")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Tipo de documento creado correctamente'
        }), 201
    
    except Exception as e:
        print(f"[CREAR_TIPO_DOCUMENTO] ❌ ERROR: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/crear-flujo', methods=['POST'])
@login_required
def crear_flujo_aprobacion():
    """Crear nuevo flujo de aprobación en TblFlujoAprobacionCargos"""
    print(f"\n{'='*80}")
    print(f"[CREAR_FLUJO_APROBACION] Iniciando...")
    print(f"{'='*80}")
    
    try:
        datos = request.get_json()
        print(f"[CREAR_FLUJO_APROBACION] Datos recibidos: {datos}")
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        id_tipo_documento = datos.get('id_tipo_documento')
        numero_paso = datos.get('numero_paso')
        id_cargo = datos.get('id_cargo')
        nombre_paso = datos.get('nombre_paso')
        descripcion = datos.get('descripcion')
        es_requerido = datos.get('es_requerido', 1)
        permite_rechazo = datos.get('permite_rechazo', 1)
        
        # Validar si ya existe este cargo en este paso
        cursor.execute('''
            SELECT id_flujo_cargo 
            FROM TblFlujoAprobacionCargos 
            WHERE id_tipo_documento = %s 
            AND numero_paso = %s 
            AND id_cargo = %s 
            LIMIT 1
        ''', (id_tipo_documento, numero_paso, id_cargo))
        
        if cursor.fetchone():
            cursor.close()
            connection.close()
            print(f"[CREAR_FLUJO_APROBACION] ⚠️ Cargo {id_cargo} ya existe en paso {numero_paso}")
            return jsonify({
                'success': False,
                'error': 'Este cargo ya está asignado a este paso'
            }), 409
        
        # Insertar nuevo flujo-cargo en TblFlujoAprobacionCargos
        cursor.execute('''
            INSERT INTO TblFlujoAprobacionCargos 
            (id_tipo_documento, numero_paso, nombre_paso, descripcion, es_requerido, permite_rechazo, id_cargo, activo)
            VALUES (%s, %s, %s, %s, %s, %s, %s, 1)
        ''', (
            id_tipo_documento,
            numero_paso,
            nombre_paso,
            descripcion,
            es_requerido,
            permite_rechazo,
            id_cargo
        ))
        
        id_flujo_cargo = cursor.lastrowid
        connection.commit()
        
        print(f"[CREAR_FLUJO_APROBACION] ✓ Flujo-cargo creado (ID: {id_flujo_cargo})")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Flujo de aprobación creado correctamente',
            'id_flujo_cargo': id_flujo_cargo
        }), 201
    
    except Exception as e:
        print(f"[CREAR_FLUJO_APROBACION] ❌ ERROR: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# NUEVOS ENDPOINTS PARA GESTIÓN DE FLUJOS CONECTADOS A BD
# ============================================================================

@main_bp.route('/api/flujo-aprobacion/detalle/<int:id_tipo_documento>', methods=['GET'])
@login_required
def obtener_detalle_flujo(id_tipo_documento):
    """Obtener detalle del flujo de aprobación para un tipo de documento"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[FLUJO_DETALLE] Obteniendo detalle para tipo: {id_tipo_documento}")
        
        # Llamar SP para obtener flujo
        cursor.callproc('sp_ObtenerFlujoAprobacion', [id_tipo_documento])
        
        pasos = []
        for result in cursor.stored_results():
            pasos = result.fetchall()
        
        print(f"[FLUJO_DETALLE] [✓ OK] {len(pasos)} pasos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': pasos
        }), 200
    
    except Error as e:
        print(f"[FLUJO_DETALLE] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/registrar-aprobacion', methods=['POST'])
@login_required
def registrar_aprobacion():
    """Registrar aprobación de un paso del flujo - CON VALIDACIÓN DE FLUJO COMPLETO"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[REGISTRAR_APROBACION] Iniciando para usuario: {num_documento}")
    print(f"{'='*80}")
    
    try:
        datos = request.get_json()
        print(f"[REGISTRAR_APROBACION] Datos recibidos: {datos}")
        
        # Parámetros
        id_tipo_documento = datos.get('id_tipo_documento')
        id_documento_referencia = datos.get('id_documento_referencia')
        numero_paso = datos.get('numero_paso')
        id_cargo_aprobador = datos.get('id_cargo_aprobador')
        num_documento_aprobador = int(num_documento)
        comentario = datos.get('comentario', '')
        
        print(f"[REGISTRAR_APROBACION] Parámetros:")
        print(f"  - Tipo Documento: {id_tipo_documento}")
        print(f"  - ID Documento: {id_documento_referencia}")
        print(f"  - Paso: {numero_paso}")
        print(f"  - Usuario: {num_documento_aprobador}")
        
        # PASO 1: Importar funciones de validación
        from app.funciones.validar_flujo_aprobacion import (
            registrar_aprobacion_en_flujo,
            validar_flujo_completo,
            actualizar_estado_documento
        )
        
        # PASO 2: Registrar aprobación en TblRegistroAprobacion
        print(f"[REGISTRAR_APROBACION] Registrando aprobación en TblRegistroAprobacion...")
        result_registro = registrar_aprobacion_en_flujo(
            id_tipo_documento=id_tipo_documento,
            id_documento_referencia=id_documento_referencia,
            numero_paso=numero_paso,
            id_cargo_aprobador=id_cargo_aprobador,
            num_documento_aprobador=num_documento_aprobador,
            comentario=comentario
        )
        
        if not result_registro['success']:
            print(f"[REGISTRAR_APROBACION] Error al registrar: {result_registro['message']}")
            return jsonify({'success': False, 'error': result_registro['message']}), 400
        
        print(f"[REGISTRAR_APROBACION] ✓ Aprobación registrada en TblRegistroAprobacion")
        
        # PASO 3: Validar si flujo está completo
        print(f"[REGISTRAR_APROBACION] Validando si flujo está completo...")
        flujo_info = validar_flujo_completo(id_tipo_documento, id_documento_referencia)
        
        print(f"[REGISTRAR_APROBACION] Estado del flujo:")
        print(f"  - Total pasos: {flujo_info['total_pasos']}")
        print(f"  - Pasos aprobados: {flujo_info['pasos_aprobados']}")
        print(f"  - Pasos rechazados: {flujo_info['pasos_rechazados']}")
        print(f"  - Estado: {flujo_info['estado']}")
        
        # PASO 4: Actualizar estado del documento basado en el flujo
        nuevo_estado = flujo_info['estado']  # PENDIENTE, APROBADO, o RECHAZADO
        print(f"[REGISTRAR_APROBACION] Actualizando estado del documento a: {nuevo_estado}")
        
        result_actualizacion = actualizar_estado_documento(
            id_tipo_documento=id_tipo_documento,
            id_documento_referencia=id_documento_referencia,
            nuevo_estado=nuevo_estado
        )
        
        if not result_actualizacion['success']:
            print(f"[REGISTRAR_APROBACION] Warning: No se pudo actualizar estado: {result_actualizacion['message']}")
        else:
            print(f"[REGISTRAR_APROBACION] ✓ Estado actualizado a {nuevo_estado}")
        
        # PASO 5: Determinar si puede notificar siguiente paso
        puede_notificar = flujo_info['estado'] == 'PENDIENTE'  # Solo si falta algo (no rechazado ni aprobado final)
        
        print(f"[REGISTRAR_APROBACION] ¿Puede notificar siguiente paso?: {puede_notificar}")
        
        print(f"[REGISTRAR_APROBACION] [✓ OK] Aprobación completada exitosamente")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True,
            'message': f'Paso {numero_paso} aprobado correctamente',
            'estado_flujo': flujo_info['estado'],
            'pasos_completados': f"{flujo_info['pasos_aprobados']}/{flujo_info['total_pasos']}",
            'flujo_completo': flujo_info['flujo_completo'],
            'puede_notificar_siguiente': puede_notificar,
            'id_registro': result_registro['id_registro']
        }), 201
    
    except Exception as e:
        print(f"[REGISTRAR_APROBACION] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/registrar-rechazo', methods=['POST'])
@login_required
def registrar_rechazo():
    """Registrar rechazo de un paso del flujo - CAMBIA ESTADO A RECHAZADO INMEDIATAMENTE"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[REGISTRAR_RECHAZO] Iniciando para usuario: {num_documento}")
    print(f"{'='*80}")
    
    try:
        datos = request.get_json()
        print(f"[REGISTRAR_RECHAZO] Datos recibidos: {datos}")
        
        # Parámetros
        id_tipo_documento = datos.get('id_tipo_documento')
        id_documento_referencia = datos.get('id_documento_referencia')
        numero_paso = datos.get('numero_paso')
        id_cargo_aprobador = datos.get('id_cargo_aprobador')
        num_documento_aprobador = int(num_documento)
        comentario = datos.get('comentario', '')
        
        print(f"[REGISTRAR_RECHAZO] Parámetros:")
        print(f"  - Tipo Documento: {id_tipo_documento}")
        print(f"  - ID Documento: {id_documento_referencia}")
        print(f"  - Paso: {numero_paso}")
        print(f"  - Usuario: {num_documento_aprobador}")
        print(f"  - Comentario: {comentario[:50]}..." if len(comentario) > 50 else f"  - Comentario: {comentario}")
        
        # PASO 1: Importar funciones de validación
        from app.funciones.validar_flujo_aprobacion import (
            registrar_rechazo_en_flujo,
            actualizar_estado_documento
        )
        
        # PASO 2: Registrar rechazo en TblRegistroAprobacion
        print(f"[REGISTRAR_RECHAZO] Registrando rechazo en TblRegistroAprobacion...")
        result_registro = registrar_rechazo_en_flujo(
            id_tipo_documento=id_tipo_documento,
            id_documento_referencia=id_documento_referencia,
            numero_paso=numero_paso,
            id_cargo_aprobador=id_cargo_aprobador,
            num_documento_aprobador=num_documento_aprobador,
            comentario=comentario
        )
        
        if not result_registro['success']:
            print(f"[REGISTRAR_RECHAZO] Error al registrar: {result_registro['message']}")
            return jsonify({'success': False, 'error': result_registro['message']}), 400
        
        print(f"[REGISTRAR_RECHAZO] ✓ Rechazo registrado en TblRegistroAprobacion")
        
        # PASO 3: Cambiar estado a RECHAZADO INMEDIATAMENTE (no espera otros pasos)
        print(f"[REGISTRAR_RECHAZO] Actualizando estado del documento a RECHAZADO...")
        
        result_actualizacion = actualizar_estado_documento(
            id_tipo_documento=id_tipo_documento,
            id_documento_referencia=id_documento_referencia,
            nuevo_estado='RECHAZADO'
        )
        
        if not result_actualizacion['success']:
            print(f"[REGISTRAR_RECHAZO] Warning: No se pudo actualizar estado: {result_actualizacion['message']}")
        else:
            print(f"[REGISTRAR_RECHAZO] ✓ Estado actualizado a RECHAZADO")
        
        print(f"[REGISTRAR_RECHAZO] [✓ OK] Rechazo procesado exitosamente")
        print(f"{'='*80}\n")
        
        return jsonify({
            'success': True,
            'message': f'Paso {numero_paso} ha sido rechazado',
            'estado_documento': 'RECHAZADO',
            'comentario': comentario,
            'id_registro': result_registro['id_registro']
        }), 201
    
    except Exception as e:
        print(f"[REGISTRAR_RECHAZO] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/historial/<int:id_tipo_documento>/<int:id_documento>', methods=['GET'])
@login_required
def obtener_historial_aprobacion(id_tipo_documento, id_documento):
    """Obtener historial de aprobaciones de un documento"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[HISTORIAL_APROBACION] Obteniendo historial: tipo={id_tipo_documento}, doc={id_documento}")
        
        # Llamar SP
        cursor.callproc('sp_ObtenerHistorialAprobacion', [id_tipo_documento, id_documento])
        
        historial = []
        for result in cursor.stored_results():
            historial = result.fetchall()
            # Convertir timestamp a ISO format
            for reg in historial:
                if reg['fecha_aprobacion']:
                    reg['fecha_aprobacion'] = reg['fecha_aprobacion'].isoformat()
                if reg['fecha_asignacion']:
                    reg['fecha_asignacion'] = reg['fecha_asignacion'].isoformat()
        
        print(f"[HISTORIAL_APROBACION] [✓ OK] {len(historial)} registros")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': historial
        }), 200
    
    except Error as e:
        print(f"[HISTORIAL_APROBACION] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/flujo-aprobacion/proximo-paso/<int:id_tipo_documento>/<int:id_documento>', methods=['GET'])
@login_required
def obtener_proximo_paso(id_tipo_documento, id_documento):
    """Obtener el próximo paso de aprobación pendiente - VALIDANDO QUE PASO ANTERIOR ESTÉ APROBADO"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n[PROXIMO_PASO] Obteniendo próximo paso: tipo={id_tipo_documento}, doc={id_documento}")
        
        # Llamar SP para obtener próximo paso
        cursor.callproc('sp_ObtenerProximoPasoAprobacion', [id_tipo_documento, id_documento])
        
        proximo_paso = None
        for result in cursor.stored_results():
            pasos = result.fetchall()
            if pasos:
                proximo_paso = pasos[0]
        
        # Si no hay próximo paso, retornar
        if not proximo_paso:
            print(f"[PROXIMO_PASO] [✓ OK] No hay próximo paso (flujo completo)")
            cursor.close()
            connection.close()
            return jsonify({
                'success': False,
                'message': 'Flujo de aprobación completado',
                'data': None
            }), 200
        
        numero_paso_siguiente = proximo_paso['numero_paso']
        print(f"[PROXIMO_PASO] Próximo paso encontrado: {numero_paso_siguiente}")
        
        # VALIDACIÓN NUEVA: Verificar que el paso anterior está APROBADO
        if numero_paso_siguiente > 1:
            print(f"[PROXIMO_PASO] Validando que paso anterior ({numero_paso_siguiente - 1}) está APROBADO...")
            
            cursor.execute('''
                SELECT estado_aprobacion FROM TblRegistroAprobacion
                WHERE id_tipo_documento = %s
                  AND id_documento_referencia = %s
                  AND numero_paso = %s
                LIMIT 1
            ''', (id_tipo_documento, id_documento, numero_paso_siguiente - 1))
            
            paso_anterior = cursor.fetchone()
            
            if not paso_anterior:
                print(f"[PROXIMO_PASO] ❌ Paso anterior NO tiene registro")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False,
                    'error': f'Paso {numero_paso_siguiente - 1} no ha sido procesado aún',
                    'message': 'Debe aprobar el paso anterior primero'
                }), 403
            
            if paso_anterior['estado_aprobacion'] != 'APROBADO':
                print(f"[PROXIMO_PASO] ❌ Paso anterior estado: {paso_anterior['estado_aprobacion']}")
                cursor.close()
                connection.close()
                return jsonify({
                    'success': False,
                    'error': f'Paso {numero_paso_siguiente - 1} debe estar APROBADO',
                    'estado_paso_anterior': paso_anterior['estado_aprobacion'],
                    'message': 'El paso anterior debe ser aprobado antes de proceder'
                }), 403
            
            print(f"[PROXIMO_PASO] ✓ Paso anterior está APROBADO")
        
        print(f"[PROXIMO_PASO] [✓ OK] Próximo paso habilitado para aprobación")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': proximo_paso,
            'puede_proceder': True
        }), 200
    
    except Error as e:
        print(f"[PROXIMO_PASO] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# NUEVO ENDPOINT: NOTIFICACIONES DE APROBACIÓN
# ============================================================================

@main_bp.route('/api/notificaciones/pendientes', methods=['GET'])
@login_required
def obtener_notificaciones_pendientes():
    """Obtener notificaciones de documentos pendientes de aprobación para el usuario"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[NOTIFICACIONES_PENDIENTES] Obteniendo para usuario: {num_documento}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener id_cargo del usuario
        print(f"[NOTIFICACIONES] Obteniendo cargo del usuario...")
        cursor.execute("""
            SELECT 
                tc.id_cargo,
                tc.nombre as cargo_nombre
            FROM TblCargo tc
            INNER JOIN TblUsuario tu ON tc.id_cargo = tu.id_cargo
            WHERE tu.num_documento = %s AND tu.estado = 'Activo'
            LIMIT 1
        """, (num_documento,))
        
        cargo_result = cursor.fetchone()
        
        if not cargo_result:
            print(f"[NOTIFICACIONES] ⚠️ Usuario no tiene cargo asignado")
            cursor.close()
            connection.close()
            return jsonify({
                'success': True,
                'data': []
            }), 200
        
        id_cargo = cargo_result['id_cargo']
        cargo_nombre = cargo_result['cargo_nombre']
        
        print(f"[NOTIFICACIONES] ✓ Cargo encontrado: {id_cargo} - {cargo_nombre}")
        
        # 2. Llamar SP para obtener notificaciones - VERSIÓN CORREGIDA
        print(f"[NOTIFICACIONES] Obteniendo notificaciones para cargo: {id_cargo}")
        
        # DEBUG: Primero, ver qué flujos existen para este cargo
        cursor.execute("""
            SELECT DISTINCT
                fac.id_tipo_documento,
                fac.numero_paso,
                tda.nombre
            FROM TblFlujoAprobacionCargos fac
            LEFT JOIN TblTipoDocumentoAprobacion tda ON fac.id_tipo_documento = tda.id_tipo_documento
            WHERE fac.id_cargo = %s AND fac.activo = 1
        """, (id_cargo,))
        
        flujos = cursor.fetchall()
        print(f"[NOTIFICACIONES] DEBUG: Encontrados {len(flujos)} flujos para cargo {id_cargo}")
        for flujo in flujos:
            print(f"[NOTIFICACIONES]   - Tipo Doc {flujo.get('id_tipo_documento')}, Paso {flujo.get('numero_paso')}, Nombre: {flujo.get('nombre')}")
        
        # DEBUG: Ver presupuestos pendientes en general
        cursor.execute("""
            SELECT COUNT(*) as total
            FROM TblPresupuesto
            WHERE estado = 'PENDIENTE'
        """)
        pendientes_total = cursor.fetchone()
        print(f"[NOTIFICACIONES] DEBUG: Total presupuestos PENDIENTES en BD: {pendientes_total.get('total')}")
        
        # NUEVA QUERY: Buscar registros PENDIENTE en TblRegistroAprobacion para ANY paso (no solo paso 1)
        # Esto permite que usuarios vean notificaciones para cualquier paso del flujo donde son aprobadores
        # IMPORTANTE: Solo incluir documentos donde TODOS los pasos anteriores estén APROBADOS
        cursor.execute("""
            SELECT 
                tda.id_tipo_documento,
                tda.nombre AS nombre_documento,
                COALESCE(tda.icono, 'fa-file') AS icono,
                COALESCE(tda.color, 'blue') AS color,
                COALESCE(tda.descripcion, '') AS descripcion_documento,
                COUNT(DISTINCT ra.id_documento_referencia) AS cantidad_pendientes,
                fac.numero_paso,
                COALESCE(fac.nombre_paso, '') AS descripcion_paso,
                COALESCE(fac.descripcion, '') AS descripcion_detalle,
                MIN(ra.fecha_asignacion) AS documento_mas_antiguo,
                TIMEDIFF(NOW(), MIN(ra.fecha_asignacion)) AS tiempo_pendiente
            FROM 
                TblTipoDocumentoAprobacion tda
            INNER JOIN 
                TblFlujoAprobacionCargos fac ON tda.id_tipo_documento = fac.id_tipo_documento
            INNER JOIN 
                TblRegistroAprobacion ra ON tda.id_tipo_documento = ra.id_tipo_documento 
                    AND ra.numero_paso = fac.numero_paso 
                    AND ra.estado_aprobacion = 'PENDIENTE'
            WHERE 
                fac.id_cargo = %s
                AND fac.activo = 1
                AND fac.es_requerido = 1
                AND tda.activo = 1
                AND tda.requiere_aprobacion = 1
                -- CRÍTICO: Verificar que TODOS los pasos anteriores estén APROBADOS
                AND NOT EXISTS (
                    SELECT 1 
                    FROM TblRegistroAprobacion ra_prev
                    WHERE ra_prev.id_tipo_documento = ra.id_tipo_documento
                      AND ra_prev.id_documento_referencia = ra.id_documento_referencia
                      AND ra_prev.numero_paso < ra.numero_paso
                      AND ra_prev.estado_aprobacion <> 'APROBADO'
                )
            GROUP BY 
                tda.id_tipo_documento,
                tda.nombre,
                tda.icono,
                tda.color,
                tda.descripcion,
                fac.numero_paso,
                fac.nombre_paso,
                fac.descripcion
            
            ORDER BY 
                cantidad_pendientes DESC,
                documento_mas_antiguo ASC
        """, (id_cargo,))
        
        notificaciones = cursor.fetchall()
        
        print(f"[NOTIFICACIONES] ✓ Obtenidas {len(notificaciones)} notificaciones")
        
        # Convertir timestamps a strings para JSON
        for notif in notificaciones:
            if notif.get('documento_mas_antiguo'):
                notif['documento_mas_antiguo'] = notif['documento_mas_antiguo'].isoformat()
            
            # Convertir timedelta a string y remover el original
            if notif.get('tiempo_pendiente'):
                td = notif['tiempo_pendiente']
                if td:
                    notif['tiempo_pendiente_str'] = str(td)
                else:
                    notif['tiempo_pendiente_str'] = ''
                # Remover el timedelta que no es serializable
                del notif['tiempo_pendiente']
            else:
                notif['tiempo_pendiente_str'] = ''
                # Remover el timedelta si existe
                if 'tiempo_pendiente' in notif:
                    del notif['tiempo_pendiente']
        
        # Log de notificaciones
        for notif in notificaciones:
            print(f"[NOTIFICACIONES]   • {notif['nombre_documento']}: {notif['cantidad_pendientes']} pendiente(s)")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': notificaciones,
            'usuario_cargo': cargo_nombre
        }), 200
    
    except Error as e:
        print(f"[NOTIFICACIONES] ❌ ERROR: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/notificaciones/contar', methods=['GET'])
@login_required
def contar_notificaciones():
    """Obtener la cantidad total de documentos pendientes de aprobación"""
    num_documento = session.get('user_documento')
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Obtener cargo del usuario
        cursor.execute("""
            SELECT tc.id_cargo
            FROM TblCargo tc
            INNER JOIN TblUsuario tu ON tc.id_cargo = tu.id_cargo
            WHERE tu.num_documento = %s AND tu.estado = 'Activo'
            LIMIT 1
        """, (num_documento,))
        
        cargo_result = cursor.fetchone()
        
        if not cargo_result:
            cursor.close()
            connection.close()
            return jsonify({'success': True, 'total': 0}), 200
        
        id_cargo = cargo_result['id_cargo']
        
        # Llamar SP
        cursor.callproc('sp_ObtenerNotificacionesPendientes', [id_cargo])
        
        notificaciones = []
        for result in cursor.stored_results():
            notificaciones = result.fetchall()
        
        # Contar total de documentos pendientes
        total_pendientes = sum(n['cantidad_pendientes'] for n in notificaciones)
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'total': total_pendientes,
            'tipos_documento': len(notificaciones)
        }), 200
    
    except Error as e:
        print(f"[CONTAR_NOTIFICACIONES] ERROR: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/notificaciones/detalles/<int:id_tipo_documento>', methods=['GET'])
@login_required
def obtener_detalles_pendientes(id_tipo_documento):
    """Obtener detalles de documentos pendientes (Presupuestos o Requerimientos)"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[DETALLES_PENDIENTES] Tipo documento recibido: {id_tipo_documento} (tipo: {type(id_tipo_documento).__name__})")
    print(f"[DETALLES_PENDIENTES] Usuario: {num_documento}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[DETALLES_PENDIENTES] ERROR: No connection")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        documentos = []
        
        # Obtener el cargo del usuario
        cursor.execute("""
            SELECT 
                tc.id_cargo
            FROM TblCargo tc
            INNER JOIN TblUsuario tu ON tc.id_cargo = tu.id_cargo
            WHERE tu.num_documento = %s AND tu.estado = 'Activo'
            LIMIT 1
        """, (num_documento,))
        
        cargo_result = cursor.fetchone()
        if not cargo_result:
            print(f"[DETALLES_PENDIENTES] Usuario no tiene cargo asignado")
            cursor.close()
            connection.close()
            return jsonify({'success': True, 'data': []}), 200
        
        id_cargo = cargo_result['id_cargo']
        print(f"[DETALLES_PENDIENTES] Cargo encontrado: {id_cargo}")
        print(f"[DETALLES_PENDIENTES] DEBUG: user_documento={num_documento}, id_cargo={id_cargo}")
        
        # Obtener nombre del cargo para verificación
        cursor.execute("""
            SELECT nombre FROM TblCargo WHERE id_cargo = %s
        """, (id_cargo,))
        cargo_name_result = cursor.fetchone()
        cargo_name = cargo_name_result['nombre'] if cargo_name_result else 'DESCONOCIDO'
        print(f"[DETALLES_PENDIENTES] Cargo nombre: {cargo_name}")
        
        # Procesar según tipo de documento
        if id_tipo_documento == 1:  # PRESUPUESTO
            print(f"[DETALLES_PENDIENTES] Rama: PRESUPUESTOS - Usando SP genérico")
            
            # Llamar SP genérico que filtra por cargo
            print(f"[DETALLES_PENDIENTES] Ejecutando: sp_ObtenerDocumentosPendientesPorCargo({id_cargo}, {id_tipo_documento})")
            cursor.callproc('sp_ObtenerDocumentosPendientesPorCargo', [id_cargo, id_tipo_documento])
            
            # Obtener resultados del SP - IMPORTANTE: usar stored_results() con callproc
            documentos_raw = []
            for result_set in cursor.stored_results():
                documentos_raw = result_set.fetchall()
            
            print(f"[DETALLES_PENDIENTES] SP retornó {len(documentos_raw)} documentos raw")
            
            # Para presupuestos, necesitamos obtener monto, obra, responsable
            # Hacer query adicional para enriquecer los datos
            documentos = []
            if documentos_raw:
                print(f"[DETALLES_PENDIENTES] Enriqueciendo datos de {len(documentos_raw)} documentos...")
                for doc_base in documentos_raw:
                    id_doc = doc_base['id_documento']  # From SP result dict
                    numero_paso = doc_base.get('numero_paso')
                    
                    # VERIFICAR: que el documento esté PENDIENTE en este paso específico
                    cursor.execute("""
                        SELECT estado_aprobacion 
                        FROM TblRegistroAprobacion
                        WHERE id_tipo_documento = %s
                        AND id_documento_referencia = %s
                        AND numero_paso = %s
                        AND id_cargo_aprobador = %s
                    """, (id_tipo_documento, id_doc, numero_paso, id_cargo))
                    
                    estado_check = cursor.fetchone()
                    if not estado_check or estado_check['estado_aprobacion'] != 'PENDIENTE':
                        print(f"[DETALLES_PENDIENTES] ⚠️  Documento {id_doc} paso {numero_paso} NO está PENDIENTE, skipping")
                        continue
                    
                    # Obtener detalles del presupuesto
                    cursor.execute("""
                        SELECT 
                            p.numero_presupuesto,
                            p.monto,
                            o.nombre as obra,
                            CONCAT(COALESCE(per.nombres, ''), ' ', COALESCE(per.apellido_paterno, '')) as responsable,
                            p.fecha_creacion
                        FROM TblPresupuesto p
                        LEFT JOIN TblObra o ON p.id_obra = o.id_obra
                        LEFT JOIN TblUsuario u ON p.num_documento = u.num_documento
                        LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
                        WHERE p.id_presupuesto = %s
                    """, (id_doc,))
                    
                    pres_detail = cursor.fetchone()
                    if pres_detail:
                        documentos.append({
                            'id_documento': id_doc,
                            'numero': pres_detail['numero_presupuesto'],
                            'monto': pres_detail['monto'],
                            'obra': pres_detail['obra'],
                            'responsable': pres_detail['responsable'],
                            'fecha_creacion': pres_detail['fecha_creacion'],
                            'numero_paso': numero_paso,
                            'fecha_asignacion': doc_base.get('fecha_asignacion')
                        })
            
            print(f"[DETALLES_PENDIENTES] ✓ Presupuestos encontrados para cargo {id_cargo}: {len(documentos)}")
            
        elif id_tipo_documento == 2:  # REQUERIMIENTO
            print(f"[DETALLES_PENDIENTES] Rama: REQUERIMIENTOS - Usando SP genérico")
            
            # Llamar SP genérico que filtra por cargo
            print(f"[DETALLES_PENDIENTES] Ejecutando: sp_ObtenerDocumentosPendientesPorCargo({id_cargo}, {id_tipo_documento})")
            cursor.callproc('sp_ObtenerDocumentosPendientesPorCargo', [id_cargo, id_tipo_documento])
            
            # Obtener resultados del SP - IMPORTANTE: usar stored_results() con callproc
            documentos_raw = []
            for result_set in cursor.stored_results():
                documentos_raw = result_set.fetchall()
            
            # Para requerimientos, necesitamos obtener código, cantidad, descripción
            documentos = []
            if documentos_raw:
                for doc_base in documentos_raw:
                    id_doc = doc_base['id_documento']  # From SP result dict
                    
                    # Obtener detalles del requerimiento
                    cursor.execute("""
                        SELECT 
                            r.codigo,
                            r.cantidad as cantidad_items,
                            r.descripcion,
                            COALESCE(CONCAT(per.nombres, ' ', per.apellido_paterno), 'Sin asignar') as responsable,
                            r.fecha_creacion
                        FROM TblRequerimiento r
                        LEFT JOIN TblUsuario u ON r.num_usuario = u.num_usuario
                        LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
                        WHERE r.id_requerimiento = %s
                    """, (id_doc,))
                    
                    req_detail = cursor.fetchone()
                    if req_detail:
                        documentos.append({
                            'id_documento': id_doc,
                            'numero': req_detail['codigo'],
                            'cantidad_items': req_detail['cantidad_items'],
                            'descripcion': req_detail['descripcion'],
                            'responsable': req_detail['responsable'],
                            'fecha_creacion': req_detail['fecha_creacion'],
                            'numero_paso': doc_base['numero_paso'],
                            'fecha_asignacion': doc_base['fecha_asignacion']
                        })
            
            print(f"[DETALLES_PENDIENTES] ✓ Requerimientos encontrados para cargo {id_cargo}: {len(documentos)}")
        else:
            print(f"[DETALLES_PENDIENTES] ⚠️ TIPO DE DOCUMENTO NO VÁLIDO: {id_tipo_documento}")
        
        # Convertir datetime a string para JSON
        from datetime import datetime
        for doc in documentos:
            if isinstance(doc.get('fecha_creacion'), datetime):
                doc['fecha_creacion'] = doc['fecha_creacion'].isoformat()
            if isinstance(doc.get('fecha_asignacion'), datetime):
                doc['fecha_asignacion'] = doc['fecha_asignacion'].isoformat()
        
        print(f"[DETALLES_PENDIENTES] ✓ Retornando {len(documentos)} documentos")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': documentos,
            'tipo_documento_id': id_tipo_documento
        }), 200
    
    except Error as e:
        print(f"[DETALLES_PENDIENTES] ❌ ERROR SQL: {e}")
        import traceback
        traceback.print_exc()
        cursor.close()
        connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[DETALLES_PENDIENTES] ❌ ERROR GENERAL: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500
