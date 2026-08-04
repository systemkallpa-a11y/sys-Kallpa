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

@main_bp.route('/presupuesto')
@login_required
def presupuesto():
    """Página principal de gestión de presupuestos"""
    num_documento = session.get('user_documento')
    
    # Validar acceso a Presupuesto
    # Menu 5 = O.T, SubMenu 9 = Presupuesto
    # Permitir si tiene acceso completo a O.T O acceso específico a Presupuesto
    
    print(f"\n{'='*80}")
    print(f"[PRESUPUESTO_ACCESS] Validando acceso a /presupuesto")
    print(f"[PRESUPUESTO_ACCESS] Documento: {num_documento}")
    print(f"{'='*80}")
    
    # Opción 1: Acceso completo a Menu 5 (O.T)
    print(f"[PRESUPUESTO_ACCESS] 1️⃣ Validando acceso COMPLETO a menú 5 (O.T)...")
    tiene_acceso_completo = validar_acceso_usuario(num_documento, id_menu=5, id_submenu=None)
    print(f"[PRESUPUESTO_ACCESS] Resultado acceso completo: {tiene_acceso_completo}")
    
    # Opción 2: Acceso específico a SubMenu 9 (Presupuesto)
    print(f"[PRESUPUESTO_ACCESS] 2️⃣ Validando acceso específico a menú 5, submenú 9...")
    tiene_acceso_presupuesto = validar_acceso_usuario(num_documento, id_menu=5, id_submenu=9)
    print(f"[PRESUPUESTO_ACCESS] Resultado acceso Presupuesto: {tiene_acceso_presupuesto}")
    
    print(f"[PRESUPUESTO_ACCESS] ✅ Acceso permitido: {tiene_acceso_completo or tiene_acceso_presupuesto}")
    
    if not (tiene_acceso_completo or tiene_acceso_presupuesto):
        print(f"[PRESUPUESTO_ACCESS] ❌ ACCESO DENEGADO - Redirigiendo a dashboard")
        print(f"{'='*80}\n")
        flash('No tienes acceso a Gestión de Presupuestos', 'danger')
        return redirect(url_for('main.dashboard'))
    
    print(f"[PRESUPUESTO_ACCESS] ✅ ACCESO PERMITIDO - Cargando presupuesto.html")
    print(f"{'='*80}\n")
    return render_template('presupuesto.html')

@main_bp.route('/api/presupuestos/obtener', methods=['GET'])
@login_required
def obtener_presupuestos():
    """Obtener lista de presupuestos usando SP actualizado"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[PRESUPUESTOS] [GET] Obteniendo reporte de presupuestos")
        
        # Intentar llamar al SP
        try:
            cursor.execute('CALL sp_ReportePresupuestos()')
            presupuestos = cursor.fetchall()
            
            # Consumir resultados restantes si los hay
            while cursor.nextset():
                pass
        except Exception as sp_error:
            print(f"[PRESUPUESTOS] [WARN] Error con SP, usando query directa: {sp_error}")
            # Si el SP falla, usar query directa como fallback
            # IMPORTANTE: Usar GROUP BY para evitar duplicados por múltiples registros de aprobación
            cursor.execute('''
                SELECT 
                    pr.id_presupuesto,
                    pr.numero_presupuesto,
                    pr.estado,
                    pr.monto,
                    o.nombre as nombre_obra,
                    p.nombre as nombre_proyecto,
                    CONCAT(
                        COALESCE(per.nombres, ''),
                        ' ',
                        COALESCE(per.apellido_paterno, ''),
                        ' ',
                        COALESCE(per.apellido_materno, '')
                    ) as creado_por,
                    MAX(CONCAT(
                        COALESCE(per_aprobador.nombres, ''),
                        ' ',
                        COALESCE(per_aprobador.apellido_paterno, ''),
                        ' ',
                        COALESCE(per_aprobador.apellido_materno, '')
                    )) as aprobado_rechazado_por,
                    MAX(CASE 
                        WHEN pr.estado = 'RECHAZADO' THEN COALESCE(ra.comentario, 'Sin motivo especificado')
                        ELSE NULL
                    END) as comentario_rechazo
                FROM TblPresupuesto pr
                LEFT JOIN TblObra o ON pr.id_obra = o.id_obra
                LEFT JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
                LEFT JOIN TblUsuario u ON pr.num_documento = u.num_documento
                LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
                LEFT JOIN TblRegistroAprobacion ra ON 
                    pr.id_presupuesto = ra.id_documento_referencia 
                    AND ra.id_tipo_documento = 1
                    AND ra.estado_aprobacion = 'APROBADO'
                LEFT JOIN TblPersona per_aprobador ON ra.num_documento_aprobador = per_aprobador.num_documento
                WHERE pr.estado != 'ELIMINADO'
                GROUP BY pr.id_presupuesto
                ORDER BY pr.fecha_creacion DESC
            ''')
            presupuestos = cursor.fetchall()
        
        print(f"[PRESUPUESTOS] [OK] {len(presupuestos)} presupuestos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': presupuestos}), 200
    
    except Error as e:
        print(f"[PRESUPUESTOS] [ERROR] Error al obtener: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[PRESUPUESTOS] [ERROR] Error general: {e}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/presupuestos/buscar', methods=['POST'])
@login_required
def buscar_presupuestos():
    """Buscar presupuestos con filtros avanzados usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Obtener filtros del request
        datos = request.get_json() or {}
        
        # Parámetros opcionales (None si no se envían)
        p_numero = datos.get('numero') or None
        p_estado = datos.get('estado') or None
        p_id_proyecto = datos.get('id_proyecto') or None
        p_id_obra = datos.get('id_obra') or None
        p_fecha_desde = datos.get('fecha_desde') or None
        p_fecha_hasta = datos.get('fecha_hasta') or None
        p_nombre_creador = datos.get('nombre_creador') or None
        p_monto_desde = datos.get('monto_desde') or None
        p_monto_hasta = datos.get('monto_hasta') or None
        
        print(f"\n{'='*80}")
        print(f"[BUSCAR_PRESUPUESTOS] Iniciando búsqueda avanzada")
        print(f"{'='*80}")
        print(f"[BUSCAR_PRESUPUESTOS] Filtros recibidos:")
        print(f"  - numero: {p_numero}")
        print(f"  - estado: {p_estado}")
        print(f"  - id_proyecto: {p_id_proyecto}")
        print(f"  - id_obra: {p_id_obra}")
        print(f"  - fecha_desde: {p_fecha_desde}")
        print(f"  - fecha_hasta: {p_fecha_hasta}")
        print(f"  - nombre_creador: {p_nombre_creador}")
        print(f"  - monto_desde: {p_monto_desde}")
        print(f"  - monto_hasta: {p_monto_hasta}")
        print(f"{'='*80}")
        
        try:
            # Llamar al SP con parámetros
            cursor.execute("""
                CALL sp_BuscarPresupuestosAvanzado(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
            """, (
                p_numero,
                p_estado,
                p_id_proyecto,
                p_id_obra,
                p_fecha_desde,
                p_fecha_hasta,
                p_nombre_creador,
                p_monto_desde,
                p_monto_hasta
            ))
            
            presupuestos = cursor.fetchall()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            print(f"[BUSCAR_PRESUPUESTOS] ✓ SP ejecutado: {len(presupuestos)} registros encontrados")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({'success': True, 'data': presupuestos}), 200
        
        except Error as db_error:
            print(f"[BUSCAR_PRESUPUESTOS] [ERROR] Error en SP: {db_error}")
            print(f"[BUSCAR_PRESUPUESTOS] [ERROR] Código: {getattr(db_error, 'errno', 'N/A')}")
            print(f"[BUSCAR_PRESUPUESTOS] [ERROR] SQL State: {getattr(db_error, 'sqlstate', 'N/A')}")
            print(f"{'='*80}\n")
            
            cursor.close()
            if connection:
                connection.close()
            
            return jsonify({'success': False, 'error': f'Error en base de datos: {str(db_error)}'}), 500
    
    except Exception as e:
        print(f"[BUSCAR_PRESUPUESTOS] [ERROR] Excepción general: {e}")
        import traceback
        print(traceback.format_exc())
        print(f"{'='*80}\n")
        
        if connection:
            connection.close()
        
        return jsonify({'success': False, 'error': f'Error del servidor: {str(e)}'}), 500

