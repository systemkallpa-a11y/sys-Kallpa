"""
Configuración de base de datos para Kallpa
Lee las credenciales desde variables de entorno
"""
import os
from dotenv import load_dotenv
import logging

# Cargar variables de entorno desde .env
load_dotenv()

# Habilitar logs
logging.basicConfig(level=logging.DEBUG)

class DatabaseConfig:
    """Configuración de base de datos - KALLPA"""
    HOST = os.getenv('DB_HOST', 'localhost')
    PORT = int(os.getenv('DB_PORT', 3306))
    USER = os.getenv('DB_USER', 'root')
    PASSWORD = os.getenv('DB_PASSWORD', '')
    DATABASE = os.getenv('DB_NAME', 'kallgwkn_kallpa_bd')
    
    @classmethod
    def get_connection_params(cls):
        """Retorna diccionario con parámetros de conexión"""
        params = {
            'host': cls.HOST,
            'port': cls.PORT,
            'user': cls.USER,
            'password': cls.PASSWORD,
            'database': cls.DATABASE,
            'ssl_disabled': True,
        }
        
        return params


class DatabaseConfigKallpa:
    """Configuración de base de datos - KALLPA"""
    HOST = os.getenv('DB_KALLPA_HOST', 'localhost')
    PORT = int(os.getenv('DB_KALLPA_PORT', 3306))
    USER = os.getenv('DB_KALLPA_USER', 'root')
    PASSWORD = os.getenv('DB_KALLPA_PASSWORD', '')
    DATABASE = os.getenv('DB_KALLPA_NAME', 'kallgwkn_kallpa_bd')
    
    @classmethod
    def get_connection_params(cls):
        """Retorna diccionario con parámetros de conexión"""
        params = {
            'host': cls.HOST,
            'port': cls.PORT,
            'user': cls.USER,
            'password': cls.PASSWORD,
            'database': cls.DATABASE,
            'ssl_disabled': True,
        }
        
        return params

