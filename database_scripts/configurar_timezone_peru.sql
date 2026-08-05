-- ============================================================================
-- CONFIGURACIÓN DE ZONA HORARIA DE PERÚ (UTC-5) EN MYSQL
-- Fecha: 05 Agosto 2026
-- ============================================================================

-- ============================================================================
-- OPCIÓN 1: CONFIGURAR ZONA HORARIA A NIVEL DE SESIÓN
-- (Se aplica solo a la conexión actual)
-- ============================================================================

SET time_zone = '-05:00';

-- Verificar configuración actual
SELECT @@session.time_zone AS 'Zona Horaria de Sesión',
       @@global.time_zone AS 'Zona Horaria Global',
       NOW() AS 'Fecha/Hora Actual';


-- ============================================================================
-- OPCIÓN 2: CONFIGURAR ZONA HORARIA GLOBAL (RECOMENDADO)
-- (Se aplica a todas las nuevas conexiones)
-- Requiere privilegios SUPER o SYSTEM_VARIABLES_ADMIN
-- ============================================================================

SET GLOBAL time_zone = '-05:00';

-- Verificar configuración global
SELECT @@global.time_zone AS 'Zona Horaria Global',
       NOW() AS 'Fecha/Hora Actual';


-- ============================================================================
-- VERIFICACIÓN COMPLETA
-- ============================================================================

SELECT 
    @@global.time_zone AS 'Global Timezone',
    @@session.time_zone AS 'Session Timezone',
    NOW() AS 'Hora Servidor',
    CONVERT_TZ(NOW(), '+00:00', '-05:00') AS 'Hora Perú (si servidor en UTC)',
    CURDATE() AS 'Fecha Actual',
    CURTIME() AS 'Hora Actual';


-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================