@main_bp.route('/api/presupuestos/obtener/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_presupuesto(id_presupuesto):
    """Obtener datos de un presupuesto específico sin id_material"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_PRESUPUESTO] Iniciando para ID: {id_presupuesto}")
        print(f"{'='*80}")
        
        cursor.execute("""
            SELECT 
                pr.id_presupuesto,
                pr.numero_presupuesto,
                pr.id_obra,
                pr.num_documento,
                o.codigo_obra,
                o.nombre as nombre_obra,
                p.codigo_proyecto,
                p.nombre as nombre_proyecto,
                per.nombres as usuario_nombre,
                per.apellido_paterno as usuario_apellido,
                pr.monto,
                pr.estado,
                pr.observaciones,
                pr.fecha_creacion,
                pr.fecha_actualizacion,
                COUNT(DISTINCT pd.id_detalle) as total_items,
                GROUP_CONCAT(DISTINCT m.nombre SEPARATOR ', ') as materiales_utilizados
            FROM TblPresupuesto pr
            INNER JOIN TblObra o ON pr.id_obra = o.id_obra
            INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
            INNER JOIN TblPersona per ON u.num_documento = per.num_documento
            LEFT JOIN TblPresupuestoDetalle pd ON pr.id_presupuesto = pd.id_presupuesto
            LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
            WHERE pr.id_presupuesto = %s
            GROUP BY pr.id_presupuesto, pr.numero_presupuesto, pr.id_obra, pr.num_documento,
                     o.codigo_obra, o.nombre, p.codigo_proyecto, p.nombre,
                     per.nombres, per.apellido_paterno, pr.monto, pr.estado,
                     pr.observaciones, pr.fecha_creacion, pr.fecha_actualizacion
        """, (id_presupuesto,))
        
        presupuesto = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if not presupuesto:
            print(f"[OBTENER_PRESUPUESTO] [WARN] Presupuesto no encontrado")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        print(f"[OBTENER_PRESUPUESTO] [OK] Presupuesto encontrado")
        print(f"{'='*80}\n")
        
        return jsonify({'success': True, 'data': presupuesto}), 200
    
    except Error as e:
        print(f"[OBTENER_PRESUPUESTO] [ERROR] Error SQL: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuestos/visualizar/<int:id_presupuesto>', methods=['GET'])
@login_required
def visualizar_presupuesto(id_presupuesto):
    """Obtener detalles completos del presupuesto usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[VISUALIZAR_PRESUPUESTO] Llamando SP para ID: {id_presupuesto}")
        print(f"{'='*80}")
        
        # Llamar al SP directamente
        print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] Ejecutando SP directamente...")
        cursor.execute(f'CALL sp_obtener_presupuesto_detalle_completo({id_presupuesto})')
        
        # El SP retorna 3 conjuntos de resultados: PRESUPUESTO, DETALLES, RESUMEN
        presupuesto_data = None
        detalles_data = None
        resumen_data = None
        
        # PARTE 1: Obtener presupuesto
        try:
            resultado1 = cursor.fetchall()
            if resultado1:
                presupuesto_data = resultado1[0]
                print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] PARTE 1 (Presupuesto): {presupuesto_data}")
            else:
                print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] PARTE 1 vacía")
        except Exception as e:
            print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] Error PARTE 1: {e}")
        
        # PARTE 2: Obtener detalles
        try:
            if cursor.nextset():
                detalles_data = cursor.fetchall()
                print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] PARTE 2 (Detalles): {len(detalles_data or [])} registros")
            else:
                print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] No hay PARTE 2")
        except Exception as e:
            print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] Error PARTE 2: {e}")
        
        # PARTE 3: Obtener resumen
        try:
            if cursor.nextset():
                resumen_result = cursor.fetchall()
                if resumen_result:
                    resumen_data = resumen_result[0]
                    print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] PARTE 3 (Resumen): {resumen_data}")
                else:
                    print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] PARTE 3 vacía")
            else:
                print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] No hay PARTE 3")
        except Exception as e:
            print(f"[VISUALIZAR_PRESUPUESTO] [DEBUG] Error PARTE 3: {e}")
        
        cursor.close()
        connection.close()
        
        if not presupuesto_data:
            print(f"[VISUALIZAR_PRESUPUESTO] [WARN] Presupuesto no encontrado (PARTE 1 vacía)")
            print(f"[VISUALIZAR_PRESUPUESTO] [INFO] Detalles encontrados: {len(detalles_data or [])} items")
            print(f"[VISUALIZAR_PRESUPUESTO] [INFO] Resumen: {resumen_data}")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        # Estructurar respuesta
        respuesta = {
            'presupuesto': presupuesto_data,
            'detalles': detalles_data or [],
            'resumen': resumen_data or {}
        }
        
        print(f"[VISUALIZAR_PRESUPUESTO] [OK] Presupuesto obtenido con {len(detalles_data or [])} items")
        print(f"{'='*80}\n")
        
        return jsonify({'success': True, 'data': respuesta}), 200
    
    except Error as e:
        print(f"[VISUALIZAR_PRESUPUESTO] [ERROR] Error SQL: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[VISUALIZAR_PRESUPUESTO] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuestos/crear', methods=['POST'])
@login_required
def crear_presupuesto():
    """Crear un nuevo presupuesto con múltiples materiales y servicios usando SP"""
    connection = None
    print(f"\n{'='*80}")
    print(f"[CREAR_PRESUPUESTO] Iniciando...")
    print(f"{'='*80}")
    
    try:
        # Obtener num_documento del usuario autenticado
        num_documento = session.get('user_documento')
        print(f"[CREAR_PRESUPUESTO] Usuario autenticado: {num_documento}")
        
        if not num_documento:
            print(f"[CREAR_PRESUPUESTO] [ERROR] Usuario no autenticado o num_documento no disponible")
            return jsonify({'success': False, 'error': 'Usuario no autenticado'}), 401
        
        datos = request.get_json()
        if not datos:
            print(f"[CREAR_PRESUPUESTO] [ERROR] No se recibió JSON válido")
            return jsonify({'success': False, 'error': 'Datos inválidos'}), 400
        
        print(f"[CREAR_PRESUPUESTO] ✅ Datos recibidos del frontend")
        
        # Mostrar TODOS los datos recibidos
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        print(f"[CREAR_PRESUPUESTO] DATOS DEL FRONTEND:")
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        for key, value in datos.items():
            if key in ['materiales', 'servicios']:
                print(f"[CREAR_PRESUPUESTO]   {key}: {len(value)} items")
                if len(value) > 0 and isinstance(value, list):
                    print(f"[CREAR_PRESUPUESTO]     • Primer item: {value[0]}")
            else:
                print(f"[CREAR_PRESUPUESTO]   {key}: {value}")
        
        # Validar datos obligatorios
        if not datos.get('id_empresa') or not datos.get('id_obra'):
            print(f"[CREAR_PRESUPUESTO] [ERROR] Falta id_empresa o id_obra")
            return jsonify({'success': False, 'error': 'Empresa y Obra son requeridas'}), 400
        
        # Validar que al menos haya un material o servicio
        materiales = datos.get('materiales', [])
        servicios = datos.get('servicios', [])
        
        if not materiales and not servicios:
            print(f"[CREAR_PRESUPUESTO] [ERROR] Sin materiales ni servicios")
            return jsonify({'success': False, 'error': 'Debe agregar al menos un material o servicio'}), 400
        
        print(f"[CREAR_PRESUPUESTO] ✓ Validaciones básicas pasadas")
        
        connection = get_db_connection()
        if not connection:
            print(f"[CREAR_PRESUPUESTO] [ERROR] No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Preparar JSON para materiales y servicios
        import json
        materiales_json = json.dumps(materiales)
        servicios_json = json.dumps(servicios)
        
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        print(f"[CREAR_PRESUPUESTO] DATOS A ENVIAR AL SP:")
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        print(f"[CREAR_PRESUPUESTO] Parámetro 1: id_empresa = {datos.get('id_empresa')}")
        print(f"[CREAR_PRESUPUESTO] Parámetro 2: id_obra = {datos.get('id_obra')}")
        print(f"[CREAR_PRESUPUESTO] Parámetro 3: comentarios = '{datos.get('comentarios', '')}'")
        print(f"[CREAR_PRESUPUESTO] Parámetro 4: materiales_json = {len(materiales_json)} bytes, {len(materiales)} items")
        print(f"[CREAR_PRESUPUESTO] Parámetro 5: servicios_json = {len(servicios_json)} bytes, {len(servicios)} items")
        
        if len(materiales) > 0:
            print(f"[CREAR_PRESUPUESTO] Ejemplo material: {json.dumps(materiales[0], indent=2)}")
        if len(servicios) > 0:
            print(f"[CREAR_PRESUPUESTO] Ejemplo servicio: {json.dumps(servicios[0], indent=2)}")
        
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        print(f"[CREAR_PRESUPUESTO] Ejecutando SP: sp_CrearPresupuestoCompleto")
        print(f"[CREAR_PRESUPUESTO] ───────────────────────────────────────────")
        
        try:
            # Obtener valores de desglose (con valores por defecto si no existen)
            gastos_generales = float(datos.get('gastos_generales', 0))
            utilidad = float(datos.get('utilidad', 0))
            supervision_obra = float(datos.get('supervision_obra', 0))
            
            print(f"[CREAR_PRESUPUESTO] Desglose:")
            print(f"  - Gastos Generales: {gastos_generales}")
            print(f"  - Utilidad: {utilidad}")
            print(f"  - Supervisión Obra: {supervision_obra}")
            
            # Llamar SP con los parámetros (incluyendo num_documento del usuario autenticado)
            cursor.execute("""
                CALL sp_CrearPresupuestoCompleto(
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    @p_id_presupuesto_created
                )
            """, (
                int(datos.get('id_empresa')),
                int(datos.get('id_obra')),
                num_documento,
                datos.get('comentarios', ''),
                gastos_generales,
                utilidad,
                supervision_obra,
                materiales_json,
                servicios_json
            ))
            
            print(f"[CREAR_PRESUPUESTO] ✓ SP ejecutado correctamente")
            
            # Obtener el ID del presupuesto creado
            cursor.execute("SELECT @p_id_presupuesto_created as id_presupuesto")
            result = cursor.fetchone()
            
            if not result:
                print(f"[CREAR_PRESUPUESTO] [ERROR] No se obtuvo ID de presupuesto")
                raise Exception("No se pudo obtener el ID del presupuesto creado")
            
            id_presupuesto = result.get('id_presupuesto')
            
            if not id_presupuesto:
                print(f"[CREAR_PRESUPUESTO] [ERROR] ID presupuesto es NULL: {result}")
                raise Exception("El SP no retornó un ID válido")
            
            connection.commit()
            
            print(f"[CREAR_PRESUPUESTO] ✅ [OK] Presupuesto creado con ID: {id_presupuesto}")
            print(f"[CREAR_PRESUPUESTO]   - Materiales insertados: {len(materiales)}")
            print(f"[CREAR_PRESUPUESTO]   - Servicios insertados: {len(servicios)}")
            print(f"[CREAR_PRESUPUESTO]   - Usuario: {num_documento}")
            print(f"{'='*80}\n")
            
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': 'Presupuesto creado correctamente',
                'id_presupuesto': id_presupuesto,
                'data': {
                    'id_presupuesto_creado': id_presupuesto
                }
            }), 201
        
        except Error as db_error:
            print(f"[CREAR_PRESUPUESTO] [ERROR] Error en SP: {str(db_error)}")
            print(f"[CREAR_PRESUPUESTO] Código: {getattr(db_error, 'errno', 'N/A')}")
            print(f"[CREAR_PRESUPUESTO] SQL State: {getattr(db_error, 'sqlstate', 'N/A')}")
            print(f"[CREAR_PRESUPUESTO] Message: {getattr(db_error, 'msg', 'N/A')}")
            
            if connection:
                connection.rollback()
                cursor.close()
                connection.close()
            
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': f'Error en base de datos: {str(db_error)}'}), 500
    
    except Exception as e:
        print(f"[CREAR_PRESUPUESTO] ❌ [ERROR] Excepción general: {str(e)}")
        import traceback
        print(f"[CREAR_PRESUPUESTO] Traceback:")
        print(traceback.format_exc())
        print(f"{'='*80}\n")
        
        if connection:
            try:
                connection.rollback()
                connection.close()
            except:
                pass
        
        return jsonify({'success': False, 'error': f'Error del servidor: {str(e)}'}), 500

