# 🔍 REVISIÓN COMPLETA DEL FLUJO DEL SISTEMA KALLMAX

**Fecha:** Julio 3, 2026  
**Estado:** En Producción  
**Versión del Sistema:** 1.0  

---

## 📊 RESUMEN EJECUTIVO

El sistema KallMax funciona con flujos principales:

1. ✅ **Autenticación** - Funcional pero con seguridad débil
2. ✅ **Carga de Menús** - Funcional con filtrado redundante
3. ⚠️ **Control de Accesos** - INCOMPLETO (sin filtrado por área)
4. ⚠️ **Registro de Asesores** - Funcional pero con problemas de diseño
5. ⚠️ **Gestión de Usuarios** - Funcional pero sin auditoría
6. 🔴 **Seguridad por Área** - NO IMPLEMENTADO

---

## 🔴 PROBLEMAS CRÍTICOS (DEBE ARREGLAR YA)

### 1. CONTROL DE ACCESO POR ÁREA NO IMPLEMENTADO
**Severidad:** CRÍTICA | **Impacto:** Data Leak

**Problema:**
```
Usuario en área "VENTAS" puede ver datos de área "REPORTES"
```

**Ubicación:** `/api/clientes`, `/api/usuarios-asesores`, etc.

**Causa:** Los SPs retornan todos los datos sin filtrar por `session['user_area']`

**Ejemplo:**
```python
# ACTUAL (VULNERABLE):
GET /api/clientes
→ CALL sp_ListarClientes()  # Retorna TODO
→ Retorna 1000 clientes de todas las áreas

# CORRECTO:
GET /api/clientes
→ Obtener area = session['user_area']  # "VENTAS"
→ CALL sp_ListarClientes(area)  # Retorna solo clientes de VENTAS
→ Retorna 50 clientes de VENTAS
```

**Solución:**
1. Modificar todos los SPs para aceptar parámetro `p_area`
2. En backend, pasar `session['user_area']` a cada SP
3. Validar que área de sesión es válida

**Archivos a cambiar:**
- `app/routes/main.py` - Agregar `session['user_area']` a queries
- `database_scripts/` - Modificar SPs para filtrar por área
- `app/funciones/` - Pasar área a SPs

---

### 2. HASH DE CONTRASEÑA DÉBIL (SHA-256 sin salt)
**Severidad:** CRÍTICA | **Impacto:** Fuerza bruta exitosa

**Problema:**
```python
# ACTUAL:
def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()
    # SHA-256 simple sin salt = vulnerable a rainbow tables
```

**Solución:**
```python
from werkzeug.security import generate_password_hash, check_password_hash

def hash_password(password):
    return generate_password_hash(password, method='pbkdf2:sha256')

def verify_password(password, hashed):
    return check_password_hash(hashed, password)
```

**Archivos a cambiar:**
- `app/funciones/funGeneral.py` - Cambiar `hash_password()`
- `app/routes/auth.py` - Cambiar validación en `validate_user()`
- `database_scripts/sp_RegistrarAsesor.sql` - Regenerar hashes

---

### 3. CONTRASEÑA = NÚMERO DE DOCUMENTO
**Severidad:** ALTA | **Impacto:** Acceso no autorizado

**Problema:**
```
Usuario nuevo registrado con documento 73017111
→ Contraseña = 73017111 (predecible, públicamente conocida)
→ Cualquiera con documento puede loguear
```

**Solución:**
```python
import secrets

def generar_contrasena_aleatoria():
    # Generar password de 12 caracteres
    # Ej: "kP9#mL2$xQw1"
    return secrets.token_urlsafe(12)
```

**Cambios:**
- `app/funciones/register_user.py` - Generar contraseña aleatoria
- Email contraseña temporal al usuario
- Forzar cambio en primer login

---

### 4. ROL/CARGO POR NOMBRE, NO ID
**Severidad:** MEDIA | **Impacto:** Asigna rol incorrecto

**Problema:**
```sql
-- En sp_RegistrarAsesor:
SELECT id_rol INTO v_id_rol 
FROM TblRol 
WHERE nombre = p_rol_nombre;  -- ¿Qué si hay duplicados?
```

**Ejemplo:**
- BD tiene: `id_rol=1: "Asesor"`, `id_rol=99: "Asesor"` (duplicado)
- Sistema asigna siempre al primero encontrado
- Usuario obtiene rol incorrecto

