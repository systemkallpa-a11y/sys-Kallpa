"""
Rutas para el módulo de Inventario
"""
from flask import Blueprint, render_template, request, session, jsonify
from functools import wraps
import json
import re
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


# ============================================================================
# SECCIONES POR TIPO DE INVENTARIO (todo se lee de la BD)
# ============================================================================
# Cada tipo físico tiene una tabla de sección 1 a 1 con TblInventario
# (TblInventarioRopa, TblInventarioMaterial, ...). La tabla, sus campos, el
# tipo de dato, el largo máximo y las opciones de las listas se leen de la BD:
#   sp_obtener_tabla_seccion(tipo)   -> nombre de la tabla de sección
#   sp_listar_campos_seccion(tipo)   -> campos + etiqueta + control + opciones
# Agregar una columna a una sección NO requiere tocar este archivo.
# Ver database_scripts/items_inventario/ (Partes 3 y 4).

RE_ENTERO = re.compile(r'^[0-9]+$')
RE_DECIMAL = re.compile(r'^[0-9]+(\.[0-9]+)?$')


def _texto(valor):
    """Los SPs que leen information_schema devuelven bytes en algunas columnas."""
    if isinstance(valor, (bytes, bytearray)):
        return valor.decode('utf-8')
    return valor


def _filas_sp(cursor):
    """Filas de los result sets de un SP como lista de dicts."""
    filas = []
    for resultado in cursor.stored_results():
        columnas = resultado.column_names
        for fila in resultado.fetchall():
            if isinstance(fila, dict):
                filas.append({k: _texto(v) for k, v in fila.items()})
            else:
                filas.append({c: _texto(v) for c, v in zip(columnas, fila)})
    return filas


def usuario_actual():
    """Documento del usuario logueado como entero (convención de realizado_por)."""
    try:
        return int(session.get('user_documento'))
    except (TypeError, ValueError):
        return None


def numero(valor, etiqueta, defecto=0.0):
    """Convierte un valor del formulario a float; '' o None -> defecto."""
    if valor is None or (isinstance(valor, str) and not valor.strip()):
        return defecto
    try:
        return float(valor)
    except (TypeError, ValueError):
        raise ValueError(f'{etiqueta} debe ser un número')


def entero_o_none(valor):
    if valor is None or (isinstance(valor, str) and not valor.strip()):
        return None
    return int(valor)


def tabla_seccion(conn, tipo):
    """Tabla de sección del tipo (None para SERVICIO / PARTIDA)."""
    if not tipo:
        return None
    cur = conn.cursor()
    try:
        res = cur.callproc('sp_obtener_tabla_seccion', [tipo, None])
        return _texto(res[1])
    finally:
        cur.close()


def campos_seccion(conn, tipo):
    """Campos visibles de la sección del tipo, con su estructura real."""
    cur = conn.cursor()
    try:
        cur.callproc('sp_listar_campos_seccion', [tipo])
        campos = _filas_sp(cur)
    finally:
        cur.close()
    for c in campos:
        opciones = c.get('opciones')
        c['opciones'] = opciones.strip("'").split("','") if opciones else []
        for clave in ('largo_maximo', 'decimales', 'minimo', 'orden'):
            if c.get(clave) is not None:
                c[clave] = int(c[clave])
    return campos


def validar_ficha(campos, ficha):
    """Valida los datos técnicos contra la estructura de la sección.

    Mismas reglas que sp_guardar_item: lista -> una de sus opciones;
    entero / decimal -> número no negativo; texto -> largo máximo.
    Devuelve {columna: valor normalizado}; claves desconocidas se ignoran.
    """
    if not isinstance(ficha, dict):
        raise ValueError('Las especificaciones técnicas deben enviarse como objeto')
    datos = {}
    for c in campos:
        col = c['columna']
        if col not in ficha:
            continue
        valor = ficha.get(col)
        texto = '' if valor is None else str(valor).strip()
        if texto == '':
            datos[col] = None
            continue
        if c['control'] == 'select':
            coincidencia = next((o for o in c['opciones'] if o.upper() == texto.upper()), None)
            if coincidencia is None:
                raise ValueError(f'Valor no válido en "{c["etiqueta"]}": {texto} '
                                 f'(opciones: {", ".join(c["opciones"])})')
            datos[col] = coincidencia
        elif c['control'] == 'numero':
            if c.get('decimales') == 0:
                if not RE_ENTERO.match(texto):
                    raise ValueError(f'Valor no válido en "{c["etiqueta"]}": {texto} (debe ser un número entero)')
                datos[col] = int(texto)
            else:
                if not RE_DECIMAL.match(texto):
                    raise ValueError(f'Valor no válido en "{c["etiqueta"]}": {texto} (debe ser un número)')
                datos[col] = float(texto)
        else:
            largo = c.get('largo_maximo')
            if largo and len(texto) > largo:
                raise ValueError(f'Valor no válido en "{c["etiqueta"]}": {texto} (máximo {largo} caracteres)')
            datos[col] = texto
    return datos


