#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Funciones para la gestión de Permisos y Roles
- Crear menús
- Gestionar permisos por rol
- Listar menús
"""

from flask import request
import mysql.connector
from mysql.connector import Error
from app.funciones.funGeneral import get_db_connection


def crear_menu_api():
    """API para crear un nuevo menú en TblMenu usando Stored Procedure"""
    try:
        from flask import jsonify
        
        data = request.get_json() or {}
        
        # Obtener datos (de JSON o form)
        nombre_menu = data.get('nombre_menu', request.form.get('nombre_menu', '')).strip()
        descripcion = data.get('descripcion', request.form.get('descripcion', '')).strip()
        ruta = data.get('ruta', request.form.get('ruta', '')).strip()
        estado = data.get('estado', request.form.get('estado', '')).strip()
        
        # Validar campos requeridos
        if not all([nombre_menu, ruta, estado]):
            return jsonify({'success': False, 'message': 'Faltan campos requeridos (nombre_menu, ruta, estado)'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Usar SP para crear el menú (versión con ruta)
        query = """
            CALL sp_CrearMenu(%s, %s, %s, %s)
        """
        
        cursor.execute(query, (
            nombre_menu,
            descripcion,
            ruta,
            estado
        ))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': 'Menú creado exitosamente',
            'data': {
                'nombre_menu': nombre_menu,
                'ruta': ruta,
                'estado': estado
            }
        }), 201
        
    except Error as e:
        print(f"Error en crear_menu_api: {e}")
        return jsonify({'success': False, 'message': f'Error de BD: {str(e)}'}), 500
    except Exception as e:
        print(f"Error general en crear_menu_api: {e}")
        return jsonify({'success': False, 'message': f'Error del servidor: {str(e)}'}), 500


def listar_menus_api():
    """API para obtener lista de menús"""
    try:
        from flask import jsonify
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Usar SP para obtener menús
        cursor.execute("CALL sp_ListarMenus()")
        menus = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': menus,
            'total': len(menus)
        }), 200
        
    except Error as e:
        print(f"Error en listar_menus_api: {e}")
        return jsonify({'success': False, 'message': f'Error de BD: {str(e)}'}), 500
    except Exception as e:
        print(f"Error general en listar_menus_api: {e}")
        return jsonify({'success': False, 'message': f'Error del servidor: {str(e)}'}), 500


def obtener_todos_menus_y_submenus_api():
    """API para obtener TODOS los menús y submenús disponibles (sin filtrar permisos)
    Usado para el modal de asignación de accesos"""
    try:
        from flask import jsonify
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Obtener todos los menús activos con sus submenús
        query = """
            SELECT 
                m.id_menu,
                m.nombre_menu,
                m.descripcion,
                m.ruta,
                m.estado,
                sm.id_submenu,
                sm.nombre_submenu,
                sm.descripcion AS submenu_descripcion,
                sm.icono,
                sm.orden
            FROM TblMenu m
            LEFT JOIN TblSubMenu sm ON m.id_menu = sm.id_menu 
                AND sm.estado = 'Activo'
            WHERE m.estado = 'Activo'
            ORDER BY m.nombre_menu, sm.orden, sm.nombre_submenu
        """
        
        cursor.execute(query)
        rows = cursor.fetchall()
        
        # Consolidar estructura jerárquica
        menus_dict = {}
        
        for row in rows:
            menu_id = row['id_menu']
            
            if menu_id not in menus_dict:
                menus_dict[menu_id] = {
                    'id_menu': menu_id,
                    'nombre_menu': row['nombre_menu'],
                    'descripcion': row['descripcion'],
                    'ruta': row['ruta'],
                    'estado': row['estado'],
                    'submenus': []
                }
            
            # Agregar submenú si existe
            if row['id_submenu'] is not None:
                submenu_data = {
                    'id_submenu': row['id_submenu'],
                    'nombre_submenu': row['nombre_submenu'],
                    'descripcion': row['submenu_descripcion'],
                    'icono': row['icono'],
                    'orden': row['orden']
                }
                menus_dict[menu_id]['submenus'].append(submenu_data)
        
        # Convertir a lista
        menus = sorted(menus_dict.values(), key=lambda x: x['nombre_menu'])
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': menus,
            'total_menus': len(menus)
        }), 200
        
    except Error as e:
        print(f"Error en obtener_todos_menus_y_submenus_api: {e}")
        return jsonify({'success': False, 'message': f'Error de BD: {str(e)}'}), 500
    except Exception as e:
        print(f"Error general en obtener_todos_menus_y_submenus_api: {e}")
        return jsonify({'success': False, 'message': f'Error del servidor: {str(e)}'}), 500


def obtener_menu_por_id_api(id_menu):
    """API para obtener datos de un menú específico"""
    try:
        connection = get_db_connection()
        if not connection:
            return {'success': False, 'message': 'Error de conexion'}, 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Usar SP para obtener menú
        cursor.execute("CALL sp_ObtenerMenu(%s)", (id_menu,))
        menu = cursor.fetchone()
        
        cursor.close()
        connection.close()
        
        if not menu:
            return {'success': False, 'message': 'Menú no encontrado'}, 404
        
        return {
            'success': True,
            'data': menu
        }, 200
        
    except Error as e:
        print(f"Error en obtener_menu_por_id_api: {e}")
        return {'success': False, 'message': f'Error: {str(e)}'}, 500
    except Exception as e:
        print(f"Error general en obtener_menu_por_id_api: {e}")
        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500


def actualizar_menu_api(id_menu):
    """API para actualizar un menú existente"""
    try:
        connection = get_db_connection()
        if not connection:
            return {'success': False, 'message': 'Error de conexion'}, 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Obtener datos del formulario
        nombre_menu = request.form.get('nombre_menu')
        descripcion = request.form.get('descripcion', '')
        icono = request.form.get('icono')
        url = request.form.get('url')
        orden = request.form.get('orden')
        estado = request.form.get('estado')
        
        # Validar campos requeridos
        if not all([nombre_menu, icono, url, orden, estado]):
            cursor.close()
            connection.close()
            return {'success': False, 'message': 'Faltan campos requeridos'}, 400
        
        # Usar SP para actualizar el menú
        query = """
            CALL sp_ActualizarMenu(%s, %s, %s, %s, %s, %s, %s)
        """
        
        cursor.execute(query, (
            id_menu,
            nombre_menu,
            descripcion,
            icono,
            url,
            int(orden),
            estado
        ))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': 'Menú actualizado exitosamente'
        }, 200
        
    except Error as e:
        print(f"Error en actualizar_menu_api: {e}")
        return {'success': False, 'message': f'Error: {str(e)}'}, 500
    except Exception as e:
        print(f"Error general en actualizar_menu_api: {e}")
        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500


def eliminar_menu_api(id_menu):
    """API para eliminar un menú"""
    try:
        connection = get_db_connection()
        if not connection:
            return {'success': False, 'message': 'Error de conexion'}, 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Usar SP para eliminar el menú
        cursor.execute("CALL sp_EliminarMenu(%s)", (id_menu,))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': 'Menú eliminado exitosamente'
        }, 200
        
    except Error as e:
        print(f"Error en eliminar_menu_api: {e}")
        return {'success': False, 'message': f'Error: {str(e)}'}, 500
    except Exception as e:
        print(f"Error general en eliminar_menu_api: {e}")
        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500


def asignar_permiso_rol_api():
    """API para asignar permisos a un rol"""
    try:
        connection = get_db_connection()
        if not connection:
            return {'success': False, 'message': 'Error de conexion'}, 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Obtener datos del formulario
        id_rol = request.form.get('id_rol')
        id_menu = request.form.get('id_menu')
        tipo_acceso = request.form.get('tipo_acceso')
        
        # Validar campos requeridos
        if not all([id_rol, id_menu, tipo_acceso]):
            cursor.close()
            connection.close()
            return {'success': False, 'message': 'Faltan campos requeridos'}, 400
        
        # Usar SP para asignar permiso
        query = """
            CALL sp_AsignarPermisoRol(%s, %s, %s)
        """
        
        cursor.execute(query, (
            int(id_rol),
            int(id_menu),
            tipo_acceso
        ))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'message': 'Permiso asignado exitosamente'
        }, 200
        
    except Error as e:
        print(f"Error en asignar_permiso_rol_api: {e}")
        return {'success': False, 'message': f'Error: {str(e)}'}, 500
    except Exception as e:
        print(f"Error general en asignar_permiso_rol_api: {e}")
        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500


def listar_permisos_rol_api(id_rol):
    """API para obtener permisos de un rol específico"""
    try:
        connection = get_db_connection()
        if not connection:
            return {'success': False, 'message': 'Error de conexion'}, 500
        
        cursor = connection.cursor(dictionary=True)
        
        # Usar SP para obtener permisos del rol
        cursor.execute("CALL sp_ListarPermisosRol(%s)", (id_rol,))
        permisos = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return {
            'success': True,
            'data': permisos,
            'total': len(permisos)
        }, 200
        
    except Error as e:
        print(f"Error en listar_permisos_rol_api: {e}")
        return {'success': False, 'message': f'Error: {str(e)}'}, 500
    except Exception as e:
        print(f"Error general en listar_permisos_rol_api: {e}")
        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500



def crear_submenu_api():
    """API para crear un nuevo submenú en TblSubMenu"""
    try:
        from flask import jsonify
        
        data = request.get_json() or {}
        
        # Obtener datos (de JSON o form)
        id_menu = data.get('id_menu', request.form.get('id_menu', ''))
        nombre_submenu = data.get('nombre_submenu', request.form.get('nombre_submenu', '')).strip()
        descripcion = data.get('descripcion', request.form.get('descripcion', '')).strip()
        icono = data.get('icono', request.form.get('icono', 'circle')).strip()
        orden = data.get('orden', request.form.get('orden', '1')).strip()
        estado = data.get('estado', request.form.get('estado', 'Activo')).strip()
        
        # Validar campos requeridos
        if not all([id_menu, nombre_submenu]):
            return jsonify({'success': False, 'message': 'Faltan campos requeridos (id_menu, nombre_submenu)'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Insertar directamente (sin ruta)
            query = """
                INSERT INTO TblSubMenu (id_menu, nombre_submenu, descripcion, icono, orden, estado)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            cursor.execute(query, (
                int(id_menu),
                nombre_submenu,
                descripcion,
                icono,
                int(orden),
                estado
            ))
            
            connection.commit()
            
        except Error as e:
            connection.rollback()
            raise e
        finally:
            cursor.close()
            connection.close()
        
        return jsonify({
            'success': True,
            'message': 'SubMenú creado exitosamente',
            'data': {
                'nombre_submenu': nombre_submenu,
                'estado': estado
            }
        }), 201
        
    except ValueError as e:
        print(f"Error de validación: {e}")
        return jsonify({'success': False, 'message': 'Valores inválidos'}), 400
    except Error as e:
        print(f"Error en crear_submenu_api: {e}")
        
        # Mensajes de error más específicos
        if "1062" in str(e):
            return jsonify({'success': False, 'message': f'Error: Submenú duplicado'}), 400
        elif "1054" in str(e):
            return jsonify({'success': False, 'message': 'Error: Campo no existe en la tabla'}), 400
        else:
            return jsonify({'success': False, 'message': f'Error de BD: {str(e)}'}), 500
    except Exception as e:
        print(f"Error general en crear_submenu_api: {e}")
        return jsonify({'success': False, 'message': f'Error del servidor: {str(e)}'}), 500


