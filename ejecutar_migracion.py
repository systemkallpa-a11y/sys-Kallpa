#!/usr/bin/env python3
import mysql.connector
from mysql.connector import Error
from app.config import DatabaseConfig

def ejecutar():
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params, autocommit=True)
        cursor = connection.cursor(dictionary=True)
        
        print("\n" + "="*80)
        print("🚀 EJECUTANDO MIGRACIÓN: Cambiar unidad_medida por id_unidad")
        print("="*80)
        
        # Leer el archivo SQL
        with open('database_scripts/migrar_id_unidad.sql', 'r', encoding='utf-8') as f:
            sql = f.read()
        
        # Dividir por comentarios
        statements = [s.strip() for s in sql.split(';') if s.strip() and not s.strip().startswith('--')]
        
        print(f"\n[1] Ejecutando {len(statements)} statements...")
        
        for i, stmt in enumerate(statements, 1):
            if stmt:
                try:
                    cursor.execute(stmt)
                    print(f"    [{i}/{len(statements)}] ✅ Completado")
                except Error as e:
                    if 'already exists' in str(e).lower():
                        print(f"    [{i}/{len(statements)}] ⚠️  Ya existe (OK)")
                    elif 'cant drop' in str(e).lower():
                        print(f"    [{i}/{len(statements)}] ⚠️  No se puede eliminar (OK)")
                    else:
                        print(f"    [{i}/{len(statements)}] ❌ Error: {e}")
                        raise
        
        print(f"\n[2] Verificando nueva estructura...")
        cursor.execute("DESC TblRequerimientoDetalle")
        columnas = cursor.fetchall()
        
        tiene_id_unidad = any(c['Field'] == 'id_unidad' for c in columnas)
        tiene_unidad_medida = any(c['Field'] == 'unidad_medida' for c in columnas)
        
        print(f"    id_unidad: {'✅' if tiene_id_unidad else '❌'}")
        print(f"    unidad_medida: {'❌ (eliminada)' if not tiene_unidad_medida else '⚠️'}")
        
        print(f"\n[3] Verificando datos...")
        cursor.execute("SELECT COUNT(*) as total FROM TblRequerimientoDetalle WHERE id_unidad IS NOT NULL")
        result = cursor.fetchone()
        print(f"    Requerimientos con id_unidad: {result['total']}")
        
        print("\n" + "="*80)
        print("✅ MIGRACIÓN COMPLETADA")
        print("="*80)
        
        cursor.close()
        connection.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    ejecutar()