/*
╔═══════════════════════════════════════════════════════════════════════════╗
║  CONFIGURACIÓN PERMANENTE (my.cnf / my.ini)                               ║
╚═══════════════════════════════════════════════════════════════════════════╝

Para hacer la configuración PERMANENTE (que se mantenga después de reiniciar
MySQL), debes editar el archivo de configuración de MySQL:

1. LINUX/UNIX:
   Archivo: /etc/mysql/my.cnf  o  /etc/my.cnf
   
   [mysqld]
   default-time-zone = '-05:00'

2. WINDOWS:
   Archivo: C:\ProgramData\MySQL\MySQL Server X.X\my.ini
   
   [mysqld]
   default-time-zone = '-05:00'

3. DOCKER:
   Agregar al docker-compose.yml:
   
   services:
     mysql:
       environment:
         - TZ=America/Lima
       command: --default-time-zone=-05:00

4. PYTHONANYWHERE / HOSTING:
   - Usar SET time_zone en cada conexión desde Python
   - O agregar en la URL de conexión: ?time_zone=-05:00

Después de editar el archivo de configuración, REINICIAR MySQL:
- Linux: sudo systemctl restart mysql
- Windows: net stop mysql && net start mysql
- Docker: docker-compose restart


╔═══════════════════════════════════════════════════════════════════════════╗
║  CONFIGURACIÓN EN PYTHON (Flask/MySQL)                                    ║
╚═══════════════════════════════════════════════════════════════════════════╝

Opción A: Configurar en la conexión (RECOMENDADO para hosting compartido)

En app/config.py, modificar DatabaseConfig.get_connection_params():

@staticmethod
def get_connection_params():
    return {
        'host': os.getenv('DB_HOST', 'localhost'),
        'user': os.getenv('DB_USER', 'root'),
        'password': os.getenv('DB_PASSWORD', ''),
        'database': os.getenv('DB_NAME', 'Kallpa'),
        'time_zone': '-05:00',  # ← AGREGAR ESTA LÍNEA
        'charset': 'utf8mb4'
    }

Opción B: Ejecutar SET después de conectar

def get_db_connection():
    try:
        connection = mysql.connector.connect(**params)
        cursor = connection.cursor()
        cursor.execute("SET time_zone = '-05:00'")
        cursor.close()
        return connection
    except Error as e:
        print(f"Error: {e}")
        return None


╔═══════════════════════════════════════════════════════════════════════════╗
║  VENTAJAS DE CONFIGURAR A NIVEL DE SERVIDOR                               ║
╚═══════════════════════════════════════════════════════════════════════════╝

✅ NOW() retorna automáticamente hora de Perú
✅ CURDATE() retorna fecha correcta de Perú
✅ No necesitas CONVERT_TZ() en stored procedures
✅ Timestamps se almacenan en zona horaria correcta
✅ Simplifica toda la lógica de fechas


╔═══════════════════════════════════════════════════════════════════════════╗
║  CAMBIOS NECESARIOS EN STORED PROCEDURES EXISTENTES                       ║
╚═══════════════════════════════════════════════════════════════════════════╝

Después de configurar la zona horaria global, SIMPLIFICAR los SPs:

ANTES:
  SET v_fecha_hora_actual = CONVERT_TZ(NOW(), '+00:00', '-05:00');

DESPUÉS:
  SET v_fecha_hora_actual = NOW();


ANTES:
  WHERE DATE(CONVERT_TZ(fecha_marcacion, '+00:00', '-05:00')) = DATE(v_fecha_hora_actual)

DESPUÉS:
  WHERE DATE(fecha_marcacion) = DATE(v_fecha_hora_actual)


╔═══════════════════════════════════════════════════════════════════════════╗
║  PROBLEMAS COMUNES Y SOLUCIONES                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

Problema: "Unknown or incorrect time zone: 'America/Lima'"
Solución: 
  - Usar offset numérico: '-05:00' en lugar de 'America/Lima'
  - O cargar timezone data: mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root mysql

Problema: "Access denied; you need the SUPER privilege"
Solución:
  - Solo puedes cambiar time_zone de sesión, no global
  - Contactar al administrador del servidor
  - O configurar en cada conexión desde Python

Problema: "El servidor está en hosting compartido"
Solución:
  - Configurar time_zone en los parámetros de conexión de Python
  - O ejecutar SET time_zone después de conectar


╔═══════════════════════════════════════════════════════════════════════════╗
║  VERIFICACIÓN FINAL                                                        ║
╚═══════════════════════════════════════════════════════════════════════════╝

Para verificar que la configuración funciona:

SELECT 
    NOW() AS 'Hora Actual',
    CURDATE() AS 'Fecha Actual',
    CURTIME() AS 'Tiempo Actual',
    @@session.time_zone AS 'Timezone Sesión',
    @@global.time_zone AS 'Timezone Global';

La hora debe coincidir con la hora actual de Perú (UTC-5).

*/


-- ============================================================================
-- EJEMPLO DE USO EN STORED PROCEDURE (SIMPLIFICADO)
-- ============================================================================

/*
-- Después de configurar timezone global, los SPs se simplifican:

DELIMITER $$

CREATE PROCEDURE ejemplo_con_timezone()
BEGIN
    DECLARE v_fecha_actual DATETIME;
    
    -- Ya no necesitas CONVERT_TZ
    SET v_fecha_actual = NOW();
    
    -- Todas las operaciones de fecha usan zona horaria correcta
    INSERT INTO tabla (fecha) VALUES (v_fecha_actual);
    
    -- Comparaciones de fecha también se simplifican
    SELECT * FROM tabla 
    WHERE DATE(fecha) = DATE(v_fecha_actual);
    
END$$

DELIMITER ;
*/


-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

SELECT '✅ Zona horaria configurada a Perú (UTC-5)' AS mensaje;
SELECT 'ℹ️  Para configuración permanente, editar my.cnf/my.ini' AS nota;
SELECT '📝 Ver comentarios del script para más detalles' AS info;
