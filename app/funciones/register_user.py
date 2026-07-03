#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""

Funciones para gestion de usuarios y asesores

- Registrar asesor

- Buscar usuario por documento

- Actualizar asesor

- Cambiar contrasena

- Eliminar asesor

- Listar asesores

- Obtener asesor por documento

"""



from flask import request, session, current_app

from mysql.connector import Error

import re

from .funGeneral import get_db_connection, hash_password

def safe_print(*args, **kwargs):
    """Print con manejo de encoding para evitar UnicodeEncodeError"""
    try:
        print(*args, **kwargs)
    except:
        pass  # Ignorar errores de encoding en logs




def register_asesor_api():

    """API para registrar un nuevo asesor desde el modal"""

    try:

        data = request.get_json()

        

        print("=" * 80)

        # print("DEBUG: Datos recibidos en el servidor:")

        # Log de data omitido - puede contener caracteres especiales

        print("=" * 80)

        

        # NUEVO: Obtener documento de jerarquia del formulario

        num_documento_jerarquia = data.get('num_documento_jerarquia', '').strip()

        

        # Si no se proporciono documento de jerarquia, usar el usuario logueado como padre

        if num_documento_jerarquia:

            num_documento_creador = num_documento_jerarquia

        else:

            # Obtener del usuario logueado en session

            num_documento_creador = session.get('user_num_documento', None)

        

        # print(f"DEBUG: Documento jerarquia (padre): {num_documento_creador}")

        if num_documento_creador is None:

            # print("DEBUG: Sin padre - sera nivel 0 (nivel mas alto en jerarquia)")

            pass

        else:

            # print(f"DEBUG: Con padre {num_documento_creador} - sera un subnivel")

            pass

        

        # Obtener datos del formulario

        num_documento = data.get('num_documento', '').strip().upper()

        tipo_documento = data.get('tipo_documento', 'DNI').upper()

        nombres = data.get('nombres', '').strip().upper()

        apellido_paterno = data.get('apellido_paterno', '').strip().upper()

        apellido_materno = data.get('apellido_materno', '').strip().upper()

        fecha_nacimiento = data.get('fecha_nacimiento', '').strip() or None

        estado_civil = data.get('estado_civil', '').strip() or None

        email = data.get('email', '').strip().lower()

        celular = data.get('celular', '').strip()

        numero_emergencia = data.get('numero_emergencia', '').strip()

        direccion = data.get('direccion', '').strip().upper()

        

        # NUEVO: Obtener NOMBRES en lugar de IDs
        rol_nombre = data.get('rol_nombre', '').strip()
        cargo_nombre = data.get('cargo_nombre', '').strip()

        

        genero = data.get('genero', '').strip()

        

        # print(f"DEBUG: Datos procesados:")

        # print(f"  num_documento: '{num_documento}'")

        # print(f"  email: '{email}'")

        # Omitidos apellidos del log por codificacion ASCII

        # print(f"  fecha_nacimiento: '{fecha_nacimiento}'")

        # print(f"  estado_civil: '{estado_civil}'")

        # print(f"  email: '{email}'")

        # print(f"  genero: '{genero}'")

        # Log omitido - puede contener caracteres especiales

        # Log omitido - puede contener caracteres especiales

        # Log omitido - puede contener caracteres especiales

        

        # Validar campos requeridos

        if not all([num_documento, nombres, apellido_paterno, email, rol_nombre, cargo_nombre]):

            # print("  ERROR: Faltan campos requeridos")

            # print(f"  num_documento: {bool(num_documento)}")

            # print(f"  email: {bool(email)}")

            # Omitido apellido_paterno del log por codificacion ASCII

            # print(f"  email: {bool(email)}")

            # Log omitido - puede contener caracteres especiales

            # Log omitido - puede contener caracteres especiales

            return {'success': False, 'message': 'Por favor completa los campos requeridos'}, 400

        

        # Validar formato de email

        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

        if not re.match(email_pattern, email):

            print(f"  ERROR: Email invalido: {email}")

            return {'success': False, 'message': 'Formato de email invalido'}, 400

        

        # Validar longitud de documento

        if len(num_documento) < 8:

            print(f"  ERROR: Documento muy corto: {num_documento}")

            return {'success': False, 'message': 'El numero de documento debe tener al menos 8 caracteres'}, 400

        

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion con la base de datos'}, 500

        

        try:

            cursor = connection.cursor(dictionary=True)

            

            # La contraseña es el num_documento

            password_hash = hash_password(num_documento)

            

            # print(f"DEBUG: Password hash generado")

            

            # Obtener datos de ubicacion geografica (Departamento, Provincia, Distrito)
            # Ahora el frontend envia: departamento_nombre, provincia_nombre, distrito_nombre
            departamento = data.get('departamento_nombre', data.get('departamento', '')).strip().upper()
            provincia = data.get('provincia_nombre', data.get('provincia', '')).strip().upper()
            distrito = data.get('distrito_nombre', data.get('distrito', '')).strip().upper()
            
            # print(f"DEBUG: Ubicacion recibida - Depto: {departamento}, Prov: {provincia}, Dist: {distrito}")
            
            if not all([departamento, provincia, distrito]):

                # print("  ERROR: Faltan datos de ubicación")

                return {'success': False, 'message': 'Departamento, Provincia y Distrito son requeridos'}, 400

            
            # Obtener area_resumen desde los datos
            area_resumen = data.get('area_resumen', '').strip()
            id_area = data.get('id_area', '').strip()
            
            if not area_resumen and id_area:
                # Si no viene el nombre del area, buscarlo en la BD usando el ID
                try:
                    conexion_area = get_db_connection()
                    if conexion_area:
                        cursor_area = conexion_area.cursor(dictionary=True)
                        cursor_area.execute("SELECT nombre_resumen FROM TblAreas WHERE id_area = %s AND estado = 'Activo' LIMIT 1", (int(id_area),))
                        resultado_area = cursor_area.fetchone()
                        cursor_area.close()
                        conexion_area.close()
                        
                        if resultado_area:
                            area_resumen = resultado_area['nombre_resumen'].strip()
                            try:
                                print(f"DEBUG: Area obtenida desde ID {id_area}: {area_resumen}")
                            except:
                                pass
                        else:
                            area_resumen = 'Ventas'
                    else:
                        area_resumen = 'Ventas'
                except Exception as e:
                    try:
                        print(f"DEBUG: Error al buscar area: {e}")
                    except:
                        pass
                    area_resumen = 'Ventas'
            elif not area_resumen:
                area_resumen = 'Ventas'
            
            # print(f"DEBUG: area_resumen final: {area_resumen}")

            # Llamar al Stored Procedure

            query = """
                CALL sp_RegistrarAsesor(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s,
                    @p_usuario, @p_registrado, @p_mensaje
                );
                SELECT @p_usuario as usuario, @p_registrado as registrado, @p_mensaje as mensaje
            """

            # print(f"DEBUG: Llamando al SP con parametros:")
            # print(f"1. num_documento: {num_documento}")
            # print(f"2. tipo_documento: {tipo_documento}")
            # print(f"3. nombres: {nombres}")
            # print(f"4. apellido_paterno: {apellido_paterno}")
            # print(f"5. apellido_materno: {apellido_materno}")
            # print(f"6. fecha_nacimiento: {fecha_nacimiento}")
            # print(f"7. estado_civil: {estado_civil}")
            # print(f"8. email: {email}")
            # print(f"9. celular: {celular}")
            # print(f"10. numero_emergencia: {numero_emergencia}")
            # print(f"11. direccion: {direccion}")
            # print(f"12. departamento: {departamento}")
            # print(f"13. provincia: {provincia}")
            # print(f"14. distrito: {distrito}")
            # print(f"15. genero: {genero}")
            # print(f"16. password_hash: [HASH]")
            # print(f"17. rol_nombre: {rol_nombre}")
            # print(f"18. cargo_nombre: {cargo_nombre}")
            # print(f"19. area_resumen: {area_resumen}")
            # print(f"20. num_documento_creador: {num_documento_creador}")

            cursor.execute(query, (
                num_documento, tipo_documento, nombres, apellido_paterno, apellido_materno,
                fecha_nacimiento, estado_civil,
                email, celular, numero_emergencia, direccion, departamento, provincia, distrito, genero,
                password_hash, rol_nombre, cargo_nombre, area_resumen, num_documento_creador
            ))

            

            # Obtener todos los resultados del stored procedure

            results = []

            try:

                if cursor.with_rows:

                    results.extend(cursor.fetchall())

                

                while cursor.nextset():

                    if cursor.with_rows:

                        results.extend(cursor.fetchall())

                

                # Log omitido - results puede contener caracteres especiales
                # print(f"DEBUG: Resultados del SP recibidos: {len(results)} registros")

                result = results[-1] if results else None

                

            except Exception as e:

                current_app.logger.error(f"Error al procesar resultados: {type(e).__name__}")

                result = None

            

            # print(f"DEBUG: Respuesta del SP:")

            # print(f"  registrado: {result.get('registrado') if result else 'None'}")

            # print(f"  mensaje: {result.get('mensaje') if result else 'None'}")

            

            cursor.close()

            connection.close()

            

            if not result:

                # print("  ERROR: No se obtuvo respuesta del SP")

                return {'success': False, 'message': 'Error al registrar el asesor. No se obtuvo respuesta del stored procedure.'}, 500

            

            registrado = result.get('registrado')

            mensaje = result.get('mensaje')
            usuario_generado = result.get('usuario')

            

            # print(f"DEBUG: Procesando respuesta:")

            # print(f"  usuario generado: {usuario_generado}")

            # print(f"  registrado: {registrado} (tipo: {type(registrado)})")

            # print(f"  mensaje recibido (tipo: {type(mensaje).__name__})")

            

            if registrado == 1:

                # print(f"  EXITO: Asesor registrado")

                return {

                    'success': True,

                    'message': 'Asesor registrado exitosamente!',

                    'usuario': usuario_generado,

                    'contrasena': num_documento

                }, 201

            else:

                if mensaje is None or mensaje == 'None' or str(mensaje).strip() == '':

                    mensaje_error = 'Error desconocido en el stored procedure. Verifica que todos los datos sean correctos.'

                else:

                    mensaje_error = str(mensaje)

                    

                # print(f"  ERROR del SP: {mensaje_error}")

                return {'success': False, 'message': mensaje_error}, 400

            

        except Error as e:

            current_app.logger.error(f"Error SQL: {type(e).__name__}")

            if connection.is_connected():

                connection.close()

            return {'success': False, 'message': f'Error de base de datos: {str(e)}'}, 500

    

    except Exception as e:

        current_app.logger.error(f"Error general: {type(e).__name__}")
# traceback omitido - evita error ASCII

        return {'success': False, 'message': 'Error al procesar la solicitud. Verifica los datos ingresados.'}, 500







def buscar_usuario_por_documento():

    """Buscar usuario por numero de documento - OPTIMIZADO CON SP"""

    try:

        num_documento = request.args.get('num_documento', '').strip()

        

        if not num_documento:

            return {'success': False, 'message': 'Numero de documento requerido'}, 400

        

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion'}, 500

        

        cursor = connection.cursor(dictionary=True)

        

        print(f"DEBUG: Buscando usuario con documento: {num_documento} (usando SP optimizado)")

        

        try:

            cursor.execute("CALL sp_BuscarUsuarioPorDocumento(%s)", (num_documento,))

            usuario = cursor.fetchone()

            

            cursor.close()

            connection.close()

            

            if usuario:

                # Log sin caracteres especiales para evitar error ASCII
                print(f"DEBUG:   Usuario encontrado con documento: {usuario['num_documento']}")

                return {

                    'success': True,

                    'found': True,

                    'data': {

                        'num_documento': usuario['num_documento'],

                        'usuario': usuario['usuario'],

                        'nombre_completo': usuario['nombre_completo'],

                        'rol': usuario['rol'],

                        'cargo': usuario['cargo'],

                        'area': usuario['area'],

                        'estado': usuario['estado'],

                        'nivel': usuario['nivel'],

                        'total_hijos': usuario['total_hijos']

                    }

                }, 200

            else:

                print(f"DEBUG:   Usuario no encontrado: {num_documento}")

                return {

                    'success': True,

                    'found': False,

                    'message': f'No se encontro ningun usuario con el documento {num_documento}'

                }, 200

                

        except Error as sp_error:

            print(f"DEBUG:   Error con SP, usando query de respaldo: {sp_error}")

            connection = get_db_connection()

            cursor = connection.cursor(dictionary=True)

            

            query = """

                SELECT u.num_documento, u.usuario, p.nombres, p.apellido_paterno, p.apellido_materno,

                    CONCAT(p.nombres, ' ', p.apellido_paterno, ' ', COALESCE(p.apellido_materno, '')) as nombre_completo,

                    r.nombre as rol, c.nombre as cargo, a.nombre as area, u.estado,

                    COALESCE(j.nivel, 0) as nivel,

                    (SELECT COUNT(*) FROM TblJerarquiaUsuarios WHERE num_documento_padre COLLATE utf8mb4_unicode_ci = u.num_documento COLLATE utf8mb4_unicode_ci) as total_hijos

                FROM TblUsuarios u

                INNER JOIN TblPersona p ON u.num_documento COLLATE utf8mb4_unicode_ci = p.num_documento COLLATE utf8mb4_unicode_ci

                LEFT JOIN TblRol r ON u.id_rol = r.id_rol

                LEFT JOIN TblCargos c ON u.id_cargo = c.id_cargo

                LEFT JOIN TblAreas a ON c.id_area = a.id_area

                LEFT JOIN TblJerarquiaUsuarios j ON u.num_documento COLLATE utf8mb4_unicode_ci = j.num_documento COLLATE utf8mb4_unicode_ci

                WHERE u.num_documento = %s

                LIMIT 1

            """

            

            cursor.execute(query, (num_documento,))

            usuario = cursor.fetchone()

            

            cursor.close()

            connection.close()

            

            if usuario:

                return {'success': True, 'found': True, 'data': dict(usuario)}, 200

            else:

                return {'success': True, 'found': False, 'message': f'No se encontro ningun usuario con el documento {num_documento}'}, 200

        

    except Error as e:

        current_app.logger.error(f"Error: {type(e).__name__}")

        if connection and connection.is_connected():

            connection.close()

        return {'success': False, 'message': f'Error al buscar usuario: {str(e)}'}, 500







def update_asesor_api():

    """API para actualizar un asesor existente"""

    try:

        data = request.get_json()

        

        print("=" * 80)

        # print("DEBUG: Datos recibidos para actualizacion:")

        # Log de data omitido - puede contener caracteres especiales

        print("=" * 80)

        

        documento_original = data.get('documento_original', '').strip()

        

        if not documento_original:

            return {'success': False, 'message': 'Documento original requerido para actualizacion'}, 400

        

        num_documento_jerarquia = data.get('num_documento_jerarquia', '').strip()

        num_documento_creador = num_documento_jerarquia if num_documento_jerarquia else None

        

        print(f"DEBUG: Documento original: {documento_original}")

        print(f"DEBUG: Documento jerarquia (padre): {num_documento_creador}")

        

        # Obtener datos del formulario

        num_documento = data.get('num_documento', '').strip().upper()

        tipo_documento = data.get('tipo_documento', 'DNI').upper()

        nombres = data.get('nombres', '').strip().upper()

        apellido_paterno = data.get('apellido_paterno', '').strip().upper()

        apellido_materno = data.get('apellido_materno', '').strip().upper()

        fecha_nacimiento = data.get('fecha_nacimiento', '').strip() or None

        estado_civil = data.get('estado_civil', '').strip() or None

        email = data.get('email', '').strip().lower()

        celular = data.get('celular', '').strip()

        numero_emergencia = data.get('numero_emergencia', '').strip()

        direccion = data.get('direccion', '').strip().upper()

        

        rol_nombre = data.get('rol_nombre', '').strip()

        cargo_nombre = data.get('cargo_nombre', '').strip()

        

        genero = data.get('genero', '').strip()

        

        print(f"DEBUG: Datos procesados para actualizacion:")

        print(f"  num_documento: '{num_documento}'")

        print(f"  email: '{email}'")

        # Omitidos apellidos del log por codificacion ASCII

        print(f"  fecha_nacimiento: '{fecha_nacimiento}'")

        print(f"  estado_civil: '{estado_civil}'")

        print(f"  email: '{email}'")

        

        if not all([num_documento, nombres, apellido_paterno, email, rol_nombre, cargo_nombre]):

            print("  ERROR: Faltan campos requeridos")

            return {'success': False, 'message': 'Por favor completa los campos requeridos'}, 400

        

        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

        if not re.match(email_pattern, email):

            print(f"  ERROR: Email invalido: {email}")

            return {'success': False, 'message': 'Formato de email invalido'}, 400

        

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion con la base de datos'}, 500

        

        try:

            cursor = connection.cursor(dictionary=True)

            

            # Generar usuario automaticamente

            primera_letra_nombre = nombres[0].lower() if nombres else ''

            apellido_pat_lower = apellido_paterno.lower() if apellido_paterno else ''

            

            if apellido_materno:

                primera_letra_mat = apellido_materno[0].lower()

            else:

                primera_letra_mat = ''

            

            usuario = f"{primera_letra_nombre}{apellido_pat_lower}{primera_letra_mat}"

            

            # Log omitido - usuario puede contener caracteres del apellido

            

            distrito_id = data.get('id_distrito', '')

            try:

                distrito_id = int(distrito_id) if distrito_id else None

                if distrito_id is None:

                    print("  ERROR: ID de distrito no valido")

                    return {'success': False, 'message': 'ID de distrito requerido'}, 400

            except ValueError:

                print(f"  ERROR: ID de distrito no es un numero valido: {distrito_id}")

                return {'success': False, 'message': 'ID de distrito debe ser un numero valido'}, 400

            

            print(f"DEBUG: Llamando al SP de actualizacion con parametros:")

            print(f"  0. documento_original: {documento_original}")

            print(f"  1. num_documento: {num_documento}")

            print(f"  17. num_documento_creador: {num_documento_creador}")

            

            args = [

                documento_original, num_documento, tipo_documento, nombres, apellido_paterno, apellido_materno,

                fecha_nacimiento, estado_civil, email, celular, numero_emergencia, direccion, distrito_id, genero,

                usuario, rol_nombre, cargo_nombre, num_documento_creador,

                0, ''

            ]

            result_args = cursor.callproc('sp_ActualizarAsesorPorNombre', args)

            

            actualizado = result_args.get('sp_ActualizarAsesorPorNombre_arg19', 0)

            mensaje = result_args.get('sp_ActualizarAsesorPorNombre_arg20', None)

            

            print(f"DEBUG: Respuesta del SP usando callproc:")

            print(f"  actualizado: {actualizado} (tipo: {type(actualizado)})")

            print(f"  mensaje recibido (tipo: {type(mensaje).__name__})")

            

            if mensaje is None:

                print("  ADVERTENCIA: El SP devolvio mensaje = None")

            

            cursor.close()

            connection.close()

            

            if actualizado == 1:

                print(f"  EXITO: Asesor actualizado")

                return {

                    'success': True,

                    'message': 'Asesor actualizado exitosamente!',

                    'usuario': usuario

                }, 200

            else:

                if mensaje is None or mensaje == 'None' or str(mensaje).strip() == '':

                    mensaje_error = 'Error desconocido al actualizar el asesor. Verifica que todos los datos sean correctos.'

                else:

                    mensaje_error = str(mensaje)

                

                print(f"  ERROR del SP: {mensaje_error}")

                return {'success': False, 'message': mensaje_error}, 400

            

        except Error as e:

            current_app.logger.error(f"Error SQL: {type(e).__name__}")

            if connection.is_connected():

                connection.close()

            return {'success': False, 'message': f'Error de base de datos: {str(e)}'}, 500

    

    except Exception as e:

        current_app.logger.error(f"Error general: {type(e).__name__}")
# traceback omitido - evita error ASCII

        return {'success': False, 'message': 'Error al procesar la solicitud. Verifica los datos ingresados.'}, 500







def cambiar_contrasena_api():

    """Cambiar contrasena del usuario actual usando SP"""

    try:

        data = request.get_json()

        contrasena_actual = data.get('contrasena_actual', '').strip()

        contrasena_nueva = data.get('contrasena_nueva', '').strip()

        usuario = session.get('user_usuario')

        

        if not usuario:

            return {'success': False, 'message': 'Usuario no autenticado'}, 401

        

        if not contrasena_actual or not contrasena_nueva:

            return {'success': False, 'message': 'Faltan datos requeridos'}, 400

        

        if len(contrasena_nueva) < 6:

            return {'success': False, 'message': 'La nueva contrasena debe tener al menos 6 caracteres'}, 400

        

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion'}, 500

        

        cursor = connection.cursor(dictionary=True)

        

        # Log omitido - usuario puede contener caracteres especiales

        

        contrasena_actual_hash = hash_password(contrasena_actual)

        contrasena_nueva_hash = hash_password(contrasena_nueva)

        

        args = [usuario, contrasena_actual_hash, contrasena_nueva_hash, 0, '']

        result_args = cursor.callproc('sp_CambiarContrasena', args)

        

        cambiado = result_args.get('sp_CambiarContrasena_arg4', 0)

        mensaje = result_args.get('sp_CambiarContrasena_arg5', None)

        

        print(f"DEBUG: Respuesta del SP de cambio de contrasena:")

        print(f"  cambiado: {cambiado}")

        # Log omitido - mensaje puede contener caracteres especiales

        

        cursor.close()

        connection.close()

        

        if cambiado == 1:

            print(f"  EXITO: Contrasena cambiada")

            return {

                'success': True,

                'message': mensaje or 'Contrasena actualizada exitosamente'

            }, 200

        else:

            print(f"  ERROR: {mensaje}")

            return {

                'success': False,

                'message': mensaje or 'No se pudo cambiar la contrasena'

            }, 400

        

    except Error as e:

        current_app.logger.error(f"Error SQL: {type(e).__name__}")

        if connection and connection.is_connected():

            connection.close()

        return {'success': False, 'message': f'Error de base de datos: {str(e)}'}, 500

    

    except Exception as e:

        current_app.logger.error(f"Error general: {type(e).__name__}")
# traceback omitido - evita error ASCII

        return {'success': False, 'message': 'Error al procesar la solicitud. Verifica los datos ingresados.'}, 500







def delete_asesor_api(num_documento):

    """Eliminar un asesor de todas las tablas usando SP"""

    try:

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion'}, 500

        

        cursor = connection.cursor(dictionary=True)

        

        print(f"DEBUG: Eliminando asesor con documento: {num_documento}")

        

        args = [num_documento, 0, '']

        result_args = cursor.callproc('sp_EliminarAsesor', args)

        

        eliminado = result_args.get('sp_EliminarAsesor_arg2', 0)

        mensaje = result_args.get('sp_EliminarAsesor_arg3', None)

        

        print(f"DEBUG: Respuesta del SP de eliminacion:")

        print(f"  eliminado: {eliminado}")

        # Log omitido - mensaje puede contener caracteres especiales

        

        cursor.close()

        connection.close()

        

        if eliminado == 1:

            print(f"  EXITO: Asesor eliminado")

            return {

                'success': True,

                'message': mensaje or 'Asesor eliminado exitosamente'

            }, 200

        else:

            print(f"  ERROR: {mensaje}")

            return {

                'success': False,

                'message': mensaje or 'No se pudo eliminar el asesor'

            }, 400

        

    except Error as e:

        current_app.logger.error(f"Error SQL: {type(e).__name__}")

        if connection and connection.is_connected():

            connection.close()

        return {'success': False, 'message': f'Error de base de datos: {str(e)}'}, 500

    

    except Exception as e:

        current_app.logger.error(f"Error general: {type(e).__name__}")
# traceback omitido - evita error ASCII

        return {'success': False, 'message': 'Error al procesar la solicitud. Verifica los datos ingresados.'}, 500







def get_usuarios_asesores():

    """Obtener listado de usuarios asesores usando SP"""

    try:

        current_app.logger.info("=== LISTAR ASESORES ===")

        

        connection = get_db_connection()

        if not connection:

            current_app.logger.error("  Error de conexion a la base de datos")

            return {'success': False, 'message': 'Error de conexion'}, 500

        

        cursor = connection.cursor(dictionary=True)

        

        current_app.logger.info("Ejecutando SP: sp_ListarAsesores()")

        

        cursor.execute("CALL sp_ListarAsesores()")

        usuarios = cursor.fetchall()

        

        cursor.close()

        connection.close()

        

        current_app.logger.info(f"  Se obtuvieron {len(usuarios)} asesores del SP")

        

        if usuarios and len(usuarios) > 0:

            current_app.logger.info(f"Primer asesor: {usuarios[0]}")

        

        return {

            'success': True,

            'data': usuarios,

            'total': len(usuarios)

        }, 200

        

    except Error as e:

        current_app.logger.error(f"  ERROR SQL al listar asesores: {e}")

        print(f"  ERROR CRITICO: El SP sp_ListarAsesores no existe o tiene errores")

        current_app.logger.error(f"Error tipo: {type(e).__name__}")

        print(f"  SOLUCION: Ejecuta el script ejecutar_todos_sps_optimizados.sql")

        return {'success': False, 'message': f'Error: SP no encontrado. Ejecuta ejecutar_todos_sps_optimizados.sql'}, 500

    

    except Exception as e:

        current_app.logger.error(f"  ERROR general al listar asesores: {e}", exc_info=True)

        return {'success': False, 'message': f'Error del servidor: {str(e)}'}, 500







def get_asesor_by_documento(num_documento):

    """Obtener un asesor especifico por numero de documento usando SP"""

    try:

        connection = get_db_connection()

        if not connection:

            return {'success': False, 'message': 'Error de conexion'}, 500

        

        cursor = connection.cursor(dictionary=True)

        

        print(f"DEBUG: Obteniendo asesor con documento: {num_documento} (usando SP)")

        

        try:

            cursor.execute("CALL sp_ObtenerDatosEdicionAsesor(%s)", (num_documento,))

            asesor = cursor.fetchone()

            

            cursor.close()

            connection.close()

            

            if asesor:

                print(f"DEBUG:   Asesor encontrado con documento: {num_documento}")

                print(f"DEBUG: fecha_nacimiento: {asesor.get('fecha_nacimiento')}")

                print(f"DEBUG: estado_civil: {asesor.get('estado_civil')}")

                print(f"DEBUG: Ubicacion - Departamento: {asesor.get('id_departamento')}, Provincia: {asesor.get('id_provincia')}, Distrito: {asesor.get('id_distrito')}")

                print(f"DEBUG: Area: {asesor.get('id_area')}, Cargo: {asesor.get('id_cargo')}")

                

                return {

                    'success': True,

                    'data': asesor

                }, 200

            else:

                print(f"DEBUG:   No se encontro asesor con documento: {num_documento}")

                return {

                    'success': False,

                    'message': f'No se encontro el asesor con documento {num_documento}'

                }, 404

                

        except Error as e:

            current_app.logger.error(f"Error con SP: {type(e).__name__}")

            cursor.close()

            connection.close()

            return {

                'success': False,

                'message': f'Error al obtener datos del asesor: {str(e)}'

            }, 500

        

    except Error as e:

        current_app.logger.error(f"Error: {type(e).__name__}")

        if connection.is_connected():

            connection.close()

        return {'success': False, 'message': f'Error al obtener asesor: {str(e)}'}, 500