**Solución:**
1. Cambiar a recibir `p_id_rol` en lugar de `p_rol_nombre`
2. Validar que rol existe y es único
3. Agregar UNIQUE constraint en `TblRol.nombre`

---

### 5. SIN VALIDACIÓN DE PERMISOS DE ROL
**Severidad:** ALTA | **Impacto:** Usuarios normales acceden a admin

**Problema:**
```python
# ACTUAL:
@main_bp.route('/api/asignar-multiples-submenus-usuario', methods=['POST'])
@login_required  # ← Solo valida que esté logueado, NO que sea admin
def asignar_multiples_submenus_usuario_api():
    # Cualquier usuario logueado puede asignar permisos a otros
```

**Solución:**
```python
def require_role(required_role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            user_role = session.get('user_role')
            if user_role != required_role:
                return {'error': 'Acceso denegado'}, 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@main_bp.route('/api/asignar-multiples-submenus-usuario', methods=['POST'])
@login_required
@require_role('Admin')  # ← Ahora valida rol
def asignar_multiples_submenus_usuario_api():
    ...
```

---

## 🟡 PROBLEMAS IMPORTANTES

### 6. Doble filtrado de permisos (BD + Frontend)
**Ubicación:** `sidebar.html` + `sp_ObtenerPermisosUsuario`

**Problema:**
- SP retorna `permitido=0` y `permitido=1`
- Frontend filtra: `if (permitido === 1)`
- Confusing: ¿Por qué el SP no filtra?

**Impacto:** Confusión en debugging, posible bug si frontend cambia

**Solución:**
- SP retorna SOLO permisos=1
- Frontend no necesita filtrar

---

### 7. Sin auditoría de cambios
**Ubicación:** Sistema completo

**Problema:**
- Admin cambia permisos de usuario
- 2 semanas después, alguien pregunta: "¿Quién le dio acceso?"
- Respuesta: "No sé, no hay registros"

**Impacto:** Imposible rastrear cambios

**Solución:**
```sql
-- Crear tabla TblAuditoria
CREATE TABLE TblAuditoria (
    id_auditoria INT PRIMARY KEY AUTO_INCREMENT,
    tabla VARCHAR(50),
    operacion ENUM('INSERT', 'UPDATE', 'DELETE'),
    documento_usuario VARCHAR(20),
    documento_afectado VARCHAR(20),
    cambios JSON,
    fecha_cambio TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- En cada cambio:
INSERT INTO TblAuditoria VALUES (
    NULL, 'TblUsuarioPermisos', 'INSERT',
    session['user_documento'], '73017111',
    JSON_OBJECT('id_submenu', 5, 'permitido', 1),
    NOW()
);
```

---

### 8. Sin caché de menús
**Ubicación:** `sidebar.html` + `sp_ObtenerPermisosUsuario`

**Problema:**
- Cada carga de página = 1 query a BD
- 100 usuarios = 100 queries idénticas

**Impacto:** Lentitud con muchos usuarios

**Solución:**
```python
from flask_caching import Cache

cache = Cache(app, config={'CACHE_TYPE': 'redis'})

@main_bp.route('/api/menus/usuario/<num_documento>')
@cache.cached(timeout=300, query_string=True)  # 5 minutos
def api_menus_usuario(num_documento):
    # Cache la respuesta por usuario
    return obtener_menus_usuario_api(num_documento)
```

---

### 9. Eliminación hard-delete sin recuperación
**Ubicación:** `sp_EliminarAsesor`

**Problema:**
```sql
-- Elimina completamente del sistema
DELETE FROM TblUsuarios WHERE num_documento = '73017111';
-- Dato PERDIDO PERMANENTEMENTE
```

**Impacto:** Imposible auditar qué pasó con el usuario

**Solución:**
```sql
-- Soft-delete: Marcar como eliminado
UPDATE TblUsuarios 
SET estado = 'Eliminado', fecha_eliminacion = NOW()
WHERE num_documento = '73017111';

-- Datos aún existen, solo marcados como eliminados
```

---

### 10. Sin límite de intentos de login (Rate Limiting)
**Ubicación:** `auth.py`

**Problema:**
- SP bloquea usuario después de 5 intentos
- Pero hay 0 rate limiting en aplicación
- Atacante puede intentar 1000 usuarios/segundo

