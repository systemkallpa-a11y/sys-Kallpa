"""
Rutas para Proveedores
Módulo para gestionar proveedores del sistema usando Stored Procedures
"""

from flask import render_template, jsonify, request, session
from functools import wraps
import re
import mysql.connector
from mysql.connector import Error
from app.routes import main_bp
from app.config import DatabaseConfig

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
# DECORADOR: Login Required
# ============================================================================
def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'success': False, 'error': 'No autorizado'}), 401
        return f(*args, **kwargs)
    return decorated_function


# ============================================================================
# VALIDACIÓN: RUC (solo se exige que tenga exactamente 11 dígitos numéricos)
# ============================================================================
def validar_ruc(ruc):
    """Devuelve un mensaje de error o None si el RUC es válido."""
    if not ruc or not re.fullmatch(r'\d{11}', str(ruc)):
        return 'El RUC debe tener exactamente 11 dígitos numéricos'
    return None


# ============================================================================
# RUTA: Vista Principal de Proveedores
# ============================================================================
@main_bp.route('/proveedores')
@login_required
def proveedores():
    """Página principal de proveedores"""
    user_name = session.get('user_name', 'Usuario')
    user_role = session.get('user_role', 'Rol')
    user_empresa = session.get('user_empresa', 'Empresa')
    
    return render_template('proveedores.html',
                         user_name=user_name,
                         user_role=user_role,
                         user_empresa=user_empresa)


