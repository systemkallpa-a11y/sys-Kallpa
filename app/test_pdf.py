#!/usr/bin/env python3
"""
Test script para verificar la generación de PDFs con estructura fija
"""

import sys
import os
sys.path.insert(0, '.')

import mysql.connector
from config import DatabaseConfig

def test_pdf_generation():
    """Test simple de generación de PDF"""
    try:
        # Conectar a la base de datos
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(**params)
        cursor = connection.cursor(dictionary=True)
        
        print("[TEST] 🧪 Iniciando test de PDF...")
        
        # Obtener un presupuesto de prueba
        cursor.callproc('sp_ObtenerPresupuestoPDF', [2])  # Usar presupuesto ID 2
        
        # Convertir stored_results() a lista
        results_list = list(cursor.stored_results())
        
        if not results_list or len(results_list) < 2:
            print("[TEST] ❌ No se obtuvieron result sets del SP")
            return False
            
        # Result Set 1: Información del Presupuesto
        presupuesto = results_list[0].fetchone()
        
        # Result Set 2: Materiales
        materiales = results_list[1].fetchall() if len(results_list) > 1 else []
        
        # Result Set 3: Servicios
        servicios = results_list[2].fetchall() if len(results_list) > 2 else []
        
        cursor.close()
        connection.close()
        
        print(f"[TEST] ✓ Presupuesto: {presupuesto['numero_presupuesto']}")
        print(f"[TEST] ✓ Materiales: {len(materiales)} items")
        print(f"[TEST] ✓ Servicios: {len(servicios)} items")
        
        # Importar funciones helper
        from routes.pdf_helpers import PDFStyles, crear_tabla_materiales, crear_desglose_financiero
        
        # Obtener estilos
        pdf_styles = PDFStyles.get_styles()
        print(f"[TEST] ✓ Estilos PDF cargados: {len(pdf_styles)} estilos")
        
        # Test crear tabla de materiales
        if materiales:
            header_mat, table_mat = crear_tabla_materiales(materiales, pdf_styles)
            if header_mat and table_mat:
                print("[TEST] ✓ Tabla de materiales creada correctamente")
            else:
                print("[TEST] ❌ Error creando tabla de materiales")
        
        # Test crear desglose financiero
        header_desglose, table_desglose = crear_desglose_financiero(presupuesto, materiales, servicios, pdf_styles)
        if header_desglose and table_desglose:
            print("[TEST] ✓ Desglose financiero creado correctamente")
        else:
            print("[TEST] ❌ Error creando desglose financiero")
        
        print("[TEST] 🎉 ¡Test de PDF completado exitosamente!")
        return True
        
    except Exception as e:
        print(f"[TEST] ❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_pdf_generation()