**Solución:**
```python
from flask_limiter import Limiter

limiter = Limiter(app, key_func=lambda: request.remote_addr)

@auth_bp.route('/login', methods=['POST'])
@limiter.limit("5 per minute")  # 5 intentos por minuto por IP
def login():
    ...
```

---

## 🟢 ESTADO ACTUAL

### ✅ FUNCIONANDO CORRECTAMENTE

| Componente | Estado | Notas |
|-----------|--------|-------|
| Autenticación | ✅ Funciona | Débil en seguridad, pero funciona |
| Carga menús | ✅ Funciona | Con doble filtrado innecesario |
| Asignación permisos | ✅ Funciona | Sin validación de rol admin |
| Registro asesores | ✅ Funciona | Con problemas de diseño |
| Gestión usuarios | ✅ Funciona | Sin auditoría |
| Sidebar renderizado | ✅ Funciona | Filtrado correcto implementado |

### ⚠️ PARCIALMENTE FUNCIONA

| Componente | Estado | Problema |
|-----------|--------|----------|
| Control de accesos | ⚠️ Parcial | Filtrado por menú OK, filtrado por datos NO |
| Permisos por área | ⚠️ Parcial | Sesión tiene área, pero no se usa |
| Contraseñas | ⚠️ Funciona | Débil: SHA-256 sin salt |

### 🔴 NO IMPLEMENTADO

| Componente | Estado | Necesario |
|-----------|--------|-----------|
| Auditoría de cambios | ❌ No existe | Crítico para compliance |
| Row-level security | ❌ No existe | Crítico para data leak prevention |
| Rate limiting | ❌ No existe | Importante para seguridad |
| Soft-delete | ❌ No existe | Importante para recuperación |
| Caché de datos | ❌ No existe | Importante para performance |

---

## 📋 PLAN DE ACCIÓN

### FASE 1: SEGURIDAD (CRÍTICO - 3 días)

- [ ] **Día 1:** Implementar control de acceso por área
  - Modificar SPs para aceptar parámetro área
  - Pasar `session['user_area']` en cada GET /api/*
  - Validar area es válida
  
- [ ] **Día 2:** Cambiar hash de contraseña a bcrypt
  - Generar contraseñas aleatorias (no documento)
  - Migrar hashes existentes
  - Implementar change-password-on-first-login
  
- [ ] **Día 3:** Agregar validación de rol
  - Crear decorador `@require_role`
  - Proteger rutas administrativas
  - Auditar permisos actuales

### FASE 2: AUDITORÍA (IMPORTANTE - 2 días)

- [ ] Crear tabla `TblAuditoria`
- [ ] Loguear todos los cambios (CREATE/UPDATE/DELETE)
- [ ] Dashboard de auditoría

### FASE 3: PERFORMANCE (MEDIA - 2 días)

- [ ] Caché Redis para menús
- [ ] Paginación en listados
- [ ] Índices en BD

### FASE 4: DATA INTEGRITY (IMPORTANTE - 3 días)

- [ ] Soft-delete en lugar de hard-delete
- [ ] Validación de jerarquía
- [ ] Unique constraints
- [ ] Transacciones explícitas

---

## 🔐 MATRIZ DE RIESGO

| # | Riesgo | Probabilidad | Impacto | Prioridad |
|---|--------|------------|--------|----------|
| 1 | Data leak entre áreas | ALTA | CRÍTICO | P0 |
| 2 | Fuerza bruta de contraseña | MEDIA | CRÍTICO | P0 |
| 3 | Usuario normal accede admin | MEDIA | CRÍTICO | P0 |
| 4 | Eliminación accidental irreversible | BAJA | ALTO | P1 |
| 5 | Sin auditoría de cambios | MEDIA | ALTO | P1 |
| 6 | Performance degradada | BAJA | MEDIO | P2 |

---

## 📞 SIGUIENTE ACCIÓN

**Recomendación:** Arreglar los 3 problemas P0 antes de seguir en producción.

Tiempo estimado: 3 días  
Riesgo de cambios: BAJO (mejoras de seguridad)  
Rollback si es necesario: SÍ (git tags disponibles)

---

**Generado por:** Revisión de Flujo del Sistema  
**Fecha:** Julio 3, 2026  
**Disponible en:** REVISION_FLUJO_SISTEMA.md
