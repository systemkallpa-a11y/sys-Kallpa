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
        
        # PASO 1
        print("\n[1] Agregando columna id_unidad...")
        try:
            cursor.execute("""
                ALTER TABLE TblRequerimientoDetalle 
                ADD COLUMN id_unidad INT(11) NULL DEFAULT NULL 
                AFTER id_material
            """)
            print("    ✅ Columna agregada")
        except Exception as e:
            if 'already exists' in str(e).lower() or 'duplicate' in str(e).lower():
                print("    ⚠️  La columna ya existe")
            else:
                raise
        
        # PASO 2
        print("\n[2] Agregando Foreign Key...")
        try:
            cursor.execute("""
                ALTER TABLE TblRequerimientoDetalle 
                ADD CONSTRAINT fk_requerimiento_detalle_unidad 
                FOREIGN KEY (id_unidad) REFERENCES TblUnidadMedida(id_unidad)
            """)
            print("    ✅ Foreign Key agregada")
        except Exception as e:
            if 'already exists' in str(e).lower():
                print("    ⚠️  Foreign Key ya existe")
            else:
                raise
        
        # PASO 3
        print("\n[3] Migrando datos de unidad_medida a id_unidad...")
        cursor.execute("""
            UPDATE TblRequerimientoDetalle rd
            SET rd.id_unidad = (
                SELECT um.id_unidad 
                FROM TblUnidadMedida um 
                WHERE LOWER(TRIM(um.nombre)) = LOWER(TRIM(rd.unidad_medida))
                LIMIT 1
            )
            WHERE rd.unidad_medida IS NOT NULL
              AND rd.id_unidad IS NULL
        """)
        affected = cursor.rowcount
        print(f"    ✅ {affected} registros actualizados")
        
        # PASO 4
        print("\n[4] Asignando unidad por defecto para registros sin unidad...")
        cursor.execute("""
            UPDATE TblRequerimientoDetalle rd
            SET rd.id_unidad = (
                SELECT id_unidad FROM TblUnidadMedida 
                WHERE nombre = 'und' 
                LIMIT 1
            )
            WHERE rd.id_unidad IS NULL
        """)
        affected = cursor.rowcount
        print(f"    ✅ {affected} registros con defecto")
        
        # PASO 5
        print("\n[5] Eliminando columna unidad_medida...")
        try:
            cursor.execute("ALTER TABLE TblRequerimientoDetalle DROP COLUMN unidad_medida")
            print("    ✅ Columna eliminada")
        except Exception as e:
            if 'cant drop' in str(e).lower():
                print("    ⚠️  No se pudo eliminar (puede haber dependencias)")
            else:
                raise
        
        # Verificación
        print("\n[6] Verificando nueva estructura...")
        cursor.execute("DESC TblRequerimientoDetalle")
        columnas = cursor.fetchall()
        
        print("    Columnas:")
        for col in columnas:
            if col['Field'] in ['id_unidad', 'unidad_medida', 'id_material', 'descripcion']:
                print(f"      - {col['Field']}: {col['Type']}")
        
        # Verificar datos
        print("\n[7] Verificando datos migracion...")
        cursor.execute("SELECT COUNT(*) as total, COUNT(DISTINCT id_unidad) as con_unidad FROM TblRequerimientoDetalle")
        result = cursor.fetchone()
        print(f"    Total registros: {result['total']}")
        print(f"    Con id_unidad: {result['con_unidad']}")
        
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
