# -*- coding: utf-8 -*-
import sys
import io

# Fix Windows console encoding for Unicode/emoji in logs
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

from flask import Flask
import os
import logging
from logging.handlers import RotatingFileHandler

# Intentar cargar .env si existe (para Namecheap)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv no instalado, continuar sin l

def create_app():
    app = Flask(__name__, template_folder='templates', static_folder='static', static_url_path='/static')
    
    # Forzar UTF-8 para todas las respuestas
    app.config['JSON_AS_ASCII'] = False
    app.config['BABEL_DEFAULT_LOCALE'] = 'es'
    app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')
    
    # Configurar cookies para evitar problemas de compresin
    app.config['SESSION_COOKIE_HTTPONLY'] = True
    # En desarrollo local sin HTTPS, permitir cookies HTTP
    app.config['SESSION_COOKIE_SECURE'] = False  # HTTP local
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
    app.config['SESSION_COOKIE_AGE'] = 3600  # 1 hora
    app.config['COMPRESS_RESPONSE'] = False
    # No usar modo production para desarrollo local
    # app.config['ENV'] = 'production'
    # app.config['FLASK_ENV'] = 'production'
    app.config['PRESERVE_CONTEXT_ON_EXCEPTION'] = False
    app.config['JSON_SORT_KEYS'] = False
    
    # VERSION DE ASSETS - Incrementar este nmero cuando se actualicen archivos estticos
    app.config['ASSETS_VERSION'] = '20260813_2'

    # Configurar logging
    if not app.debug:
        # Crear directorio de logs si no existe
        log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        
        # Archivo de log con rotacin (10MB mximo, mantener 5 backups)
        log_file = os.path.join(log_dir, 'kallpa_app.log')
        file_handler = RotatingFileHandler(log_file, maxBytes=10240000, backupCount=5, encoding='utf-8')
        file_handler.setFormatter(logging.Formatter(
            '[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
        ))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)
        
        app.logger.setLevel(logging.INFO)
        app.logger.info('Kallpa Application startup')
    
    # Register blueprints - Solo lo necesario para Kallpa
    from app.routes import main_bp, auth_bp
    from app.routes.presupuesto_pdf import pdf_bp
    from app.routes.requerimientos_pdf import requerimientos_pdf_bp
    from app.routes.empresa_logo import logo_bp
    from app.routes.materiales import materiales_bp
    from app.routes.marcacion import marcacion_bp
    from app.routes.memo_pdf import memo_pdf_bp
    
    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(pdf_bp)
    app.register_blueprint(requerimientos_pdf_bp)
    app.register_blueprint(logo_bp)
    app.register_blueprint(materiales_bp)
    app.register_blueprint(marcacion_bp)
    app.register_blueprint(memo_pdf_bp)
    
    # Inyectar versin de assets en todos los templates
    @app.context_processor
    def inject_assets_version():
        return {'assets_version': app.config.get('ASSETS_VERSION', '1')}
    
    # Asegurar que todas las respuestas HTML tengan charset UTF-8
    @app.after_request
    def set_utf8_charset(response):
        if 'Content-Type' in response.headers:
            content_type = response.headers['Content-Type']
            if 'text/html' in content_type and 'charset' not in content_type:
                response.headers['Content-Type'] = content_type + '; charset=utf-8'
        return response
    
    # Error handlers: SIEMPRE retornar JSON para rutas /api/*
    @app.errorhandler(500)
    def handle_500(e):
        import traceback
        from flask import jsonify, request
        app.logger.error(f"[500 ERROR] Path: {request.path} | Error: {e}")
        app.logger.error(f"[500 ERROR] Traceback: {traceback.format_exc()}")
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': str(e)}), 500
        return '<h1>500 Internal Server Error</h1><p>Revisa los logs para mas detalles.</p>', 500

    @app.errorhandler(404)
    def handle_404(e):
        from flask import jsonify, request
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': 'Endpoint no encontrado'}), 404
        return '<h1>404 No encontrado</h1>', 404

    @app.errorhandler(405)
    def handle_405(e):
        from flask import jsonify, request
        if request.path.startswith('/api/'):
            return jsonify({'success': False, 'error': 'Metodo no permitido'}), 405
        return '<h1>405 Metodo no permitido</h1>', 405

    # Interceptar requests a /api/* sin sesion - SIEMPRE retornar JSON
    @app.before_request
    def check_api_auth():
        from flask import request, session, jsonify
        if request.path.startswith('/api/'):
            if 'user_documento' not in session and 'user_email' not in session:
                return jsonify({'success': False, 'error': 'No autenticado'}), 401

    # Capturar errores no manejados y retornar JSON para APIs
    @app.teardown_request
    def handle_exception(exc):
        import traceback as tb
        from flask import request, jsonify, g
        if exc is not None and request.path.startswith('/api/'):
            app.logger.error(f"[TEARDOWN ERROR] Path: {request.path} | {exc}")
            app.logger.error(f"[TEARDOWN ERROR] Traceback: {tb.format_exc()}")

    return app
