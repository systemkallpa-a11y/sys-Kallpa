# 📋 MIGRACIÓN A STORED PROCEDURES - REQUERIMIENTOS

## 🎯 Objetivo
Reemplazar todas las consultas SQL directas en `requerimientos.py` por Stored Procedures para:
- Centralizar lógica de negocio en la base de datos
- Mejorar seguridad y mantenibilidad
- Reducir complejidad en código Python

---

## ✅ CAMBIOS REALIZADOS

### 1️⃣ **Lectura de Requerimientos**

#### **SP Creado:** `sp_ObtenerRequerimiento`
- **Archivo:** `database_scripts/sp_ObtenerRequerimiento.sql`
- **Propósito:** Obtener información completa de un requerimiento con solicitante y presupuesto

#### **SP Creado:** `sp_ObtenerRequerimientoDetalles`
- **Archivo:** `database_scripts/sp_ObtenerRequerimiento.sql`
- **Propósito:** Obtener todos los detalles (items) de un requerimiento con materiales y unidades

#### **Funciones Python Actualizadas:**
- ✅ `obtener_requerimiento()` - Usa ambos SPs
- ✅ `obtener_requerimiento_detalles()` - Usa ambos SPs

---

### 2️⃣ **Eliminación de Requerimientos**

#### **SP Creado:** `sp_EliminarRequerimiento`
- **Archivo:** `database_scripts/sp_EliminarRequerimiento.sql`
- **Propósito:** Hard delete de requerimiento con reversión de presupuesto
- **Funcionalidad:**
  - Elimina detalles del requerimiento
  - Elimina registros de aprobación
  - Elimina requerimiento principal
  - Reversa cambios en `TblPresupuesto` (cantidad_consumida, cantidad_saldo, monto_gastado)
  - Reversa cambios en `TblPresupuestoDetalle` por descripción
- **Parámetros OUT:**
  - `p_codigo`: Código del requerimiento eliminado
  - `p_detalles_eliminados`: Número de detalles eliminados
  - `p_aprobaciones_eliminadas`: Número de aprobaciones eliminadas
  - `p_presupuesto_reversado`: Boolean indicando si se reversó presupuesto
  - `p_mensaje`: Mensaje de resultado

#### **Función Python Actualizada:**
- ✅ `eliminar_requerimiento()` - Usa `sp_EliminarRequerimiento`

---

### 3️⃣ **Aprobación de Requerimientos**

#### **SP Creado:** `sp_AprobarRequerimiento`
- **Archivo:** `database_scripts/sp_AprobarRequerimiento.sql`
- **Propósito:** Aprobación progresiva de requerimientos
- **Funcionalidad:**
  - Verifica que usuario tenga cargo activo
  - Verifica que tenga registro PENDIENTE para este requerimiento
  - Actualiza registro a APROBADO
  - Si todos los pasos están aprobados, cambia estado del requerimiento a APROBADO
- **Parámetros OUT:**
  - `p_aprobacion_completa`: Boolean indicando si se completó la aprobación total
  - `p_mensaje`: Mensaje de resultado con progreso

#### **Función Python Actualizada:**
- ✅ `aprobar_requerimiento()` - Usa `sp_AprobarRequerimiento`

---

## 📦 ARCHIVOS CREADOS

```
database_scripts/
├── sp_ObtenerRequerimiento.sql          ← Lectura de requerimientos
├── sp_EliminarRequerimiento.sql         ← Eliminación con reversión
└── sp_AprobarRequerimiento.sql          ← Aprobación progresiva
```

---

## 🚀 INSTRUCCIONES DE DEPLOY

### **PASO 1: Ejecutar SPs en MySQL Workbench**

Ejecutar en orden:

1. **Lectura:**
   ```sql
   -- Archivo: sp_ObtenerRequerimiento.sql
   -- Selecciona TODO y ejecuta
   ```

2. **Eliminación:**
   ```sql
   -- Archivo: sp_EliminarRequerimiento.sql
   -- Selecciona TODO y ejecuta
   ```

3. **Aprobación:**
   ```sql
   -- Archivo: sp_AprobarRequerimiento.sql
   -- Selecciona TODO y ejecuta
   ```

