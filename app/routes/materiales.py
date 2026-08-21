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
def crear_material():
    """
    Crea un nuevo material en TblMateriales usando SP que genera cdigo automticamente
    """
    try:
        data = request.json
        print(f"[CREAR_MATERIAL] Datos recibidos: {data}")
        
        # Validar campos obligatorios
        if not data.get('nombre') or not data.get('id_unidad'):
            return jsonify({
                'success': False,
                'error': 'Faltan campos obligatorios: nombre, id_unidad'
            }), 400
        
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)
        
        # Preparar parmetros para el SP
        nombre = data['nombre']
        descripcion = data.get('descripcion')
        id_categoria = data.get('id_categoria')
        id_unidad = data['id_unidad']
        observaciones = data.get('observaciones')
        
        # Llamar al Stored Procedure usando CALL directo
        try:
            cursor.execute("""
                CALL sp_CrearMaterialConCodigoAuto(
                    %s, %s, %s, %s, %s,
                    @p_id_material_creado,
                    @p_codigo_generado,
                    @p_resultado
                )
            """, (nombre, descripcion, id_categoria, id_unidad, observaciones))
        except Error as sp_error:
            print(f"[CREAR_MATERIAL] [X] Error al ejecutar SP: {sp_error}")
            cursor.close()
            connection.close()
            return jsonify({
                'success': False,
                'error': f'Error al ejecutar procedimiento almacenado: {str(sp_error)}'
            }), 500
        
        # Obtener los parmetros OUT
        cursor.execute("SELECT @p_id_material_creado, @p_codigo_generado, @p_resultado")
        result = cursor.fetchone()
        
        p_id_material_creado = result['@p_id_material_creado']
        p_codigo_generado = result['@p_codigo_generado']
        p_resultado = result['@p_resultado']
        
        print(f"[CREAR_MATERIAL] SP retorn:")
        print(f"  - Resultado: {p_resultado}")
        print(f"  - ID creado: {p_id_material_creado}")
        print(f"  - Cdigo generado: {p_codigo_generado}")
        
        if p_resultado == 1:
            # Obtener el material creado con sus relaciones
            cursor.execute("""
                SELECT 
                    m.id_material,
                    m.codigo_material,
                    m.nombre,
                    m.descripcion,
                    m.observaciones,
                    m.estado,
                    c.nombre as categoria,
                    u.nombre as unidad_medida
                FROM TblMateriales m
                LEFT JOIN TblCategoriaMaterial c ON m.id_categoria = c.id_categoria
                LEFT JOIN TblUnidadMedida u ON m.id_unidad = u.id_unidad
                WHERE m.id_material = %s
            """, (p_id_material_creado,))
            
            material_creado = cursor.fetchone()
            
            cursor.close()
            connection.close()
            
            print(f"[CREAR_MATERIAL] [OK] Material creado exitosamente")
            
            return jsonify({
                'success': True,
                'message': 'Material creado correctamente',
                'data': material_creado
            }), 201
        else:
            cursor.close()
            connection.close()
            
            print(f"[CREAR_MATERIAL] [X] SP retorn error (resultado={p_resultado})")
            
            return jsonify({
                'success': False,
                'error': 'Error al crear el material en la base de datos'
            }), 500
        
    except Error as e:
        print(f"[CREAR_MATERIAL] [X] Error MySQL: {e}")
        return jsonify({
            'success': False,
            'error': f'Error de base de datos: {str(e)}'
        }), 500
    except Exception as e:
        print(f"[CREAR_MATERIAL] [X] Error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


# ==============================================================================
# ENDPOINT: Obtener Unidades de Medida
# ==============================================================================
@materiales_bp.route('/api/presupuestos/combo/unidades', methods=['GET'])
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
