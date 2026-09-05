# PROBLEMA: ERROR 500 - CONEXIÓN A BASE DE DATOS VIA SSH TUNNEL

**Fecha:** 21/08/2026  
**Estado:** RESUELTO  
**Archivos afectados:** `app/config.py`

---

## 1. SÍNTOMA

Al intentar iniciar la aplicación Flask y hacer login:

```
[LOGIN KALLPA] Validando credenciales...
[!] [DB CONFIG] Conexin directa a kallpasystem.mysql.pythonanywhere-services.com:3306 (tnel no disponible)
[LOGIN KALLPA] ERROR de autenticacin: No se pudo conectar a la base de datos
```

- La app Flask crea correctamente (`App creada OK`)
- El login falla con error "No se pudo conectar a la base de datos"
- El log muestra que intenta **conexión directa** en lugar de usar el SSH tunnel
- Timeout al conectar directamente a `kallpasystem.mysql.pythonanywhere-services.com:3306`

---

## 2. CAUSA RAÍZ

**El valor de `USE_SSH_TUNNEL` se evaluaba al definir la clase `DatabaseConfig`, ANTES de que `load_dotenv()` cargara las variables del archivo `.env`.**

### Flujo del error:

```
1. Python carga app/config.py
2. load_dotenv() → carga .env → USE_SSH_TUNNEL=True en os.environ
3. Class DatabaseConfig se define:
   USE_SSH_TUNNEL = os.getenv('USE_SSH_TUNNEL', 'False').lower() == 'true'
   ↑ SE EVALÚA AQUÍ y almacena False (por algún reason de timing/imports)
4. Luego en get_connection_params():
   if cls.USE_SSH_TUNNEL:  ← Siempre es False
       → Nunca intenta crear el tunnel
5. Falla a conexión directa → timeout → error 500
```

### Por qué falla la conexión directa:

PythonAnywhere MySQL **NO permite conexiones externas**. Solo acepta conexiones desde sus propios servidores. Por eso:

```
host: kallpasystem.mysql.pythonanywhere-services.com
port: 3306
Resultado: TimeoutError (conexión rechazada/bloqueada)
```

La ÚNICA forma de conectarse localmente es vía SSH tunnel.

---

## 3. SOLUCIÓN

Convertir `USE_SSH_TUNNEL` de **atributo de clase** (se evalúa al importar) a un **método `@classmethod`** (se evalúa en runtime):

### ANTES (CÓDIGO CON ERROR):

```python
class DatabaseConfig:
    HOST = os.getenv('DB_HOST', 'localhost')
    PORT = int(os.getenv('DB_PORT', 3306))
    USER = os.getenv('DB_USER', 'root')
    PASSWORD = os.getenv('DB_PASSWORD', '')
    DATABASE = os.getenv('DB_NAME', 'kallgwkn_kallpa_bd')
    
    # ERROR: Se evalúa al definir la clase, antes de load_dotenv()
    USE_SSH_TUNNEL = os.getenv('USE_SSH_TUNNEL', 'False').lower() == 'true'
    
    @classmethod
    def get_connection_params(cls):
        if cls.USE_SSH_TUNNEL:  # ← Siempre False
            tunnel = get_ssh_tunnel()
            # ...
```

### DESPUÉS (CÓDIGO CORREGIDO):

```python
class DatabaseConfig:
    HOST = os.getenv('DB_HOST', 'localhost')
    PORT = int(os.getenv('DB_PORT', 3306))
    USER = os.getenv('DB_USER', 'root')
    PASSWORD = os.getenv('DB_PASSWORD', '')
    DATABASE = os.getenv('DB_NAME', 'kallgwkn_kallpa_bd')
    
    @classmethod
    def get_use_ssh_tunnel(cls):
        """Leer USE_SSH_TUNNEL en runtime (no al definir la clase)"""
        return os.getenv('USE_SSH_TUNNEL', 'False').lower() == 'true'
    
    @classmethod
    def get_connection_params(cls):
        use_ssh = cls.get_use_ssh_tunnel()  # ← Lee en runtime
        if use_ssh:
            tunnel = get_ssh_tunnel()
            # ...
```