### **PASO 2: Verificar SPs Creados**

```sql
-- Verificar que los SPs existen
SHOW PROCEDURE STATUS WHERE Db = 'kallpasystem$kallgwkn_kallpa_bd'
AND Name IN ('sp_ObtenerRequerimiento', 
             'sp_ObtenerRequerimientoDetalles',
             'sp_EliminarRequerimiento',
             'sp_AprobarRequerimiento');
```

### **PASO 3: Probar Localmente**

```bash
# En tu máquina local
cd sys-Kallpa
python run.py
```

**Pruebas recomendadas:**
1. Abrir detalle de requerimiento → Verificar que se muestra solicitante
2. Aprobar un requerimiento → Verificar que progresa correctamente
3. Eliminar un requerimiento → Verificar que se reversa presupuesto

### **PASO 4: Commit y Push**

```bash
git add .
git commit -m "Migración a SPs: lectura, eliminación y aprobación de requerimientos"
git push origin main
```

### **PASO 5: Deploy a Producción**

```bash
# En el servidor PythonAnywhere
cd ~/sys-Kallpa
git pull origin main
touch tmp/restart.txt
```

---

## 🔍 CONSULTAS DIRECTAS QUE PERMANECEN

Las siguientes funciones **AÚN USAN CONSULTAS DIRECTAS** porque:
- Ya usan SPs existentes (crear, actualizar)
- Son operaciones de lectura simple
- No requieren lógica compleja

### ✅ **Ya usan SPs:**
- `crear_requerimiento()` → Usa `sp_CrearRequerimiento`
- `actualizar_requerimiento()` → Usa `sp_ActualizarRequerimiento`
- `rechazar_requerimiento()` → Usa `sp_RechazarRequerimiento`

### 📊 **Consultas simples (no requieren SP):**
- `obtener_flujo_requerimiento()` → Solo lee flujo de aprobación
- `puede_aprobar()` → Verificación simple de permisos

---

## 📊 RESUMEN

| Función | Estado | SP Usado |
|---------|--------|----------|
| `obtener_requerimiento()` | ✅ Migrado | `sp_ObtenerRequerimiento` + `sp_ObtenerRequerimientoDetalles` |
| `obtener_requerimiento_detalles()` | ✅ Migrado | `sp_ObtenerRequerimiento` + `sp_ObtenerRequerimientoDetalles` |
| `eliminar_requerimiento()` | ✅ Migrado | `sp_EliminarRequerimiento` |
| `aprobar_requerimiento()` | ✅ Migrado | `sp_AprobarRequerimiento` |
| `crear_requerimiento()` | ✅ Ya usaba SP | `sp_CrearRequerimiento` |
| `actualizar_requerimiento()` | ✅ Ya usaba SP | `sp_ActualizarRequerimiento` |
| `rechazar_requerimiento()` | ✅ Ya usaba SP | `sp_RechazarRequerimiento` |

---

## ✨ BENEFICIOS

1. **Seguridad:** Lógica de negocio protegida en BD
2. **Mantenibilidad:** Cambios en lógica solo requieren actualizar SP
3. **Consistencia:** Misma lógica usada desde cualquier cliente
4. **Performance:** Menos round-trips a BD
5. **Transacciones:** Manejo atómico de operaciones complejas

---

## 🐛 TROUBLESHOOTING

### **Error: PROCEDURE does not exist**
```bash
# Ejecutar los scripts SQL en MySQL Workbench
# Verificar con:
SHOW PROCEDURE STATUS WHERE Name LIKE 'sp_%Requerimiento%';
```

### **Error: Access denied**
```bash
# Si no tienes permisos para crear SPs, pedir al admin:
GRANT CREATE ROUTINE ON kallpasystem$kallgwkn_kallpa_bd.* TO 'kallpasystem'@'%';
```

### **Error al obtener parámetros OUT**
```python
# Asegúrate de usar callproc correctamente:
result = cursor.callproc('sp_NombreSP', [param1, param2, out1_placeholder, out2_placeholder])
# Los valores OUT están en result[índice_out]
```

---

**Fecha:** 3 de Agosto de 2026  
**Autor:** Kiro AI Assistant  
**Versión:** 1.0
