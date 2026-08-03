# ✅ RESUMEN FINAL: Todos los Fixes de Requerimientos

**Fecha:** 3 Agosto 2026  
**Estado:** ✅ LISTO PARA APLICAR

---

## 📋 PROBLEMAS CORREGIDOS

### 1. ❌ Solicitante Vacío
- **Causa:** JOIN incorrecto (directo a TblPersona)
- **Fix:** JOIN correcto: `TblRequerimiento → TblUsuario → TblPersona`

### 2. ❌ Error en columnas de TblRegistroAprobacion
- **Causa:** Nombres incorrectos de columnas
- **Fix:** Usar columnas correctas: `fecha_aprobacion`, `comentario`, `num_documento_aprobador`

### 3. ❌ Presupuesto NO se descuenta al crear requerimiento
- **Causa:** SP no actualizaba `TblPresupuestoDetalle`
- **Fix:** Agregar lógica de descuento automático

---

## ✅ STORED PROCEDURES ACTUALIZADOS

### 1. `sp_ObtenerRequerimiento`
**Usado en:** Detalle de requerimiento y PDF

**Cambio:**
```sql
-- ❌ ANTES
FROM TblRequerimiento tr
LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento

-- ✅ AHORA
FROM TblRequerimiento tr
LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
```

---

### 2. `sp_ObtenerRequerimientosConAprobadores`
**Usado en:** Lista de requerimientos

**Cambios:**
- ✅ JOIN correcto para solicitante
- ✅ Columna correcta: `ra.num_documento_aprobador` (no `ra.num_usuario`)
- ✅ Alias correctos: `fecha_aprobacion` AS `fecha_aprobacion_rechazo`
- ✅ Alias correctos: `comentario` AS `comentario_rechazo`

---

### 3. `sp_CrearRequerimientoCompleto`
**Usado en:** Crear nuevo requerimiento

**NUEVO - Descuento Automático de Presupuesto:**
```sql
-- ✅ Descontar cantidades de TblPresupuestoDetalle
UPDATE TblPresupuestoDetalle pd
SET 
    pd.cantidad_consumida = pd.cantidad_consumida + cantidad_requerida,
    -- cantidad_saldo se recalcula automáticamente (GENERATED)
    pd.fecha_actualizacion = NOW()
WHERE pd.id_presupuesto = p_id_presupuesto;

-- ✅ Actualizar totales globales en TblPresupuesto
UPDATE TblPresupuesto
SET 
    cantidad_consumida = cantidad_consumida + v_cantidad_total,
    fecha_actualizacion = NOW()
WHERE id_presupuesto = p_id_presupuesto;
```

---

## 🔄 FLUJO COMPLETO DE PRESUPUESTO

### Crear Requerimiento → Descuenta Presupuesto
```
1. Usuario crea requerimiento con 10 unidades del material X
2. TblPresupuestoDetalle.cantidad_consumida += 10
3. TblPresupuestoDetalle.cantidad_saldo se recalcula (GENERATED)
4. TblPresupuesto.cantidad_consumida aumenta
```

### Eliminar Requerimiento → Reversa Presupuesto
```
1. Usuario elimina requerimiento
2. sp_EliminarRequerimiento (ya existe)
3. TblPresupuestoDetalle.cantidad_consumida -= 10
4. TblPresupuestoDetalle.cantidad_saldo se recalcula (GENERATED)
5. TblPresupuesto.cantidad_consumida disminuye
```

---

## 📦 SCRIPT PARA EJECUTAR

**Archivo:** `database_scripts/EJECUTAR_TODOS_LOS_FIXES_REQUERIMIENTO.sql`

**Contiene:**
1. ✅ `sp_ObtenerRequerimiento` (fix solicitante)
2. ✅ `sp_ObtenerRequerimientosConAprobadores` (fix solicitante + columnas)
3. ✅ `sp_CrearRequerimientoCompleto` (fix descuento de presupuesto)

---

## 🚀 DEPLOYMENT

### Paso 1: Ejecutar Script en BD

```bash
# En el servidor
cd ~/sys-Kallpa
git pull origin main
mysql -u usuario -p kallpasystem\$kallgwkn_kallpa_bd < database_scripts/EJECUTAR_TODOS_LOS_FIXES_REQUERIMIENTO.sql
```

O copiar y pegar en MySQL Workbench.

### Paso 2: Verificar

#### A. Solicitante en Lista
- Ir a: Gestión de Requerimientos
- Verificar columna "Solicitante" → debe mostrar nombres

#### B. Solicitante en PDF
- Descargar PDF de un requerimiento
- Verificar campo "SOLICITANTE:" → debe mostrar nombre

#### C. Descuento de Presupuesto
1. Ver presupuesto antes: `cantidad_saldo` = X
2. Crear requerimiento con 5 unidades
3. Ver presupuesto después: `cantidad_saldo` = X - 5
4. Eliminar requerimiento
5. Ver presupuesto: `cantidad_saldo` = X (restaurado)

---

## 📊 EJEMPLO PRÁCTICO

### Escenario:
- **Presupuesto:** PRES-001
- **Material:** Cemento
- **cantidad:** 100 bolsas
- **cantidad_consumida:** 0
- **cantidad_saldo:** 100 (GENERATED)

### Acción 1: Crear Requerimiento de 30 bolsas
```
RESULTADO:
- cantidad_consumida: 0 → 30
- cantidad_saldo: 100 → 70 (automático)
```

### Acción 2: Crear Requerimiento de 20 bolsas
```
RESULTADO:
- cantidad_consumida: 30 → 50
- cantidad_saldo: 70 → 50 (automático)
```

### Acción 3: Eliminar primer requerimiento (30 bolsas)
```
RESULTADO:
- cantidad_consumida: 50 → 20
- cantidad_saldo: 50 → 80 (automático)
```

---

## 📝 NOTAS IMPORTANTES

1. **`cantidad_saldo` es columna GENERATED:**
   - NO se actualiza manualmente
   - Se calcula automáticamente: `cantidad - cantidad_consumida`

2. **Múltiples requerimientos por presupuesto:**
   - ✅ Cada requerimiento descuenta su cantidad
   - ✅ Las cantidades se acumulan
   - ✅ Un presupuesto puede tener varios requerimientos activos

3. **Validación de saldo:**
   - Considerar agregar validación: `cantidad_consumida <= cantidad`
   - Prevenir sobregiro del presupuesto

---

## ✅ CHECKLIST DE VERIFICACIÓN

- [ ] Script ejecutado en base de datos
- [ ] Sin errores en la ejecución
- [ ] `sp_ObtenerRequerimiento(57)` muestra solicitante
- [ ] Lista de requerimientos muestra solicitante
- [ ] PDF muestra solicitante
- [ ] Crear requerimiento descuenta presupuesto
- [ ] Eliminar requerimiento reversa presupuesto
- [ ] `cantidad_saldo` se recalcula automáticamente

---

**✅ TODOS LOS FIXES LISTOS PARA APLICAR**
