from flask import Blueprint

# Create blueprints - Solo lo necesario para Kallpa
main_bp = Blueprint('main', __name__)
auth_bp = Blueprint('auth', __name__)

# Import routes after blueprints are created
from . import main, auth, empresa, usuarios, roles, requerimientos, ot, presupuesto, flujo_aprobacion, gerencia, materiales, marcacion, ordenes_compra, memo_pdf, expediente_tecnico
