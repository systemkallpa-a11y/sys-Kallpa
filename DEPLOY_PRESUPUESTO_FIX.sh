#!/bin/bash
# =====================================================
# DEPLOY FIX: Edición manual de campos de desglose
# =====================================================
# Fecha: 31 Julio 2026
# Fix: Sistema de bandera para edición manual de desglose
# =====================================================

echo "=========================================="
echo "  DEPLOY: Fix Edición Manual Desglose"
echo "=========================================="
echo ""

# Navegar al directorio de la aplicación
cd /home/kallugwo/kallpa || exit 1

echo "✓ Directorio: $(pwd)"
echo ""

# Hacer pull del último código
echo "📥 Descargando cambios desde Git..."
git pull origin main

if [ $? -ne 0 ]; then
    echo "❌ Error al hacer pull de Git"
    exit 1
fi

echo "✓ Código actualizado correctamente"
echo ""

# Verificar que el archivo modificado existe
if [ -f "app/static/js/presupuesto.js" ]; then
    echo "✓ Archivo presupuesto.js encontrado"
else
    echo "❌ Error: presupuesto.js no encontrado"
    exit 1
fi

echo ""
echo "🔄 Reiniciando aplicación web..."

# Reiniciar la aplicación usando el touch method de PythonAnywhere
if [ -f "/var/www/kallugwo_pythonanywhere_com_wsgi.py" ]; then
    touch /var/www/kallugwo_pythonanywhere_com_wsgi.py
    echo "✓ Aplicación reiniciada (touch wsgi.py)"
else
    echo "⚠️  Archivo WSGI no encontrado en la ruta esperada"
    echo "   Intentando con ruta alternativa..."
    
    # Buscar el archivo WSGI
    WSGI_FILE=$(find /var/www -name "*wsgi.py" 2>/dev/null | head -1)
    
    if [ -n "$WSGI_FILE" ]; then
        touch "$WSGI_FILE"
        echo "✓ Aplicación reiniciada: $WSGI_FILE"
    else
        echo "❌ No se pudo encontrar el archivo WSGI"
        echo "   Reinicia manualmente desde el dashboard de PythonAnywhere"
    fi
fi

echo ""
echo "=========================================="
echo "  ✅ DEPLOY COMPLETADO"
echo "=========================================="
echo ""
echo "📋 CAMBIOS APLICADOS:"
echo "  - Sistema de bandera desglose_editado_manualmente"
echo "  - Edición manual respetada (no recalcula)"
echo "  - Limpiar Desglose resetea bandera"
echo "  - Calcular % Automático resetea bandera"
echo ""
echo "🌐 Verifica en: https://kallpainmovilaria.com"
echo ""
echo "=========================================="