def guardar_ficha(conn, id_inventario, tipo, datos):
    """Actualiza la fila de sección del ítem (la crea si falta)."""
    tabla = tabla_seccion(conn, tipo)
    if not tabla:
        return
    cur = conn.cursor()
    try:
        cur.callproc('sp_asegurar_seccion_inventario', [id_inventario])
        if datos:
            # Las columnas vienen de validar_ficha (estructura real de la BD)
            asignaciones = ', '.join(f'`{col}` = %s' for col in datos)
            cur.execute(f'UPDATE `{tabla}` SET {asignaciones} WHERE id_inventario = %s',
                        list(datos.values()) + [id_inventario])
    finally:
        cur.close()


def eliminar_ficha(conn, id_inventario, tipo):
    """Elimina la fila de sección (necesario antes de cambiar de tipo)."""
    tabla = tabla_seccion(conn, tipo)
    if not tabla:
        return
    cur = conn.cursor()
    try:
        cur.execute(f'DELETE FROM `{tabla}` WHERE id_inventario = %s', (id_inventario,))
    finally:
        cur.close()


def leer_ficha(conn, id_inventario, tipo):
    """Datos de la sección del ítem como dict (sin columnas técnicas)."""
    tabla = tabla_seccion(conn, tipo)
    if not tabla:
        return {}
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(f'SELECT * FROM `{tabla}` WHERE id_inventario = %s', (id_inventario,))
        fila = cur.fetchone()
    finally:
        cur.close()
    if not fila:
        return {}
    for clave in ('id_inventario', 'tipo_inventario', 'fecha_actualizacion'):
        fila.pop(clave, None)
    return fila


