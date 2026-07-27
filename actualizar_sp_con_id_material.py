#!/usr/bin/env python3
"""
Actualizar SP con los campos id_material y unidad_medida
"""
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig

def actualizar():
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(
            **params,
            autocommit=True
        )
        cursor = connection.cursor(dictionary=True)
        
        print("\n" + "="*80)
        print("🚀 ACTUALIZANDO SP: sp_CrearRequerimientoCompleto")
        print("="*80)
        
        # Leer el archivo SQL actualizado
        with open('database_scripts/sp_CrearRequerimientoCompleto_TASK6.sql', 'r', encoding='utf-8') as f:
            sp_sql = f.read()
        
        # Primero eliminar el SP existente
        print("\n[1] Eliminando SP anterior...")
        try:
            cursor.execute("DROP PROCEDURE IF EXISTS sp_CrearRequerimientoCompleto")
            print("    ✓ SP anterior eliminado")
        except Exception as e:
            print(f"    ⚠️  {e}")
        
        # Crear el nuevo SP
        print("\n[2] Creando SP actualizado...")
        try:
            cursor.execute(sp_sql)
            print("    ✅ SP creado exitosamente")
        except Error as e:
            print(f"    ❌ Error: {e}")
            cursor.close()
            connection.close()
            return
        
        # Verificar que existe
        print("\n[3] Verificando SP...")
        cursor.execute("""
            SELECT ROUTINE_NAME, ROUTINE_TYPE
            FROM INFORMATION_SCHEMA.ROUTINES
            WHERE ROUTINE_SCHEMA = DATABASE()
              AND ROUTINE_NAME = 'sp_CrearRequerimientoCompleto'
        """)
        
        result = cursor.fetchone()
        if result:
            print(f"    ✅ SP verificado: {result['ROUTINE_NAME']} ({result['ROUTINE_TYPE']})")
        else:
            print(f"    ❌ SP no encontrado después de crear")
        
        print("\n" + "="*80)
        print("✅ SP ACTUALIZADO EXITOSAMENTE")
        print("="*80)
        print("\nAhora el SP extraerá:")
        print("  - id_material (del JSON)")
        print("  - tipo_item (del JSON)")
        print("  - unidad_medida (del JSON)")
        print("\nFlask necesita reiniciarse para cargar los cambios")
        
        cursor.close()
        connection.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    actualizar()
