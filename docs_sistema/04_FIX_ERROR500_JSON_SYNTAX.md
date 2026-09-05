================================================================================
KALLPA - ERROR 500 GENERALizado + SYNTAXERROR JSON
Fecha del problema: 20/08/2026
Fecha de solucion: 20/08/2026
================================================================================

================================================================================
RESUMEN
================================================================================

  El sistema presentaba error 500 (Internal Server Error) en TODAS las paginas
  despues del login. Adicionalmente, la consola del navegador (F12) mostraba:

    SyntaxError: Unexpected token '<', "<!doctype "... is not valid JSON

  Esto indicaba que las APIs devolvian HTML en vez de JSON cuando fallaban.

================================================================================
CAUSA RAIZ #1: INCOMPATIBILIDAD PARAMIKO + SSHTUNNEL (ERROR PRINCIPAL)
================================================================================

SINTOMA:
  - Todas las paginas retornan error 500 despues del login
  - La base de datos nunca se conecta
  - El tunnel SSH falla silenciosamente

CAUSA:
  Teniamos instalado paramiko 5.0.0, pero sshtunnel 0.4.0 necesita la funcion
  paramiko.DSSKey que fue ELIMINADA en paramiko 4.0+.

  Error exacto en consola:
    AttributeError: module 'paramiko' has no attribute 'DSSKey'

  Flujo del error:
  1. La app inicia y llama get_ssh_tunnel()
  2. SSHTunnelForwarder intenta crear el tunnel
  3. Internamente usa paramiko.DSSKey (eliminado en paramiko 5.x)
  4. Se lanza AttributeError -> tunnel no se crea
  5. La app intenta conexion directa a MySQL (kallpasystem.mysql...)
  6. PythonAnywhere NO permite conexiones MySQL externas directas
  7. get_db_connection() retorna None
  8. TODAS las rutas que necesitan BD retornan error 500

ARCHIVO AFECTADO:
  requirements.txt (paramiko estaba en 5.0.0 en vez de 3.4.0)

SOLUCION:
  Revertir paramiko a version compatible:
    pip install paramiko==3.4.0

  Verificar en requirements.txt que diga:
    paramiko==3.4.0
    sshtunnel==0.4.0

VERIFICACION:
  Verificar version instalada:
    pip show paramiko
    pip show sshtunnel

  Debe mostrar paramiko 3.4.0 y sshtunnel 0.4.0.

================================================================================
CAUSA RAIZ #2: APIs RETORNABAN HTML EN VEZ DE JSON CUANDO FALLABAN
================================================================================

