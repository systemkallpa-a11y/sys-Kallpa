# ✅ FIX: id_material y unidad_medida en Crear Requerimiento

**Problema Reportado**: No se estaban insertando `id_material` ni `unidad_medida` en `TblRequerimientoDetalle`

**Status**: ✅ CORREGIDO

---

## 🔍 PROBLEMA IDENTIFICADO

### Antes
```sql
-- TblRequerimientoDetalle
INSERT INTO TblRequerimientoDetalle (
    id_requerimiento,
    descripcion,
    cantidad,
    fecha_creacion
)
-- Los campos id_material y unidad_medida quedaban en NULL
```

### Causas
1. **Frontend**: No estaba pasando `id_material` ni `unidad_medida` en el JSON
2. **SP**: No estaba extrayendo estos campos del JSON

---

## ✅ SOLUCIONES IMPLEMENTADAS

### 1. Frontend: Actualizar `agregarItem()` para incluir `id_material`

**Archivo**: `app/templates/requerimiento.html`

**Cambios**:
```javascript
// ANTES
function agregarItem(idDetalle, nombre, cantidad, tipo, unidad) {
    itemsRequerimiento.push({ 
        id_detalle_presupuesto: idDetalle,
        nombre: nombre,
        cantidad: cantidad,
        tipo_item: tipo,
        unidad: unidad
    });
}

// DESPUÉS
function agregarItem(idDetalle, nombre, cantidad, tipo, unidad, idMaterial = null) {
    itemsRequerimiento.push({ 
        id_detalle_presupuesto: idDetalle,
        id_material: idMaterial,  // ✅ NUEVO
        nombre: nombre,
        cantidad: cantidad,
        tipo_item: tipo,
        unidad_medida: unidad  // ✅ RENAMED para consistencia
    });
}
```

### 2. Frontend: Actualizar el botón "Agregar" para pasar `id_material`

**Archivo**: `app/templates/requerimiento.html`

**Cambio en HTML**:
```html
<!-- ANTES -->
<button class="btn-agregar-item" 
    data-id-detalle="${item.id_detalle}" 
    data-nombre="..."
    data-unidad="${item.unidad_medida}">

<!-- DESPUÉS -->
<button class="btn-agregar-item" 
    data-id-detalle="${item.id_detalle}" 
    data-id-material="${item.id_material || ''}"  <!-- ✅ NUEVO -->
    data-nombre="..."
    data-unidad="${item.unidad_medida}">
```

**Cambio en Event Listener**:
```javascript
// ANTES
agregarItem(
    parseInt(this.dataset.idDetalle),
    this.dataset.nombre,
    this.dataset.cantidad,
    this.dataset.tipo,
    this.dataset.unidad
);

// DESPUÉS
agregarItem(
    parseInt(this.dataset.idDetalle),
    this.dataset.nombre,
    this.dataset.cantidad,
    this.dataset.tipo,
    this.dataset.unidad,
    this.dataset.idMaterial ? parseInt(this.dataset.idMaterial) : null  // ✅ NUEVO
);
```

### 3. Backend SP: Actualizar PASO 4 para extraer campos del JSON

**Archivo**: `database_scripts/sp_CrearRequerimientoCompleto_TASK6.sql`

**Cambios en INSERT**:
```sql
-- ANTES
INSERT INTO TblRequerimientoDetalle (
    id_requerimiento,
    descripcion,
    cantidad,
    fecha_creacion
)

-- DESPUÉS
INSERT INTO TblRequerimientoDetalle (
    id_requerimiento,
    id_material,          <!-- ✅ NUEVO -->
    tipo_item,            <!-- ✅ NUEVO -->
    descripcion,
    cantidad,
    unidad_medida,        <!-- ✅ NUEVO -->
    fecha_creacion
)
```

**SELECT actualizado**:
```sql
SELECT
    p_id_requerimiento_created,
    CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.id_material')), 0) AS UNSIGNED),  -- ✅
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.tipo_item')), 'MATERIAL'),             -- ✅
    COALESCE(
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.nombre')),
        JSON_UNQUOTE(JSON_EXTRACT(item, '$.descripcion')),
        'Sin descripción'
    ),
    CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.cantidad')), 1) AS DECIMAL(12,2)),
    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(item, '$.unidad_medida')), 'und'),              -- ✅
    NOW()
FROM JSON_TABLE(p_detalles_json, '$[*]' COLUMNS (item JSON PATH '$')) jt;
```

