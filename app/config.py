"""
Configuración de base de datos para Kallpa
Lee las credenciales desde variables de entorno
"""
import os
from dotenv import load_dotenv
import logging
from sshtunnel import SSHTunnelForwarder
import atexit

# Cargar variables de entorno desde .env
load_dotenv()

# Habilitar logs
logging.basicConfig(level=logging.DEBUG)

# Variable global para mantener el túnel SSH activo
ssh_tunnel = None

def get_ssh_tunnel():
    """Obtener o crear el túnel SSH (singleton)"""
    global ssh_tunnel
    
    use_ssh = os.getenv('USE_SSH_TUNNEL', 'False').lower() == 'true'
    
    if not use_ssh:
        return None
    
    # Si ya existe y está activo, retornarlo
    if ssh_tunnel and ssh_tunnel.is_active:
        return ssh_tunnel
    
    # Crear nuevo túnel
    try:
        ssh_host = os.getenv('SSH_HOST', 'ssh.pythonanywhere.com')
        ssh_port = int(os.getenv('SSH_PORT', 22))
        ssh_user = os.getenv('SSH_USER', '')
        ssh_password = os.getenv('SSH_PASSWORD', '')
        db_host = os.getenv('DB_HOST', 'localhost')
        db_port = int(os.getenv('DB_PORT', 3306))
        
        logging.info(f"[SSH TUNNEL] Iniciando túnel SSH a {ssh_host}:{ssh_port}")
        
        ssh_tunnel = SSHTunnelForwarder(
            (ssh_host, ssh_port),
            ssh_username=ssh_user,
            ssh_password=ssh_password,
            remote_bind_address=(db_host, db_port)
        )
        ssh_tunnel.start()
        
        logging.info(f"[SSH TUNNEL] Túnel activo. Puerto local: {ssh_tunnel.local_bind_port}")
        
        # Registrar cierre del túnel al salir
        def close_tunnel():
            global ssh_tunnel
            if ssh_tunnel:
                logging.info("[SSH TUNNEL] Cerrando túnel SSH...")
                ssh_tunnel.stop()
                ssh_tunnel = None
        
        atexit.register(close_tunnel)
        
        return ssh_tunnel
        
    except Exception as e:
        logging.error(f"[SSH TUNNEL] Error al crear túnel: {e}")
        ssh_tunnel = None
        return None

class DatabaseConfig:
    """Configuración de base de datos - KALLPA"""
    HOST = os.getenv('DB_HOST', 'localhost')
    PORT = int(os.getenv('DB_PORT', 3306))
    USER = os.getenv('DB_USER', 'root')
    PASSWORD = os.getenv('DB_PASSWORD', '')
    DATABASE = os.getenv('DB_NAME', 'kallgwkn_kallpa_bd')
    
    # Configuración SSH (opcional)
    USE_SSH_TUNNEL = os.getenv('USE_SSH_TUNNEL', 'False').lower() == 'true'
    
    @classmethod
    def get_connection_params(cls):
        """Retorna diccionario con parámetros de conexión"""
        
        # Intentar obtener túnel SSH si está habilitado
        tunnel = get_ssh_tunnel()
        
        if tunnel and tunnel.is_active:
            # Usar el túnel SSH
            params = {
                'host': '127.0.0.1',
                'port': tunnel.local_bind_port,
                'user': cls.USER,
                'password': cls.PASSWORD,
                'database': cls.DATABASE,
                'ssl_disabled': True,
                'charset': 'utf8mb4',
                'collation': 'utf8mb4_unicode_ci',
                'use_unicode': True
            }
            logging.debug(f"[DB CONFIG] Usando túnel SSH en puerto {tunnel.local_bind_port}")
        else:
            # Conexión directa
            params = {
                'host': cls.HOST,
                'port': cls.PORT,
                'user': cls.USER,
                'password': cls.PASSWORD,
                'database': cls.DATABASE,
                'ssl_disabled': True,
                'charset': 'utf8mb4',
                'collation': 'utf8mb4_unicode_ci',
                'use_unicode': True
            }
            logging.debug(f"[DB CONFIG] Conexión directa a {cls.HOST}:{cls.PORT}")
        
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