SINTOMA:
  En la consola del navegador (F12) aparecia:
    SyntaxError: Unexpected token '<', "<!doctype "... is not valid JSON

  Esto pasaba porque las llamadas fetch() a /api/* recibian:
  - Redirect 302 al login (HTML) cuando la sesion fallaba
  - Pagina de error 500 de Flask (HTML) cuando la BD fallaba

  El JavaScript intentaba hacer .json() en una respuesta HTML -> SyntaxError.

CAUSA:
  1. El decorator @login_required en cada archivo de rutas verificaba
     si el request era JSON con:
       if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest'
     Pero las llamadas fetch() del sidebar (sidebar-accesos.js) NO enviaban
     ese header, asi que el decorator retornaba un redirect HTML al login.

  2. El error handler 500 original solo retornaba HTML:
       @app.errorhandler(500)
       def handle_500(e):
           return '<h1>500 Internal Server Error</h1>', 500

     No verificaba si la ruta era /api/* para retornar JSON.

ARCHIVOS AFECTADOS:
  - app/__init__.py (error handlers)
  - Todos los archivos de rutas con @login_required (15 archivos)

SOLUCION:
  Agregar en app/__init__.py:

  a) before_request que INTERCEPTA todas las llamadas a /api/* sin sesion
     y SIEMPRE retorna JSON 401 (antes de que cualquier decorator ejecute):

    @app.before_request
    def check_api_auth():
        from flask import request, session, jsonify
        if request.path.startswith('/api/'):
            if 'user_documento' not in session and 'user_email' not in session:
                return jsonify({'success': False, 'error': 'No autenticado'}), 401

  b) Error handlers que SIEMPRE retornan JSON para rutas /api/*:

    @app.errorhandler(500)
    def handle_500(e):
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': str(e)}), 500
        return '<h1>500 Internal Server Error</h1>', 500

    @app.errorhandler(404)
    def handle_404(e):
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': 'Endpoint no encontrado'}), 404
        return '<h1>404 No encontrado</h1>', 404

    @app.errorhandler(405)
    def handle_405(e):
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': 'Metodo no permitido'}), 405
        return '<h1>405 Metodo no permitido</h1>', 405

  c) teardown_request para loggear errores no capturados:

    @app.teardown_request
    def handle_exception(exc):
        if exc is not None and request.path.startswith('/api/'):
            app.logger.error(f"[TEARDOWN ERROR] Path: {request.path} | {exc}")

REGLA PARA FUTUROS DESARROLLOS:
  SIEMPRE que se cree un endpoint /api/*, el error handler debe retornar JSON.
  NUNCA retornar HTML desde un endpoint de API. Los endpoints de API deben
  ser consistentes: exito -> JSON 200, error -> JSON con codigo apropiado.

================================================================================
CAUSA RAIZ #3: PROCESOS PYTHON ZOMBIE BLOQUEANDO EL PUERTO 5000
================================================================================

SINTOMA:
  - Se ejecutaba iniciar.bat pero los cambios no se reflejaban
  - El error 500 persistia incluso despues de "reiniciar"
  - Flask no tenia auto-reload porque DEBUG=False

CAUSA:
  Flask estaba configurado con DEBUG=False (produccion). Sin auto-reload,
  si se ejecutaba iniciar.bat sin cerrar primero la consola anterior,
  el puerto 5000 seguia ocupado por el proceso viejo.

  El nuevo proceso no podia arrancar, pero el navegador seguia conectado
  al proceso viejo (sin los cambios).

SOLUCION:
  1. Matar TODOS los procesos python antes de reiniciar:
       Get-Process python* | Stop-Process -Force
  2. Verificar que el puerto 5000 este libre:
       Get-NetTCPConnection -LocalPort 5000
  3. Iniciar la app

  Para desarrollo, considerar usar DEBUG=True o FLASK_ENV=development
  para tener auto-reload y evitar este problema.

  Alternativa: agregar al final de iniciar.bat:
    taskkill /F /IM python.exe /T 2>nul
    timeout /t 2 /nobreak >nul

================================================================================
ARCHIVOS MODIFICADOS EN ESTA SOLUCION
================================================================================

  1. app/__init__.py
     - Agregado errorhandler(500) con log y retorno JSON para /api/*
     - Agregado errorhandler(404) con retorno JSON para /api/*
     - Agregado errorhandler(405) con retorno JSON para /api/*
     - Agregado before_request check_api_auth() para proteger APIs
     - Agregado teardown_request para loggear errores no capturados

  2. requirements.txt
     - paramiko mantenido en 3.4.0 (ya estaba correcto)

  3. Terminal
     - pip install paramiko==3.4.0 (reemplazando 5.0.0)

================================================================================
COMANDOS DE VERIFICACION RAPIDA
================================================================================

  # Verificar que el SSH tunnel funciona
  python -c "from app.config import get_ssh_tunnel; t = get_ssh_tunnel(); print('OK' if t else 'FAIL')"

  # Verificar que la BD responde
  python -c "
  from app.config import DatabaseConfig
  import mysql.connector
  params = DatabaseConfig.get_connection_params()
  conn = mysql.connector.connect(**params)
  print('BD OK' if conn.is_connected() else 'BD FAIL')
  conn.close()
  "

  # Verificar que las APIs retornan JSON (no HTML)
  curl -v http://127.0.0.1:5000/api/notificaciones/pendientes
  # Debe retornar: {"success": false, "error": "No autenticado"} con status 401
  # NO debe retornar HTML

  # Verificar version de paramiko
  pip show paramiko | findstr Version
  # Debe decir: Version: 3.4.0

================================================================================
LECCIONES APRENDIDAS
================================================================================

  1. SIEMPRE usar versiones fijas de dependencias en requirements.txt
     (paramiko==3.4.0, no paramiko>=3.4.0)

  2. Las APIs SIEMPRE deben retornar JSON, incluso cuando fallan.
     El frontend (JavaScript) espera JSON en todas las respuestas de /api/*.

  3. El error handler 500 de Flask NO distingue entre rutas HTML y API.
     Es responsabilidad del developer retornar el formato correcto.

  4. Cuando DEBUG=False, Flask NO tiene auto-reload. Cualquier cambio
     de codigo requiere reiniciar manualmente el servidor.

  5. Siempre verificar que no hay procesos zombie ocupando el puerto
     antes de iniciar el servidor. En Windows:
       Get-NetTCPConnection -LocalPort 5000

  6. El SSH tunnel a PythonAnywhere solo funciona desde PythonAnywhere
     o via SSH. Desde una maquina local, la conexion directa a MySQL
     NO funciona. SIEMPRE se necesita el tunnel.

  7. Los errores de "SyntaxError: Unexpected token '<'" en JavaScript
     casi siempre significan que una API retorno HTML en vez de JSON.
     Verificar: content-type del response en F12 > Network.

================================================================================
