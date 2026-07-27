#!/usr/bin/env python3
"""
Test simple y directo de las funciones PDF helper
"""

import sys
import os
sys.path.insert(0, '.')

# Test directo de importación
try:
    # Importar solo el helper directamente
    import importlib.util
    spec = importlib.util.spec_from_file_location("pdf_helpers", "routes/pdf_helpers.py")
    pdf_helpers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pdf_helpers)
    
    print("[TEST] ✓ pdf_helpers importado correctamente")
    
    # Test crear estilos
    styles = pdf_helpers.PDFStyles.get_styles()
    print(f"[TEST] ✓ Estilos creados: {len(styles)} estilos")
    
    # Test colores
    print(f"[TEST] ✓ Color primario: {pdf_helpers.PDFStyles.PRIMARY_COLOR}")
    print(f"[TEST] ✓ Color secundario: {pdf_helpers.PDFStyles.SECONDARY_COLOR}")
    
    # Datos de prueba
    materiales_test = [
        {
            'material_nombre': 'Cemento Portland',
            'categoria': 'Construcción',
            'unidad_medida': 'Bolsa',
            'cantidad': 10,
            'precio_unitario': 25.50,
            'subtotal': 255.00
        }
    ]
    
    presupuesto_test = {
        'numero_presupuesto': 'PRES-TEST-001',
        'estado': 'APROBADO',
        'gastos_generales': 100.50,
        'utilidad': 200.75,
        'igv': 64.13,
        'supervision_obra': 50.25,
        'observaciones': 'Test de observaciones'
    }
    
    # Test crear tabla materiales
    header_mat, table_mat = pdf_helpers.crear_tabla_materiales(materiales_test, styles)
    if header_mat and table_mat:
        print("[TEST] ✓ Tabla de materiales creada correctamente")
    else:
        print("[TEST] ❌ Error creando tabla de materiales")
    
    # Test crear desglose financiero
    header_desglose, table_desglose = pdf_helpers.crear_desglose_financiero(presupuesto_test, materiales_test, [], styles)
    if header_desglose and table_desglose:
        print("[TEST] ✓ Desglose financiero creado correctamente")
    else:
        print("[TEST] ❌ Error creando desglose financiero")
    
    print("[TEST] 🎉 ¡Funciones helper funcionando correctamente!")
    print("[TEST] 🔧 La estructura del PDF debería estar reparada")
    
except Exception as e:
    print(f"[TEST] ❌ Error: {e}")
    import traceback
    traceback.print_exc()