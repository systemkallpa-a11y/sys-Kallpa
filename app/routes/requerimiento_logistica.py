"""
Rutas de Logística › Requerimiento General y del Requerimiento Administrativo.

- Requerimiento General (vista): lista TODOS los requerimientos (obras + administrativos).
  Los de obra son solo consulta; se gestionan en O.T › Requerimiento de Obras.
- Requerimiento Administrativo: se crea desde el Dashboard, descuenta stock al crearse
  y pasa por el flujo de aprobación del tipo de documento 7 (Jefe de Logística Administrativo).

Permisos:
- Vista y listado general:        TblSubMenu id_menu = 2 (Logística) / id_submenu = 16.
- Crear administrativo:           cualquier usuario autenticado (botón del Dashboard).
- Ver detalle administrativo:     acceso al submenú 16, el solicitante o un aprobador del flujo.
- Aprobar / rechazar:             el cargo del paso pendiente (validado en el SP).
- Editar / eliminar:              acceso al submenú 16 y estado PENDIENTE (validado en el SP).

Toda la lógica de datos vive en los SP de
database_scripts/requerimiento_administrativo/03_sps_requerimiento_administrativo.sql
"""

import json
from datetime import date, datetime
from decimal import Decimal
from functools import wraps

import mysql.connector
from mysql.connector import Error
from flask import render_template, request, session, flash, redirect, url_for, jsonify

from app.config import DatabaseConfig
from . import main_bp
from .main import validar_acceso_usuario

ID_MENU_LOGISTICA = 2
ID_SUBMENU_REQ_GENERAL = 16
ID_TIPO_DOC_ADMINISTRATIVO = 7
SQLSTATE_NEGOCIO = '45000'


def get_db_connection():
    """Crear conexión a la base de datos Kallpa."""
    try:
        return mysql.connector.connect(**DatabaseConfig.get_connection_params())
    except Error as e:
        print(f"[REQ_ADMIN] Error de conexión: {e}")
        return None


