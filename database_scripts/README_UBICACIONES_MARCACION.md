# Ubicaciones de Marcación - Setup de Base de Datos

## Fecha: 05 Agosto 2026

## Descripción

Scripts SQL para crear la tabla y stored procedures necesarios para el sistema de **Ubicaciones de Marcación**, que permite definir zonas geográficas donde los usuarios pueden marcar asistencia.

## Problema Resuelto

```
Error 1305 (42000): PROCEDURE sp_CrearUbicacionMarcacion does not exist
```

## Archivos

1. **`create_table_ubicaciones_marcacion.sql`** - Crea la tabla principal
2. **`create_sp_ubicaciones_marcacion.sql`** - Crea los 3 stored procedures

## Orden de Ejecución

### 1. Crear la Tabla (si no existe)

```bash
mysql -u kallpasystem -p Kallpa < create_table_ubicaciones_marcacion.sql
```

O desde MySQL Workbench/cliente:
```sql
SOURCE d:/kallpa/sys-Kallpa/sys-Kallpa/database_scripts/create_table_ubicaciones_marcacion.sql;
```

### 2. Crear los Stored Procedures

```bash
mysql -u kallpasystem -p Kallpa < create_sp_ubicaciones_marcacion.sql
```

O desde MySQL Workbench/cliente:
```sql
SOURCE d:/kallpa/sys-Kallpa/sys-Kallpa/database_scripts/create_sp_ubicaciones_marcacion.sql;
```

## Estructura de la Tabla

```sql
TblUbicacionMarcacion
├── id_ubicacion (INT) - PK, AUTO_INCREMENT
├── num_documento (VARCHAR) - FK a TblUsuario
├── nombre_zona (VARCHAR) - Nombre descriptivo
├── latitud_centro (DECIMAL) - Coordenada GPS
├── longitud_centro (DECIMAL) - Coordenada GPS
├── radio_metros (INT) - Radio permitido
├── direccion_referencia (VARCHAR) - Dirección
├── tipo_zona (VARCHAR) - OFICINA, OBRA, PROYECTO, CLIENTE, OTRO
├── descripcion (TEXT) - Información adicional
├── estado (VARCHAR) - ACTIVO, INACTIVO
├── creado_por (VARCHAR) - Usuario creador
├── fecha_creacion (DATETIME)
└── fecha_actualizacion (DATETIME)
```

## Stored Procedures Creados

### 1. sp_CrearUbicacionMarcacion

**Parámetros IN:**
- `p_num_documento` (VARCHAR) - Documento del usuario
- `p_nombre_zona` (VARCHAR) - Nombre de la zona
- `p_latitud_centro` (DECIMAL) - Latitud GPS
- `p_longitud_centro` (DECIMAL) - Longitud GPS
- `p_radio_metros` (INT) - Radio en metros
- `p_direccion_referencia` (VARCHAR) - Dirección
- `p_tipo_zona` (VARCHAR) - Tipo de zona
- `p_descripcion` (TEXT) - Descripción
- `p_estado` (VARCHAR) - Estado
- `p_creado_por` (VARCHAR) - Usuario creador

**Parámetros OUT:**
- `p_id_ubicacion` (INT) - ID de la ubicación creada
- `p_mensaje` (VARCHAR) - Mensaje de resultado

**Ejemplo:**
```sql
CALL sp_CrearUbicacionMarcacion(
    '12345678',
    'Oficina Central',
    -12.0464,
    -77.0428,
    100,
    'Av. Javier Prado 123',
    'OFICINA',
    'Sede principal',
    'ACTIVO',
    '12345678',
    @id,
    @msg
);
SELECT @id, @msg;
```

### 2. sp_ActualizarUbicacionMarcacion