@main_bp.route('/api/presupuestos/eliminar/<int:id_presupuesto>', methods=['DELETE'])
@login_required
def eliminar_presupuesto(id_presupuesto):
    """Eliminar un presupuesto (soft delete)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        try:
            print(f"\n{'='*80}")
            print(f"[ELIMINAR_PRESUPUESTO] Iniciando para ID: {id_presupuesto}")
            print(f"{'='*80}")
            
            # Usar SP que elimina presupuesto Y sus registros de aprobación
            cursor.callproc('sp_MarcarPresupuestoEliminado', [id_presupuesto])
            
            # Obtener resultado del SP
            for result in cursor.stored_results():
                sp_result = result.fetchone()
                if sp_result and sp_result[0] == 'ERROR':
                    raise Error(sp_result[1])
            
            print(f"[ELIMINAR_PRESUPUESTO] [OK] Presupuesto y registros de aprobación eliminados")
            
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"{'='*80}\n")
            
            return jsonify({
                'success': True,
                'message': 'Presupuesto eliminado exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ELIMINAR_PRESUPUESTO] [ERROR] Error SQL: {e}")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ELIMINAR_PRESUPUESTO] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# ENDPOINTS PARA CARGAR COMBO DATA (OBRAS, USUARIOS, MATERIALES)
# ============================================================================

@main_bp.route('/api/presupuestos/combo/obras', methods=['GET'])
@login_required
def combo_obras():
    """Obtener lista de obras para dropdown"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                o.id_obra,
                o.codigo_obra,
                o.nombre,
                p.nombre as nombre_proyecto
            FROM TblObra o
            INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            WHERE o.estado != 'ELIMINADO'
            ORDER BY o.codigo_obra
        """)
        
        obras = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': obras}), 200
    
    except Error as e:
        print(f"[COMBO_OBRAS] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuestos/combo/usuarios', methods=['GET'])
@login_required
def combo_usuarios():
    """Obtener lista de usuarios para dropdown"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                u.num_documento,
                p.nombres,
                p.apellido_paterno,
                p.apellido_materno,
                u.usuario
            FROM TblUsuario u
            INNER JOIN TblPersona p ON u.num_documento = p.num_documento
            WHERE u.estado != 'INACTIVO'
            ORDER BY p.nombres
        """)
        
        usuarios = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': usuarios}), 200
    
    except Error as e:
        print(f"[COMBO_USUARIOS] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuestos/combo/categorias', methods=['GET'])
@login_required
def combo_categorias():
    """Obtener lista de categorías de materiales desde SP"""
    print(f"\n[COMBO_CATEGORIAS] Iniciando...")
    
    connection = None
    try:
        connection = get_db_connection()
        if not connection:
            print(f"[COMBO_CATEGORIAS] [ERROR] No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        print(f"[COMBO_CATEGORIAS] Llamando SP: sp_ObtenerCategoriasMaterial()")
        # Llamar al SP
        try:
            cursor.execute('CALL sp_ObtenerCategoriasMaterial()')
            categorias = cursor.fetchall()
            
            print(f"[COMBO_CATEGORIAS] [OK] {len(categorias)} categorías obtenidas")
            
            # Consumir resultsets adicionales si los hay
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            return jsonify({'success': True, 'data': categorias}), 200
        
        except Error as db_error:
            print(f"[COMBO_CATEGORIAS] [ERROR] Error en SP: {db_error}")
            print(f"[COMBO_CATEGORIAS] [ERROR] Código: {getattr(db_error, 'errno', 'N/A')}, SQL State: {getattr(db_error, 'sqlstate', 'N/A')}")
            cursor.close()
            if connection:
                connection.close()
            return jsonify({'success': False, 'error': f'Error en base de datos: {str(db_error)}'}), 500
    
    except Exception as e:
        print(f"[COMBO_CATEGORIAS] [ERROR] Excepción general: {e}")
        import traceback
        print(f"[COMBO_CATEGORIAS] [TRACEBACK]:\n{traceback.format_exc()}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error del servidor: {str(e)}'}), 500

@main_bp.route('/api/presupuestos/combo/materiales', methods=['GET'])
@login_required
def combo_materiales():
    """Obtener lista de materiales para dropdown - con filtros dinámicos"""
    print(f"\n[COMBO_MATERIALES] Iniciando...")
    
    # Obtener parámetros de búsqueda
    termino_busqueda = request.args.get('termino', '').strip()
    id_categoria = request.args.get('categoria', '0')
    
    print(f"[COMBO_MATERIALES] Parámetros recibidos:")
    print(f"  - termino_busqueda: '{termino_busqueda}' (tipo: {type(termino_busqueda).__name__}, len: {len(termino_busqueda)})")
    print(f"  - id_categoria: '{id_categoria}' (tipo: {type(id_categoria).__name__})")
    
    connection = None
    try:
        connection = get_db_connection()
        if not connection:
            print(f"[COMBO_MATERIALES] [ERROR] No se pudo conectar a BD")
            return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Convertir id_categoria a int
        try:
            id_categoria_int = int(id_categoria)
        except (ValueError, TypeError) as e:
            print(f"[COMBO_MATERIALES] [ERROR] id_categoria inválido: {e}")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': f'Parámetro categoria inválido: {id_categoria}'}), 400
        
        print(f"[COMBO_MATERIALES] Llamando SP: sp_BuscarMateriales(termino='{termino_busqueda}', categoria={id_categoria_int})")
        
        # Llamar al SP con parámetros
        try:
            cursor.execute('CALL sp_BuscarMateriales(%s, %s)', (termino_busqueda, id_categoria_int))
            materiales = cursor.fetchall()
            
            print(f"[COMBO_MATERIALES] [OK] {len(materiales)} materiales encontrados")
            
            # Consumir resultsets adicionales si los hay
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            return jsonify({'success': True, 'data': materiales}), 200
        
        except Error as db_error:
            print(f"[COMBO_MATERIALES] [ERROR] Error en ejecución de SP: {db_error}")
            print(f"[COMBO_MATERIALES] [ERROR] Código de error: {getattr(db_error, 'errno', 'N/A')}")
            print(f"[COMBO_MATERIALES] [ERROR] SQL State: {getattr(db_error, 'sqlstate', 'N/A')}")
            
            cursor.close()
            if connection:
                connection.close()
            
            return jsonify({'success': False, 'error': f'Error en base de datos: {str(db_error)}'}), 500
    
    except Exception as e:
        print(f"[COMBO_MATERIALES] [ERROR] Excepción general: {e}")
        import traceback
        print(f"[COMBO_MATERIALES] [TRACEBACK]:\n{traceback.format_exc()}")
        
        if connection:
            connection.close()
        
        return jsonify({'success': False, 'error': f'Error del servidor: {str(e)}'}), 500

# ============================================================================
# ENDPOINTS PARA TblPresupuestoDetalle (ITEMS DE MATERIALES)
# ============================================================================

@main_bp.route('/api/presupuesto-detalle/crear', methods=['POST'])
@login_required
def crear_presupuesto_detalle():
    """Crear un item de material para un presupuesto"""
    try:
        data = request.get_json()
        
        # Validar campos - id_material es OPCIONAL
        campos_requeridos = ['id_presupuesto', 'cantidad', 'precio_unitario']
        for campo in campos_requeridos:
            if not data.get(campo):
                return jsonify({'success': False, 'error': f'Campo requerido: {campo}'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor()
            
            print(f"[CREAR_PRESUPUESTO_DETALLE] Creando item para presupuesto {data['id_presupuesto']}")
            
            # Insertar item - id_material puede ser NULL
            cursor.execute("""
                INSERT INTO TblPresupuestoDetalle (
                    id_presupuesto,
                    id_material,
                    cantidad,
                    precio_unitario,
                    observaciones,
                    fecha_creacion
                ) VALUES (%s, %s, %s, %s, %s, NOW())
            """, (
                data['id_presupuesto'],
                data.get('id_material'),  # Puede ser None/null
                data['cantidad'],
                data['precio_unitario'],
                data.get('observaciones', '')
            ))
            
            detalle_id = cursor.lastrowid
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"[CREAR_PRESUPUESTO_DETALLE] [OK] Item creado con ID: {detalle_id}")
            
            return jsonify({
                'success': True,
                'message': 'Item creado exitosamente',
                'id': detalle_id
            }), 201
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[CREAR_PRESUPUESTO_DETALLE] [ERROR] {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_PRESUPUESTO_DETALLE] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuesto-detalle/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_presupuesto_detalle(id_presupuesto):
    """Obtener items de un presupuesto"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                pd.id_detalle,
                pd.id_presupuesto,
                pd.id_material,
                pd.cantidad,
                pd.precio_unitario,
                pd.subtotal,
                pd.observaciones,
                m.codigo_material,
                m.nombre as nombre_material
            FROM TblPresupuestoDetalle pd
            INNER JOIN TblMateriales m ON pd.id_material = m.id_material
            WHERE pd.id_presupuesto = %s
            ORDER BY pd.fecha_creacion
        """, (id_presupuesto,))
        
        detalles = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': detalles}), 200
    
    except Error as e:
        print(f"[OBTENER_PRESUPUESTO_DETALLE] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@main_bp.route('/api/presupuesto-detalle/eliminar/<int:id_detalle>', methods=['DELETE'])
@login_required
def eliminar_presupuesto_detalle(id_detalle):
    """Eliminar un item de presupuesto"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        try:
            print(f"[ELIMINAR_PRESUPUESTO_DETALLE] Eliminando item: {id_detalle}")
            
            cursor.execute("DELETE FROM TblPresupuestoDetalle WHERE id_detalle = %s", (id_detalle,))
            
            connection.commit()
            cursor.close()
            connection.close()
            
            print(f"[ELIMINAR_PRESUPUESTO_DETALLE] [OK] Item eliminado")
            
            return jsonify({
                'success': True,
                'message': 'Item eliminado exitosamente'
            }), 200
        
        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"[ELIMINAR_PRESUPUESTO_DETALLE] [ERROR] {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[ELIMINAR_PRESUPUESTO_DETALLE] [ERROR] {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# NUEVOS ENDPOINTS PARA CARGAR EMPRESAS, PROYECTOS Y OBRAS
