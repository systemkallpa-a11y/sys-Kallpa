#!/usr/bin/env python3
import mysql.connector
from app.config import DatabaseConfig

try:
    conn = mysql.connector.connect(**DatabaseConfig.get_connection_params(), autocommit=True)
    cursor = conn.cursor()

    print("🔧 Eliminando unidad_medida...")
    cursor.execute("ALTER TABLE TblRequerimientoDetalle DROP COLUMN unidad_medida")
    print("✅ Eliminada")

    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")