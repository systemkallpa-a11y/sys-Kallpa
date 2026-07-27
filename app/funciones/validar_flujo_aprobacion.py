"""
MÓDULO: Validación de Flujo de Aprobación Completo
FECHA: 17 de Julio de 2026
PROPÓSITO: Funciones para validar si un flujo de aprobación está completo
"""

from app.config import DatabaseConfigKallpa
import mysql.connector
from mysql.connector import Error


def get_db_connection():
    """Obtener conexión a BD"""
    try:
        params = DatabaseConfigKallpa.get_connection_params()
        return mysql.connector.connect(**params)
    except Error as e:
        print(f"[DB_ERROR] {e}")
        return None


def obtener_total_pasos_requeridos(id_tipo_documento):
    """
    Obtiene el total de pasos requeridos para un tipo de documento
    desde TblFlujoAprobacionCargos
    
    Args:
        id_tipo_documento: ID del tipo de documento (1=Presupuesto, 2=Requerimiento, etc)
    
    Returns:
        int: Total de pasos requeridos (0 si no hay flujo)
    """
    connection = get_db_connection()
    if not connection:
        return 0
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT COUNT(DISTINCT numero_paso) as total_pasos
            FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = %s AND activo = 1
        ''', (id_tipo_documento,))
        
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        
        return result['total_pasos'] if result else 0
    
    except Error as e:
        print(f"[OBTENER_TOTAL_PASOS] Error: {e}")
        return 0


def obtener_pasos_completados(id_tipo_documento, id_documento_referencia):
    """
    Obtiene los pasos completados (APROBADOS) de un documento
    
    Args:
        id_tipo_documento: ID del tipo de documento
        id_documento_referencia: ID del documento (presupuesto, requerimiento, etc)
    
    Returns:
        dict: {
            'pasos_aprobados': int,
            'pasos_rechazados': int,
            'estado': 'PENDIENTE', 'APROBADO', 'RECHAZADO'
        }
    """
    connection = get_db_connection()
    if not connection:
        return {'pasos_aprobados': 0, 'pasos_rechazados': 0, 'estado': 'ERROR'}
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT 
                SUM(CASE WHEN estado_aprobacion = 'APROBADO' THEN 1 ELSE 0 END) as pasos_aprobados,
                SUM(CASE WHEN estado_aprobacion = 'RECHAZADO' THEN 1 ELSE 0 END) as pasos_rechazados
            FROM TblRegistroAprobacion
            WHERE id_tipo_documento = %s
              AND id_documento_referencia = %s
        ''', (id_tipo_documento, id_documento_referencia))
        
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        
        pasos_aprobados = result['pasos_aprobados'] or 0
        pasos_rechazados = result['pasos_rechazados'] or 0
        
        return {
            'pasos_aprobados': pasos_aprobados,
            'pasos_rechazados': pasos_rechazados,
            'estado': 'RECHAZADO' if pasos_rechazados > 0 else (
                'APROBADO' if pasos_aprobados > 0 else 'PENDIENTE'
            )
        }
    
    except Error as e:
        print(f"[OBTENER_PASOS_COMPLETADOS] Error: {e}")
        return {'pasos_aprobados': 0, 'pasos_rechazados': 0, 'estado': 'ERROR'}


def validar_flujo_completo(id_tipo_documento, id_documento_referencia):
    """
    Valida si el flujo de aprobación está COMPLETO
    
    Args:
        id_tipo_documento: ID del tipo de documento
        id_documento_referencia: ID del documento
    
    Returns:
        dict: {
            'flujo_completo': bool (True = todos aprobados),
            'estado': 'PENDIENTE', 'APROBADO', 'RECHAZADO',
            'total_pasos': int,
            'pasos_aprobados': int,
            'pasos_rechazados': int
        }
    """
    total_pasos = obtener_total_pasos_requeridos(id_tipo_documento)
    pasos_info = obtener_pasos_completados(id_tipo_documento, id_documento_referencia)
    
    flujo_completo = (total_pasos > 0 and 
                      pasos_info['pasos_aprobados'] == total_pasos and 
                      pasos_info['pasos_rechazados'] == 0)
    
    return {
        'flujo_completo': flujo_completo,
        'estado': 'APROBADO' if flujo_completo else pasos_info['estado'],
        'total_pasos': total_pasos,
        'pasos_aprobados': pasos_info['pasos_aprobados'],
        'pasos_rechazados': pasos_info['pasos_rechazados']
    }