def validar_clasificacion(conn, tipo, id_categoria, id_unidad):
    """Categoría activa y del mismo tipo + unidad permitida en la categoría.
    Devuelve un mensaje de error o None. Mismas reglas que sp_guardar_item."""
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute('SELECT tipo_aplicable, nombre, estado FROM TblCategoriaInventario '
                    'WHERE id_categoria = %s', (id_categoria,))
        cat = cur.fetchone()
    finally:
        cur.close()
    if not cat or cat['estado'] != 'ACTIVO':
        return 'La categoría no existe o está inactiva'
    if cat['tipo_aplicable'] != tipo:
        return f'La categoría "{cat["nombre"]}" no corresponde al tipo {tipo}'
    cur = conn.cursor()
    try:
        cur.callproc('sp_listar_unidades_categoria', [id_categoria])
        permitidas = {u['id_unidad'] for u in _filas_sp(cur)}
    finally:
        cur.close()
    if int(id_unidad) not in permitidas:
        return f'La unidad elegida no está permitida para la categoría "{cat["nombre"]}"'
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
    """Categorías de inventario.

    ?tipo=ROPA -> categorías seleccionables de ese tipo (sp_listar_categorias_tipo):
                  subcategorías agrupadas por su padre (campo `grupo`).
    sin tipo   -> todas las activas (filtro del listado de Inventario).
    """
    try:
        tipo = request.args.get('tipo', '')  # Filtro opcional por tipo

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            if tipo:
                cursor.callproc('sp_listar_categorias_tipo', [tipo])
                categorias = _filas_sp(cursor)
            else:
                cursor.execute("""
                    SELECT id_categoria, codigo, nombre, descripcion, nivel, tipo_aplicable
                    FROM TblCategoriaInventario
                    WHERE estado = 'ACTIVO'
                    ORDER BY nivel, orden ASC
                """)
                categorias = cursor.fetchall()

            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'categorias': categorias
            }), 200
        
        except Error as e:
            print(f"[CATEGORIAS] Error SQL: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        print(f"[CATEGORIAS] Error: {e}")
        return jsonify({'success': False, 'error': 'Error del servidor'}), 500


# ============================================================================
# API: TIPOS DE INVENTARIO Y CAMPOS DE SU SECCIÓN (desde la BD)
# ============================================================================

@inventario_bp.route('/api/inventario/tipos', methods=['GET'])
@login_required
def obtener_tipos():
    """Tipos de inventario = categorías de nivel 1 (sp_listar_tipos_inventario).
    ?solo_fisicos=1 (por defecto) oculta SERVICIO y PARTIDA."""
    solo_fisicos = 0 if request.args.get('solo_fisicos') == '0' else 1
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    try:
        cursor = connection.cursor()
        cursor.callproc('sp_listar_tipos_inventario', [solo_fisicos])
        tipos = _filas_sp(cursor)
        cursor.close()
        return jsonify({'success': True, 'tipos': tipos}), 200
    except Error as e:
        print(f"[TIPOS] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        connection.close()


@inventario_bp.route('/api/inventario/campos', methods=['GET'])
@login_required
def obtener_campos_seccion():
    """Campos de la sección de un tipo (?tipo=ROPA), con su estructura real:
    control (texto/numero/select/fecha), opciones, largo máximo y decimales."""
    tipo = request.args.get('tipo', '')
    if not tipo:
        return jsonify({'success': False, 'message': 'Parámetro requerido: tipo'}), 400
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    try:
        return jsonify({'success': True, 'campos': campos_seccion(connection, tipo)}), 200
    except Error as e:
        print(f"[CAMPOS] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        connection.close()


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
    """Unidades de medida.

    ?id_categoria=N -> solo las permitidas en esa categoría (propias o heredadas
                       del padre), la predeterminada primero (campo `predeterminada`).
    sin parámetro   -> todas las activas.
    """
    try:
        id_categoria = request.args.get('id_categoria', '')
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            if id_categoria:
                cursor.callproc('sp_listar_unidades_categoria', [int(id_categoria)])
                unidades = _filas_sp(cursor)
            else:
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
                'unidades': unidades
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
                'almacenes': almacenes
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
    """Crea un ítem nuevo con sp_guardar_item, en UNA transacción:
    TblInventario (código PREFIJO-001) + su sección (ficha técnica) + stock
    inicial con su movimiento en el kardex. Si algo falla no se guarda nada.

    Las validaciones (categoría del mismo tipo, unidad permitida, mínimo <=
    máximo, nombre repetido, valores de la ficha) las hace el SP y devuelve
    un mensaje claro en `message`.
    """
    data = request.get_json(silent=True) or {}

    for field in ('nombre', 'tipo_inventario', 'id_categoria', 'id_unidad'):
        if not data.get(field):
            return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400

    try:
        id_categoria = int(data['id_categoria'])
        id_unidad = int(data['id_unidad'])
        id_almacen = entero_o_none(data.get('id_almacen'))
        stock_minimo = numero(data.get('stock_minimo'), 'El stock mínimo')
        stock_maximo = numero(data.get('stock_maximo'), 'El stock máximo')
        precio_compra = numero(data.get('precio_compra'), 'El precio de compra')
        stock_inicial = numero(data.get('stock_inicial'), 'El stock inicial')
    except ValueError as e:
        return jsonify({'success': False, 'message': str(e)}), 400

    ficha = data.get('ficha') or {}
    if not isinstance(ficha, dict):
        return jsonify({'success': False, 'message': 'Las especificaciones técnicas deben enviarse como objeto'}), 400
    ficha_json = json.dumps(ficha, ensure_ascii=False) if ficha else None

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'message': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        res = cursor.callproc('sp_guardar_item', [
            data['nombre'],
            data.get('descripcion') or None,
            data['tipo_inventario'],
            id_categoria,
            id_unidad,
            stock_minimo,
            stock_maximo,
            precio_compra,
            id_almacen,
            data.get('ubicacion_fisica') or None,
            ficha_json,
            stock_inicial,
            usuario_actual(),
            0, '', 0, ''          # OUT: success, message, id_inventario, codigo
        ])
        cursor.close()
        ok, mensaje, id_inventario, codigo = res[13], res[14], res[15], res[16]

        if not ok:
            return jsonify({'success': False, 'message': mensaje}), 400

        return jsonify({
            'success': True,
            'message': mensaje,
            'id_inventario': int(id_inventario),
            'codigo': codigo,
            'stock_actual': stock_inicial
        }), 201

    except Error as e:
        print(f"[CREAR ITEM] Error SQL: {e}")
        return jsonify({'success': False, 'message': f'Error de base de datos: {e.msg}'}), 500
    finally:
        connection.close()


# ============================================================================
# API: DETALLE DEL ITEM
# ============================================================================

@inventario_bp.route('/api/inventario/detalle/<int:id_inventario>', methods=['GET'])
@login_required
def detalle_item(id_inventario):
    """Obtener detalle completo de un item con sus atributos"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            print(f"[DEBUG] Consultando item con id={id_inventario}")
            
            # Consulta directa para obtener el item
            query_item = """
                SELECT 
                    i.*,
                    c.nombre AS categoria,
                    u.nombre AS unidad,
                    u.abreviatura AS unidad_abrev,
                    a.nombre AS almacen,
                    a.codigo AS almacen_codigo
                FROM TblInventario i
                LEFT JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
                LEFT JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
                LEFT JOIN TblAlmacen a ON i.id_almacen = a.id_almacen
                WHERE i.id_inventario = %s
            """
            
            cursor.execute(query_item, (id_inventario,))
            item = cursor.fetchone()
            
            if not item:
                cursor.close()
                connection.close()
                print(f"[DEBUG] Item no encontrado con id={id_inventario}")
                return jsonify({'success': False, 'message': 'Item no encontrado'}), 404
            
            print(f"[DEBUG] Item encontrado: {item.get('nombre', 'N/A')}")
            
            # Consulta para obtener atributos
            query_atributos = """
                SELECT nombre_atributo, valor_atributo, tipo_dato
                FROM TblInventarioAtributos
                WHERE id_inventario = %s
                ORDER BY nombre_atributo
            """
            
            cursor.execute(query_atributos, (id_inventario,))
            atributos = cursor.fetchall()

            # Ficha propia del tipo (1 a 1): tabla y columnas leídas de la BD
            ficha = leer_ficha(connection, id_inventario, item.get('tipo_inventario'))
            
            print(f"[DEBUG] Atributos encontrados: {len(atributos)}")
            
            cursor.close()
            connection.close()
            
            # Estructura de respuesta que espera el frontend
            return jsonify({
                'success': True,
                'data': {
                    'item': item,
                    'ficha': ficha,
                    'atributos': atributos
                }
            }), 200
        
        except Error as e:
            print(f"[DETALLE ITEM] Error SQL: {e}")
            import traceback
            traceback.print_exc()
            return jsonify({'success': False, 'error': f'Error SQL: {str(e)}'}), 500
    
    except Exception as e:
        print(f"[DETALLE ITEM] Error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': f'Error del servidor: {str(e)}'}), 500


# ============================================================================
# API: ACTUALIZAR ITEM DE INVENTARIO
# ============================================================================

@inventario_bp.route('/api/inventario/actualizar', methods=['PUT'])
@login_required
def actualizar_item():
    """Actualiza los datos generales del ítem y su ficha técnica.

    - Valida categoría (del mismo tipo) y unidad permitida, igual que el alta.
    - Valida la ficha contra la estructura real de la sección (BD).
    - Si cambia el tipo: borra la ficha vieja, actualiza y crea la nueva fila
      de sección (sp_asegurar_seccion_inventario).
    - El stock NO se edita aquí: solo con movimientos (kardex).
    """
    data = request.get_json(silent=True) or {}

    for field in ('id_inventario', 'nombre', 'tipo_inventario', 'id_categoria', 'id_unidad'):
        if not data.get(field):
            return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400

    try:
        id_inventario = int(data['id_inventario'])
        id_categoria = int(data['id_categoria'])
        id_unidad = int(data['id_unidad'])
        id_almacen = entero_o_none(data.get('id_almacen'))
        stock_minimo = numero(data.get('stock_minimo'), 'El stock mínimo')
        stock_maximo = numero(data.get('stock_maximo'), 'El stock máximo')
        precio_compra = numero(data.get('precio_compra'), 'El precio de compra')
    except ValueError as e:
        return jsonify({'success': False, 'message': str(e)}), 400

    if stock_minimo < 0 or stock_maximo < 0 or precio_compra < 0:
        return jsonify({'success': False, 'message': 'Stock y precio no pueden ser negativos'}), 400
    if stock_maximo > 0 and stock_minimo > stock_maximo:
        return jsonify({'success': False, 'message': 'El stock mínimo no puede ser mayor que el stock máximo'}), 400

    tipo_nuevo = data['tipo_inventario']
    estado = data.get('estado') or 'ACTIVO'

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'message': 'Error de conexión'}), 500

    try:
        error = validar_clasificacion(connection, tipo_nuevo, id_categoria, id_unidad)
        if error:
            return jsonify({'success': False, 'message': error}), 400

        try:
            ficha = validar_ficha(campos_seccion(connection, tipo_nuevo), data.get('ficha') or {})
        except ValueError as e:
            return jsonify({'success': False, 'message': str(e)}), 400

        cursor = connection.cursor(dictionary=True)

        # Bloquea la fila para que el cambio de tipo sea consistente
        cursor.execute(
            "SELECT tipo_inventario FROM TblInventario WHERE id_inventario = %s FOR UPDATE",
            (id_inventario,)
        )
        fila = cursor.fetchone()
        if not fila:
            connection.rollback()
            return jsonify({'success': False, 'message': 'El item no existe'}), 404

        tipo_anterior = fila['tipo_inventario']

        # La ficha vieja se elimina antes de cambiar el tipo (si no, la FK lo impide)
        if tipo_anterior != tipo_nuevo:
            eliminar_ficha(connection, id_inventario, tipo_anterior)

        cursor.execute("""
            UPDATE TblInventario
            SET nombre = %s,
                descripcion = %s,
                tipo_inventario = %s,
                id_categoria = %s,
                id_unidad = %s,
                stock_minimo = %s,
                stock_maximo = %s,
                precio_compra = %s,
                id_almacen = %s,
                ubicacion_fisica = %s,
                estado = %s,
                fecha_actualizacion = NOW()
            WHERE id_inventario = %s
        """, [
            data['nombre'].strip(),
            (data.get('descripcion') or '').strip() or None,
            tipo_nuevo, id_categoria, id_unidad,
            stock_minimo, stock_maximo, precio_compra,
            id_almacen,
            (data.get('ubicacion_fisica') or '').strip() or None,
            estado,
            id_inventario,
        ])
        cursor.close()

        # Fila de sección del tipo actual (aunque la ficha venga vacía) + sus datos
        guardar_ficha(connection, id_inventario, tipo_nuevo, ficha)

        connection.commit()
        return jsonify({'success': True, 'message': 'Item actualizado correctamente'}), 200

    except Error as e:
        connection.rollback()
        print(f"[ACTUALIZAR ITEM] Error SQL: {e}")
        return jsonify({'success': False, 'message': f'Error de base de datos: {e.msg}'}), 500
    finally:
        connection.close()


# ============================================================================
# API: REGISTRAR MOVIMIENTO DE INVENTARIO
# ============================================================================

@inventario_bp.route('/api/inventario/movimiento', methods=['POST'])
@login_required
def registrar_movimiento():
    """Entrada / salida / ajuste manual con sp_ajustar_stock (Parte 5):
    cambia stock_actual y deja su movimiento en el kardex."""
    data = request.get_json(silent=True) or {}

    for field in ('id_inventario', 'tipo_movimiento', 'cantidad', 'motivo'):
        if data.get(field) in (None, ''):
            return jsonify({'success': False, 'message': f'Campo requerido: {field}'}), 400

    try:
        id_inventario = int(data['id_inventario'])
        cantidad = numero(data['cantidad'], 'La cantidad')
    except ValueError as e:
        return jsonify({'success': False, 'message': str(e)}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'message': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        res = cursor.callproc('sp_ajustar_stock', [
            id_inventario,
            data['tipo_movimiento'],
            cantidad,
            data['motivo'],
            data.get('documento_referencia') or '',
            usuario_actual(),          # documento del usuario (entero), nunca el email
            0, '', 0.0                 # OUT: success, message, nuevo_stock
        ])
        cursor.close()
        ok, mensaje, nuevo_stock = res[6], res[7], res[8]

        if ok:
            return jsonify({'success': True, 'message': mensaje,
                            'nuevo_stock': float(nuevo_stock or 0)}), 200
        return jsonify({'success': False, 'message': mensaje}), 400

    except Error as e:
        print(f"[MOVIMIENTO] Error SQL: {e}")
        return jsonify({'success': False, 'message': f'Error de base de datos: {e.msg}'}), 500
    finally:
        connection.close()


# ============================================================================
# API: PROVEEDORES DE UN ÍTEM DE INVENTARIO
# Orden importante: rutas estáticas primero, dinámicas después
# ============================================================================

@inventario_bp.route('/api/inventario/proveedores/selector', methods=['GET'])
@login_required
def listar_proveedores_selector():
    """Lista proveedores activos para el <select> del modal de asociar"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        cursor = connection.cursor(dictionary=True)
        cursor.callproc('sp_listar_proveedores_selector')

        proveedores = []
        for result in cursor.stored_results():
            proveedores = result.fetchall()

        cursor.close()
        connection.close()

        return jsonify({'success': True, 'proveedores': proveedores}), 200

    except Error as e:
        print(f"[INV-PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@inventario_bp.route('/api/inventario/proveedores/desasociar/<int:id_relacion>', methods=['DELETE'])
@login_required
def desasociar_proveedor_inventario(id_relacion):
    """Desasocia (soft-delete) un proveedor de un ítem usando SP con OUT"""
    try:
        user_doc = session.get('user_documento', '')

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        cursor = connection.cursor()

        args = [
            id_relacion,
            str(user_doc),
            0,   # OUT p_success
            ''   # OUT p_message
        ]

        result = cursor.callproc('sp_desasociar_proveedor_inventario', args)

        p_success = result[2]
        p_message = result[3]

        if p_success:
            connection.commit()
            cursor.close()
            connection.close()
            return jsonify({'success': True, 'message': p_message}), 200
        else:
            connection.rollback()
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': p_message}), 400

    except Error as e:
        print(f"[INV-PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@inventario_bp.route('/api/inventario/<int:id_inventario>/proveedores', methods=['GET'])
@login_required
def listar_proveedores_de_inventario(id_inventario):
    """Lista los proveedores vinculados a un ítem usando SP"""
    try:
        print(f"[INV-PROVEEDORES] GET /api/inventario/{id_inventario}/proveedores")
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        cursor = connection.cursor(dictionary=True)
        cursor.callproc('sp_listar_proveedores_de_inventario', [id_inventario])

        proveedores = []
        for result in cursor.stored_results():
            proveedores = result.fetchall()

        cursor.close()
        connection.close()

        # Serializar tipos no-JSON (Decimal, datetime, date)
        from decimal import Decimal
        import datetime
        def serializar(obj):
            if isinstance(obj, Decimal):
                return float(obj)
            if isinstance(obj, (datetime.datetime, datetime.date)):
                return obj.isoformat()
            return obj

        proveedores_serializados = [
            {k: serializar(v) for k, v in row.items()}
            for row in proveedores
        ]

        print(f"[INV-PROVEEDORES] Devolviendo {len(proveedores_serializados)} proveedores")
        return jsonify({'success': True, 'proveedores': proveedores_serializados}), 200

    except Error as e:
        print(f"[INV-PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[INV-PROVEEDORES] Error general: {e}")
        import traceback; traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@inventario_bp.route('/api/inventario/<int:id_inventario>/proveedores/asociar', methods=['POST'])
@login_required
def asociar_proveedor_inventario(id_inventario):
    """Asocia un proveedor a un ítem usando SP con parámetros OUT"""
    try:
        data = request.get_json()
        if not data or not data.get('ruc_proveedor'):
            return jsonify({'success': False, 'error': 'ruc_proveedor es requerido'}), 400

        user_doc = session.get('user_documento', '')
        print(f"[ASOCIAR] es_principal recibido: {data.get('es_principal')} tipo: {type(data.get('es_principal'))}")

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500

        cursor = connection.cursor()

        args = [
            id_inventario,
            data['ruc_proveedor'],
            data.get('codigo_proveedor') or None,
            float(data['precio_compra']) if data.get('precio_compra') else None,
            data.get('moneda', 'SOLES'),
            int(data['plazo_entrega_dias']) if data.get('plazo_entrega_dias') else None,
            1 if data.get('es_principal') in (True, 1, '1', 'true') else 0,
            data.get('observaciones') or None,
            str(user_doc),
            0,    # OUT p_success
            '',   # OUT p_message
            0     # OUT p_id_relacion
        ]

        result = cursor.callproc('sp_asociar_proveedor_inventario', args)

        p_success     = result[9]
        p_message     = result[10]
        p_id_relacion = result[11]

        if p_success:
            connection.commit()
            cursor.close()
            connection.close()
            return jsonify({
                'success': True,
                'message': p_message,
                'id_relacion': int(p_id_relacion)
            }), 200
        else:
            connection.rollback()
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': p_message}), 400

    except Error as e:
        print(f"[INV-PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