**Parámetros IN:**
- `p_id_ubicacion` (INT) - ID a actualizar
- `p_nombre_zona` (VARCHAR)
- `p_latitud_centro` (DECIMAL)
- `p_longitud_centro` (DECIMAL)
- `p_radio_metros` (INT)
- `p_direccion_referencia` (VARCHAR)
- `p_tipo_zona` (VARCHAR)
- `p_descripcion` (TEXT)
- `p_estado` (VARCHAR)

**Parámetros OUT:**
- `p_mensaje` (VARCHAR)

### 3. sp_EliminarUbicacionMarcacion

**Parámetros IN:**
- `p_id_ubicacion` (INT) - ID a eliminar

**Parámetros OUT:**
- `p_mensaje` (VARCHAR)

## Verificación Post-Instalación

### Verificar que la tabla existe:
```sql
SHOW TABLES LIKE 'TblUbicacionMarcacion';
DESC TblUbicacionMarcacion;
```

### Verificar que los SPs existen:
```sql
SHOW PROCEDURE STATUS WHERE Db = 'Kallpa' AND Name LIKE '%UbicacionMarcacion%';
```

### Probar creación de ubicación:
```sql
CALL sp_CrearUbicacionMarcacion(
    '12345678',  -- Reemplazar con documento real
    'Prueba Oficina',
    -12.0464,
    -77.0428,
    150,
    'Dirección de prueba',
    'OFICINA',
    'Ubicación de prueba',
    'ACTIVO',
    '12345678',
    @p_id,
    @p_msg
);

SELECT @p_id AS id_creado, @p_msg AS mensaje;

-- Verificar que se creó
SELECT * FROM TblUbicacionMarcacion WHERE id_ubicacion = @p_id;
```

## Funcionalidades del Sistema

Una vez instalado, el sistema permite:

✅ **Crear ubicaciones** con búsqueda por ciudad/dirección
✅ **Definir zonas geográficas** con centro GPS y radio en metros
✅ **Múltiples ubicaciones** por usuario
✅ **Tipos de zona**: Oficina, Obra, Proyecto, Cliente, Otro
✅ **Estados**: Activo, Inactivo
✅ **Validación GPS** al marcar asistencia

## Integración con Frontend

El frontend en `Gestión de Usuarios → Ubicaciones de Marcación` usa estos SPs para:

1. Buscar direcciones con OpenStreetMap (Nominatim)
2. Mostrar ubicaciones en mapa interactivo (Leaflet)
3. Crear/editar/eliminar ubicaciones
4. Validar marcaciones dentro del radio permitido

## Troubleshooting

### Error: PROCEDURE does not exist
**Solución**: Ejecutar `create_sp_ubicaciones_marcacion.sql`

### Error: Table doesn't exist
**Solución**: Ejecutar `create_table_ubicaciones_marcacion.sql`

### Error: Foreign key constraint fails
**Causa**: El `num_documento` no existe en TblUsuario
**Solución**: Verificar que el usuario esté creado primero

### Eliminar y recrear todo:
```sql
-- ⚠️ CUIDADO: Esto borra todos los datos
DROP TABLE IF EXISTS TblUbicacionMarcacion;
DROP PROCEDURE IF EXISTS sp_CrearUbicacionMarcacion;
DROP PROCEDURE IF EXISTS sp_ActualizarUbicacionMarcacion;
DROP PROCEDURE IF EXISTS sp_EliminarUbicacionMarcacion;

-- Luego volver a ejecutar los scripts en orden
```

## Notas

- La tabla usa `ON DELETE CASCADE` para eliminar ubicaciones si se elimina el usuario
- Los índices optimizan las consultas por usuario y estado
- El campo `fecha_actualizacion` se actualiza automáticamente con cada UPDATE
- Coordenadas GPS usan DECIMAL para precisión (8 decimales = ~1mm de precisión)

## Soporte

Si hay problemas:
1. Verificar que la base de datos sea `Kallpa`
2. Verificar permisos del usuario `kallpasystem`
3. Revisar logs del servidor Python
4. Verificar que TblUsuario existe y tiene el campo `num_documento`