# ============================================================================

@main_bp.route('/api/presupuestos/empresas/listar', methods=['GET'])
@login_required
def presupuestos_listar_empresas():
    """Obtener lista de empresas desde TblEmpresa para presupuestos"""
    print(f"\n[PRESUPUESTOS_LISTAR_EMPRESAS] Iniciando...")
    
    connection = get_db_connection()
    if not connection:
        print(f"[PRESUPUESTOS_LISTAR_EMPRESAS] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[PRESUPUESTOS_LISTAR_EMPRESAS] Llamando SP: sp_ObtenerEmpresas()")
        # Llamar al SP
        cursor.execute('CALL sp_ObtenerEmpresas()')
        
        empresas = cursor.fetchall()
        print(f"[PRESUPUESTOS_LISTAR_EMPRESAS] [OK] {len(empresas)} empresas obtenidas")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': empresas}), 200
    
    except Error as e:
        print(f"[PRESUPUESTOS_LISTAR_EMPRESAS] [ERROR] Error MySQL: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[PRESUPUESTOS_LISTAR_EMPRESAS] [ERROR] Error general: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


@main_bp.route('/api/presupuestos/proyectos/listar', methods=['GET'])
@login_required
def presupuestos_listar_proyectos():
    """Obtener lista de proyectos desde TblProyecto para presupuestos"""
    print(f"\n[PRESUPUESTOS_LISTAR_PROYECTOS] Iniciando...")
    
    connection = get_db_connection()
    if not connection:
        print(f"[PRESUPUESTOS_LISTAR_PROYECTOS] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[PRESUPUESTOS_LISTAR_PROYECTOS] Llamando SP: sp_ObtenerProyectos()")
        # Llamar al SP
        cursor.execute('CALL sp_ObtenerProyectos()')
        
        proyectos = cursor.fetchall()
        print(f"[PRESUPUESTOS_LISTAR_PROYECTOS] [OK] {len(proyectos)} proyectos obtenidos")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': proyectos}), 200
    
    except Error as e:
        print(f"[PRESUPUESTOS_LISTAR_PROYECTOS] [ERROR] Error MySQL: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[PRESUPUESTOS_LISTAR_PROYECTOS] [ERROR] Error general: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


@main_bp.route('/api/presupuestos/obras/listar', methods=['GET'])
@login_required
def presupuestos_listar_obras():
    """Obtener lista de obras filtradas por proyecto para presupuestos"""
    print(f"\n[PRESUPUESTOS_LISTAR_OBRAS] Iniciando...")
    
    id_proyecto = request.args.get('id_proyecto')
    print(f"[PRESUPUESTOS_LISTAR_OBRAS] id_proyecto: {id_proyecto}")
    
    if not id_proyecto:
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] [ERROR] id_proyecto es requerido")
        return jsonify({'success': False, 'error': 'id_proyecto es requerido'}), 400
    
    connection = get_db_connection()
    if not connection:
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión a base de datos'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] Llamando SP: sp_ObtenerObrasPorProyecto({id_proyecto})")
        # Llamar al SP con parámetro
        cursor.execute('CALL sp_ObtenerObrasPorProyecto(%s)', (int(id_proyecto),))
        
        obras = cursor.fetchall()
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] [OK] {len(obras)} obras obtenidas")
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'data': obras}), 200
    
    except Error as e:
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] [ERROR] Error MySQL: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[PRESUPUESTOS_LISTAR_OBRAS] [ERROR] Error general: {str(e)}")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500

# ============================================================================
# ENDPOINTS PARA EDITAR PRESUPUESTOS
# ============================================================================

