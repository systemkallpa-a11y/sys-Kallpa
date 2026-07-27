import sys
import os

# Agregar el directorio de la app al path de Python
app_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, app_dir)

# Importar la aplicación Flask desde main.py
from main import app

# La variable 'application' es requerida por Passenger
application = app
