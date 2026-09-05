from flask import render_template, request, jsonify, session
from . import main_bp
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig


def get_db_connection():
    """Crear conexion a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        cursor = connection.cursor()
        cursor.execute("SET NAMES utf8mb4")
        cursor.close()
        return connection
    except Error as e:
        print(f"Error de conexion: {e}")
        return None


# ============================================================================
# RUTA: VACACIONES (vista HTML)
# ============================================================================

# ============================================================================
# API: OBTENER LISTA DE VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/obtener', methods=['GET'])
def obtener_vacaciones():
    """Obtener solicitudes de vacaciones con filtros"""
    estado = request.args.get('estado', '').strip() or None
    anio = request.args.get('anio', '', type=str).strip() or None
    busqueda = request.args.get('q', '').strip() or None

    if anio:
        anio = int(anio)

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexion'}), 500

    try:
        cursor = connection.cursor(dictionary=True)
        cursor.callproc('sp_ObtenerVacaciones', (estado, anio, busqueda))

        vacaciones = []
        for result in cursor.stored_results():
            vacaciones = result.fetchall()

        # Obtener empresa para cada empleado
        if vacaciones:
            documentos = list(set(str(v['num_documento']) for v in vacaciones if v.get('num_documento')))
            if documentos:
                placeholders = ','.join(['%s'] * len(documentos))
                cursor.execute(f"""
                    SELECT u.num_documento, e.nombre AS empresa
                    FROM TblUsuario u
                    LEFT JOIN TblEmpresa e ON u.id_empresa = e.id_empresa
                    WHERE u.num_documento IN ({placeholders})
                """, documentos)
                empresas_map = {str(row['num_documento']): row['empresa'] for row in cursor.fetchall()}
                
                for v in vacaciones:
                    v['empresa'] = empresas_map.get(str(v.get('num_documento')), '-')

        cursor.close()
        connection.close()

        from datetime import date, datetime
        for v in vacaciones:
            for key in v:
                val = v[key]
                if isinstance(val, datetime):
                    v[key] = val.strftime('%Y-%m-%d')
                elif isinstance(val, date):
                    v[key] = val.strftime('%Y-%m-%d')

        return jsonify({'success': True, 'data': vacaciones}), 200

    except Error as e:
        print(f"Error al obtener vacaciones: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: CREAR SOLICITUD DE VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/crear', methods=['POST'])
def crear_vacacion():
    """Crear una nueva solicitud de vacaciones"""
    try:
        data = request.get_json()
        num_documento = session.get('user_documento')

        if not num_documento:
            return jsonify({'success': False, 'error': 'No autenticado'}), 401

        campos_requeridos = ['num_documento', 'fecha_inicio', 'fecha_fin', 'tipo_vacaciones']
        for campo in campos_requeridos:
            if not data.get(campo):
                return jsonify({'success': False, 'error': f'Campo requerido: {campo}'}), 400

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexion'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                CALL sp_CrearVacacion(
                    %s, %s, %s, %s, %s, %s,
                    @p_id_vacacion, @p_mensaje
                )
            """, (
                int(data['num_documento']),
                data['fecha_inicio'],
                data['fecha_fin'],
                data['tipo_vacaciones'],
                data.get('observaciones', ''),
                int(num_documento)
            ))

            cursor.execute("SELECT @p_id_vacacion as id_vacacion, @p_mensaje as mensaje")
            resultado = cursor.fetchone()

            while cursor.nextset():
                pass

            connection.commit()
            cursor.close()
            connection.close()

            if resultado and resultado['id_vacacion'] > 0:
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_vacacion': resultado['id_vacacion']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': resultado['mensaje'] if resultado else 'Error al crear solicitud'
                }), 400

        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al crear vacacion: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: ACTUALIZAR SOLICITUD DE VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/actualizar/<int:id_vacacion>', methods=['PUT'])
def actualizar_vacacion(id_vacacion):
    """Actualizar una solicitud de vacaciones (solo si esta PENDIENTE)"""
    try:
        data = request.get_json()

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexion'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                CALL sp_ActualizarVacacion(
                    %s, %s, %s, %s, %s,
                    @p_mensaje
                )
            """, (
                id_vacacion,
                data['fecha_inicio'],
                data['fecha_fin'],
                data['tipo_vacaciones'],
                data.get('observaciones', '')
            ))

            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()

            while cursor.nextset():
                pass

            connection.commit()
            cursor.close()
            connection.close()

            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Solicitud actualizada'
            }), 200

        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al actualizar vacacion: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: APROBAR VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/aprobar/<int:id_vacacion>', methods=['POST'])
def aprobar_vacacion(id_vacacion):
    """Aprobar una solicitud de vacaciones"""
    try:
        num_documento = session.get('user_documento')

        if not num_documento:
            return jsonify({'success': False, 'error': 'No autenticado'}), 401

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexion'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                CALL sp_AprobarVacacion(%s, %s, @p_mensaje)
            """, (id_vacacion, int(num_documento)))

            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()

            while cursor.nextset():
                pass

            connection.commit()
            cursor.close()
            connection.close()

            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Vacacion aprobada'
            }), 200

        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al aprobar vacacion: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: RECHAZAR VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/rechazar/<int:id_vacacion>', methods=['POST'])