@main_bp.route('/api/presupuestos/obtener-para-editar/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_presupuesto_para_editar(id_presupuesto):
    """Obtener encabezado y detalles de presupuesto para editar - FORMATO COMPATIBLE CON FRONTEND"""
    print(f"\n{'='*80}")
    print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] ID: {id_presupuesto}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener información básica del presupuesto
        cursor.execute("""
            SELECT 
                p.id_presupuesto,
                p.numero_presupuesto,
                p.id_empresa,
                e.nombre as nombre_empresa,
                p.id_obra,
                p.num_documento,
                COALESCE(p.monto_total, 0) as monto_total,
                COALESCE(p.monto_aprobado, 0) as monto_aprobado,
                COALESCE(p.gastos_generales, 0) as gastos_generales,
                COALESCE(p.utilidad, 0) as utilidad,
                COALESCE(p.igv, 0) as igv,
                COALESCE(p.supervision_obra, 0) as supervision_obra,
                p.estado,
                p.observaciones,
                o.id_proyecto,
                o.nombre as nombre_obra,
                pr.nombre as nombre_proyecto
            FROM TblPresupuesto p
            LEFT JOIN TblEmpresa e ON p.id_empresa = e.id_empresa
            LEFT JOIN TblObra o ON p.id_obra = o.id_obra
            LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
            WHERE p.id_presupuesto = %s
        """, (id_presupuesto,))
        
        presupuesto = cursor.fetchone()
        if not presupuesto:
            print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] Presupuesto no encontrado")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] ✓ Presupuesto encontrado")
        
        # 2. Obtener detalles (materiales y servicios)
        cursor.execute("""
            SELECT 
                pd.id_detalle,
                pd.id_presupuesto,
                pd.id_material,
                pd.tipo_item,
                pd.descripcion,
                pd.cantidad,
                pd.cantidad_original,
                pd.cantidad_consumida,
                COALESCE(pd.cantidad_saldo, 0) as cantidad_saldo,
                pd.precio_unitario,
                pd.subtotal,
                COALESCE(m.nombre, pd.descripcion) as nombre_item,
                m.codigo_material,
                COALESCE(mc.nombre, 'General') as categoria,
                COALESCE(um.nombre, 'und') as unidad_medida,
                COALESCE(um.nombre, 'und') as unidad_nombre,
                COALESCE(um.abreviatura, 'und') as unidad_abreviatura
            FROM TblPresupuestoDetalle pd
            LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
            LEFT JOIN TblCategoriaMaterial mc ON m.id_categoria = mc.id_categoria
            LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
            WHERE pd.id_presupuesto = %s
            ORDER BY pd.tipo_item ASC, pd.id_detalle ASC
        """, (id_presupuesto,))
        
        detalles_raw = cursor.fetchall()
        print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] ✓ {len(detalles_raw) if detalles_raw else 0} detalles obtenidos")
        
        # 3. Procesar detalles en arrays separados (formato que espera el frontend)
        materiales = []
        servicios = []
        
        if detalles_raw:
            for d in detalles_raw:
                if d.get('tipo_item') == 'SERVICIO':
                    servicios.append({
                        'id_temporal': d['id_detalle'],
                        'id_detalle': d['id_detalle'],
                        'descripcion': d.get('descripcion', ''),
                        'cantidad': float(d.get('cantidad', 0)),
                        'precio_unitario': float(d.get('precio_unitario', 0)),
                        'subtotal': float(d.get('subtotal', 0))
                    })
                else:  # MATERIAL
                    materiales.append({
                        'id_temporal': d['id_detalle'],
                        'id_detalle': d['id_detalle'],
                        'id_material': d.get('id_material'),
                        'nombre': d.get('nombre_item', 'Sin nombre'),
                        'codigo': d.get('codigo_material', ''),
                        'categoria': d.get('categoria', 'General'),
                        'unidad': d.get('unidad_medida', 'und'),
                        'cantidad': float(d.get('cantidad', 0)),
                        'precio_unitario': float(d.get('precio_unitario', 0)),
                        'subtotal': float(d.get('subtotal', 0))
                    })
        
        print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] ✓ {len(materiales)} materiales, {len(servicios)} servicios")
        
        cursor.close()
        connection.close()
        
        # Retornar en formato que espera el frontend
        respuesta = {
            'presupuesto': presupuesto,
            'data': {
                'detalles': materiales + servicios,
                'materiales': materiales,
                'servicios': servicios
            }
        }
        
        print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] ✓ Enviando respuesta")
        print(f"{'='*80}\n")
        
        return jsonify({'success': True, 'data': respuesta}), 200
    
    except Exception as e:
        print(f"[OBTENER_PRESUPUESTO_PARA_EDITAR] [ERROR] {str(e)}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/presupuestos/obtener-detalles/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_presupuesto_detalles(id_presupuesto):
    """Obtener detalles completos del presupuesto"""
    print(f"\n{'='*80}")
    print(f"[OBTENER_PRESUPUESTO_DETALLES] Iniciando... id_presupuesto={id_presupuesto}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[OBTENER_PRESUPUESTO_DETALLES] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # 1. Obtener información del presupuesto
        print(f"[OBTENER_PRESUPUESTO_DETALLES] Obteniendo información del presupuesto...")
        cursor.execute("""
            SELECT 
                pr.id_presupuesto,
                pr.numero_presupuesto,
                pr.id_obra,
                pr.num_documento,
                o.codigo_obra,
                o.nombre as nombre_obra,
                p.codigo_proyecto,
                p.nombre as nombre_proyecto,
                per.nombres as usuario_nombre,
                per.apellido_paterno as usuario_apellido,
                pr.monto,
                pr.estado,
                pr.observaciones,
                pr.fecha_creacion,
                pr.fecha_actualizacion
            FROM TblPresupuesto pr
            INNER JOIN TblObra o ON pr.id_obra = o.id_obra
            INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            INNER JOIN TblUsuario u ON pr.num_documento = u.num_documento
            INNER JOIN TblPersona per ON u.num_documento = per.num_documento
            WHERE pr.id_presupuesto = %s
        """, (id_presupuesto,))
        
        presupuesto = cursor.fetchone()
        if not presupuesto:
            print(f"[OBTENER_PRESUPUESTO_DETALLES] [ERROR] Presupuesto no encontrado")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        print(f"[OBTENER_PRESUPUESTO_DETALLES] ✓ Presupuesto obtenido")
        
        # 2. Obtener detalles (materiales y servicios)
        print(f"[OBTENER_PRESUPUESTO_DETALLES] Obteniendo detalles...")
        cursor.execute("""
            SELECT 
                pd.id_detalle,
                pd.id_presupuesto,
                pd.id_material,
                pd.cantidad,
                pd.cantidad_original,
                pd.cantidad_consumida,
                COALESCE(pd.cantidad_saldo, 0) as cantidad_saldo,
                pd.precio_unitario,
                pd.subtotal,
                pd.observaciones,
                pd.descripcion,
                COALESCE(pd.tipo_item, 'MATERIAL') as tipo_item,
                COALESCE(m.codigo_material, '') as codigo_material,
                COALESCE(m.nombre, pd.descripcion, 'Sin nombre') as nombre_item,
                COALESCE(um.nombre, 'und') as unidad_medida,
                COALESCE(um.nombre, 'und') as unidad_nombre,
                COALESCE(um.abreviatura, 'und') as unidad_abreviatura,
                COALESCE(mc.nombre, 'General') as categoria
            FROM TblPresupuestoDetalle pd
            LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
            LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
            LEFT JOIN TblCategoriaMaterial mc ON m.id_categoria = mc.id_categoria
            WHERE pd.id_presupuesto = %s
            ORDER BY COALESCE(pd.tipo_item, 'MATERIAL'), pd.id_detalle
        """, (id_presupuesto,))
        
        detalles = cursor.fetchall()
        print(f"[OBTENER_PRESUPUESTO_DETALLES] ✓ {len(detalles) if detalles else 0} detalles obtenidos")
        
        # 3. Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        total_materiales = sum(float(m.get('subtotal', 0) or 0) for m in materiales) if materiales else 0
        total_servicios = sum(float(s.get('subtotal', 0) or 0) for s in servicios) if servicios else 0
        total_general = total_materiales + total_servicios
        
        resumen = {
            'cantidad_items': len(detalles) if detalles else 0,
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios),
            'total_materiales': total_materiales,
            'total_servicios': total_servicios,
            'monto_total_calculado': total_general
        }
        
        print(f"[OBTENER_PRESUPUESTO_DETALLES] ✓ Resumen calculado: {resumen}")
        print(f"[OBTENER_PRESUPUESTO_DETALLES] Materiales: {len(materiales)}, Servicios: {len(servicios)}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'presupuesto': presupuesto,
                'detalles': detalles,
                'resumen': resumen
            }
        }), 200
    
    except Error as e:
        print(f"[OBTENER_PRESUPUESTO_DETALLES] [ERROR] Error MySQL: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[OBTENER_PRESUPUESTO_DETALLES] [ERROR] Error general: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


# ============================================================================
# ENDPOINT PARA ACTUALIZAR PRESUPUESTOS (EDICIÓN)
# ============================================================================

@main_bp.route('/api/presupuestos/actualizar/<int:id_presupuesto>', methods=['PUT'])
@login_required
def actualizar_presupuesto_editar(id_presupuesto):
    """Actualizar presupuesto existente usando SP"""
    import sys
    
    print(f"\n{'='*80}", flush=True)
    print(f"[ACTUALIZAR_PRESUPUESTO] Iniciando para ID: {id_presupuesto}", flush=True)
    print(f"{'='*80}", flush=True)
    sys.stdout.flush()
    
    try:
        datos = request.get_json()
        
        print(f"\n[ACTUALIZAR_PRESUPUESTO] DATOS RECIBIDOS DEL FRONTEND:", flush=True)
        print(f"{'─'*80}", flush=True)
        print(f"  id_empresa: {datos.get('id_empresa')}", flush=True)
        print(f"  id_proyecto: {datos.get('id_proyecto')}", flush=True)
        print(f"  id_obra: {datos.get('id_obra')}", flush=True)
        print(f"  comentarios: {datos.get('comentarios', '(vacío)')}", flush=True)
        print(f"  cantidad_materiales: {len(datos.get('materiales', []))}", flush=True)
        print(f"  cantidad_servicios: {len(datos.get('servicios', []))}", flush=True)
        print(f"{'─'*80}", flush=True)
        
        if datos.get('materiales'):
            print(f"\n[ACTUALIZAR_PRESUPUESTO] DETALLES DE MATERIALES:", flush=True)
            for idx, m in enumerate(datos.get('materiales', []), 1):
                print(f"  [{idx}] id_material: {m.get('id_material')} | nombre: {m.get('nombre')} | cantidad: {m.get('cantidad')} | precio: {m.get('precio_unitario')} | subtotal: {m.get('subtotal')}", flush=True)
        else:
            print(f"\n[ACTUALIZAR_PRESUPUESTO] SIN MATERIALES", flush=True)
        
        if datos.get('servicios'):
            print(f"\n[ACTUALIZAR_PRESUPUESTO] DETALLES DE SERVICIOS:", flush=True)
            for idx, s in enumerate(datos.get('servicios', []), 1):
                print(f"  [{idx}] descripcion: {s.get('descripcion')} | cantidad: {s.get('cantidad')} | precio: {s.get('precio_unitario')} | subtotal: {s.get('subtotal')}", flush=True)
        else:
            print(f"\n[ACTUALIZAR_PRESUPUESTO] SIN SERVICIOS", flush=True)
        
        sys.stdout.flush()
        
        connection = get_db_connection()
        if not connection:
            print(f"\n[ACTUALIZAR_PRESUPUESTO] [ERROR] No se pudo conectar a BD", flush=True)
            print(f"{'='*80}\n", flush=True)
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor()
        
        # Preparar JSON para materiales y servicios
        import json
        
        # Limpiar descripciones de servicios ANTES de enviar al SP
        servicios_limpios = []
        for servicio in datos.get('servicios', []):
            servicio_limpio = servicio.copy()
            # Limpiar escapes JSON de la descripción
            if 'descripcion' in servicio_limpio and servicio_limpio['descripcion']:
                desc = servicio_limpio['descripcion']
                # Remover escapes innecesarios
                desc = desc.replace('\\"', '"').replace('\\\\', '\\')
                servicio_limpio['descripcion'] = desc
            servicios_limpios.append(servicio_limpio)
        
        materiales_json = json.dumps(datos.get('materiales', []), ensure_ascii=False)
        servicios_json = json.dumps(servicios_limpios, ensure_ascii=False)
        
        print(f"\n[ACTUALIZAR_PRESUPUESTO] JSON A ENVIAR AL SP:", flush=True)
        print(f"{'─'*80}", flush=True)
        print(f"  materiales_json ({len(materiales_json)} caracteres):", flush=True)
        print(f"  CONTENIDO COMPLETO:", flush=True)
        print(f"  {materiales_json}", flush=True)
        print(f"\n  servicios_json ({len(servicios_json)} caracteres):", flush=True)
        print(f"  CONTENIDO COMPLETO:", flush=True)
        print(f"  {servicios_json}", flush=True)
        print(f"{'─'*80}", flush=True)
        
        print(f"\n[ACTUALIZAR_PRESUPUESTO] PARÁMETROS QUE SE ENVIARÁN AL SP:", flush=True)
        print(f"  1. id_presupuesto = {id_presupuesto} (tipo: {type(id_presupuesto).__name__})", flush=True)
        print(f"  2. id_empresa = {datos.get('id_empresa')} (tipo: {type(datos.get('id_empresa')).__name__})", flush=True)
        print(f"  3. id_obra = {datos.get('id_obra')} (tipo: {type(datos.get('id_obra')).__name__})", flush=True)
        print(f"  4. comentarios = '{datos.get('comentarios', '')}' (largo: {len(datos.get('comentarios', ''))} caracteres)", flush=True)
        print(f"  5. materiales_json = {len(materiales_json)} caracteres", flush=True)
        print(f"  6. servicios_json = {len(servicios_json)} caracteres", flush=True)
        
        print(f"\n[ACTUALIZAR_PRESUPUESTO] Ejecutando: CALL sp_ActualizarPresupuestoCompleto(...)", flush=True)
        sys.stdout.flush()
        sys.stdout.flush()
        
        # Obtener num_documento del usuario autenticado
        num_documento = session.get('user_documento')
        
        # Llamar SP
        print(f"\n[ACTUALIZAR_PRESUPUESTO] Ejecutando consulta SQL...", flush=True)
        cursor.execute("""
            CALL sp_ActualizarPresupuestoCompleto(
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s
            )
        """, (
            id_presupuesto,
            datos.get('id_empresa'),
            datos.get('id_obra'),
            num_documento,
            datos.get('comentarios', ''),
            float(datos.get('gastos_generales', 0)),
            float(datos.get('utilidad', 0)),
            float(datos.get('supervision_obra', 0)),
            materiales_json,
            servicios_json
        ))
        
        print(f"[ACTUALIZAR_PRESUPUESTO] Consulta ejecutada, haciendo COMMIT...", flush=True)
        connection.commit()
        print(f"[ACTUALIZAR_PRESUPUESTO] COMMIT realizado", flush=True)
        
        # PASO ADICIONAL: REINICIAR FLUJO DE APROBACIÓN USANDO SP
        print(f"\n[ACTUALIZAR_PRESUPUESTO] REINICIANDO FLUJO DE APROBACIÓN (usando SP)...", flush=True)
        
        try:
            # Llamar SP para reiniciar flujo
            cursor.callproc('sp_ReiniciarFlujoAprobacion', [1, id_presupuesto])
            
            # Obtener resultado del SP
            resultado_sp = cursor.fetchone()
            if resultado_sp:
                resultado = resultado_sp[0]
                mensaje = resultado_sp[1] if len(resultado_sp) > 1 else ""
                pasos = resultado_sp[2] if len(resultado_sp) > 2 else 0
                
                if resultado == 'OK':
                    print(f"[ACTUALIZAR_PRESUPUESTO]   ✓ {mensaje}", flush=True)
                else:
                    print(f"[ACTUALIZAR_PRESUPUESTO]   ⚠️ {mensaje}", flush=True)
            
            connection.commit()
            print(f"[ACTUALIZAR_PRESUPUESTO]   ✓ Flujo reiniciado", flush=True)
        
        except Exception as e:
            print(f"[ACTUALIZAR_PRESUPUESTO]   ⚠️ Error reiniciando flujo: {e}", flush=True)
            connection.rollback()
        
        print(f"\n[ACTUALIZAR_PRESUPUESTO] [✓ OK] Presupuesto actualizado y flujo reiniciado", flush=True)
        print(f"[ACTUALIZAR_PRESUPUESTO] RESUMEN:", flush=True)
        print(f"  ID Presupuesto: {id_presupuesto}", flush=True)
        print(f"  Empresa: {datos.get('id_empresa')}", flush=True)
        print(f"  Obra: {datos.get('id_obra')}", flush=True)
        print(f"  Materiales insertados: {len(datos.get('materiales', []))}", flush=True)
        print(f"  Servicios insertados: {len(datos.get('servicios', []))}", flush=True)
        print(f"{'='*80}\n", flush=True)
        sys.stdout.flush()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Presupuesto actualizado correctamente',
            'data': {
                'id_presupuesto': id_presupuesto,
                'id_empresa': datos.get('id_empresa'),
                'id_obra': datos.get('id_obra'),
                'materiales_count': len(datos.get('materiales', [])),
                'servicios_count': len(datos.get('servicios', []))
            }
        }), 200
    
    except Exception as e:
        print(f"\n[ACTUALIZAR_PRESUPUESTO] [✗ ERROR] {str(e)}", flush=True)
        import traceback
        print(traceback.format_exc(), flush=True)
        print(f"{'='*80}\n", flush=True)
        sys.stdout.flush()
        if connection:
            try:
                connection.rollback()
                connection.close()
            except:
                pass
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


