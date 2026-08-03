# -*- coding: utf-8 -*-
from flask import Flask
import os
import logging
from logging.handlers import RotatingFileHandler

# Intentar cargar .env si existe (para Namecheap)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv no instalado, continuar sin él

def create_app():
    app = Flask(__name__, template_folder='templates', static_folder='static', static_url_path='/static')
    
    # Forzar UTF-8 para todas las respuestas
    app.config['JSON_AS_ASCII'] = False
    app.config['BABEL_DEFAULT_LOCALE'] = 'es'
    app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-in-production')
    
    # Configurar cookies para evitar problemas de compresión
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
    
    # Configurar logging
    if not app.debug:
        # Crear directorio de logs si no existe
        log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'logs')
        if not os.path.exists(log_dir):
            os.makedirs(log_dir)
        
        # Archivo de log con rotación (10MB máximo, mantener 5 backups)
        log_file = os.path.join(log_dir, 'kallpa_app.log')
        file_handler = RotatingFileHandler(log_file, maxBytes=10240000, backupCount=5)
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
    
    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(pdf_bp)
    app.register_blueprint(requerimientos_pdf_bp)
    app.register_blueprint(logo_bp)
    app.register_blueprint(materiales_bp)
    
    # Asegurar que todas las respuestas HTML tengan charset UTF-8
    @app.after_request
    def set_utf8_charset(response):
        if 'Content-Type' in response.headers:
            content_type = response.headers['Content-Type']
            if 'text/html' in content_type and 'charset' not in content_type:
                response.headers['Content-Type'] = content_type + '; charset=utf-8'
        return response
    
    return app