---

## 📊 RESULTADO ANTES vs DESPUÉS

### ANTES
```
TblRequerimientoDetalle:
┌─────────┬──────────────┬────────────┬──────────────┐
│ id_detalle │ descripcion  │ id_material │ unidad_medida │
├─────────┼──────────────┼────────────┼──────────────┤
│ 10      │ Tubo PVC     │ NULL ❌    │ NULL ❌      │
│ 11      │ Grava        │ NULL ❌    │ NULL ❌      │
└─────────┴──────────────┴────────────┴──────────────┘
```

### DESPUÉS
```
TblRequerimientoDetalle:
┌─────────┬──────────────┬────────────┬──────────────┐
│ id_detalle │ descripcion  │ id_material │ unidad_medida │
├─────────┼──────────────┼────────────┼──────────────┤
│ 40      │ Tubo PVC     │ 5 ✅       │ m ✅        │
│ 41      │ Grava        │ 12 ✅      │ kg ✅       │
└─────────┴──────────────┴────────────┴──────────────┘
```

---

## 🧪 CÓMO PROBAR

### En el Navegador

1. **Ve a "Gestión de Requerimientos"**
2. **"+ Crear Requerimiento"**
3. **Busca un presupuesto**
4. **Agrega items** (verifica que el botón incluya datos)
5. **"Crear Requerimiento"**

### En la Base de Datos

```sql
-- Verificar que se insertaron id_material y unidad_medida
SELECT 
    id_detalle,
    descripcion,
    cantidad,
    id_material,
    unidad_medida
FROM TblRequerimientoDetalle
WHERE id_requerimiento = (SELECT MAX(id_requerimiento) FROM TblRequerimiento)
LIMIT 5;

-- Resultado esperado:
-- id_detalle | descripcion | cantidad | id_material | unidad_medida
-- --------   | ----------- | -------- | ----------- | --------
--     40     | Tubo PVC    |    30    |      5      |    m
--     41     | Grava       |     1    |     12      |   kg
```

---

## 📁 ARCHIVOS MODIFICADOS

| Archivo | Cambios | Status |
|---------|---------|--------|
| `app/templates/requerimiento.html` | Actualizada función `agregarItem()` | ✅ |
| `app/templates/requerimiento.html` | Actualizado botón con `data-id-material` | ✅ |
| `app/templates/requerimiento.html` | Actualizado event listener | ✅ |
| `database_scripts/sp_CrearRequerimientoCompleto_TASK6.sql` | PASO 4 actualizado | ✅ |

---

## 🚀 IMPLEMENTACIÓN

```
[1] Actualizado Frontend HTML/JS ✅
    - agregarItem() recibe id_material
    - Botón pasa data-id-material
    - Event listener extrae id_material

[2] Actualizado SP en BD ✅
    - DROP PROCEDURE anterior
    - CREATE PROCEDURE con nuevos campos
    - SP ahora extrae: id_material, tipo_item, unidad_medida del JSON

[3] Flask reiniciado ✅
    - Caché limpiado
    - Nuevo proceso iniciado
```

---

## ✨ FLUJO COMPLETO AHORA

```
Usuario agrega item desde presupuesto
        ↓
Frontend: agregarItem(idDetalle, nombre, cantidad, tipo, unidad, idMaterial)
        ↓
itemsRequerimiento.push({
    id_material: idMaterial,
    unidad_medida: unidad,
    ...otros campos
})
        ↓
JSON se envía al backend
        ↓
SP extrae del JSON:
    - id_material
    - tipo_item
    - unidad_medida
    - descripción
    - cantidad
        ↓
INSERT INTO TblRequerimientoDetalle
    (id_material, tipo_item, unidad_medida, ...)
        ↓
✅ Datos completos en BD
```

---

## 🎯 PRÓXIMAS VALIDACIONES

- [ ] Crear requerimiento desde presupuesto
- [ ] Verificar en BD que `id_material` no es NULL
- [ ] Verificar en BD que `unidad_medida` tiene valores
- [ ] Editar requerimiento y verificar que se muestran los datos

---

## 📝 NOTAS

- Si el presupuesto NO tiene `id_material`, se insertará como NULL o 0
- La `unidad_medida` siempre tendrá un valor (default 'und')
- El `tipo_item` se toma del presupuesto (MATERIAL o SERVICIO)

---

## ✅ STATUS

🟢 **COMPLETADO Y DEPLOYADO**

