#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modulo de funciones de negocio para Kallpa
Estructura modular con interfaces
"""

# Importar desde funciones generales
from .funGeneral import (
    get_db_connection,
    hash_password,
    login_required
)

# Importar validaciones de flujo
from .validar_flujo_aprobacion import validar_flujo_completo

__all__ = [
    # Funciones generales
    'get_db_connection',
    'hash_password',
    'login_required',
    # Validaciones
    'validar_flujo_completo'
]
