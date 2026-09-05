# CONTEXTO DEL SISTEMA KALLPA
**Última actualización:** 29/08/2026

---

## 1. DESCRIPCIÓN GENERAL

**Kallpa** es un sistema de gestión integral para corredores inmobiliarios. Permite gestionar usuarios, clientes, proyectos, presupuestos, requerimientos, órdenes de compra, marcación de asistencia y flujos de aprobación.

**URL Producción:** https://kallpainmovilaria.com  
**Servidor:** Namecheap (162.213.251.186 / 63.250.38.196)  
**Usuario SSH:** kallgwkn / kallugwo

---

## 2. TECNOLOGÍAS

| Componente | Tecnología |
|------------|------------|
| Backend | Flask 2.0.3 (Python) |
| Base de Datos | MySQL 8.0 |
| Frontend | HTML, CSS, JavaScript vanilla |
| Servidor Producción | Passenger (Namecheap cPanel) |
| Autenticación | SHA-256 hash + Flask sessions |
| Zona Horaria | UTC-5 (Perú) |

**Dependencias clave:**
- Flask==2.0.3
- mysql-connector-python==8.0.26
- python-dotenv==0.19.0
- openpyxl==3.1.3
- **pdfplumber==0.11.10** (instalado, NO está en requirements.txt - pendiente agregar)

---

## 3. ESTRUCTURA DEL PROYECTO

```
sys-Kallpa/
├── app/
│   ├── __init__.py              # Creación de Flask app, blueprints, logging
│   ├── config.py                # DatabaseConfig + SSH tunnel (opcional)
│   ├── funciones/
│   │   └── funGeneral.py        # get_db_connection(), hash_password()
│   ├── routes/
│   │   ├── __init__.py          # Definición de blueprints (main_bp, auth_bp)
│   │   ├── main.py              # Ruta raíz, dashboard, validar_acceso_usuario()
│   │   ├── auth.py              # Login, logout, welcome, sesión
│   │   ├── presupuesto.py       # CRUD presupuestos + importar PDF (~2400 líneas)
│   │   ├── requerimientos.py    # CRUD requerimientos (~900 líneas)
│   │   ├── ordenes_compra.py    # Órdenes de compra (~550 líneas)
│   │   ├── marcacion.py         # Marcación entrada/salida con GPS (~775 líneas)
│   │   ├── usuarios.py          # Gestión usuarios + horarios (~918 líneas)
│   │   ├── roles.py             # Roles y permisos
│   │   ├── empresa.py           # Gestión de empresas
│   │   ├── empresa_logo.py      # Logos de empresa
│   │   ├── materiales.py        # Catálogo de materiales
│   │   ├── flujo_aprobacion.py  # Flujo de aprobación de documentos
│   │   ├── guardar_cambios_flujo.py
│   │   ├── gerencia.py          # Vistas de gerencia
│   │   ├── ot.py                # Órdenes de trabajo
│   │   ├── pdf_helpers.py       # Utilidades para PDFs
│   │   ├── presupuesto_pdf.py   # Generación PDF presupuesto
│   │   └── requerimientos_pdf.py # Generación PDF requerimiento
│   ├── static/
│   │   ├── css/styles.css       # Estilos principales
│   │   ├── css/animations.css   # Animaciones
│   │   └── js/
│   │       ├── presupuesto.js   # Lógica frontend presupuestos
│   │       ├── ordenes_compra.js
│   │       ├── flujo_aprobacion.js
│   │       ├── sidebar.js       # Menú lateral
│   │       ├── sidebar-accesos.js
│   │       └── theme.js         # Tema oscuro/claro
│   └── templates/
│       ├── base.html            # Template base (incluye sidebar)
│       ├── login_kallpa.html    # Login
│       ├── dashboard.html       # Dashboard principal
│       ├── welcome.html         # Página de bienvenida
│       ├── marcacion_kallpa.html # Marcación móvil
│       ├── reporte_asistencia.html
│       ├── presupuesto.html     # Gestión presupuestos
│       ├── requerimiento.html   # Gestión requerimientos
│       ├── ordenes_compra.html  # Órdenes de compra
│       ├── usuarios.html        # Gestión usuarios
│       ├── roles.html           # Roles
│       ├── empresa.html         # Empresas
│       ├── ot.html              # Órdenes de trabajo
│       ├── vacaciones.html      # Vacaciones (CON API REAL)
│       └── gerencia/            # Vistas de gerencia
├── database_scripts/            # Scripts SQL y documentación
├── docs_sistema/                # Documentación del sistema
├── logs/                        # Logs de aplicación
├── main.py                      # Punto de entrada Flask
├── index.php                    # Proxy PHP (producción Namecheap)
├── requirements.txt             # Dependencias Python
└── .env                         # Variables de entorno (no subir a git)
```