# ============================================================================
# API: Obtener Lista de Proveedores
# ============================================================================
@main_bp.route('/api/proveedores/obtener', methods=['GET'])
@login_required
def obtener_proveedores():
    """Obtener todos los proveedores usando SP"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Llamar al stored procedure
        cursor.callproc('sp_ListarProveedores')
        
        # Obtener resultados
        proveedores = []
        for result in cursor.stored_results():
            proveedores = result.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({'success': True, 'proveedores': proveedores}), 200
        
    except Error as e:
        print(f"[PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    except Exception as e:
        print(f"[PROVEEDORES] Error general: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Obtener Proveedor por RUC
# ============================================================================
@main_bp.route('/api/proveedores/obtener/<string:ruc>', methods=['GET'])
@login_required
def obtener_proveedor(ruc):
    """Obtener detalles de un proveedor específico por RUC usando SP"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Llamar al stored procedure
        cursor.callproc('sp_ObtenerProveedorPorRUC', [ruc])
        
        # Obtener resultados
        proveedor = None
        for result in cursor.stored_results():
            proveedor = result.fetchone()
        
        cursor.close()
        connection.close()
        
        if not proveedor:
            return jsonify({'success': False, 'error': 'Proveedor no encontrado'}), 404
        
        return jsonify({'success': True, 'proveedor': proveedor}), 200
        
    except Error as e:
        print(f"[PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Crear Proveedor
# ============================================================================
@main_bp.route('/api/proveedores/crear', methods=['POST'])
@login_required
def crear_proveedor():
    """Crear un nuevo proveedor usando SP"""
    try:
        data = request.get_json()
        user_documento = session.get('user_documento')
        
        # Validar datos requeridos
        required_fields = ['ruc', 'razon_social']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({'success': False, 'error': f'Campo requerido: {field}'}), 400
        
        # Validar RUC (solo 11 dígitos numéricos)
        error_ruc = validar_ruc(data['ruc'])
        if error_ruc:
            return jsonify({'success': False, 'error': error_ruc}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Preparar parámetros para el SP
        params = [
            data['ruc'],
            data['razon_social'],
            data.get('nombre_comercial'),
            data.get('tipo_contribuyente', 'JURIDICA'),
            data.get('telefono'),
            data.get('telefono_alternativo'),
            data.get('email'),
            data.get('email_facturacion'),
            data.get('sitio_web'),
            data.get('direccion_fiscal'),
            data.get('departamento'),
            data.get('provincia'),
            data.get('distrito'),
            data.get('ubigeo'),
            data.get('referencia'),
            data.get('contacto_nombre'),
            data.get('contacto_cargo'),
            data.get('contacto_telefono'),
            data.get('contacto_email'),
            data.get('contacto_dni'),
            data.get('banco_1'),
            data.get('cuenta_banco_1'),
            data.get('tipo_cuenta_1'),
            data.get('moneda_1', 'SOLES'),
            data.get('cci_1'),
            data.get('banco_2'),
            data.get('cuenta_banco_2'),
            data.get('tipo_cuenta_2'),
            data.get('moneda_2'),
            data.get('cci_2'),
            data.get('rubro_negocio'),
            data.get('categoria', 'VARIOS'),
            data.get('calificacion', 'SIN_CALIFICAR'),
            data.get('condicion_pago', 'CONTADO'),
            data.get('plazo_entrega'),
            data.get('descuento_comercial', 0.00),
            data.get('es_agente_retencion', False),
            data.get('es_buen_contribuyente', False),
            data.get('tiene_certificado_calidad', False),
            data.get('certificados_adjuntos'),
            data.get('estado', 'ACTIVO'),
            data.get('observaciones'),
            data.get('notas_internas'),
            user_documento
        ]
        
        # Llamar al stored procedure
        cursor.callproc('sp_CrearProveedor', params)
        
        # Obtener resultado
        resultado = None
        for result in cursor.stored_results():
            resultado = result.fetchone()
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Proveedor creado exitosamente',
            'ruc': data['ruc']
        }), 201
        
    except Error as e:
        print(f"[PROVEEDORES] Error SQL: {e}")
        if 'ya está registrado' in str(e):
            return jsonify({'success': False, 'error': 'El RUC ya está registrado'}), 400
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Actualizar Proveedor
# ============================================================================
@main_bp.route('/api/proveedores/actualizar/<string:ruc>', methods=['PUT'])
@login_required
def actualizar_proveedor(ruc):
    """Actualizar un proveedor existente por RUC usando SP"""
    try:
        data = request.get_json()
        user_documento = session.get('user_documento')
        
        # El RUC del formulario puede cambiar; la URL trae el RUC actual (llave primaria)
        ruc_nuevo = (data.get('ruc') or ruc or '').strip()
        error_ruc = validar_ruc(ruc_nuevo)
        if error_ruc:
            return jsonify({'success': False, 'error': error_ruc}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Preparar parámetros para el SP (46): actual (URL) + nuevo (formulario)
        params = [
            ruc,
            ruc_nuevo,
            data.get('razon_social'),
            data.get('nombre_comercial'),
            data.get('tipo_contribuyente', 'JURIDICA'),
            data.get('telefono'),
            data.get('telefono_alternativo'),
            data.get('email'),
            data.get('email_facturacion'),
            data.get('sitio_web'),
            data.get('direccion_fiscal'),
            data.get('departamento'),
            data.get('provincia'),
            data.get('distrito'),
            data.get('ubigeo'),
            data.get('referencia'),
            data.get('contacto_nombre'),
            data.get('contacto_cargo'),
            data.get('contacto_telefono'),
            data.get('contacto_email'),
            data.get('contacto_dni'),
            data.get('banco_1'),
            data.get('cuenta_banco_1'),
            data.get('tipo_cuenta_1'),
            data.get('moneda_1', 'SOLES'),
            data.get('cci_1'),
            data.get('banco_2'),
            data.get('cuenta_banco_2'),
            data.get('tipo_cuenta_2'),
            data.get('moneda_2'),
            data.get('cci_2'),
            data.get('rubro_negocio'),
            data.get('categoria', 'VARIOS'),
            data.get('calificacion', 'SIN_CALIFICAR'),
            data.get('condicion_pago', 'CONTADO'),
            data.get('plazo_entrega'),
            data.get('descuento_comercial', 0.00),
            data.get('es_agente_retencion', False),
            data.get('es_buen_contribuyente', False),
            data.get('tiene_certificado_calidad', False),
            data.get('certificados_adjuntos'),
            data.get('estado', 'ACTIVO'),
            data.get('motivo_inactivo'),
            data.get('observaciones'),
            data.get('notas_internas'),
            user_documento
        ]
        
        # Llamar al stored procedure
        cursor.callproc('sp_ActualizarProveedor', params)
        
        # Obtener resultado
        resultado = None
        for result in cursor.stored_results():
            resultado = result.fetchone()
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Proveedor actualizado exitosamente'
        }), 200
        
    except Error as e:
        print(f"[PROVEEDORES] Error SQL: {e}")
        if 'ya está registrado' in str(e):
            return jsonify({'success': False, 'error': 'El RUC ya está registrado'}), 400
        if 'Proveedor no encontrado' in str(e):
            return jsonify({'success': False, 'error': 'Proveedor no encontrado'}), 404
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# API: Eliminar Proveedor (Soft Delete)
# ============================================================================
@main_bp.route('/api/proveedores/eliminar/<string:ruc>', methods=['DELETE'])
@login_required
def eliminar_proveedor(ruc):
    """Eliminar (soft delete) un proveedor por RUC usando SP"""
    try:
        user_documento = session.get('user_documento')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Llamar al stored procedure
        cursor.callproc('sp_EliminarProveedor', [ruc, user_documento])
        
        # Obtener resultado
        resultado = None
        for result in cursor.stored_results():
            resultado = result.fetchone()
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Proveedor eliminado exitosamente'
        }), 200
        
    except Error as e:
        print(f"[PROVEEDORES] Error SQL: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
