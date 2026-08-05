# CONFIGURACIÓN DE ZONA HORARIA PERÚ (UTC-5)

**FECHA**: 05 Agosto 2026  
**ESTADO**: ✅ CONFIGURADO A NIVEL DE CONEXIÓN

---

## 📋 PROBLEMA

MySQL por defecto usa la zona horaria del sistema operativo o UTC. En hosting compartido (como PythonAnywhere) **no tenemos permisos SUPER** para cambiar la configuración global del servidor.

### Error al intentar configurar globalmente:
```
Error Code: 1227. Access denied; you need (at least one of) 
the SUPER or SYSTEM_VARIABLES_ADMIN privilege(s) for this operation
```

---

## ✅ SOLUCIÓN IMPLEMENTADA

Se configuró la zona horaria **a nivel de conexión** en `app/config.py`, agregando el parámetro `time_zone: '-05:00'` en ambas clases de configuración:

### Cambios en `app/config.py`:

```python
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
        'charset': 'utf8mb4',
        'collation': 'utf8mb4_unicode_ci',
        'use_unicode': True,
        'connect_timeout': 10,
        'time_zone': '-05:00'  # ← AGREGADO: Zona horaria de Perú
    }
    return params
```

---

## 🎯 VENTAJAS DE ESTA SOLUCIÓN

✅ **No requiere permisos SUPER**  
✅ **Funciona en hosting compartido** (PythonAnywhere, etc.)  
✅ **Se aplica automáticamente** a todas las conexiones  
✅ **NOW() retorna hora de Perú** sin necesidad de CONVERT_TZ  
✅ **Simplifica los stored procedures**  

---

## 🔄 SIMPLIFICACIÓN DE STORED PROCEDURES

Ahora que la conexión establece automáticamente la zona horaria, los stored procedures pueden simplificarse:

### ANTES (con CONVERT_TZ):
```sql
DECLARE v_fecha_hora_actual DATETIME;

-- Convertir manualmente a zona horaria de Perú
SET v_fecha_hora_actual = CONVERT_TZ(NOW(), '+00:00', '-05:00');

-- Comparar fechas con conversión
WHERE DATE(CONVERT_TZ(fecha_marcacion, '+00:00', '-05:00')) = DATE(v_fecha_hora_actual)
```

### DESPUÉS (simplificado):
```sql
DECLARE v_fecha_hora_actual DATETIME;

-- NOW() ya retorna hora de Perú
SET v_fecha_hora_actual = NOW();

-- Comparaciones directas
WHERE DATE(fecha_marcacion) = DATE(v_fecha_hora_actual)
```

---

## 📝 STORED PROCEDURES QUE PUEDEN SIMPLIFICARSE

Los siguientes SPs aún usan `CONVERT_TZ()` y pueden simplificarse:

1. ✅ **`sp_RegistrarMarcacionCompleta_FINAL.sql`**
   - Línea: `SET v_fecha_hora_actual = CONVERT_TZ(NOW(), '+00:00', '-05:00');`
   - Cambiar a: `SET v_fecha_hora_actual = NOW();`
   - Líneas con: `CONVERT_TZ(fecha_marcacion, '+00:00', '-05:00')`
   - Cambiar a: `fecha_marcacion` (sin conversión)

2. ✅ **Otros SPs con conversión de zona horaria**
   - Buscar: `CONVERT_TZ`
   - Reemplazar con uso directo de `NOW()` y campos de fecha

### Comando para buscar SPs que necesitan actualización:
```bash
grep -r "CONVERT_TZ" database_scripts/*.sql
```

---

## 🧪 VERIFICACIÓN

Para verificar que la configuración funciona:

### 1. Conectar a MySQL y ejecutar:
```sql
SELECT 
    @@session.time_zone AS 'Timezone Sesión',
    NOW() AS 'Hora Actual',
    CURDATE() AS 'Fecha Actual',
    CURTIME() AS 'Hora Actual (solo hora)';
```

