# 🐛 FIX: Solicitante Vacío en PDF de Requerimientos

**Fecha:** 3 Agosto 2026  
**Commit:** 79357b2  
**Estado:** ✅ CORREGIDO Y SUBIDO A GIT

---

## 🔍 PROBLEMA IDENTIFICADO

El campo **SOLICITANTE** aparecía vacío en el PDF de requerimientos:

```
SOLICITANTE: [VACÍO]
```

---

## 🎯 CAUSA RAÍZ

El PDF usaba una **query directa** con `CONCAT()` que no tenía `TRIM()`:

```sql
-- ❌ ANTES (Query directa sin TRIM)
CONCAT(COALESCE(p.nombres, ''), ' ', COALESCE(p.apellido_paterno, ''), ' ', COALESCE(p.apellido_materno, '')) as solicitante_nombre
```

Esto generaba una cadena con espacios cuando los campos estaban vacíos o NULL, resultando en: `"   "` en lugar de `""`.

El resto de la aplicación (requerimientos.py) usaba el **SP** `sp_ObtenerRequerimiento` que sí tiene `TRIM()`:

```sql
-- ✅ SP CON TRIM
TRIM(CONCAT(
    COALESCE(p.nombres, ''), 
    ' ', 
    COALESCE(p.apellido_paterno, ''), 
    ' ', 
    COALESCE(p.apellido_materno, '')
)) as usuario_completo
```

---

## ✅ SOLUCIÓN IMPLEMENTADA

### 1. **Usar el mismo SP que el resto de la aplicación**

```python
# ✅ AHORA (usando SP)
cursor.callproc('sp_ObtenerRequerimiento', [id_requerimiento])

for result in cursor.stored_results():
    requerimiento = result.fetchone()
    break
```

**Beneficios:**
- ✅ Consistencia con el resto de la aplicación
- ✅ TRIM automático del nombre del solicitante
- ✅ Menos código duplicado
- ✅ Más fácil de mantener

### 2. **Query adicional para Empresa y Logo**

Como el SP no incluye datos de empresa, agregué una query adicional:

```python
if requerimiento.get('id_presupuesto'):
    query_empresa = """
        SELECT 
            e.nombre as nombre_empresa,
            e.logo as empresa_logo
        FROM TblPresupuesto pres
        LEFT JOIN TblEmpresa e ON pres.id_empresa = e.id_empresa
        WHERE pres.id_presupuesto = %s
    """
    cursor.execute(query_empresa, (requerimiento['id_presupuesto'],))
    empresa_data = cursor.fetchone()
```

### 3. **Actualizar campo de solicitante**

```python
# ❌ ANTES
solicitante = (requerimiento.get('solicitante_nombre') or 'N/A').strip()

# ✅ AHORA
solicitante = (requerimiento.get('usuario_completo') or 'N/A').strip()
```

### 4. **Usar SP para detalles también**

```python
# ✅ AHORA
cursor.callproc('sp_ObtenerRequerimientoDetalles', [id_requerimiento])

detalles = []
for result in cursor.stored_results():
    detalles = result.fetchall()
    break
```

### 5. **Actualizar nombres de campos del SP**

El SP devuelve:
- `material_codigo` (en lugar de `codigo_material`)
- `unidad_abreviatura` (en lugar de `unidad`)

```python
# ✅ ACTUALIZADO
table_data = table_headers + [[
    str(idx + 1),
    item['tipo_item'] or 'ITEM',
    item.get('material_codigo') or '',  # ← Cambiado
    item['descripcion'] or '',
    str(item['cantidad'] or 0),
    item.get('unidad_abreviatura') or ''  # ← Cambiado
] for idx, item in enumerate(detalles)]
```

---

## 📊 COMPARACIÓN ANTES/DESPUÉS

### ANTES
```python
# Query directa
query_requerimiento = """
    SELECT ..., 
    CONCAT(...) as solicitante_nombre  # Sin TRIM
    FROM TblRequerimiento tr
    LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
    ...
"""
cursor.execute(query_requerimiento, (id_requerimiento,))
requerimiento = cursor.fetchone()

# Resultado: solicitante_nombre = "   " (espacios vacíos)
```

### DESPUÉS
```python
# Usando SP
cursor.callproc('sp_ObtenerRequerimiento', [id_requerimiento])
for result in cursor.stored_results():
    requerimiento = result.fetchone()
    break

# Resultado: usuario_completo = "Juan Pérez García" (trimmed)
```

---

## 🧪 VERIFICACIÓN

1. ✅ Sintaxis Python correcta (py_compile)
2. ✅ Committed y pushed a Git
3. ⏳ Pendiente: Deployment en servidor
4. ⏳ Pendiente: Prueba funcional

---

## 🚀 DEPLOYMENT

```bash
# En el servidor
cd ~/sys-Kallpa
git pull origin main
touch tmp/restart.txt
```

---

## 📝 NOTAS ADICIONALES

- Los SPs `sp_ObtenerRequerimiento` y `sp_ObtenerRequerimientoDetalles` ya existen en el servidor
- El campo `usuario_completo` siempre está trimmed gracias al SP
- El PDF ahora usa exactamente la misma lógica que la pantalla de requerimientos
- Agregado log de debug: `print(f"[PDF-REQ] ✓ Solicitante: {requerimiento.get('usuario_completo', 'N/A')}")`

---

## 🔗 ARCHIVOS RELACIONADOS

- ✅ `app/routes/requerimientos_pdf.py` (actualizado)
- ✅ `database_scripts/sp_ObtenerRequerimiento.sql` (ya existe en servidor)
- 📄 `database_scripts/DEBUG_SOLICITANTE_PDF.sql` (script de diagnóstico)

---

**✅ FIX APLICADO - LISTO PARA DEPLOYMENT**
