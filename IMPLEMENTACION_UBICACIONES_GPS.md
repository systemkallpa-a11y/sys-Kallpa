# 📍 IMPLEMENTACIÓN DE GESTIÓN DE UBICACIONES GPS

## Fecha: 2026-08-04

---

## 🎯 OBJETIVO

Crear un sistema de gestión de ubicaciones GPS para definir **rangos/zonas circulares** donde cada usuario puede registrar su marcación de asistencia (geofencing).

---

## 📊 BASE DE DATOS

### Tabla: `TblUbicacionMarcacion`

**Ubicación:** `database_scripts/create_tbl_ubicacion_marcacion.sql`

**Estructura:**
```sql
CREATE TABLE TblUbicacionMarcacion (
    id_ubicacion INT AUTO_INCREMENT PRIMARY KEY,
    num_documento INT NOT NULL,  -- FK a TblUsuario
    
    -- Definición de la zona (área circular)
    nombre_zona VARCHAR(100) NOT NULL,
    latitud_centro DECIMAL(10, 8) NOT NULL,
    longitud_centro DECIMAL(11, 8) NOT NULL,
    radio_metros INT NOT NULL DEFAULT 100,
    
    -- Información adicional
    direccion_referencia VARCHAR(255) NULL,
    tipo_zona ENUM('OFICINA', 'OBRA', 'PROYECTO', 'CLIENTE', 'OTRO'),
    descripcion TEXT NULL,
    estado ENUM('ACTIVO', 'INACTIVO'),
    
    CONSTRAINT fk_ubicacion_usuario 
        FOREIGN KEY (num_documento) 
        REFERENCES TblUsuario(num_documento) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);
```

### Stored Procedures Creados

#### 1. `sp_ObtenerUbicacionesUsuario(p_num_documento)`
- Lista todas las ubicaciones de un usuario

#### 2. `sp_CrearUbicacionMarcacion(...)`
- Crea nueva ubicación con validaciones
- Valida usuario, coordenadas, radio (10-1000m)
- Manejo de transacciones

#### 3. `sp_ActualizarUbicacionMarcacion(...)`
- Actualiza ubicación existente
- Validaciones de datos

#### 4. `sp_EliminarUbicacionMarcacion(p_id_ubicacion)`
- Elimina ubicación

#### 5. `sp_ValidarUbicacionGPS(...)` ⭐
- Valida si coordenadas están dentro de zonas permitidas
- Fórmula de Haversine para cálculo de distancia
- Para usar en marcación de asistencia

---

## 🔧 BACKEND

### APIs con Stored Procedures

**Archivo:** `app/routes/usuarios.py`

- `GET /api/ubicaciones/obtener/<num_documento>` - Listar ubicaciones
- `POST /api/ubicaciones/crear` - Crear ubicación
- `PUT /api/ubicaciones/actualizar/<id>` - Actualizar ubicación
- `DELETE /api/ubicaciones/eliminar/<id>` - Eliminar ubicación

---

## 🎨 FRONTEND

### Modal de Ubicaciones

**Archivo:** `app/templates/components/modal_ubicaciones.html`

**Layout en 3 columnas:**
- **Izquierda:** Formulario de ubicación
- **Centro:** Mapa interactivo (Leaflet/OpenStreetMap)
- **Derecha:** Lista de ubicaciones configuradas

### JavaScript

**Archivo:** `app/static/js/ubicaciones_marcacion.js`

**Funciones principales:**
- Inicialización de mapa con Leaflet
- Colocar marcador y círculo de rango
- CRUD de ubicaciones
- Geolocalización del navegador

### Integración en Gestión de Usuarios

**Archivo:** `app/templates/usuarios.html`

Botón de ubicaciones (🗺️) agregado en la tabla de usuarios.

---

## 🗺️ TECNOLOGÍA

- **Leaflet 1.9.4** - Mapas interactivos
- **OpenStreetMap** - Tiles gratuitos
- **Sin API Key requerida**

---

## 🛡️ SEGURIDAD

✅ Stored Procedures para todas las operaciones
✅ Validaciones centralizadas en BD
✅ Prevención de SQL Injection
✅ Transacciones atómicas (COMMIT/ROLLBACK)
✅ Manejo de errores robusto
✅ Autenticación requerida en todas las rutas

---

## 📝 FLUJO DE USO

1. Ir a **Gestión de Usuarios**
2. Click en ícono de mapa (🗺️) del usuario
3. En el mapa, hacer click para marcar ubicación
4. Ajustar radio con slider (50m-500m)
5. Completar formulario y **Guardar**

---

## 📦 ARCHIVOS NUEVOS

1. ✅ `database_scripts/create_tbl_ubicacion_marcacion.sql`
2. ✅ `app/static/js/ubicaciones_marcacion.js`
3. ✅ `app/templates/components/modal_ubicaciones.html`
4. ✅ `IMPLEMENTACION_UBICACIONES_GPS.md`

## 📦 ARCHIVOS MODIFICADOS

1. ✅ `app/routes/usuarios.py`
2. ✅ `app/templates/usuarios.html`
3. ✅ `app/templates/dashboard.html`

---

## ✅ IMPLEMENTACIÓN COMPLETADA

Sistema de gestión de ubicaciones GPS con Stored Procedures listo para producción.
