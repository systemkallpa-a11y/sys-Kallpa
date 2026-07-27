#!/usr/bin/env python3
"""
Actualizar el endpoint obtener_requerimiento para usar SP
"""

# ========================================================================
# NUEVA FUNCIÓN PARA REEMPLAZAR EN app/routes/requerimientos.py
# Líneas aproximadas: 82-200
# ========================================================================

def obtener_requerimiento(id_requerimiento):
    """Obtener datos completos de un requerimiento usando SP"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'success': False, 'error': 'Error de conexión'}), 500
    
    try:
        cursor = connection.cursor(dictionary=True)
        
        print(f"\n{'='*80}")
        print(f"[OBTENER_REQUERIMIENTO] Iniciando para ID: {id_requerimiento}")
        print(f"[OBTENER_REQUERIMIENTO] Usando SP: sp_ObtenerRequerimientoCompleto")
        print(f"{'='*80}")
        
        # Llamar al SP que retorna 2 result sets
        cursor.callproc('sp_ObtenerRequerimientoCompleto', [id_requerimiento])
        
        # Result Set 1: Datos del requerimiento
        requerimiento = cursor.fetchone()
        if not requerimiento:
            print(f"[OBTENER_REQUERIMIENTO] [WARN] Requerimiento no encontrado")
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': 'Requerimiento no encontrado'}), 404
        
        # Limpiar nombres (eliminar espacios extras)
        if requerimiento.get('usuario_completo'):
            requerimiento['usuario_completo'] = ' '.join(requerimiento['usuario_completo'].split())
        
        # Result Set 2: Detalles del requerimiento
        cursor.nextset()
        detalles = cursor.fetchall()
        
        # Calcular resumen
        materiales = [d for d in detalles if d.get('tipo_item') == 'MATERIAL'] if detalles else []
        servicios = [d for d in detalles if d.get('tipo_item') == 'SERVICIO'] if detalles else []
        
        resumen = {
            'cantidad_items': len(detalles),
            'cantidad_materiales': len(materiales),
            'cantidad_servicios': len(servicios)
        }
        
        print(f"[OBTENER_REQUERIMIENTO] ✓ Requerimiento: {requerimiento.get('codigo', 'N/A')}")
        print(f"[OBTENER_REQUERIMIENTO] ✓ Usuario: {requerimiento.get('usuario_completo', 'N/A')}")
        print(f"[OBTENER_REQUERIMIENTO] ✓ Presupuesto: {requerimiento.get('numero_presupuesto', 'N/A')}")
        print(f"[OBTENER_REQUERIMIENTO] ✓ Detalles: {len(detalles)} items")
        print(f"[OBTENER_REQUERIMIENTO] ✓ Resumen: {resumen}")
        print(f"{'='*80}\n")
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'requerimiento': requerimiento,
                'detalles': detalles,
                'resumen': resumen
            }
        }), 200
    
    except Exception as e:
        print(f"[OBTENER_REQUERIMIENTO] [ERROR] {str(e)}")
        print(f"{'='*80}\n")
        if connection:
            connection.close()
        return jsonify({'success': False, 'error': str(e)}), 500

# ========================================================================
# INSTRUCCIONES:
# ========================================================================
# 1. Ejecutar: sp_ObtenerRequerimientoCompleto.sql en MySQL Workbench
# 2. Reemplazar la función obtener_requerimiento() en requerimientos.py
# 3. Reiniciar Flask
# 4. Probar módulo "Editar Requerimiento"
# ========================================================================