def puede_notificar_siguiente_paso(id_tipo_documento, numero_paso_actual):
    """
    Verifica si puede notificar al siguiente paso
    REGLA: Solo si el paso anterior está APROBADO (o es el primer paso)
    
    Args:
        id_tipo_documento: ID del tipo de documento
        numero_paso_actual: Número del paso actual
    
    Returns:
        bool: True si puede notificar
    """
    # Si es el primer paso, siempre puede notificar
    if numero_paso_actual == 1:
        return True
    
    # Para otros pasos, no notificar (la lógica está en registrar_aprobacion)
    # Esta función es de validación
    return True


def obtener_siguiente_paso(id_tipo_documento, numero_paso_actual):
    """
    Obtiene información del siguiente paso (si existe)
    desde TblFlujoAprobacionCargos
    
    Args:
        id_tipo_documento: ID del tipo de documento
        numero_paso_actual: Número del paso actual
    
    Returns:
        dict: Información del siguiente paso, None si no existe
    """
    connection = get_db_connection()
    if not connection:
        return None
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT DISTINCT
                numero_paso,
                nombre_paso,
                descripcion,
                es_requerido,
                GROUP_CONCAT(DISTINCT id_cargo ORDER BY id_cargo) as cargos_str
            FROM TblFlujoAprobacionCargos
            WHERE id_tipo_documento = %s
              AND numero_paso = %s
              AND activo = 1
            GROUP BY numero_paso
            LIMIT 1
        ''', (id_tipo_documento, numero_paso_actual + 1))
        
        result = cursor.fetchone()
        cursor.close()
        connection.close()
        
        if result:
            # Convertir string de cargos a lista
            cargos = [int(x) for x in result['cargos_str'].split(',')] if result['cargos_str'] else []
            result['cargos'] = cargos
            return result
        
        return None
    
    except Error as e:
        print(f"[OBTENER_SIGUIENTE_PASO] Error: {e}")
        return None


def obtener_cargos_paso_actual(id_tipo_documento, numero_paso):
    """
    Obtiene los cargos que deben aprobar un paso específico
    desde TblFlujoAprobacionCargos
    
    Args:
        id_tipo_documento: ID del tipo de documento
        numero_paso: Número del paso
    
    Returns:
        list: Lista de cargos del paso
    """
    connection = get_db_connection()
    if not connection:
        return []
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute('''
            SELECT 
                c.id_cargo,
                c.nombre as cargo_nombre,
                a.id_area,
                a.nombre as area_nombre
            FROM TblFlujoAprobacionCargos fac
            LEFT JOIN TblCargo c ON fac.id_cargo = c.id_cargo
            LEFT JOIN TblArea a ON c.id_area = a.id_area
            WHERE fac.id_tipo_documento = %s
              AND fac.numero_paso = %s
              AND fac.activo = 1
            ORDER BY fac.id_flujo_cargo
        ''', (id_tipo_documento, numero_paso))
        
        result = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return result if result else []
    
    except Error as e:
        print(f"[OBTENER_CARGOS_PASO_ACTUAL] Error: {e}")
        return []


def registrar_aprobacion_en_flujo(id_tipo_documento, id_documento_referencia, 
                                   numero_paso, id_cargo_aprobador, 
                                   num_documento_aprobador, comentario=''):
    """
    Registra una aprobación en TblRegistroAprobacion
    
    Args:
        id_tipo_documento: ID del tipo de documento
        id_documento_referencia: ID del documento
        numero_paso: Número del paso aprobado
        id_cargo_aprobador: ID del cargo que aprueba
        num_documento_aprobador: Documento del usuario que aprueba
        comentario: Comentarios (opcional)
    
    Returns:
        dict: {'success': bool, 'message': str, 'id_registro': int}
    """
    connection = get_db_connection()
    if not connection:
        return {'success': False, 'message': 'Error de conexión'}
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Verificar si ya existe un registro para este paso
        cursor.execute('''
            SELECT id_registro FROM TblRegistroAprobacion
            WHERE id_tipo_documento = %s
              AND id_documento_referencia = %s
              AND numero_paso = %s
            LIMIT 1
        ''', (id_tipo_documento, id_documento_referencia, numero_paso))
        
        existing = cursor.fetchone()
        
        if existing:
            # Actualizar existente
            cursor.execute('''
                UPDATE TblRegistroAprobacion
                SET 
                    estado_aprobacion = 'APROBADO',
                    id_cargo_aprobador = %s,
                    num_documento_aprobador = %s,
                    comentario = %s,
                    fecha_aprobacion = NOW()
                WHERE id_registro = %s
            ''', (id_cargo_aprobador, num_documento_aprobador, comentario, existing['id_registro']))
            
            id_registro = existing['id_registro']
        else:
            # Crear nuevo
            cursor.execute('''
                INSERT INTO TblRegistroAprobacion
                (id_tipo_documento, id_documento_referencia, numero_paso, 
                 id_cargo_aprobador, num_documento_aprobador, 
                 estado_aprobacion, comentario, fecha_aprobacion, fecha_asignacion)
                VALUES (%s, %s, %s, %s, %s, 'APROBADO', %s, NOW(), NOW())
            ''', (id_tipo_documento, id_documento_referencia, numero_paso,
                  id_cargo_aprobador, num_documento_aprobador, comentario))
            
            id_registro = cursor.lastrowid
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': f'Paso {numero_paso} registrado como APROBADO',
            'id_registro': id_registro
        }
    
    except Error as e:
        print(f"[REGISTRAR_APROBACION] Error: {e}")
        return {'success': False, 'message': str(e)}


def registrar_rechazo_en_flujo(id_tipo_documento, id_documento_referencia,
                                numero_paso, id_cargo_aprobador,
                                num_documento_aprobador, comentario=''):
    """
    Registra un rechazo en TblRegistroAprobacion
    
    Args:
        Similar a registrar_aprobacion_en_flujo
    
    Returns:
        dict: {'success': bool, 'message': str, 'id_registro': int}
    """
    connection = get_db_connection()
    if not connection:
        return {'success': False, 'message': 'Error de conexión'}
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        # Verificar si ya existe un registro para este paso
        cursor.execute('''
            SELECT id_registro FROM TblRegistroAprobacion
            WHERE id_tipo_documento = %s
              AND id_documento_referencia = %s
              AND numero_paso = %s
            LIMIT 1
        ''', (id_tipo_documento, id_documento_referencia, numero_paso))
        
        existing = cursor.fetchone()
        
        if existing:
            # Actualizar existente
            cursor.execute('''
                UPDATE TblRegistroAprobacion
                SET 
                    estado_aprobacion = 'RECHAZADO',
                    id_cargo_aprobador = %s,
                    num_documento_aprobador = %s,
                    comentario = %s,
                    fecha_aprobacion = NOW()
                WHERE id_registro = %s
            ''', (id_cargo_aprobador, num_documento_aprobador, comentario, existing['id_registro']))
            
            id_registro = existing['id_registro']
        else:
            # Crear nuevo
            cursor.execute('''
                INSERT INTO TblRegistroAprobacion
                (id_tipo_documento, id_documento_referencia, numero_paso,
                 id_cargo_aprobador, num_documento_aprobador,
                 estado_aprobacion, comentario, fecha_aprobacion, fecha_asignacion)
                VALUES (%s, %s, %s, %s, %s, 'RECHAZADO', %s, NOW(), NOW())
            ''', (id_tipo_documento, id_documento_referencia, numero_paso,
                  id_cargo_aprobador, num_documento_aprobador, comentario))
            
            id_registro = cursor.lastrowid
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': f'Paso {numero_paso} registrado como RECHAZADO',
            'id_registro': id_registro
        }
    
    except Error as e:
        print(f"[REGISTRAR_RECHAZO] Error: {e}")
        return {'success': False, 'message': str(e)}


def actualizar_estado_documento(id_tipo_documento, id_documento_referencia, nuevo_estado):
    """
    Actualiza el estado del documento (Presupuesto o Requerimiento)
    
    Args:
        id_tipo_documento: ID del tipo de documento (1=Presupuesto, 2=Requerimiento)
        id_documento_referencia: ID del documento
        nuevo_estado: PENDIENTE, APROBADO, RECHAZADO
    
    Returns:
        dict: {'success': bool, 'message': str}
    """
    connection = get_db_connection()
    if not connection:
        return {'success': False, 'message': 'Error de conexión'}
    
    try:
        cursor = connection.cursor()
        
        # Tabla según tipo de documento
        tabla = 'TblPresupuesto' if id_tipo_documento == 1 else 'TblRequerimiento'
        id_field = 'id_presupuesto' if id_tipo_documento == 1 else 'id_requerimiento'
        
        cursor.execute(f'''
            UPDATE {tabla}
            SET estado = %s, fecha_actualizacion = NOW()
            WHERE {id_field} = %s
        ''', (nuevo_estado, id_documento_referencia))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': f'Estado actualizado a {nuevo_estado}'
        }
    
    except Error as e:
        print(f"[ACTUALIZAR_ESTADO_DOCUMENTO] Error: {e}")
        return {'success': False, 'message': str(e)}
