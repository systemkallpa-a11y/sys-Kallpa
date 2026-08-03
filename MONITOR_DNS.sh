#!/bin/bash
# Script: MONITOR_DNS.sh
# Propósito: Monitorear propagación de DNS automáticamente
# Uso: ./MONITOR_DNS.sh

DOMAIN="kallpainmovilaria.com"
EXPECTED_IP="63.250.38.196"
CHECK_INTERVAL=60  # Segundos entre chequeos

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         🌐 MONITOR DE PROPAGACIÓN DNS - KALLPA            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Dominio: $DOMAIN"
echo "IP esperada: $EXPECTED_IP"
echo "Verificando cada $CHECK_INTERVAL segundos..."
echo ""

ATTEMPT=1
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Intento #$ATTEMPT..."
    
    # Intenta resolver el dominio
    RESULT=$(nslookup $DOMAIN 2>&1 | grep -A 1 "Name:")
    
    if echo "$RESULT" | grep -q "$EXPECTED_IP"; then
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                    ✅ ¡¡¡DNS PROPAGADO!!!                  ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "✅ El dominio $DOMAIN resuelve a $EXPECTED_IP"
        echo ""
        echo "🎉 Ya puedes acceder a:"
        echo "   https://$DOMAIN"
        echo ""
        echo "Logs de Flask:"
        echo "   tail -f app.log"
        echo ""
        break
    else
        # Mostrar estado actual
        if echo "$RESULT" | grep -q "NXDOMAIN"; then
            echo "   ❌ NXDOMAIN (aún no encontrado)"
        elif echo "$RESULT" | grep -q "can't find"; then
            echo "   ⏳ Sin respuesta"
        else
            echo "   ⚠️  Resolvió pero con IP diferente:"
            echo "   $RESULT"
        fi
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
    
    # Espera antes del siguiente chequeo
    if [ $ATTEMPT -lt 100 ]; then
        sleep $CHECK_INTERVAL
    else
        echo ""
        echo "⚠️  Se han realizado 100 intentos sin éxito"
        echo "Verifica la configuración DNS en Namecheap:"
        echo "1. Dashboard → Domains"
        echo "2. kallpainmovilaria.com → Manage"
        echo "3. Advanced DNS → Verifica el A record"
        echo "4. Host: @, Value: 63.250.38.196"
        break
    fi
done