def rechazar_vacacion(id_vacacion):
    """Rechazar una solicitud de vacaciones"""
    try:
        data = request.get_json()
        num_documento = session.get('user_documento')

        if not num_documento:
            return jsonify({'success': False, 'error': 'No autenticado'}), 401

        motivo = data.get('motivo', '')

        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexion'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                CALL sp_RechazarVacacion(%s, %s, %s, @p_mensaje)
            """, (id_vacacion, int(num_documento), motivo))

            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()

            while cursor.nextset():
                pass

            connection.commit()
            cursor.close()
            connection.close()

            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Vacacion rechazada'
            }), 200

        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al rechazar vacacion: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: ELIMINAR VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/eliminar/<int:id_vacacion>', methods=['DELETE'])
def eliminar_vacacion(id_vacacion):
    """Eliminar una solicitud de vacaciones"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexion'}), 500

        try:
            cursor = connection.cursor(dictionary=True)

            cursor.execute("""
                CALL sp_EliminarVacacion(%s, @p_mensaje)
            """, (id_vacacion,))

            cursor.execute("SELECT @p_mensaje as mensaje")
            resultado = cursor.fetchone()

            while cursor.nextset():
                pass

            connection.commit()
            cursor.close()
            connection.close()

            return jsonify({
                'success': True,
                'message': resultado['mensaje'] if resultado else 'Solicitud eliminada'
            }), 200

        except Error as e:
            connection.rollback()
            cursor.close()
            connection.close()
            print(f"Error al eliminar vacacion: {e}")
            return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        print(f"Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: OBTENER DIAS DISPONIBLES
# ============================================================================

@main_bp.route('/api/vacaciones/dias-disponibles', methods=['GET'])
def dias_disponibles():
    """Obtener saldo de vacaciones de un empleado"""
    num_documento = request.args.get('num_documento', '', type=str).strip()
    anio = request.args.get('anio', '', type=str).strip()

    if not num_documento:
        return jsonify({'success': False, 'error': 'num_documento requerido'}), 400

    if not anio:
        from datetime import datetime
        anio = datetime.now().year

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexion'}), 500

    try:
        cursor = connection.cursor(dictionary=True)

        cursor.callproc('sp_ObtenerDiasDisponibles', (int(num_documento), int(anio)))

        saldo = []
        for result in cursor.stored_results():
            saldo = result.fetchall()

        cursor.close()
        connection.close()

        if saldo:
            return jsonify({'success': True, 'data': saldo[0]}), 200
        else:
            return jsonify({'success': False, 'error': 'No se encontro saldo'}), 404

    except Error as e:
        print(f"Error al obtener dias disponibles: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: OBTENER ESTADISTICAS DE VACACIONES
# ============================================================================

@main_bp.route('/api/vacaciones/estadisticas', methods=['GET'])
def estadisticas_vacaciones():
    """Obtener estadisticas de vacaciones"""
    num_documento = request.args.get('num_documento', '', type=str).strip() or None
    anio = request.args.get('anio', '', type=str).strip()

    from datetime import datetime
    if not anio:
        anio = datetime.now().year

    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexion'}), 500

    try:
        cursor = connection.cursor(dictionary=True)

        cursor.callproc('sp_ObtenerEstadisticasVacaciones', (
            int(num_documento) if num_documento else None,
            int(anio)
        ))

        stats = []
        for result in cursor.stored_results():
            stats = result.fetchall()

        cursor.close()
        connection.close()

        if stats:
            return jsonify({'success': True, 'data': stats[0]}), 200
        else:
            return jsonify({'success': True, 'data': {
                'dias_disponibles': 0,
                'dias_usados': 0,
                'solicitudes_pendientes': 0,
                'total_solicitudes': 0
            }}), 200

    except Error as e:
        print(f"Error al obtener estadisticas: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: OBTENER EMPLEADOS (para el dropdown)
# ============================================================================

@main_bp.route('/api/vacaciones/empleados', methods=['GET'])
def obtener_empleados_vacaciones():
    """Obtener lista de empleados activos para el dropdown de vacaciones"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexion'}), 500

    try:
        cursor = connection.cursor(dictionary=True)

        cursor.execute("""
            SELECT 
                u.num_documento,
                CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', IFNULL(p.apellido_materno, '')) AS nombre_completo,
                a.nombre AS area
            FROM TblUsuario u
            INNER JOIN TblPersona p ON u.num_documento = p.num_documento
            LEFT JOIN TblCargo c ON u.id_cargo = c.id_cargo
            LEFT JOIN TblArea a ON c.id_area = a.id_area
            WHERE u.estado = 'Activo'
            ORDER BY p.nombres, p.apellido_paterno
        """)

        empleados = cursor.fetchall()
        cursor.close()
        connection.close()

        return jsonify({'success': True, 'data': empleados}), 200

    except Error as e:
        print(f"Error al obtener empleados: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