# ============================================================================
# ENDPOINT PARA BÚSQUEDA DE PRESUPUESTOS
# ============================================================================

@main_bp.route('/api/presupuestos/buscar-por-numero', methods=['GET'])
@login_required
def buscar_presupuesto_por_numero():
    """Buscar presupuesto por número - Retorna cantidad_saldo en lugar de monto_disponible"""
    numero = request.args.get('numero', '').strip()
    
    print(f"\n{'='*80}")
    print(f"[BUSCAR_PRESUPUESTO] Buscando por número: {numero}")
    print(f"{'='*80}")
    
    if not numero:
        return jsonify({'success': False, 'error': 'Número de presupuesto requerido'}), 400
    
    connection = get_db_connection()
    if not connection:
        print(f"[BUSCAR_PRESUPUESTO] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # TASK 6: Return cantidad_saldo instead of monto_disponible
        cursor.execute("""
            SELECT 
                pr.id_presupuesto,
                pr.numero_presupuesto,
                pr.id_obra,
                pr.num_documento,
                o.codigo_obra,
                o.nombre as nombre_obra,
                p.codigo_proyecto,
                p.nombre as nombre_proyecto,
                pr.monto,
                COALESCE(pr.cantidad_consumida, 0) as cantidad_consumida,
                COALESCE(pr.cantidad_saldo, 0) as cantidad_saldo,
                pr.estado,
                pr.observaciones,
                pr.fecha_creacion
            FROM TblPresupuesto pr
            INNER JOIN TblObra o ON pr.id_obra = o.id_obra
            INNER JOIN TblProyecto p ON o.id_proyecto = p.id_proyecto
            WHERE pr.numero_presupuesto = %s
              AND pr.estado = 'APROBADO'
        """, (numero,))
        
        presupuesto = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if presupuesto:
            print(f"[BUSCAR_PRESUPUESTO] ✓ Presupuesto encontrado")
            print(f"[BUSCAR_PRESUPUESTO]   Monto: {presupuesto['monto']}")
            print(f"[BUSCAR_PRESUPUESTO]   Cantidad Consumida: {presupuesto['cantidad_consumida']}")
            print(f"[BUSCAR_PRESUPUESTO]   Cantidad Saldo: {presupuesto['cantidad_saldo']}")
            print(f"{'='*80}\n")
            return jsonify({'success': True, 'data': presupuesto}), 200
        else:
            print(f"[BUSCAR_PRESUPUESTO] ✗ Presupuesto no encontrado")
            print(f"{'='*80}\n")
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
    
    except Error as e:
        print(f"[BUSCAR_PRESUPUESTO] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[BUSCAR_PRESUPUESTO] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


# ============================================================================

@main_bp.route('/api/presupuestos/aprobar/<int:id_presupuesto>', methods=['POST'])
@login_required
def aprobar_presupuesto(id_presupuesto):
    """Aprobar presupuesto - Cambiar estado a APROBADO"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[APROBAR_PRESUPUESTO] Iniciando... id_presupuesto={id_presupuesto}")
    print(f"[APROBAR_PRESUPUESTO] Usuario: {num_documento}")
    print(f"{'='*80}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[APROBAR_PRESUPUESTO] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[APROBAR_PRESUPUESTO] Llamando SP: sp_AprobarPresupuesto_Progresivo({id_presupuesto}, {num_documento}, 1)")
        
        # Usar SP progresivo con 3 parámetros: id_presupuesto, usuario, tipo_documento
        cursor.callproc('sp_AprobarPresupuesto_Progresivo', [id_presupuesto, num_documento, 1])
        
        # Consumir el resultado
        resultado = None
        for result in cursor.stored_results():
            rows = result.fetchall()
            if rows:
                resultado = rows[0]
                break
        
        print(f"[APROBAR_PRESUPUESTO] ✅ Presupuesto aprobado")
        print(f"[APROBAR_PRESUPUESTO] Resultado: {resultado}")
        
        # CRITICAL: Commit the transaction
        print(f"[APROBAR_PRESUPUESTO] Haciendo COMMIT...")
        connection.commit()
        print(f"[APROBAR_PRESUPUESTO] COMMIT realizado ✅")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        if resultado and resultado.get('resultado') == 'OK':
            return jsonify({
                'success': True,
                'message': 'Presupuesto aprobado correctamente'
            }), 200
        else:
            return jsonify({
                'success': False,
                'error': resultado.get('mensaje', 'Error desconocido') if resultado else 'Error ejecutando SP'
            }), 400
    
    except Error as e:
        print(f"[APROBAR_PRESUPUESTO] [ERROR] Error MySQL: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[APROBAR_PRESUPUESTO] [ERROR] Error general: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500


# ============================================================================
# ENDPOINT PARA RECHAZAR PRESUPUESTO
# ============================================================================

@main_bp.route('/api/presupuestos/rechazar/<int:id_presupuesto>', methods=['POST'])
@login_required
def rechazar_presupuesto(id_presupuesto):
    """Rechazar presupuesto - Cambiar estado a RECHAZADO y registrar motivo"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[RECHAZAR_PRESUPUESTO] Iniciando... id_presupuesto={id_presupuesto}")
    print(f"[RECHAZAR_PRESUPUESTO] Usuario: {num_documento}")
    print(f"{'='*80}")
    
    # Obtener motivo del request body - OPCIONAL
    datos = request.get_json() or {}
    motivo = datos.get('motivo', '') or None
    
    print(f"[RECHAZAR_PRESUPUESTO] Motivo: {motivo or '(sin motivo)'}")
    
    connection = get_db_connection()
    if not connection:
        print(f"[RECHAZAR_PRESUPUESTO] [ERROR] No se pudo conectar a BD")
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"[RECHAZAR_PRESUPUESTO] Llamando SP: sp_RechazarPresupuesto_Progresivo({id_presupuesto}, {num_documento}, '{motivo}', 1)")
        
        # Llamar SP progresivo con 4 parámetros: id, usuario que rechaza, motivo, tipo_documento
        cursor.callproc('sp_RechazarPresupuesto_Progresivo', [id_presupuesto, num_documento, motivo, 1])
        
        # Consumir el resultado
        resultado = None
        for result in cursor.stored_results():
            rows = result.fetchall()
            if rows:
                resultado = rows[0]
                break
        
        print(f"[RECHAZAR_PRESUPUESTO] ✅ Presupuesto rechazado")
        print(f"[RECHAZAR_PRESUPUESTO] Resultado: {resultado}")
        
        # CRITICAL: Commit the transaction
        print(f"[RECHAZAR_PRESUPUESTO] Haciendo COMMIT...")
        connection.commit()
        print(f"[RECHAZAR_PRESUPUESTO] COMMIT realizado ✅")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        if resultado and resultado.get('resultado') == 'OK':
            return jsonify({
                'success': True,
                'message': 'Presupuesto rechazado correctamente'
            }), 200
        else:
            return jsonify({
                'success': False,
                'error': resultado.get('mensaje', 'Error desconocido') if resultado else 'Error ejecutando SP'
            }), 400
    
    except Error as e:
        print(f"[RECHAZAR_PRESUPUESTO] [ERROR] Error MySQL: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[RECHAZAR_PRESUPUESTO] [ERROR] Error general: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error MySQL: {str(e)}'}), 500
    except Exception as e:
        print(f"[RECHAZAR_PRESUPUESTO] [ERROR] Error general: {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': f'Error: {str(e)}'}), 500

# ============================================================================
# ENDPOINT PARA OBTENER FLUJO DE APROBACIÓN PROGRESIVO
# ============================================================================

@main_bp.route('/api/presupuestos/flujo/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_flujo_aprobacion(id_presupuesto):
    """Obtener flujo de aprobación y historial de un presupuesto"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[FLUJO_APROBACION] Obteniendo flujo para presupuesto: {id_presupuesto}")
        print(f"{'='*80}")
        
        # PASO 1: Obtener información del presupuesto
        cursor.execute("""
            SELECT 
                id_presupuesto,
                numero_presupuesto,
                estado,
                monto,
                fecha_creacion
            FROM TblPresupuesto
            WHERE id_presupuesto = %s
        """, (id_presupuesto,))
        
        presupuesto = cursor.fetchone()
        
        if not presupuesto:
            print(f"[FLUJO_APROBACION] [WARN] Presupuesto no encontrado")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        print(f"[FLUJO_APROBACION] ✓ Presupuesto encontrado: {presupuesto['numero_presupuesto']}")
        
        # PASO 2: Obtener pasos de aprobación desde TblFlujoAprobacionCargos
        cursor.execute("""
            SELECT 
                numero_paso,
                nombre_paso,
                descripcion,
                es_final,
                id_cargo
            FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = 1
            AND activo = 1
            ORDER BY numero_paso
        """)
        
        pasos = cursor.fetchall()
        print(f"[FLUJO_APROBACION] ✓ {len(pasos)} pasos encontrados")
        
        # PASO 3: Obtener historial de aprobaciones
        cursor.execute("""
            SELECT 
                numero_paso,
                id_cargo_aprobador,
                num_documento_aprobador,
                estado_aprobacion,
                fecha_aprobacion,
                comentario
            FROM TblRegistroAprobacion
            WHERE id_documento_referencia = %s
            AND id_tipo_documento = 1
            ORDER BY numero_paso
        """, (id_presupuesto,))
        
        historial = cursor.fetchall()
        print(f"[FLUJO_APROBACION] ✓ {len(historial)} registros de aprobación encontrados")
        
        # PASO 4: Obtener nombres de aprobadores del historial
        for registro in historial:
            if registro['num_documento_aprobador']:
                cursor.execute("""
                    SELECT 
                        CONCAT(
                            COALESCE(nombres, ''),
                            ' ',
                            COALESCE(apellido_paterno, ''),
                            ' ',
                            COALESCE(apellido_materno, '')
                        ) as nombre_completo
                    FROM TblPersona
                    WHERE num_documento = %s
                """, (registro['num_documento_aprobador'],))
                
                persona = cursor.fetchone()
                if persona:
                    registro['nombre_aprobador'] = persona['nombre_completo'].strip()
        
        cursor.close()
        connection.close()
        
        # Estruturar respuesta
        respuesta = {
            'presupuesto': presupuesto,
            'flujo': {
                'pasos': pasos,
                'pasos_totales': len(pasos)
            },
            'historial': historial
        }
        
        print(f"[FLUJO_APROBACION] ✅ Flujo obtenido correctamente")
        print(f"{'='*80}\n")
        
        return jsonify({'success': True, 'data': respuesta}), 200
    
    except Error as e:
        print(f"[FLUJO_APROBACION] [ERROR] Error SQL: {e}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[FLUJO_APROBACION] [ERROR] Error general: {e}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500


@main_bp.route('/api/presupuestos/obtener-flujo-aprobacion/<int:id_presupuesto>', methods=['GET'])
@login_required
def obtener_flujo_aprobacion_presupuesto(id_presupuesto):
    """
    Obtener el estado de aprobación por cargo para un presupuesto específico
    Retorna los círculos del flujo de aprobación con estado y usuario aprobador
    """
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[FLUJO_APROBACION_PRESUPUESTO] Obteniendo flujo para presupuesto {id_presupuesto}")
        print(f"{'='*80}")
        
        # Verificar que el presupuesto existe
        cursor.execute("""
            SELECT id_presupuesto, numero_presupuesto, estado
            FROM TblPresupuesto
            WHERE id_presupuesto = %s
        """, (id_presupuesto,))
        
        pres = cursor.fetchone()
        if not pres:
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Presupuesto no encontrado'}), 404
        
        # Obtener todos los pasos del flujo de Presupuesto (tipo_documento = 1)
        cursor.execute("""
            SELECT 
                fac.numero_paso,
                fac.nombre_paso,
                fac.id_cargo,
                c.nombre as cargo_nombre,
                a.nombre as area_nombre
            FROM TblFlujoAprobacionCargos fac
            LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
            LEFT JOIN TblArea a ON c.id_area = a.id_area
            WHERE fac.id_tipo_documento = 1
            AND fac.activo = 1
            AND fac.es_requerido = 1
            ORDER BY fac.numero_paso ASC
        """)
        
        pasos_config = cursor.fetchall()
        print(f"   Pasos configurados: {len(pasos_config)}")
        
        # Para cada paso, obtener el estado de aprobación
        pasos = []
        for paso_config in pasos_config:
            # Buscar registro de aprobación para este paso
            cursor.execute("""
                SELECT 
                    ra.estado_aprobacion,
                    ra.num_documento_aprobador,
                    ra.fecha_aprobacion,
                    per.nombres,
                    per.apellido_paterno,
                    ra.comentario
                FROM TblRegistroAprobacion ra
                LEFT JOIN TblUsuario u ON ra.num_documento_aprobador = u.num_documento
                LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
                WHERE ra.id_tipo_documento = 1
                AND ra.id_documento_referencia = %s
                AND ra.numero_paso = %s
                LIMIT 1
            """, (id_presupuesto, paso_config['numero_paso']))
            
            aprobacion = cursor.fetchone()
            
            # Determinar estado y usuario
            estado = 'PENDIENTE'
            usuario_aprobador = None
            fecha_aprobacion = None
            comentario = None
            
            if aprobacion:
                estado = aprobacion['estado_aprobacion']
                fecha_aprobacion = aprobacion['fecha_aprobacion']
                comentario = aprobacion.get('comentario')
                
                print(f"   [DEBUG] Paso {paso_config['numero_paso']}: estado={estado}, doc={aprobacion['num_documento_aprobador']}")
                
                if aprobacion['num_documento_aprobador'] and aprobacion['nombres']:
                    usuario_aprobador = f"{aprobacion['nombres']} {aprobacion['apellido_paterno']}".strip()
                    print(f"   [DEBUG]   → Usuario: {usuario_aprobador}")
            
            pasos.append({
                'numero_paso': paso_config['numero_paso'],
                'nombre_paso': paso_config['nombre_paso'],
                'id_cargo': paso_config['id_cargo'],
                'cargo_nombre': paso_config['cargo_nombre'],
                'area_nombre': paso_config['area_nombre'],
                'estado': estado,
                'usuario_aprobador': usuario_aprobador,
                'fecha_aprobacion': fecha_aprobacion.isoformat() if fecha_aprobacion else None,
                'comentario': comentario
            })
            
            print(f"   Paso {paso_config['numero_paso']}: {estado} ({usuario_aprobador or 'Sin aprobador'})")
        
        print(f"[FLUJO_APROBACION_PRESUPUESTO] ✅ Flujo obtenido exitosamente")
        print(f"[FLUJO_APROBACION_PRESUPUESTO] Total pasos: {len(pasos)}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'presupuesto': pres['numero_presupuesto'],
            'estado': pres['estado'],
            'pasos': pasos
        }), 200
    
    except Error as e:
        print(f"[FLUJO_APROBACION_PRESUPUESTO] ❌ ERROR SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: CREAR PROYECTO
# ============================================================================
@main_bp.route('/api/proyectos/crear', methods=['POST'])
@login_required
def crear_proyecto():
    """Crear nuevo proyecto usando SP"""
    try:
        data = request.get_json()
        
        if not data.get('nombre'):
            return jsonify({'success': False, 'error': 'El nombre es obligatorio'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"\n{'='*80}")
            print(f"[CREAR_PROYECTO] Iniciando creación de proyecto")
            print(f"[CREAR_PROYECTO] Datos: {data}")
            print(f"{'='*80}")
            
            # Solo enviar nombre y descripción (campos que existen en TblProyecto)
            cursor.execute("""
                CALL sp_CrearProyecto(
                    %s, %s,
                    @p_id_proyecto, @p_mensaje
                )
            """, (
                data['nombre'],
                data.get('descripcion')
            ))
            
            cursor.execute("SELECT @p_id_proyecto as id_proyecto, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            connection.commit()
            cursor.close()
            connection.close()
            
            if resultado and resultado['id_proyecto'] and resultado['id_proyecto'] > 0:
                print(f"[CREAR_PROYECTO] ✅ Proyecto creado con ID: {resultado['id_proyecto']}")
                print(f"{'='*80}\n")
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_proyecto': resultado['id_proyecto']
                }), 201
            else:
                print(f"[CREAR_PROYECTO] ❌ Error: {resultado.get('mensaje', 'Error desconocido')}")
                print(f"{'='*80}\n")
                return jsonify({
                    'success': False,
                    'error': resultado.get('mensaje', 'Error al crear proyecto')
                }), 400
        
        except Error as e:
            print(f"[CREAR_PROYECTO] ❌ Error SQL: {e}")
            print(f"{'='*80}\n")
            if connection:
                connection.rollback()
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_PROYECTO] ❌ Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# API: CREAR OBRA
# ============================================================================
@main_bp.route('/api/obras/crear', methods=['POST'])
@login_required
def crear_obra():
    """Crear nueva obra usando SP"""
    try:
        data = request.get_json()
        
        if not data.get('id_proyecto') or not data.get('nombre'):
            return jsonify({'success': False, 'error': 'Proyecto y nombre son obligatorios'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"\n{'='*80}")
            print(f"[CREAR_OBRA] Iniciando creación de obra")
            print(f"[CREAR_OBRA] Datos: {data}")
            print(f"{'='*80}")
            
            # Solo enviar campos básicos que existen en TblObra
            # El codigo_obra se genera automáticamente en el SP
            cursor.execute("""
                CALL sp_CrearObra(
                    %s, %s, %s,
                    @p_id_obra, @p_mensaje
                )
            """, (
                data['id_proyecto'],
                data['nombre'],
                data.get('descripcion')
            ))
            
            cursor.execute("SELECT @p_id_obra as id_obra, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            # Consumir resultados restantes
            while cursor.nextset():
                pass
            
            connection.commit()
            cursor.close()
            connection.close()
            
            if resultado and resultado['id_obra'] and resultado['id_obra'] > 0:
                print(f"[CREAR_OBRA] ✅ Obra creada con ID: {resultado['id_obra']}")
                print(f"{'='*80}\n")
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_obra': resultado['id_obra']
                }), 201
            else:
                print(f"[CREAR_OBRA] ❌ Error: {resultado.get('mensaje', 'Error desconocido')}")
                print(f"{'='*80}\n")
                return jsonify({
                    'success': False,
                    'error': resultado.get('mensaje', 'Error al crear obra')
                }), 400
        
        except Error as e:
            print(f"[CREAR_OBRA] ❌ Error SQL: {e}")
            print(f"{'='*80}\n")
            if connection:
                connection.rollback()
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CREAR_OBRA] ❌ Error general: {e}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500
