# 📋 RESUMEN DE CAMBIOS: PRESUPUESTO CON DESGLOSE EDITABLE

**Fecha**: 2026-07-22  
**Funcionalidad**: Campos editables para Gastos Generales, Utilidad y Supervisión de Obra

---

## 🎯 OBJETIVO
Permitir que los campos **Gastos Generales**, **Utilidad** y **Supervisión de Obra** sean editables en los modales de "Crear Nuevo Presupuesto" y "Editar Presupuesto", en lugar de ser calculados automáticamente con porcentajes fijos.

---

## 🔧 CAMBIOS REALIZADOS

### 1. FRONTEND (Templates y JavaScript)

#### **Template: `app/templates/presupuesto.html`**
- ✅ **Agregados campos editables** en la sección "Desglose Financiero":
  - Input `gastos-generales` 
  - Input `utilidad`
  - Input `supervision-obra`
- ✅ **Botones de ayuda**:
  - "Calcular % Automático" (10%, 15%, 5%)
  - "Limpiar Desglose" (poner en 0)
- ✅ **IGV automático**: Se muestra como calculado automáticamente (18%)
- ✅ **Funciones JavaScript modificadas**:
  - `guardarPresupuesto()` - Envía campos del desglose al backend
  - `cargarDatosPresupuestoParaEditar()` - Carga campos del desglose al editar

#### **JavaScript: `app/static/js/presupuesto.js`**
- ✅ **Función `actualizarTotales()` modificada**: Usa valores de inputs en lugar de cálculos automáticos
- ✅ **Nuevas funciones agregadas**:
  - `calcularPorcentajesAutomaticos()` - Aplica porcentajes estándar
  - `limpiarDesglose()` - Pone campos en 0
- ✅ **Event listeners**: Los campos se recalculan automáticamente al cambiar valores

### 2. BACKEND (Python)

#### **Route: `app/routes/presupuesto.py`**
- ✅ **Función `crear_presupuesto()`**: 
  - Recibe `gastos_generales`, `utilidad`, `supervision_obra` del frontend
  - Pasa estos valores al SP como parámetros
- ✅ **Función `actualizar_presupuesto_editar()`**:
  - Recibe campos del desglose del frontend
  - Pasa estos valores al SP como parámetros  
- ✅ **Función `obtener_presupuesto_para_editar()`**: Ya consultaba campos del desglose

### 3. BASE DE DATOS (Stored Procedures)

#### **SP Creado: `sp_CrearPresupuestoCompleto`**
```sql
CREATE PROCEDURE sp_CrearPresupuestoCompleto(
    IN p_id_empresa INT,
    IN p_id_obra INT, 
    IN p_num_documento VARCHAR(20),
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_utilidad DECIMAL(12,2),            -- ⭐ NUEVO  
    IN p_supervision_obra DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_materiales_json JSON,
    IN p_servicios_json JSON,
    OUT p_id_presupuesto_created INT
)
```

#### **SP Actualizado: `sp_ActualizarPresupuestoCompleto`**
```sql
CREATE PROCEDURE sp_ActualizarPresupuestoCompleto(
    IN p_id_presupuesto INT,
    IN p_id_empresa INT,
    IN p_id_obra INT,
    IN p_num_documento VARCHAR(20), 
    IN p_comentarios LONGTEXT,
    IN p_gastos_generales DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_utilidad DECIMAL(12,2),            -- ⭐ NUEVO
    IN p_supervision_obra DECIMAL(12,2),    -- ⭐ NUEVO
    IN p_materiales_json JSON,
    IN p_servicios_json JSON
)
```

#### **Lógica de Cálculo**:
- ✅ **IGV automático**: `IGV = (subtotal + gastos_generales + utilidad + supervision_obra) × 0.18`
- ✅ **Monto total**: `Total = subtotal + gastos_generales + utilidad + supervision_obra + IGV`

---

## 📁 ARCHIVOS CREADOS/MODIFICADOS

### Archivos Nuevos
- ✅ `database_scripts/SP_CREAR_PRESUPUESTO_CON_DESGLOSE_EDITABLE.sql`
- ✅ `database_scripts/SP_ACTUALIZAR_PRESUPUESTO_CON_DESGLOSE_EDITABLE.sql`
- ✅ `EJECUTAR_SPS_DESGLOSE_EDITABLE.sql`
- ✅ `RESUMEN_CAMBIOS_DESGLOSE_EDITABLE.md`

### Archivos Modificados
- ✅ `app/templates/presupuesto.html`
- ✅ `app/static/js/presupuesto.js` 
- ✅ `app/routes/presupuesto.py`

---

## 🚀 PASOS PARA IMPLEMENTAR

### 1. Ejecutar Scripts de Base de Datos
```bash
# En MySQL Workbench o cliente MySQL:
source EJECUTAR_SPS_DESGLOSE_EDITABLE.sql;
```

### 2. Reiniciar Flask
```bash
# Para cargar los cambios de Python
flask run
# o
python app.py
```

### 3. Probar Funcionalidad
1. **Crear Presupuesto**:
   - Ir a módulo Presupuestos → "Crear Nuevo Presupuesto"
   - Agregar materiales/servicios
   - Editar campos: Gastos Generales, Utilidad, Supervisión
   - Verificar que IGV se calcula automáticamente
   - Guardar y verificar en base de datos

2. **Editar Presupuesto**: 
   - Abrir presupuesto existente → "Editar"
   - Verificar que campos se cargan correctamente
   - Modificar valores del desglose
   - Guardar y verificar cambios

---

## 🔍 VERIFICACIÓN EN BASE DE DATOS

```sql
-- Verificar que los SPs existen
SHOW PROCEDURE STATUS WHERE 
    Name IN ('sp_CrearPresupuestoCompleto', 'sp_ActualizarPresupuestoCompleto');

-- Verificar campos en TblPresupuesto
SELECT 
    id_presupuesto,
    numero_presupuesto, 
    monto,
    gastos_generales,
    utilidad,
    supervision_obra,
    igv,
    monto_total
FROM TblPresupuesto 
ORDER BY id_presupuesto DESC 
LIMIT 5;
```

---

## ✨ FUNCIONALIDAD RESULTANTE

### Para el Usuario:
1. **Flexibilidad**: Puede editar campos del desglose según necesidades del proyecto
2. **Automatización**: Botón para aplicar porcentajes estándar (10%, 15%, 5%)
3. **Simplicidad**: IGV se calcula automáticamente 
4. **Control**: Puede poner campos en 0 si no aplican gastos adicionales

### Para el Sistema:
1. **Compatibilidad**: Mantiene estructura existente de base de datos
2. **Consistencia**: Mismo flujo para crear y editar presupuestos
3. **Integridad**: Cálculos correctos y persistencia de datos
4. **Flexibilidad**: Sistema adaptable a diferentes tipos de presupuestos

---

**✅ IMPLEMENTACIÓN COMPLETADA**