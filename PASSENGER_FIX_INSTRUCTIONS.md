# 🔧 INSTRUCCIONES PARA CORREGIR PASSENGER WSGI EN SERVIDOR

## ✅ COMPLETADO EN LOCAL
- ✅ Creado `passenger_wsgi.py` SIN loop infinito
- ✅ Commiteado a GitHub: commit `ceb2190`
- ✅ Pusheado a `main` branch

## 📋 PASOS A EJECUTAR EN SERVIDOR

### OPCIÓN 1: Actualizar desde GitHub (RECOMENDADO)
```bash
# SSH al servidor como kallugwo
ssh kallugwo@63.250.38.200

# Navegar a la carpeta de la app
cd /home/kallugwo/kallpa

# Hacer pull del código actualizado
git pull origin main

# Verificar que passenger_wsgi.py es correcto
cat passenger_wsgi.py
# Debería mostrar SOLO 11 líneas, SIN "imp.load_source()"
```

### OPCIÓN 2: Crear archivo manualmente en servidor
```bash
# Si git pull falla, crear archivo manualmente:
cat > /home/kallugwo/kallpa/passenger_wsgi.py << 'EOF'
import sys
import os

# Agregar el directorio de la app al path de Python
app_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, app_dir)

# Importar la aplicación Flask desde main.py
from main import app

# La variable 'application' es requerida por Passenger
application = app
EOF
```

### PASO 3: Verificar que passenger_wsgi.py funciona
```bash
cd /home/kallugwo/kallpa
python3 -c "from passenger_wsgi import application; print('✅ application loaded successfully')"

# Debería mostrar:
# ✅ application loaded successfully
# (y también el mensaje "Kallpa Application startup")
```

### PASO 4: Reiniciar Passenger en cPanel
- Login a cPanel: https://63.250.38.200:2083
- Buscar "Python App" o "Passenger"
- Hacer click en el ícono STOP (si está corriendo)
- Esperar 5 segundos
- Hacer click en RESTART o START

### PASO 5: Verificar acceso desde terminal
```bash
# Esperar 10 segundos para que Passenger inicie
sleep 10

# Verificar que la app responde
curl -s http://127.0.0.1/login | grep "Kallpa" | head -1
# Debería mostrar algo con "Kallpa"
```

### PASO 6: Verificar acceso desde navegador
- Abrir: https://kallpainmoviliaria.com
- Debería mostrar página de login (NOT Error 500)

## ❌ POSIBLES ERRORES Y SOLUCIONES

### Error: "module 'imp' has no attribute 'load_source'"
**Causa**: Servidor está usando passenger_wsgi.py viejo con loop infinito
**Solución**: Ejecutar OPCIÓN 1 o OPCIÓN 2 arriba

### Error 500 en navegador
**Causa**: Passenger no reinició con nuevo código
**Solución**: 
- Hacer STOP + START en cPanel
- O ejecutar: `touch /home/kallugwo/kallpa/tmp/restart.txt` para forzar reinicio

### Error: "No such file or directory"
**Causa**: Ruta incorrecta
**Verificar**:
```bash
ls -la /home/kallugwo/kallpa/passenger_wsgi.py  # Debe existir
ls -la /home/kallugwo/kallpa/main.py            # Debe existir
```

## 📊 CHECKLIST FINAL

- [ ] SSH conectado al servidor
- [ ] `git pull origin main` ejecutado exitosamente
- [ ] `passenger_wsgi.py` verificado (sin "imp.load_source()")
- [ ] `python3 -c "from passenger_wsgi import application"` retorna ✅
- [ ] Passenger restarteado en cPanel
- [ ] `curl http://127.0.0.1/login` retorna HTML con "Kallpa"
- [ ] https://kallpainmoviliaria.com accesible sin Error 500

## 📂 RUTAS IMPORTANTES

- Código local: `d:\kallpa\sys-Kallpa\sys-Kallpa\`
- Servidor app: `/home/kallugwo/kallpa/`
- Servidor cPanel: `https://63.250.38.200:2083` (user: kallugwo)
- Dominio: `kallpainmoviliaria.com` (NOT kallpainmovilaria.com)

---

**Estado**: ✅ Listo para ejecutar en servidor
**Último update**: 2026-07-27 14:30 (git commit ceb2190)
