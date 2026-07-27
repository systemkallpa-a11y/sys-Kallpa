#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Funciones generales compartidas para Kallpa
- Conexión a BD
- Hash de passwords
- Utilidades generales
"""

import mysql.connector
from mysql.connector import Error
import hashlib
from app.config import DatabaseConfig


def get_db_connection():
    """Crear conexión a la base de datos Kallpa"""
    try:
        params = DatabaseConfig.get_connection_params()
        connection = mysql.connector.connect(
            **params,
            connection_timeout=30,
            auth_plugin='mysql_native_password',
            ssl_disabled=True,
            use_pure=False
        )
        connection.reset_session()
        return connection
    except Exception as e:
        print(f"Error de conexión: {str(e)}")
        # Reintentar con use_pure=True
        try:
            params = DatabaseConfig.get_connection_params()
            connection = mysql.connector.connect(
                **params,
                connection_timeout=30,
                auth_plugin='mysql_native_password',
                ssl_disabled=True,
                use_pure=True
            )
            connection.reset_session()
            return connection
        except Exception as e2:
            print(f"Error de conexión (reintento): {str(e2)}")
            return None


def hash_password(password):
    """Encriptar contraseña usando SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()