### Resultado esperado:
```
Timezone Sesión: -05:00
Hora Actual: 2026-08-05 14:30:45  (Hora de Perú)
Fecha Actual: 2026-08-05
Hora Actual (solo hora): 14:30:45
```

### 2. Desde Python (para debug):
```python
from app.config import DatabaseConfig
import mysql.connector

# Obtener parámetros de conexión
params = DatabaseConfig.get_connection_params()
print(f"Timezone configurado: {params.get('time_zone')}")

# Conectar y verificar
conn = mysql.connector.connect(**params)
cursor = conn.cursor()
cursor.execute("SELECT NOW(), @@session.time_zone")
result = cursor.fetchone()
print(f"Hora del servidor: {result[0]}")
print(f"Timezone de sesión: {result[1]}")
cursor.close()
conn.close()
```

---

## 🚀 DEPLOYMENT

### Para desarrollo local:
1. ✅ Ya configurado en `app/config.py`
2. Reiniciar servidor Flask: `python main.py`
3. Verificar logs que muestren conexión exitosa

### Para producción (PythonAnywhere):
1. ✅ Subir cambios al git
2. Pull en el servidor: `git pull origin main`
3. Reiniciar aplicación web desde el dashboard
4. Verificar que `NOW()` retorne hora correcta

---

## 📊 IMPACTO

### Afecta a:
- ✅ Todas las nuevas conexiones de Python
- ✅ `NOW()`, `CURDATE()`, `CURTIME()` en consultas
- ✅ Comparaciones de fechas en WHERE
- ✅ Timestamps automáticos (CURRENT_TIMESTAMP)
- ✅ Stored procedures que usan NOW()

### NO afecta a:
- ❌ Datos ya almacenados en la BD (se interpretan en nueva timezone)
- ❌ Conexiones de otros usuarios/aplicaciones (cada uno configura su propia sesión)
- ❌ Configuración global del servidor MySQL

---

## 🔧 ALTERNATIVAS (SI ESTA SOLUCIÓN NO FUNCIONA)

### Alternativa 1: SET time_zone después de conectar
```python
def get_db_connection():
    connection = mysql.connector.connect(**params)
    cursor = connection.cursor()
    cursor.execute("SET time_zone = '-05:00'")
    cursor.close()
    return connection
```

### Alternativa 2: Usar init_command
```python
params = {
    ...
    'init_command': "SET time_zone = '-05:00'"
}
```

### Alternativa 3: Configurar en my.cnf (solo si tienes acceso)
```ini
[mysqld]
default-time-zone = '-05:00'
```

---

## 📝 PRÓXIMOS PASOS

1. ⏳ **Opcional**: Simplificar SPs existentes eliminando CONVERT_TZ
2. ✅ **Verificar**: Probar marcaciones y confirmar hora correcta
3. ✅ **Monitorear**: Revisar logs para confirmar timezone en cada conexión

---

## 🐛 TROUBLESHOOTING

### Problema: La hora sigue siendo incorrecta
**Solución**: 
- Verificar que el servidor Flask se haya reiniciado
- Comprobar que `app/config.py` tenga los cambios
- Revisar logs de conexión

### Problema: Error "Unknown time zone"
**Solución**:
- Verificar que sea `-05:00` (con dos puntos)
- No usar `America/Lima` (no soportado sin timezone tables)

### Problema: Algunas consultas aún usan hora UTC
**Solución**:
- Identificar stored procedures con CONVERT_TZ
- Simplificarlos para usar NOW() directamente

---

## 📞 SOPORTE

Si hay problemas con la zona horaria:
1. Verificar `app/config.py` tiene `time_zone: '-05:00'`
2. Reiniciar servidor Flask
3. Ejecutar query de verificación en MySQL
4. Revisar logs de Python para errores de conexión

**Versión**: 1.0  
**Última actualización**: 05 Agosto 2026
