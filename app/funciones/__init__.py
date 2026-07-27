#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Modulo de funciones de negocio para Kallpa
Estructura modular con interfaces
"""

# Importar desde interfaces modulares
from .funGeneral import (
    get_db_connection,
    hash_password,
    get_departamentos,
    get_provincias,
    get_distritos,
    get_roles,
    get_areas,
    get_cargos,
    get_fuentes_contacto_api,
    get_proyectos_api,
    get_estados_prospeccion_api,
    get_tipos_compra_api
)

from .clientes import (
    insertar_cliente_api,
    listar_clientes_api,
    listar_todos_clientes_api,
    eliminar_cliente_api,
    obtener_cliente_por_documento_api,
    actualizar_cliente_api,
    registrar_seguimiento_api,
    listar_seguimientos_cliente_api,
    listar_tipos_seguimiento_api
)

from .register_user import (
    register_asesor_api,
    buscar_usuario_por_documento,
    update_asesor_api,
    cambiar_contrasena_api,
    delete_asesor_api,
    get_usuarios_asesores,
    get_asesor_by_documento
)

__all__ = [
    # Funciones generales
    'get_db_connection',
    'hash_password',
    'get_departamentos',
    'get_provincias',
    'get_distritos',
    'get_roles',
    'get_areas',
    'get_cargos',
    'get_fuentes_contacto_api',
    'get_proyectos_api',
    'get_estados_prospeccion_api',
    'get_tipos_compra_api',
    # Funciones de clientes
    'insertar_cliente_api',
    'listar_clientes_api',
    'listar_todos_clientes_api',
    'eliminar_cliente_api',
    'obtener_cliente_por_documento_api',
    'actualizar_cliente_api',
    # Funciones de usuarios/asesores
    'register_asesor_api',
    'buscar_usuario_por_documento',
    'update_asesor_api',
    'cambiar_contrasena_api',
    'delete_asesor_api',
    'get_usuarios_asesores',
    'get_asesor_by_documento',
    # Funciones de seguimientos
    'registrar_seguimiento_api',
    'listar_seguimientos_cliente_api',
    'listar_tipos_seguimiento_api'
]
