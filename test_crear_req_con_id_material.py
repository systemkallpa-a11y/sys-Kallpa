#!/usr/bin/env python3
"""
Test: Crear requerimiento y verificar que se insertan id_material y unidad_medida
"""
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig
import json

def test():
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(
            **params,
            autocommit=True
        )
        cursor = connection.cursor(dictionary=True)
        
        print("\n" + "="*80)
        print("🧪 TEST: Crear Requerimiento con id_material y unidad_medida")
        print("="*80)
        
        # 1. Buscar presupuesto APROBADO
        print("\n[1] Buscando presupuesto APROBADO...")
        cursor.execute("""
            SELECT p.id_presupuesto, p.numero_presupuesto
            FROM TblPresupuesto p
            WHERE p.estado = 'APROBADO'
            LIMIT 1
        """)
        
        presupuesto = cursor.fetchone()
        if not presupuesto:
            print("    ❌ No hay presupuestos APROBADOS")
            return
        
        presupuesto_id = presupuesto['id_presupuesto']
        print(f"    ✓ Presupuesto: {presupuesto['numero_presupuesto']} (ID: {presupuesto_id})")
        
        # 2. Obtener detalles del presupuesto
        print(f"\n[2] Obteniendo detalles del presupuesto...")
        cursor.execute("""
            SELECT 
                pd.id_detalle,
                pd.descripcion,
                pd.id_material,
                pd.cantidad,
                COALESCE(um.nombre, 'und') as unidad_medida
            FROM TblPresupuestoDetalle pd
            LEFT JOIN TblMateriales m ON pd.id_material = m.id_material
            LEFT JOIN TblUnidadMedida um ON m.id_unidad = um.id_unidad
            WHERE pd.id_presupuesto = %s
            LIMIT 2
        """, (presupuesto_id,))
        
        presupuesto_detalles = cursor.fetchall()
        print(f"    ✓ {len(presupuesto_detalles)} detalles encontrados")
        
        if len(presupuesto_detalles) < 2:
            print("    ⚠️  Necesitamos al menos 2 detalles para el test")
            print("    Continuaremos de todos modos...")
        
        # 3. Preparar JSON con id_material y unidad_medida
        print(f"\n[3] Preparando items del requerimiento...")
        
        items = []
        for det in presupuesto_detalles:
            items.append({
                "id_detalle_presupuesto": det['id_detalle'],
                "id_material": det['id_material'],  # ✅ INCLUIR id_material
                "nombre": det['descripcion'],
                "descripcion": det['descripcion'],
                "cantidad": min(5, float(det['cantidad'])),  # Consumir máximo 5
                "tipo_item": "MATERIAL",
                "unidad_medida": det['unidad_medida']  # ✅ INCLUIR unidad_medida
            })
        
        items_json = json.dumps(items)
        print(f"    ✓ {len(items)} items preparados")
        for i, item in enumerate(items):
            print(f"      {i+1}. {item['nombre']}: id_material={item['id_material']}, unidad={item['unidad_medida']}")
        
        # 4. Crear requerimiento usando SP
        print(f"\n[4] Creando requerimiento con SP...")
        
        resultado = cursor.callproc('sp_CrearRequerimientoCompleto', [
            1,  # num_usuario
            "Requerimiento de test con id_material",
            "test",
            items_json,
            presupuesto_id,
            0  # OUT parameter
        ])
        
        req_id = resultado.get('sp_CrearRequerimientoCompleto_arg6')
        if not req_id:
            print("    ❌ No se obtuvo ID del requerimiento")
            return
        
        print(f"    ✓ Requerimiento creado: ID {req_id}")
        
        # 5. Verificar que se insertaron los datos
        print(f"\n[5] Verificando que se insertaron id_material y unidad_medida...")
        
        cursor.execute("""
            SELECT 
                id_detalle,
                descripcion,
                id_material,
                unidad_medida,
                cantidad
            FROM TblRequerimientoDetalle
            WHERE id_requerimiento = %s
            ORDER BY id_detalle
        """, (req_id,))
        
        detalles = cursor.fetchall()
        
        print(f"    ✓ {len(detalles)} detalles insertados")
        print("\n    Datos insertados:")
        print("    ┌────────────┬──────────────────┬────────────┬──────────────┐")
        print("    │ id_material│ descripcion      │ unidad     │ cantidad     │")
        print("    ├────────────┼──────────────────┼────────────┼──────────────┤")
        
        errores = 0
        for det in detalles:
            id_mat_status = "✅" if det['id_material'] else "❌"
            unit_status = "✅" if det['unidad_medida'] else "❌"
            
            if not det['id_material']:
                errores += 1
            if not det['unidad_medida']:
                errores += 1
            
            print(f"    │ {str(det['id_material'] or 'NULL'):10s}│ {det['descripcion'][:16]:16s}│ {det['unidad_medida'][:10]:10s}│ {str(det['cantidad']):12s}│")
        
        print("    └────────────┴──────────────────┴────────────┴──────────────┘")
        
        # 6. Resultado final
        print(f"\n" + "="*80)
        if errores == 0:
            print("✅ TODO CORRECTO")
            print("   Los campos id_material y unidad_medida se insertaron correctamente")
        else:
            print(f"❌ {errores} CAMPOS NO TIENEN VALORES")
            print("   Revisa que el JSON esté siendo enviado correctamente")
        
        print("="*80)
        
        cursor.close()
        connection.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    test()