---

## 4. BASE DE DATOS

**Nombre:** kallgwkn_kallpa_bd  
**Conexión:** localhost:3306 (producción) o vía SSH tunnel (desarrollo)

### Principales tablas:

| Tabla | Propósito |
|-------|-----------|
| TblUsuario | Usuarios del sistema |
| TblPersona | Datos personales |
| TblCargo | Cargos |
| TblArea | Áreas |
| TblMenu | Menús del sistema |
| TblSubMenu | Submenús |
| TblUsuarioAccesos | Permisos de acceso |
| TblPresupuesto | Cabecera de presupuestos |
| TblPresupuestoDetalle | Detalle (materiales/servicios) |
| TblMateriales | Catálogo de materiales |
| TblRequerimiento | Requerimientos |
| TblRequerimientoDetalle | Detalle de requerimientos |
| TblOrdeneCompra | Órdenes de compra |
| TblMarcacion | Marcaciones entrada/salida |
| TblHorarioTrabajo | Horarios de trabajo |
| TblVacaciones | Solicitudes de vacaciones |
| TblVacacionSaldo | Saldo anual de vacaciones |
| TblEmpresa | Empresas |
| TblObra/Obrero | Proyectos/obras |

**Stored Procedures:** ~57 SPs (sp_ReportePresupuestos, sp_ObtenerRequerimientosConAprobadores, sp_ObtenerVacaciones, sp_CrearVacacion, sp_AprobarVacacion, etc.)

---

## 5. SISTEMA DE AUTENTICACIÓN Y PERMISOS

### Login:
- Credenciales: usuario + contraseña (SHA-256)
- Tabla: TblUsuario (campos: usuario, password_hash, estado)
- Sesión Flask con: user_documento, user_id, user_name, user_email, user_cargo, user_area

### Permisos:
- Sistema de menús y submenús
- Tabla: TblUsuarioAccesos (num_documento, id_menu, id_submenu, estado)
- Función: `validar_acceso_usuario(num_documento, id_menu, id_submenu)`
- Si id_submenu es NULL → acceso completo al menú
- Si id_submenu tiene valor → acceso específico

### Menús del sistema (IDs en BD):
| ID | Menú |
|----|------|
| 1 | RR.HH. |
| 2 | Compras/Logística |
| 5 | O.T (Órdenes de Trabajo) |

### Submenús relevantes:
| id_menu | id_submenu | Nombre |
|---------|------------|--------|
| 2 | 4 | Requerimientos |
| 2 | 5 | Órdenes de Compra |
| 5 | 9 | Presupuesto |

---

## 6. FUNCIONALIDADES PRINCIPALES

### 6.1 Marcación de Asistencia
- **Ruta:** `/marcacion-kallpa` (móvil) y `/marcacion` (admin)
- **Blueprint:** `marcacion_bp`
- **Funcionalidad:** Registro entrada/salida con GPS y foto
- **Archivos:** marcacion.py, marcacion_kallpa.html, reporte_asistencia.html

### 6.2 Presupuestos
- **Ruta:** `/presupuesto`
- **Endpoint principal:** `/api/presupuestos/obtener` (usa SP sp_ReportePresupuestos)
- **Funcionalidad:** Crear, editar, importar PDF para auto-rellenar
- **Importante:** SP retorna múltiples result sets → usar `multi=True`
- **Archivos:** presupuesto.py (~2400 líneas), presupuesto.html, presupuesto.js

#### 6.2.1 Importar PDF (IMPLEMENTADO - 13/08/2026)
- **Endpoint:** `POST /api/presupuestos/importar-pdf`
- **Descripción:** Parser de PDFs de presupuesto que extrae materiales y servicios
- **Estado:** Implementado - Crea materiales automáticamente en BD
- **Dependencia:** `pdfplumber==0.11.10` (NO está en requirements.txt)
- **Código backend:** `presupuesto.py` líneas 2345-2419
- **Código frontend:** `presupuesto.js` función `importarPDF()` (línea 1731)
- **UI:** Botón 📎 en header del modal de presupuesto
- **Flujo:**
  1. Usuario sube PDF → endpoint parsea con pdfplumber
  2. Extrae items con regex: `XX.XX.XX DESCRIPCION unidad cantidad precio subtotal`
  3. Clasifica por unidad: materiales (m2, kg, und) vs servicios (mes, día)
  4. Filtra filas de resumen/totales (FILAS_RESUMEN)
  5. **Por cada material:**
     - Busca en TblMateriales por nombre exacto
     - Si NO existe → busca id_unidad en TblUnidadMedida → crea con sp_CrearMaterialConCodigoAuto
     - Si YA existe → usa el id_material existente
  6. Retorna JSON con `materiales[]`, `materiales_nuevos[]`, `materiales_existentes[]`
