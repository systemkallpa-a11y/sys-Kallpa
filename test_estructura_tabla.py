import mysql.connector
from app.config import DatabaseConfig

conn = mysql.connector.connect(**DatabaseConfig.get_connection_params())
cursor = conn.cursor(dictionary=True)

# Ver estructura de TblRequerimientoDetalle
cursor.execute("DESC TblRequerimientoDetalle")
print("\n=== Estructura TblRequerimientoDetalle ===\n")
for row in cursor.fetchall():
    print(f"  {row['Field']:25s} {row['Type']:25s} {row['Null']:10s}")

# Ver un requerimiento con sus detalles
cursor.execute("SELECT id_requerimiento, id_material, unidad_medida FROM TblRequerimientoDetalle LIMIT 5")
print("\n=== Detalles existentes ===\n")
for row in cursor.fetchall():
    print(f"  ID Req: {row['id_requerimiento']}, ID Material: {row['id_material']}, Unidad: {row['unidad_medida']}")

cursor.close()
conn.close()