def login_required(f):
    """Decorador para proteger rutas que requieren autenticación."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesión', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


def _tiene_acceso_logistica():
    return validar_acceso_usuario(session.get('user_documento'),
                                  id_menu=ID_MENU_LOGISTICA, id_submenu=ID_SUBMENU_REQ_GENERAL)


def _serializar(valor):
    """Convierte fechas y decimales para JSON."""
    if isinstance(valor, (datetime, date)):
        return valor.isoformat()
    if isinstance(valor, Decimal):
        return float(valor)
    return valor


def _serializar_filas(filas):
    return [{k: _serializar(v) for k, v in fila.items()} for fila in filas]


def _leer_sp(cursor, nombre, args):
    """Ejecuta un SP de lectura y devuelve las filas del último result set."""
    cursor.callproc(nombre, args)
    filas = []
    for resultado in cursor.stored_results():
        filas = resultado.fetchall()
    return filas


def _error_sp(e, contexto):
    """Errores de negocio (SIGNAL 45000) -> 400 con su mensaje; el resto -> 500."""
    if getattr(e, 'sqlstate', None) == SQLSTATE_NEGOCIO:
        return jsonify({'success': False, 'error': e.msg}), 400
    print(f"[{contexto}] Error SQL: {e}")
    return jsonify({'success': False, 'error': 'Error en la base de datos. Intente nuevamente.'}), 500


def _num_documento():
    try:
        return int(session.get('user_documento'))
    except (TypeError, ValueError):
        return None


def _num_usuario():
    try:
        return int(session.get('user_id'))
    except (TypeError, ValueError):
        return None


# ============================================================================
# VISTA
# ============================================================================

@main_bp.route('/requerimiento-logistica')
@login_required
def requerimiento_logistica():
    """Página de Logística › Requerimiento General."""
    if not _tiene_acceso_logistica():
        flash('No tienes acceso a Requerimiento General', 'danger')
        return redirect(url_for('main.dashboard'))

    return render_template('requerimiento_logistica.html',
                           filtro_tipo_inicial=_filtro_tipo_por_cargo())


def _filtro_tipo_por_cargo():
    """
    Filtro 'Tipo' inicial de Requerimiento General según el flujo de aprobación
    en el que participa el cargo del usuario (TblFlujoAprobacionCargos):
      - solo en el flujo de Obra (tipo doc 2)           -> '2' (Obra)
      - solo en el flujo Administrativo (tipo doc 7)    -> '1' (Administrativo)
      - en ambos o en ninguno                            -> '' (Todos)
    """
    connection = get_db_connection()
    if not connection:
        return ''
    try:
        cursor = connection.cursor()
        cursor.execute("""
            SELECT DISTINCT f.id_tipo_documento
            FROM TblUsuario u
            INNER JOIN TblFlujoAprobacionCargos f ON f.id_cargo = u.id_cargo AND f.activo = 1
            WHERE u.num_documento = %s AND u.estado = 'Activo'
              AND f.id_tipo_documento IN (2, %s)
        """, (session.get('user_documento'), ID_TIPO_DOC_ADMINISTRATIVO))
        tipos = {fila[0] for fila in cursor.fetchall()}
        cursor.close()
    except Error as e:
        print(f"[REQ_GENERAL_FILTRO] Error SQL: {e}")
        return ''
    finally:
        connection.close()

    if tipos == {2}:
        return '2'
    if tipos == {ID_TIPO_DOC_ADMINISTRATIVO}:
        return '1'
    return ''


# ============================================================================
# API: LISTADO GENERAL (obras + administrativos)
# ============================================================================

@main_bp.route('/api/requerimientos/logistica/obtener', methods=['GET'])
@login_required
def obtener_requerimientos_general():
    if not _tiene_acceso_logistica():
        return jsonify({'success': False, 'error': 'No tienes acceso a Requerimiento General'}), 403

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor(dictionary=True)
        filas = _leer_sp(cursor, 'sp_ObtenerRequerimientosGeneral', [])
        for fila in filas:
            for campo in ('solicitante', 'aprobado_rechazado_por'):
                if fila.get(campo):
                    fila[campo] = ' '.join(fila[campo].split())
        cursor.close()
        return jsonify({'success': True, 'data': _serializar_filas(filas)}), 200
    except Error as e:
        return _error_sp(e, 'REQ_GENERAL_LISTAR')
    finally:
        connection.close()


# ============================================================================
# API: CREAR REQUERIMIENTO ADMINISTRATIVO (Dashboard)
# ============================================================================

@main_bp.route('/api/requerimientos/administrativo/crear', methods=['POST'])
@login_required
def crear_requerimiento_administrativo():
    data = request.get_json(silent=True) or {}

    descripcion = (data.get('descripcion') or '').strip()
    observaciones = (data.get('observaciones') or '').strip()
    items = data.get('items') or []

    if not descripcion:
        return jsonify({'success': False, 'error': 'La descripción es obligatoria'}), 400
    if not isinstance(items, list) or not items:
        return jsonify({'success': False, 'error': 'Debe agregar al menos un material'}), 400

    detalles = []
    for item in items:
        try:
            detalles.append({
                'id_inventario': int(item.get('id_inventario')),
                'cantidad': float(item.get('cantidad')),
            })
        except (TypeError, ValueError, AttributeError):
            return jsonify({'success': False, 'error': 'Hay materiales con datos inválidos'}), 400

    fecha_solicitud = None
    if data.get('fecha_solicitud'):
        try:
            fecha_solicitud = datetime.strptime(data['fecha_solicitud'], '%Y-%m-%d').date()
        except ValueError:
            return jsonify({'success': False, 'error': 'Fecha de solicitud inválida'}), 400

    num_usuario = _num_usuario()
    num_documento = _num_documento()
    if not num_usuario or not num_documento:
        return jsonify({'success': False, 'error': 'Usuario no autenticado'}), 401

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        resultado = cursor.callproc('sp_CrearRequerimientoAdministrativo', [
            num_usuario, num_documento, fecha_solicitud, descripcion, observaciones,
            json.dumps(detalles), 0, ''
        ])
        connection.commit()
        cursor.close()

        id_requerimiento, codigo = resultado[6], resultado[7]
        print(f"[REQ_ADMIN_CREAR] [OK] {codigo} (id {id_requerimiento}) por usuario {num_documento}")
        return jsonify({
            'success': True,
            'message': 'Requerimiento administrativo creado',
            'id': id_requerimiento,
            'codigo': codigo,
        }), 201
    except Error as e:
        connection.rollback()
        return _error_sp(e, 'REQ_ADMIN_CREAR')
    finally:
        connection.close()


# ============================================================================
# API: DETALLE (cabecera + items + pasos + permisos)
# ============================================================================

@main_bp.route('/api/requerimientos/administrativo/<int:id_requerimiento>', methods=['GET'])
@login_required
def obtener_requerimiento_administrativo(id_requerimiento):
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor(dictionary=True)

        cabecera = _leer_sp(cursor, 'sp_ObtenerRequerimiento', [id_requerimiento])
        if not cabecera or cabecera[0].get('id_tipo_documento') != ID_TIPO_DOC_ADMINISTRATIVO:
            cursor.close()
            return jsonify({'success': False, 'error': 'Requerimiento administrativo no encontrado'}), 404
        requerimiento = cabecera[0]

        detalles = _leer_sp(cursor, 'sp_ObtenerRequerimientoDetalles', [id_requerimiento])
        pasos = _leer_sp(cursor, 'sp_ObtenerPasosRequerimientoAdministrativo', [id_requerimiento])
        for paso in pasos:
            if paso.get('nombre_aprobador'):
                paso['nombre_aprobador'] = ' '.join(paso['nombre_aprobador'].split())

        # Cargo del usuario actual
        cursor.execute("""
            SELECT id_cargo FROM TblUsuario
            WHERE num_documento = %s AND estado = 'Activo' LIMIT 1
        """, (session.get('user_documento'),))
        fila_cargo = cursor.fetchone()
        id_cargo = fila_cargo['id_cargo'] if fila_cargo else None
        cursor.close()

        acceso_logistica = _tiene_acceso_logistica()
        es_solicitante = requerimiento.get('num_usuario') == _num_usuario()
        es_aprobador = id_cargo is not None and any(
            p.get('id_cargo_aprobador') == id_cargo for p in pasos
        )
        if not (acceso_logistica or es_solicitante or es_aprobador):
            return jsonify({'success': False, 'error': 'No tienes acceso a este requerimiento'}), 403

        pendiente = requerimiento.get('estado') == 'PENDIENTE'

        # Puede aprobar: tiene el primer paso PENDIENTE y todos los anteriores están APROBADOS
        puede_aprobar = False
        if pendiente and id_cargo is not None:
            for paso in pasos:
                if paso.get('estado') == 'PENDIENTE':
                    puede_aprobar = paso.get('id_cargo_aprobador') == id_cargo
                    break
                if paso.get('estado') != 'APROBADO':
                    break

        for paso in pasos:
            paso.pop('id_cargo_aprobador', None)

        requerimiento['usuario_completo'] = ' '.join((requerimiento.get('usuario_completo') or '').split())

        return jsonify({
            'success': True,
            'data': {
                'requerimiento': {k: _serializar(v) for k, v in requerimiento.items()},
                'detalles': _serializar_filas(detalles),
                'pasos': _serializar_filas(pasos),
                'permisos': {
                    'puede_aprobar': puede_aprobar,
                    'puede_editar': pendiente and acceso_logistica,
                    'puede_eliminar': pendiente and acceso_logistica,
                },
            }
        }), 200
    except Error as e:
        return _error_sp(e, 'REQ_ADMIN_DETALLE')
    finally:
        connection.close()


# ============================================================================
# API: APROBAR / RECHAZAR
# ============================================================================

@main_bp.route('/api/requerimientos/administrativo/<int:id_requerimiento>/aprobar', methods=['PUT'])
@login_required
def aprobar_requerimiento_administrativo(id_requerimiento):
    data = request.get_json(silent=True) or {}
    comentario = (data.get('comentario') or '').strip()

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        resultado = cursor.callproc('sp_AprobarRequerimientoAdministrativo', [
            id_requerimiento, _num_documento(), comentario, 0, ''
        ])
        connection.commit()
        cursor.close()
        return jsonify({
            'success': True,
            'aprobacion_completa': bool(resultado[3]),
            'message': resultado[4],
        }), 200
    except Error as e:
        connection.rollback()
        return _error_sp(e, 'REQ_ADMIN_APROBAR')
    finally:
        connection.close()


@main_bp.route('/api/requerimientos/administrativo/<int:id_requerimiento>/rechazar', methods=['PUT'])
@login_required
def rechazar_requerimiento_administrativo(id_requerimiento):
    data = request.get_json(silent=True) or {}
    comentario = (data.get('comentario') or '').strip()
    if not comentario:
        return jsonify({'success': False, 'error': 'Debe indicar el motivo del rechazo'}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        resultado = cursor.callproc('sp_RechazarRequerimientoAdministrativo', [
            id_requerimiento, _num_documento(), comentario, ''
        ])
        connection.commit()
        cursor.close()
        return jsonify({'success': True, 'message': resultado[3]}), 200
    except Error as e:
        connection.rollback()
        return _error_sp(e, 'REQ_ADMIN_RECHAZAR')
    finally:
        connection.close()


# ============================================================================
# API: EDITAR / ELIMINAR (solo PENDIENTE, acceso a Logística)
# ============================================================================

@main_bp.route('/api/requerimientos/administrativo/<int:id_requerimiento>', methods=['PUT'])
@login_required
def actualizar_requerimiento_administrativo(id_requerimiento):
    if not _tiene_acceso_logistica():
        return jsonify({'success': False, 'error': 'No tienes acceso a Requerimiento General'}), 403

    data = request.get_json(silent=True) or {}
    descripcion = (data.get('descripcion') or '').strip()
    observaciones = (data.get('observaciones') or '').strip()
    if not descripcion:
        return jsonify({'success': False, 'error': 'La descripción es obligatoria'}), 400

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        resultado = cursor.callproc('sp_ActualizarRequerimientoAdministrativo', [
            id_requerimiento, descripcion, observaciones, ''
        ])
        connection.commit()
        cursor.close()
        return jsonify({'success': True, 'message': resultado[3]}), 200
    except Error as e:
        connection.rollback()
        return _error_sp(e, 'REQ_ADMIN_EDITAR')
    finally:
        connection.close()


@main_bp.route('/api/requerimientos/administrativo/<int:id_requerimiento>', methods=['DELETE'])
@login_required
def eliminar_requerimiento_administrativo(id_requerimiento):
    if not _tiene_acceso_logistica():
        return jsonify({'success': False, 'error': 'No tienes acceso a Requerimiento General'}), 403

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500

    try:
        cursor = connection.cursor()
        resultado = cursor.callproc('sp_EliminarRequerimientoAdministrativo', [
            id_requerimiento, _num_documento(), '', ''
        ])
        connection.commit()
        cursor.close()
        return jsonify({'success': True, 'codigo': resultado[2], 'message': resultado[3]}), 200
    except Error as e:
        connection.rollback()
        return _error_sp(e, 'REQ_ADMIN_ELIMINAR')
    finally:
        connection.close()
