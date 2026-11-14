# Ejecutar el sistema en local (Windows)

**Actualizado:** 13/11/2026

## Requisitos

- Python 3.12.
- Internet: la BD está en PythonAnywhere y en local solo se llega por túnel SSH.
- Archivo `.env` en `sys-Kallpa/` (copiar `.env.example` y completar).

## `.env` para desarrollo

```env
SECRET_KEY=<clave larga aleatoria>
DEBUG=True

DB_HOST=kallpasystem.mysql.pythonanywhere-services.com
DB_PORT=3306
DB_USER=<usuario MySQL>
DB_PASSWORD=<contraseña MySQL>
DB_NAME=kallpasystem$kallgwkn_kallpa_bd

USE_SSH_TUNNEL=True
SSH_HOST=ssh.pythonanywhere.com
SSH_PORT=22
SSH_USER=<usuario PythonAnywhere>
SSH_PASSWORD=<contraseña PythonAnywhere>
```

Las credenciales reales se piden al responsable del sistema; **nunca** se
escriben en documentos ni se suben a git.

## Pasos

```powershell
cd F:\Kallpa\sistema3\sys-Kallpa
python -m venv venv                 # solo la primera vez
.\venv\Scripts\activate
pip install -r requirements.txt     # primera vez o si cambia requirements.txt
python main.py
```

Abrir http://127.0.0.1:5000 e iniciar sesión.

Alternativa: `iniciar.bat` (instala dependencias, abre el navegador y arranca).

Para tener recarga automática al editar código:

```powershell
$env:FLASK_ENV='development'; $env:PYTHONIOENCODING='utf-8'; python main.py
```

## Comprobaciones rápidas

```powershell
pip show paramiko sshtunnel     # deben ser 3.4.0 y 0.4.0
Get-Content logs\kallpa_app.log -Tail 50
```

Si algo falla, ver `SOLUCION_PROBLEMAS.md`.

## Scripts de base de datos

Los scripts de `database_scripts/` se ejecutan a mano en MySQL Workbench
(conectado por SSH a PythonAnywhere), completos y en el orden de su número.
Ver `database_scripts/README.md`.