# ============================================================================
# Función para obtener menús y submenús del usuario usando SP
# ============================================================================

def obtener_menus_usuario_api(num_documento):
    """API para obtener los permisos del usuario usando SP"""
    try:
        from flask import jsonify, current_app
        
        current_app.logger.info(f"obtener_menus_usuario_api: Solicitado para {num_documento}")
        
        connection = get_db_connection()
        if not connection:
            current_app.logger.error("No hay conexión a BD")
            return jsonify({'success': False, 'message': 'Error de conexión'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Usar SP para obtener permisos del usuario
            current_app.logger.info(f"Ejecutando CALL sp_ObtenerPermisosUsuario({num_documento})")
            cursor.execute("CALL sp_ObtenerPermisosUsuario(%s)", (num_documento,))
            rows = cursor.fetchall()
            
            current_app.logger.info(f"SP retornó {len(rows)} filas")
            
            # Consumir otros result sets si existen
            try:
                while cursor.nextset():
                    pass
            except Exception as e:
                current_app.logger.warning(f"Error consumiendo result sets: {e}")
                pass
            
            # Si no hay filas, retornar lista vacía
            if not rows:
                current_app.logger.info(f"No hay filas para {num_documento}")
                return jsonify({
                    'success': True,
                    'data': [],
                    'total_menus': 0
                }), 200
            
            # Consolidar la estructura jerárquica: Menú > Submenús
            menus_dict = {}
            
            for row in rows:
                try:
                    menu_id = row.get('id_menu')
                    if menu_id is None:
                        continue
                    
                    # Si el menú no existe en el diccionario, crearlo
                    if menu_id not in menus_dict:
                        menus_dict[menu_id] = {
                            'id_menu': menu_id,
                            'nombre_menu': row.get('nombre_menu', ''),
                            'descripcion': row.get('descripcion', ''),
                            'ruta': row.get('ruta', ''),
                            'estado': row.get('estado', ''),
                            'submenus': []
                        }
                    
                    # Agregar submenú si existe
                    id_submenu = row.get('id_submenu')
                    if id_submenu is not None:
                        submenu_data = {
                            'id_submenu': id_submenu,
                            'nombre_submenu': row.get('nombre_submenu', ''),
                            'descripcion': row.get('submenu_descripcion', ''),
                            'ruta': None,
                            'icono': row.get('icono', 'circle'),
                            'orden': row.get('orden', 0),
                            'permitido': row.get('permitido', 0)
                        }
                        menus_dict[menu_id]['submenus'].append(submenu_data)
                except Exception as row_error:
                    current_app.logger.error(f"Error procesando fila: {row_error}")
                    continue
            
            # Convertir a lista y ordenar
            menus = sorted(menus_dict.values(), key=lambda x: x['nombre_menu'])
            
            current_app.logger.info(f"Retornando {len(menus)} menús")
            
            return jsonify({
                'success': True,
                'data': menus,
                'total_menus': len(menus)
            }), 200
        
        finally:
            cursor.close()
            connection.close()
        
    except Exception as e:
        import traceback
        current_app.logger.error(f"Error en obtener_menus_usuario_api: {str(e)}")
        current_app.logger.error(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Error: {str(e)}'}), 500


def asignar_multiples_submenus_usuario_api():
    """API para asignar múltiples submenús a un usuario usando SP"""
    try:
        from flask import jsonify
        import json
        
        data = request.get_json() or {}
        
        num_documento = data.get('num_documento', '').strip()
        submenus = data.get('submenus', [])
        
        print(f"\n[INICIO] Asignando permisos")
        print(f"[INPUT] num_documento: {num_documento}")
        print(f"[INPUT] submenus recibidos: {submenus}")
        
        if not num_documento or not submenus or not isinstance(submenus, list):
            print(f"[ERROR] Validación fallida")
            return jsonify({'success': False, 'message': 'Faltan campos requeridos (num_documento, submenus)'}), 400
        
        if len(submenus) == 0:
            print(f"[ERROR] Lista de submenús vacía")
            return jsonify({'success': False, 'message': 'No hay submenús para asignar'}), 400
        
        connection = get_db_connection()
        if not connection:
            print(f"[ERROR] No hay conexión a BD")
            return jsonify({'success': False, 'message': 'Error de conexión a base de datos'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        try:
            # Verificar usuario
            print(f"[PASO 1] Verificando usuario {num_documento} en TblUsuarios...")
            cursor.execute("SELECT num_documento FROM TblUsuarios WHERE num_documento = %s", (num_documento,))
            user_result = cursor.fetchone()
            
            if not user_result:
                cursor.close()
                connection.close()
                print(f"[ERROR] Usuario {num_documento} no encontrado en TblUsuarios")
                return jsonify({'success': False, 'message': f'Usuario {num_documento} no existe en TblUsuarios'}), 400
            
            print(f"[PASO 1] ✓ Usuario encontrado")
            
            # Convertir submenús a JSON con ensure_ascii=False para UTF-8
            submenus_json = json.dumps(submenus, ensure_ascii=False)
            print(f"[PASO 2] Convertiendo a JSON...")
            print(f"[DEBUG] JSON: {submenus_json}")
            
            # Llamar el SP
            print(f"[PASO 3] Llamando SP sp_AsignarPermisosUsuario...")
            cursor.execute("CALL sp_AsignarPermisosUsuario(%s, %s)", (num_documento, submenus_json))
            
            # Obtener resultado del SP
            result = cursor.fetchone()
            print(f"[PASO 3] ✓ Resultado del SP: {result}")
            
            connection.commit()
            print(f"[PASO 4] ✓ Transacción confirmada (COMMIT)")
            
            # Verificar qué se guardó en la BD
            print(f"[PASO 5] Verificando datos guardados en TblUsuarioPermisos...")
            cursor.execute("""
                SELECT id_usuario_permiso, num_documento, id_submenu, permitido, fecha_creacion 
                FROM TblUsuarioPermisos 
                WHERE num_documento = %s
            """, (num_documento,))
            saved_permissions = cursor.fetchall()
            print(f"[PASO 5] Registros guardados: {len(saved_permissions)}")
            for perm in saved_permissions:
                print(f"  - ID: {perm['id_usuario_permiso']}, Submenú: {perm['id_submenu']}, Permitido: {perm['permitido']}")
            
            cursor.close()
            connection.close()
            
            print(f"[ÉXITO] Operación completada\n")
            
            # Retornar éxito con detalles (jsonify ya maneja UTF-8 correctamente)
            return jsonify({
                'success': True,
                'message': f'Permisos asignados exitosamente al usuario {num_documento}',
                'data': {
                    'usuario': num_documento,
                    'permisos_asignados': len([s for s in submenus if s.get('permitido') == 1]),
                    'total_en_base_datos': len(saved_permissions)
                }
            }), 200
        
        except Exception as e:
            cursor.close()
            connection.close()
            print(f"[ERROR] Excepción: {str(e)}")
            import traceback
            traceback.print_exc()
            # Asegurar que el mensaje de error también sea UTF-8
            error_message = str(e).encode('utf-8', errors='replace').decode('utf-8')
            return jsonify({'success': False, 'message': f'Error al asignar permisos: {error_message}'}), 500
        
    except Exception as e:
        print(f"[ERROR] General: {e}")
        import traceback
        traceback.print_exc()
        # Asegurar que el mensaje de error también sea UTF-8
        error_message = str(e).encode('utf-8', errors='replace').decode('utf-8')
        return jsonify({'success': False, 'message': f'Error general: {error_message}'}), 500
