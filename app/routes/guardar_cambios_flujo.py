"""
ENDPOINT: POST /api/flujo-aprobacion/guardar-cambios-flujo

Permite guardar mltiples cambios en un flujo de aprobacin:
- Agregar nuevos cargos en pasos especficos
- Eliminar cargos existentes
"""

from flask import jsonify, request
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig

def get_db_connection():
    """Crear conexin a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        return connection
    except Error as e:
        print(f"Error de conexin: {e}")
        return None

def guardar_cambios_flujo():
    """
    Guardar cambios acumulados en un flujo:
    - Agregar nuevos cargos
    - Eliminar cargos existentes
    
    Request:
    {
        "id_tipo_documento": 1,
        "cargos_agregados": [
            {"numero_paso": 1, "id_cargo": 5, "nombre_cargo": "...", "nombre_area": "...", "orden": 1},
            {"numero_paso": 1, "id_cargo": 8, "nombre_cargo": "...", "nombre_area": "...", "orden": 2}
        ],
        "cargos_eliminados": [2, 3]
    }
    
    Response:
    {
        "success": true,
        "message": "Cambios guardados: 2 cargos agregados, 1 eliminado",
        "cargos_agregados": 2,
        "cargos_eliminados": 1
    }
    """
    
    print(f"\n{'='*80}")
    print(f"[GUARDAR_CAMBIOS_FLUJO] Iniciando...")
    print(f"{'='*80}")
    
    try:
        datos = request.get_json()
        print(f"[GUARDAR_CAMBIOS_FLUJO] Datos recibidos: {datos}")
        
        id_tipo_documento = datos.get('id_tipo_documento')
        cargos_agregar = datos.get('cargos_agregados', [])
        cargos_eliminar = datos.get('cargos_eliminados', [])
        
        print(f"[GUARDAR_CAMBIOS_FLUJO] Parmetros:")
        print(f"  - Tipo documento: {id_tipo_documento}")
        print(f"  - Cargos a agregar: {len(cargos_agregar)}")
        print(f"  - Cargos a eliminar: {len(cargos_eliminar)}")
        
        # Validar parmetros
        if not id_tipo_documento:
            return jsonify({
                'success': False,
                'error': 'Parmetro requerido: id_tipo_documento'
            }), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexin'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        contador_agregados = 0
        contador_eliminados = 0
        
        # ====================================================================
        # PASO 1: ELIMINAR CARGOS
        # ====================================================================
        
        if cargos_eliminar:
            print(f"[GUARDAR_CAMBIOS_FLUJO] Eliminando {len(cargos_eliminar)} cargos...")
            
            for id_flujo_cargo in cargos_eliminar:
                try:
                    # Ejecutar SP para eliminar
                    cursor.callproc('sp_EliminarFlujoAprobacion', [
                        id_flujo_cargo,
                        id_tipo_documento,
                        '',  # OUT p_resultado
                        ''   # OUT p_mensaje
                    ])
                    
                    # Procesar resultado
                    for result in cursor.stored_results():
                        rows = result.fetchall()
                        if rows:
                            resultado = rows[0]
                            if resultado.get('resultado') == 'OK':
                                contador_eliminados += 1
                                print(f"  [OK] Eliminado flujo {id_flujo_cargo}")
                            else:
                                print(f"  [!] {resultado.get('mensaje')}")
                    
                except Error as e:
                    print(f"  [X] Error al eliminar {id_flujo_cargo}: {e}")
        
        # ====================================================================
        # PASO 2: AGREGAR NUEVOS CARGOS
        # ====================================================================
        
        if cargos_agregar:
            print(f"[GUARDAR_CAMBIOS_FLUJO] Agregando {len(cargos_agregar)} cargos...")
            
            for cargo in cargos_agregar:
                try:
                    id_cargo = cargo.get('id_cargo')
                    numero_paso = cargo.get('numero_paso')
                    nombre_paso = cargo.get('nombre_paso', '')
                    orden = cargo.get('orden', 0)
                    
                    # Validar si ya existe
                    cursor.execute('''
                        SELECT id_flujo_cargo 
                        FROM TblFlujoAprobacionCargos 
                        WHERE id_tipo_documento = %s 
                        AND numero_paso = %s 
                        AND id_cargo = %s 
                        LIMIT 1
                    ''', (id_tipo_documento, numero_paso, id_cargo))
                    
                    if cursor.fetchone():
                        print(f"  [!] Cargo {id_cargo} ya existe en paso {numero_paso}")
                        continue
                    
                    # Obtener nombre del paso si no viene
                    if not nombre_paso:
                        cursor.execute('''
                            SELECT nombre_paso
                            FROM TblFlujoAprobacionCargos
                            WHERE id_tipo_documento = %s
                            AND numero_paso = %s
                            LIMIT 1
                        ''', (id_tipo_documento, numero_paso))
                        
                        result = cursor.fetchone()
                        if result:
                            nombre_paso = result['nombre_paso']
                    
                    # Insertar nuevo cargo
                    cursor.execute('''
                        INSERT INTO TblFlujoAprobacionCargos 
                        (id_tipo_documento, numero_paso, nombre_paso, descripcion, 
                         es_requerido, permite_rechazo, id_cargo, orden_visualizacion, activo)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1)
                    ''', (
                        id_tipo_documento,
                        numero_paso,
                        nombre_paso,
                        '',
                        1,  # es_requerido
                        1,  # permite_rechazo
                        id_cargo,
                        orden
                    ))
                    
                    contador_agregados += 1
                    print(f"  [OK] Agregado cargo {id_cargo} en paso {numero_paso}")
                    
                except Error as e:
                    print(f"  [X] Error al agregar cargo {cargo.get('id_cargo')}: {e}")
        
        # Hacer commit de todos los cambios
        connection.commit()
        
        print(f"[GUARDAR_CAMBIOS_FLUJO] [OK] Cambios guardados:")
        print(f"  - Cargos agregados: {contador_agregados}")
        print(f"  - Cargos eliminados: {contador_eliminados}")
        
        # ====================================================================
        # PASO 3: REINICIAR FLUJO DE APROBACIN EN PRESUPUESTOS PENDIENTE
        # ====================================================================
        
        print(f"\n[GUARDAR_CAMBIOS_FLUJO] REINICIANDO FLUJO DE APROBACIN EN PRESUPUESTOS PENDIENTE...")
        
        contador_reiniciados = 0
        
        try:
            # Obtener todos los presupuestos PENDIENTE con este tipo_documento
            cursor.execute('''
                SELECT DISTINCT tp.id_presupuesto
                FROM TblPresupuesto tp
                WHERE tp.estado = 'PENDIENTE'
                AND tp.id_tipo_documento = %s
            ''', (id_tipo_documento,))
            
            presupuestos_pendiente = cursor.fetchall()
            
            if presupuestos_pendiente:
                print(f"   Encontrados {len(presupuestos_pendiente)} presupuesto(s) PENDIENTE")
                
                for row in presupuestos_pendiente:
                    id_presupuesto = row['id_presupuesto']
                    
                    try:
                        # Eliminar todos los registros de aprobacin para reiniciar el flujo
                        # Esto hace que el presupuesto vuelva a empezar desde el Paso 1
                        # con la nueva configuracin del flujo
                        cursor.execute('''
                            DELETE FROM TblRegistroAprobacion
                            WHERE id_presupuesto = %s
                        ''', (id_presupuesto,))
                        
                        contador_reiniciados += 1
                        print(f"  [OK] Flujo reiniciado en presupuesto {id_presupuesto}")
                        
                    except Error as e:
                        print(f"  [!] Error al reiniciar presupuesto {id_presupuesto}: {e}")
                        # Continuar con el siguiente
                
                connection.commit()
                
                print(f"  [OK] Flujos reiniciados: {contador_reiniciados}/{len(presupuestos_pendiente)}")
            else:
                print(f"   No hay presupuestos PENDIENTE con este tipo de documento")
        
        except Error as e:
            print(f"  [X] Error al reiniciar flujos: {e}")
            # No fallar el endpoint, pero advertir
        
        cursor.close()
        connection.close()
        
        print(f"{'='*80}\n")
        
        # Preparar mensaje
        mensaje_partes = []
        if contador_agregados > 0:
            mensaje_partes.append(f"{contador_agregados} cargo(s) agregado(s)")
        if contador_eliminados > 0:
            mensaje_partes.append(f"{contador_eliminados} cargo(s) eliminado(s)")
        if contador_reiniciados > 0:
            mensaje_partes.append(f"{contador_reiniciados} presupuesto(s) actualizado(s)")
        
        if not mensaje_partes:
            mensaje = "Sin cambios aplicados"
        else:
            mensaje = "Cambios guardados: " + ", ".join(mensaje_partes)
        
        return jsonify({
            'success': True,
            'message': mensaje,
            'cargos_agregados': contador_agregados,
            'cargos_eliminados': contador_eliminados,
            'presupuestos_reiniciados': contador_reiniciados
        }), 200
    
    except Exception as e:
        print(f"[GUARDAR_CAMBIOS_FLUJO] [X] ERROR: {str(e)}")
        print(f"{'='*80}\n")
        return jsonify({'success': False, 'error': str(e)}), 500