**Archivo:** `app/config.py` línea 115-124

---

## 4. CONFIGURACIÓN REQUERIDA EN `.env`

```env
# Database Configuration - KALLPA BD (PythonAnywhere MySQL)
DB_HOST=kallpasystem.mysql.pythonanywhere-services.com
DB_PORT=3306
DB_USER=kallpasystem
DB_PASSWORD=tu_password
DB_NAME=kallpasystem$kallgwkn_kallpa_bd

# SSH Tunnel Configuration (OBLIGATORIO para desarrollo local)
USE_SSH_TUNNEL=True
SSH_HOST=ssh.pythonanywhere.com
SSH_PORT=22
SSH_USER=tu_usuario_pythonanywhere
SSH_PASSWORD=tu_password_pythonanywhere
```

**IMPORTANTE:** PythonAnywhere MySQL solo acepta conexiones desde sus propios servidores. Sin SSH tunnel, la conexión falla con timeout.

---

## 5. VERIFICACIÓN

Para verificar que el SSH tunnel funciona:

```bash
# Test 1: Verificar conexión a BD via tunnel
python -c "from app.config import DatabaseConfig; params = DatabaseConfig.get_connection_params(); import mysql.connector; conn = mysql.connector.connect(**params); print('OK:', conn.is_connected()); conn.close()"

# Test 2: Verificar que la app inicia correctamente
python -c "from app import create_app; app = create_app(); print('App OK')"
```

Logs esperados al funcionar correctamente:

```
[DB CONFIG] USE_SSH_TUNNEL=True
[SSH TUNNEL] [...] Iniciando tnel SSH...
[SSH TUNNEL]    SSH: kallpasystem@ssh.pythonanywhere.com:22
[SSH TUNNEL] [OK] Tnel SSH activo!
[SSH TUNNEL]    Puerto local: 54944
[OK] [DB CONFIG] Usando tnel SSH en puerto local 54944
```

---

## 6. NOTAS PARA FUTURAS ENTREGAS

### Reglas importantes:

1. **NUNCA hardcodear** `USE_SSH_TUNNEL` como atributo de clase. Siempre leer en runtime con `os.getenv()`.

2. **`.env` nunca se sube a Git.** Verificar que `.gitignore` lo incluye.

3. **Credenciales SSH** de PythonAnywhere son las mismas que las de la cuenta web.

4. **Producción (Namecheap)** NO necesita SSH tunnel. En `.env` de producción:
   ```env
   USE_SSH_TUNNEL=False
   DB_HOST=localhost
   ```

5. **El tunnel se crea como singleton.** Se reutiliza entre requests. Se cierra automáticamente al salir de la app.

### Si ves este error en el futuro:

```
[!] [DB CONFIG] Conexin directa a ... (tnel no disponible)
```

**Verificar:**
1. ¿Está `USE_SSH_TUNNEL=True` en `.env`?
2. ¿Las credenciales SSH son correctas?
3. ¿`get_use_ssh_tunnel()` es un `@classmethod` (no un atributo)?
4. ¿PythonAnywhere no bloqueó la cuenta SSH?

---

## 7. ARCHIVOS MODIFICADOS

| Archivo | Cambio |
|---------|--------|
| `app/config.py` | `USE_SSH_TUNNEL` convertido de atributo a `@classmethod get_use_ssh_tunnel()` |
| `.env` | Agregadas variables SSH (`USE_SSH_TUNNEL`, `SSH_HOST`, `SSH_PORT`, `SSH_USER`, `SSH_PASSWORD`) |

---

*Documento generado el 21/08/2026 para referencia futura.*
