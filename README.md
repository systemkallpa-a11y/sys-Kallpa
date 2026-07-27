# Kallpa - Sistema de Gestión Inmobiliaria

Sistema de gestión para corredores inmobiliarios desarrollado con Flask y MySQL.

## 📋 Tabla de Contenidos

- [Descripción](#descripción)
- [Tecnologías](#tecnologías)
- [Configuración Local](#configuración-local)
- [Despliegue en Producción](#despliegue-en-producción)
- [Base de Datos](#base-de-datos)
- [Estructura del Proyecto](#estructura-del-proyecto)

---

## 📝 Descripción

Kallpa es un sistema de gestión para corredores inmobiliarios que incluye:
- Gestión de usuarios y asesores
- Sistema de autenticación
- Gestión de clientes
- Sistema de tareas

---

## 🛠 Tecnologías

- **Backend:** Flask 3.0.3
- **Base de Datos:** MySQL 8.0
- **Frontend:** HTML, CSS, JavaScript
- **Servidor Producción:** Passenger (Namecheap)
- **Dependencias:** Ver `requirements.txt`

---

## 💻 Configuración Local

### 1. Clonar repositorio

```bash
git clone <repository-url>
cd sys-Kallpa
```

### 2. Crear entorno virtual

```bash
python -m venv venv
venv\Scripts\activate  # Windows
```

### 3. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 4. Configurar variables de entorno

Editar archivo `.env`:

```env
SECRET_KEY=7c705c25adc799bf3444babc43da4bb48fe11dfee5dd826a242ad7f5b71533cd
DEBUG=True

# Base de Datos
DB_HOST=localhost
DB_PORT=3306
DB_USER=kallgwkn_user
DB_PASSWORD=TU_PASSWORD_AQUI
DB_NAME=kallgwkn_kallpa_bd
```

### 5. Ejecutar aplicación

```bash
python main.py
```

Abrir en navegador: http://localhost:5000

### 6. Verificar conexión a BD

```bash
python verificar_conexion.py
```

---

## 🚀 Despliegue en Producción

### Producción: Namecheap

**URL:** https://kallpainmovilaria.com

#### Subir archivos con WinSCP:

1. **Conectar:**
   - Host: `162.213.251.186`
   - Usuario: `kallgwkn`
   - Password: `#215292159xD`

2. **Subir archivos desde `namecheap_deploy/`:**
   - Todos los archivos → `/home/kallugwo/kallpa/`

3. **Editar `.env` en servidor:**
   ```env
   SECRET_KEY=7c705c25adc799bf3444babc43da4bb48fe11dfee5dd826a242ad7f5b71533cd
   DEBUG=False
   
   DB_HOST=localhost
   DB_PORT=3306
   DB_USER=kallgwkn_user
   DB_PASSWORD=PASSWORD_MYSQL_REAL
   DB_NAME=kallgwkn_kallpa_bd
   ```

4. **Reiniciar aplicación:**
   - cPanel → Setup Python App → Restart
   - O crear archivo: `touch ~/kallpa/tmp/restart.txt`

#### Logs de Producción:

```bash
tail -f ~/kallpa/logs/kallpa.log
```

---

## 🗄 Base de Datos

### Credenciales Producción (Namecheap):

```
Host: localhost
Port: 3306
User: kallgwkn_user
Database: kallgwkn_kallpa_bd
Password: [Obtener desde cPanel → MySQL Databases]
```

### Backup de Base de Datos:

- **Archivo:** `kallpa_backup.sql`
- **Estado:** Ya importado en Namecheap

### Importar backup (si es necesario):

1. Ir a phpMyAdmin en cPanel
2. Seleccionar base de datos `kallgwkn_kallpa_bd`
3. Importar → Seleccionar archivo `kallpa_backup.sql`
4. Click en "Importar"

---

## 📁 Estructura del Proyecto

```
sys-Kallpa/
├── app/
│   ├── funciones/          # Funciones de negocio
│   ├── routes/             # Rutas de Flask
│   ├── static/             # CSS, JS, imágenes
│   ├── templates/          # Plantillas HTML
│   ├── config.py           # Configuración de BD
│   └── __init__.py
├── namecheap_deploy/       # Archivos para producción
├── .env                    # Variables de entorno (local)
├── .env.example            # Ejemplo de variables
├── .gitignore
├── main.py                 # Punto de entrada
├── requirements.txt        # Dependencias
├── Procfile                # Para Railway/Heroku
├── iniciar.bat             # Script de inicio Windows
├── verificar_conexion.py   # Verificar BD
└── README_MIGRACION.md     # Guía de migración de BD
```

---

## 🔧 Scripts Útiles

### Windows:

```bash
# Iniciar aplicación
iniciar.bat

# Verificar conexión a BD
python verificar_conexion.py

# Generar nueva SECRET_KEY
python generar_secret_key.py
```

---

## 📚 Documentación Adicional

- **`README_MIGRACION.md`** - Guía de migración de base de datos
- **`INSTRUCCIONES_ACTUALIZAR_BD.md`** - Instrucciones detalladas de actualización
- **`RESUMEN_MIGRACION_BD.txt`** - Resumen visual de la migración

---

## 🔐 Seguridad

- Las credenciales están en `.env` (no se sube a Git)
- Passwords hasheados con SHA-256
- SECRET_KEY único por instalación
- Validación de sesiones

---

## 📞 Soporte

Si encuentras problemas:

1. Revisar logs: `~/kallpa/logs/kallpa.log`
2. Verificar credenciales en `.env`
3. Ejecutar `python verificar_conexion.py`
4. Revisar documentación en `README_MIGRACION.md`

---

## 📝 Notas

- **Base de Datos:** Migrada de servidor externo a Namecheap (localhost)
- **Producción:** https://kallpainmovilaria.com
- **Backup BD:** `kallpa_backup.sql` (sin DEFINER)

---

**Desarrollado para Kallpa Inmobiliaria**