- **SPs utilizados:**
  - `sp_BuscarMaterialPorNombre(p_nombre)` → retorna id_material
  - `sp_BuscarUnidadPorNombre(p_nombre)` → retorna id_unidad
  - `sp_CrearMaterialConCodigoAuto(...)` → crea material con código MAT-XXX
- **Pendientes:**
  - Agregar pdfplumber a requirements.txt
  - Probar con otros formatos de PDF

### 6.3 Requerimientos
- **Ruta:** `/requerimiento`
- **Endpoint:** `/api/requerimientos/obtener` (usa SP sp_ObtenerRequerimientosConAprobadores)
- **Funcionalidad:** CRUD completo con flujo de aprobación
- **Archivos:** requerimientos.py (~900 líneas), requerimiento.html

### 6.4 Órdenes de Compra
- **Ruta:** `/ordenes-compra`
- **Permisos:** Menu 2, SubMenu 5
- **Funcionalidad:** Crear OC a partir de requerimientos aprobados
- **Archivos:** ordenes_compra.py, ordenes_compra.html

### 6.5 Gestión de Usuarios
- **Ruta:** `/usuarios` (implícita en routes)
- **Funcionalidad:** CRUD usuarios, horarios de trabajo (2 turnos por día)
- **Archivos:** usuarios.py (~918 líneas), usuarios.html

### 6.6 Flujo de Aprobación
- **Archivos:** flujo_aprobacion.py, guardar_cambios_flujo.py
- **JS:** flujo_aprobacion.js, flujo_aprobacion_visual.js

### 6.7 Gestión de Empresas
- **Archivos:** empresa.py, empresa_logo.py, empresa.html

### 6.8 Roles
- **Archivos:** roles.py, roles.html

### 6.9 Módulo de Vacaciones
- **Ruta:** `/vacaciones`
- **Endpoint principal:** `/api/vacaciones/obtener` (usa SP sp_ObtenerVacaciones)
- **Funcionalidad:** CRUD completo: solicitar, aprobar, rechazar, editar, eliminar
- **Saldo:** 30 días/año, calculado automáticamente
- **Integración:** Vacaciones aprobadas aparecen como "VACACIONES" en reporte de asistencia
- **Archivos:** vacaciones.py (~350 líneas), vacaciones.html
- **BD:** TblVacaciones, TblVacacionSaldo, 8 SPs

---

## 7. ARCHIVOS CLAVE PARA CADA SESIÓN

### Si vas a modificar PRESUPUESTOS:
1. `app/routes/presupuesto.py` - Backend (~2400 líneas)
2. `app/templates/presupuesto.html` - Frontend HTML
3. `app/static/js/presupuesto.js` - Lógica JS
4. `app/routes/presupuesto_pdf.py` - Generación PDF

### Si vas a modificar REQUERIMIENTOS:
1. `app/routes/requerimientos.py` - Backend (~900 líneas)
2. `app/templates/requerimiento.html` - Frontend HTML

### Si vas a modificar MARCACIÓN:
1. `app/routes/marcacion.py` - Backend (~775 líneas)
2. `app/templates/marcacion_kallpa.html` - Vista móvil
3. `app/templates/reporte_asistencia.html` - Vista admin

### Si vas a modificar USUARIOS:
1. `app/routes/usuarios.py` - Backend (~918 líneas)
2. `app/templates/usuarios.html` - Frontend HTML

### Si vas a modificar ÓRDENES DE COMPRA:
1. `app/routes/ordenes_compra.py` - Backend (~550 líneas)
2. `app/templates/ordenes_compra.html` - Frontend HTML

---

## 8. PROBLEMAS CONOCIDOS Y SOLUCIONES

### Problema: SP con múltiples result sets
**Error:** "Use multi=True when executing multiple statements"  
**Solución:** Usar `cursor.execute('CALL sp_XXX()', multi=True)` y consumir todos los result sets.

