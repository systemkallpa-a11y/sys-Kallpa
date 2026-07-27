#!/usr/bin/env python3
import mysql.connector
from app.config import DatabaseConfig

conn = mysql.connector.connect(**DatabaseConfig.get_connection_params(), autocommit=True)
cursor = conn.cursor()

print("\n" + "="*80)
print("🚀 MIGRACIÓN: Eliminar unidad_medida de TblRequerimientoDetalle")
print("="*80)

print("\n[1] Eliminando columna unidad_medida...")
try:
    cursor.execute("ALTER TABLE TblRequerimientoDetalle DROP COLUMN unidad_medida")
    print("    ✅ Columna eliminada")
except Exception as e:
    print(f"    ⚠️  {e}")

print("\n[2] Verificando estructura...")
cursor.execute("DESC TblRequerimientoDetalle")
for row in cursor.fetchall():
    print(f"    {row[0]:25s} {row[1]}")

print("\n" + "="*80)
print("✅ COMPLETADO - La unidad se obtiene vía id_material → TblMateriales → TblUnidadMedida")
print("="*80)

cursor.close()
conn.close()
