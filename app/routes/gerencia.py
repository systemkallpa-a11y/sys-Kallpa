"""
MÓDULO: Gerencia
DESCRIPCIÓN: Rutas y funciones para el módulo de Gerencia
"""

from flask import render_template, request, jsonify, session, flash, redirect, url_for
from . import main_bp
from functools import wraps
from .main import validar_acceso_usuario

# Decorador para requerir autenticación
def login_required(f):
    """Decorador para proteger rutas que requieren autenticación"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_documento' not in session and 'user_email' not in session:
            if request.is_json or request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return {'success': False, 'message': 'No autenticado'}, 401
            flash('Debes iniciar sesión', 'warning')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


# ============================================================================
# RUTA PRINCIPAL: PROCESO DE ABASTECIMIENTO
# ============================================================================

@main_bp.route('/proceso-de-abastecimiento')
@login_required
def proceso_abastecimiento():
    """Página principal de Proceso de Abastecimiento"""
    num_documento = session.get('user_documento')
    
    print(f"\n{'='*80}")
    print(f"[PROCESO_ABASTECIMIENTO_ACCESS] Validando acceso")
    print(f"[PROCESO_ABASTECIMIENTO_ACCESS] Documento: {num_documento}")
    print(f"{'='*80}")
    
    # Validar acceso - Menú Gerencia (ID a confirmar), Submenu Proceso Abastecimiento
    # Por ahora lo dejamos como acceso libre para pruebas
    tiene_acceso = True
    
    if not tiene_acceso:
        print(f"[PROCESO_ABASTECIMIENTO_ACCESS] ❌ ACCESO DENEGADO")
        flash('No tienes acceso a Proceso de Abastecimiento', 'danger')
        return redirect(url_for('main.dashboard'))
    
    print(f"[PROCESO_ABASTECIMIENTO_ACCESS] ✅ ACCESO PERMITIDO")
    print(f"{'='*80}\n")
    
    return render_template('gerencia/proceso_abastecimiento.html')


# ============================================================================
# ENDPOINTS API - PLACEHOLDER
# ============================================================================

@main_bp.route('/api/gerencia/proceso-abastecimiento/obtener', methods=['GET'])
@login_required
def obtener_procesos_abastecimiento():
    """Obtener lista de procesos de abastecimiento"""
    try:
        # Por ahora retorna datos de ejemplo
        datos = {
            'success': True,
            'data': []
        }
        return jsonify(datos), 200
    except Exception as e:
        print(f"[PROCESO_ABASTECIMIENTO] Error: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500