### Problema: Conexión SSH tunnel
**Configuración:** En `.env` con `USE_SSH_TUNNEL=True`  
**Archivo:** `app/config.py` - función `get_ssh_tunnel()`

---

## 8.1 FUNCIONALIDAD: IMPORTAR PDF EN PRESUPUESTOS

**Archivo de referencia:** `docs_sistema/03_FUNCIONALIDADES_CAMBIOS.txt`

### Elementos clave:

| Ubicación | Descripción |
|-----------|-------------|
| `presupuesto.py:2215-2226` | `UNIDADES_SERVICIO` - lista de unidades que clasifican como servicio |
| `presupuesto.py:2228-2234` | `FILAS_RESUMEN` - palabras clave para filtrar totales |
| `presupuesto.py:2237-2245` | `clasificar_unidad()` - determina MATERIAL o SERVICIO |
| `presupuesto.py:2248-2250` | `es_fila_item()` - valida formato XX.XX.XX |
| `presupuesto.py:2253-2342` | `extraer_items_del_pdf()` - parser principal |
| `presupuesto.py:2345-2419` | Endpoint `POST /api/presupuestos/importar-pdf` |
| `presupuesto.html:2-5` | Botón upload + input file oculto |
| `presupuesto.js:1731-1823` | Función `importarPDF()` - frontend |

### Regex utilizado:
```
# Para extraer código + descripción
^(\d{2}\.\d{2}\.\d{2})\s+(.+)

# Para extraer descripción + unidad + cantidad + precio + subtotal
^(.+?)\s+([a-zA-Záéíóúñ\d]+)\s+([\d,.]+)\s+([\d,.]+)\s+([\d,.]+)\s*$
```

### Constantes:
- **UNIDADES_SERVICIO:** mes, dia, día, semana, hora, hora, h, min, minuto, año, quincena, bimestre, trimestre, semestre
- **FILAS_RESUMEN:** costo directo, costo total, gastos generales, utilidad, subtotal, igv, presupuesto total

### SPs para auto-creación de materiales:
- **sp_BuscarMaterialPorNombre(p_nombre)** → Retorna id_material si existe
- **sp_BuscarUnidadPorNombre(p_nombre)** → Retorna id_unidad buscando por abreviatura o nombre
- **sp_CrearMaterialConCodigoAuto(...)** → Crea material con código MAT-XXX automático

---

## 9. COMANDOS ÚTILES

```bash
# Ejecutar aplicación localmente
python main.py

# Verificar conexión a BD
python verificar_conexion.py

# Iniciar en Windows
iniciar.bat

# Ver logs
# Archivo: logs/kallpa_app.log
```

---

## 10. VARIABLES DE ENTorno (.env)

```env
SECRET_KEY=7c705c25adc799bf3444babc43da4bb48fe11dfee5dd826a242ad7f5b71533cd
DEBUG=True

DB_HOST=localhost
DB_PORT=3306
DB_USER=kallgwkn_user
DB_PASSWORD=<password>
DB_NAME=kallgwkn_kallpa_bd

# SSH Tunnel (opcional)
USE_SSH_TUNNEL=False
SSH_HOST=ssh.pythonanywhere.com
SSH_PORT=22
SSH_USER=<user>
SSH_PASSWORD=<password>
```

---

## 11. NOTAS IMPORTANTES

1. **Nunca subir `.env` a Git** - contiene credenciales
2. **Producción usa PHP proxy** (`index.php`) que redirige a Flask en puerto 5000
3. **ASSETS_VERSION** en `app/__init__.py` - incrementar al modificar archivos estáticos
4. **Timezone:** Sistema usa UTC-5 (hora Perú)
5. **Encoding:** Todo usa UTF-8
6. **pdfplumber** está instalado pero NO está en requirements.txt
7. **Blueprints registrados:** main_bp, auth_bp, pdf_bp, requerimientos_pdf_bp, logo_bp, materiales_bp, marcacion_bp, vacaciones (usa main_bp)

---

*Documento generado automáticamente para mantener contexto entre sesiones de desarrollo.*

Documentos de referencia:
- `docs_sistema/01_PROBLEMAS_Y_SOLUCIONES.txt` - Errores conocidos
- `docs_sistema/02_PASOS_EJECUCION_LOCAL.txt` - Pasos para ejecutar localmente
- `docs_sistema/03_FUNCIONALIDADES_CAMBIOS.txt` - Importar PDF en presupuestos
- `docs_sistema/04_FUNCIONALIDADES_CAMBIOS_29_08.txt` - Módulo de Vacaciones (29/08/2026)
