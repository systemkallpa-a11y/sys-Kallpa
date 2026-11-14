# ==============================================================================
# RUTAS: MATERIALES
# ==============================================================================
# Descripcin: Endpoints para gestionar materiales
# Fecha: 31 Julio 2026
# ==============================================================================

from flask import Blueprint, request, jsonify
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig
from app.routes.inventario import login_required, usuario_actual

materiales_bp = Blueprint('materiales', __name__)

# ==============================================================================
# Funcin auxiliar: Obtener conexin a la base de datos
# ==============================================================================
def get_db_connection():
    """Crear conexin a MySQL usando DatabaseConfig"""
    params = DatabaseConfig.get_connection_params()
    return mysql.connector.connect(**params)

# ==============================================================================
# ENDPOINT: Crear Nuevo Material
# ==============================================================================
@materiales_bp.route('/api/materiales/crear', methods=['POST'])
@login_required
def crear_material():
    """
    Alta rápida desde el modal "Nuevo material" de Presupuesto.

    Usa el MISMO alta que Inventario (sp_guardar_item): el ítem queda en
    TblInventario y en su sección, con código PREFIJO-001.
    - El tipo sale de la categoría elegida (antes se forzaba MATERIAL).
    - Sin categoría -> "Otros Materiales" (MAT-OTROS).
    - Las observaciones se agregan a la descripción (antes se perdían).
    Devuelve id_inventario como campo principal.
    """
    connection = None
    try:
        data = request.get_json(silent=True) or {}

        # Validar campos obligatorios
        if not data.get('nombre') or not data.get('id_unidad'):
            return jsonify({
                'success': False,
                'error': 'Faltan campos obligatorios: nombre, id_unidad'
            }), 400

        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        # Categoría y tipo (el tipo es el de la categoría)
        id_categoria = data.get('id_categoria')
        if id_categoria:
            cursor.execute("SELECT id_categoria, tipo_aplicable FROM TblCategoriaInventario "
                           "WHERE id_categoria = %s AND estado = 'ACTIVO'", (int(id_categoria),))
        else:
            cursor.execute("SELECT id_categoria, tipo_aplicable FROM TblCategoriaInventario "
                           "WHERE codigo = 'MAT-OTROS'")
        categoria = cursor.fetchone()
        if not categoria:
            return jsonify({'success': False, 'error': 'La categoría no existe o está inactiva'}), 400

        descripcion = (data.get('descripcion') or '').strip()
        observaciones = (data.get('observaciones') or '').strip()
        if observaciones:
            descripcion = f"{descripcion}\nObservaciones: {observaciones}" if descripcion else f"Observaciones: {observaciones}"

        sp_cursor = connection.cursor()
        res = sp_cursor.callproc('sp_guardar_item', [
            data['nombre'], descripcion or None, categoria['tipo_aplicable'],
            categoria['id_categoria'], int(data['id_unidad']),
            0, 0, 0,            # stock mínimo, máximo, precio (se completan en Inventario)
            None, None,         # almacén, ubicación
            None,               # ficha técnica (se completa en Inventario)
            0,                  # stock inicial
            usuario_actual(),
            0, '', 0, ''        # OUT: success, message, id_inventario, codigo
        ])
        sp_cursor.close()
        p_resultado, p_mensaje, p_id_inventario_creado = res[13], res[14], res[15]

        print(f"[CREAR_MATERIAL] sp_guardar_item -> {p_resultado} {p_mensaje}")

        if not p_resultado:
            return jsonify({'success': False, 'error': p_mensaje}), 400

        # Material creado con sus relaciones (lo usa el presupuesto para agregarlo)
        cursor.execute("""
            SELECT
                i.id_inventario,
                i.codigo,
                i.nombre,
                i.descripcion,
                i.tipo_inventario,
                i.estado,
                c.nombre as categoria,
                u.nombre as unidad_medida
            FROM TblInventario i
            LEFT JOIN TblCategoriaInventario c ON i.id_categoria = c.id_categoria
            LEFT JOIN TblUnidadMedida u ON i.id_unidad = u.id_unidad
            WHERE i.id_inventario = %s
        """, (p_id_inventario_creado,))
        material_creado = cursor.fetchone()
        cursor.close()

        return jsonify({
            'success': True,
            'message': p_mensaje,
            'data': material_creado
        }), 201

    except Error as e:
        print(f"[CREAR_MATERIAL] [X] Error MySQL: {e}")
        return jsonify({
            'success': False,
            'error': f'Error de base de datos: {e.msg}'
        }), 500
    except Exception as e:
        print(f"[CREAR_MATERIAL] [X] Error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500
    finally:
        if connection:
            connection.close()


# ==============================================================================
# ENDPOINT: Obtener Unidades de Medida
# ==============================================================================
@materiales_bp.route('/api/presupuestos/combo/unidades', methods=['GET'])
@login_required
def obtener_unidades_medida():
    """
    Obtiene la lista de unidades de medida disponibles
    """
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute("""
            SELECT 
                id_unidad,
                nombre,
                abreviatura
            FROM TblUnidadMedida
            WHERE estado = 'ACTIVO'
            ORDER BY nombre ASC
        """)
        
        unidades = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': unidades
        }), 200
        
    except Exception as e:
        print(f"[OBTENER_UNIDADES] [X] Error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


# ==============================================================================
# ENDPOINT: Buscar Materiales (Autocompletado)
# ==============================================================================
@materiales_bp.route('/api/materiales/buscar', methods=['GET'])
@login_required
def buscar_materiales():
    """
    Busca materiales activos por nombre o código para autocompletado
    """
    try:
        busqueda = request.args.get('q', '')
        
        if len(busqueda) < 2:
            return jsonify({
                'success': True,
                'data': []
            }), 200
        
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        print(f"[BUSCAR_MATERIALES] Buscando: '{busqueda}'")
        
        # Llamar al SP de búsqueda
        cursor.callproc('sp_BuscarMaterialesAutocompletado', (busqueda,))
        
        # Obtener resultados
        materiales = []
        for result in cursor.stored_results():
            materiales = result.fetchall()
        
        print(f"[BUSCAR_MATERIALES] [OK] {len(materiales)} materiales encontrados")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': materiales
        }), 200
        
    except Exception as e:
        print(f"[BUSCAR_MATERIALES] [X] Error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

