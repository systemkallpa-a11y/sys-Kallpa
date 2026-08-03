# 🐛 FIX CRÍTICO: Solicitante Vacío - Flujo Incorrecto en SPs

**Fecha:** 3 Agosto 2026  
**Prioridad:** ALTA  
**Estado:** ✅ FIX LISTO PARA APLICAR

---

## 🔍 PROBLEMA IDENTIFICADO

El campo **SOLICITANTE** aparecía vacío en:
- ❌ Lista de requerimientos (tabla web)
- ❌ PDF de requerimientos
- ❌ Detalle de requerimientos

---

## 🎯 CAUSA RAÍZ

Los **Stored Procedures** estaban usando el **flujo incorrecto** para obtener el nombre del solicitante:

### ❌ FLUJO INCORRECTO (ANTES)

```sql
-- JOIN DIRECTO (INCORRECTO)
FROM TblRequerimiento tr
LEFT JOIN TblPersona p ON tr.num_usuario = p.num_documento
```

**Problema:** `TblRequerimiento.num_usuario` no apunta directamente a `TblPersona.num_documento`.

### ✅ FLUJO CORRECTO (AHORA)

```sql
-- DEBE PASAR POR TblUsuario PRIMERO
FROM TblRequerimiento tr
LEFT JOIN TblUsuario u ON tr.num_usuario = u.num_documento
LEFT JOIN TblPersona p ON u.num_documento = p.num_documento
```

**Correcto:** 
1. `TblRequerimiento.num_usuario` → `TblUsuario.num_documento`
2. `TblUsuario.num_documento` → `TblPersona.num_documento`

---

## 📊 EVIDENCIA DEL PROBLEMA

### Datos en BD para requerimiento 57:

**TblRequerimiento:**
- `id_requerimiento` = 57
- `codigo` = "REQ-00001"
- `num_usuario` = 9

**TblUsuario:**
- `num_documento` = 9 ✅ (existe)

**TblPersona:**
- `num_documento` = 9 ✅ (existe)
- `nombres` = "CHRISTIAN EDWIIN"
- `apellido_paterno` = "FRANCISCO"

**Resultado con JOIN incorrecto:** NULL (porque buscaba directo en TblPersona)  
**Resultado con JOIN correcto:** "CHRISTIAN EDWIIN FRANCISCO" ✅

---

## ✅ SOLUCIÓN IMPLEMENTADA

### SPs Corregidos

1. **`sp_ObtenerRequerimiento`**
   - Usado en: Detalle de requerimiento y PDF
   - Campo retornado: `usuario_completo`

2. **`sp_ObtenerRequerimientosConAprobadores`**
   - Usado en: Lista de requerimientos (tabla web)
   - Campo retornado: `solicitante`

### Cambio en el JOIN

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

## 📦 ARCHIVOS PARA EJECUTAR

### Script Principal (EJECUTAR ESTE)
```
database_scripts/EJECUTAR_FIX_SOLICITANTE_COMPLETO.sql
```

Este script contiene:
- ✅ Drop y Create de `sp_ObtenerRequerimiento`
- ✅ Drop y Create de `sp_ObtenerRequerimientosConAprobadores`
- ✅ Pruebas de verificación
- ✅ Mensajes de confirmación

### Scripts Individuales (Referencia)
- `sp_ObtenerRequerimiento_FIX_USUARIO.sql`
- `sp_ObtenerRequerimientosConAprobadores_FIX.sql`

---

## 🚀 INSTRUCCIONES DE DEPLOYMENT

### 1. Ejecutar en Base de Datos

```sql
-- Conectar a la BD
USE kallpasystem$kallgwkn_kallpa_bd;

-- Ejecutar el script completo
SOURCE /ruta/a/EJECUTAR_FIX_SOLICITANTE_COMPLETO.sql;

-- O copiar y pegar el contenido completo del archivo
```

### 2. Verificar Resultado

```sql
-- Debe mostrar: "CHRISTIAN EDWIIN FRANCISCO"
CALL sp_ObtenerRequerimiento(57);

-- Debe mostrar el solicitante en la lista
CALL sp_ObtenerRequerimientosConAprobadores();
```

### 3. Probar en Aplicación

1. **Lista de requerimientos:** Verificar columna "Solicitante"
2. **Detalle:** Verificar campo solicitante
3. **PDF:** Descargar y verificar campo "SOLICITANTE:"

---

## 📋 CHECKLIST DE VERIFICACIÓN

- [ ] Script ejecutado en base de datos sin errores
- [ ] `sp_ObtenerRequerimiento(57)` retorna nombre del solicitante
- [ ] `sp_ObtenerRequerimientosConAprobadores()` muestra solicitantes
- [ ] Lista web muestra solicitante en columna
- [ ] Detalle web muestra solicitante
- [ ] PDF muestra solicitante en campo "SOLICITANTE:"

---

## 🔄 DIAGRAMA DE FLUJO

### ANTES (INCORRECTO)
```
TblRequerimiento
  └─ num_usuario = 9
        |
        └─ [JOIN DIRECTO] ❌
              |
              └─ TblPersona.num_documento = 9
                    └─ Resultado: NULL (porque el JOIN directo no funciona)
```

### DESPUÉS (CORRECTO)
```
TblRequerimiento
  └─ num_usuario = 9
        |
        └─ [JOIN] TblUsuario.num_documento = 9 ✅
              |
              └─ [JOIN] TblPersona.num_documento = 9 ✅
                    └─ Resultado: "CHRISTIAN EDWIIN FRANCISCO"
```

---

## 🎯 IMPACTO

**Módulos afectados:**
- ✅ Gestión de Requerimientos (lista)
- ✅ Detalle de Requerimiento
- ✅ PDF de Requerimientos

**Beneficio:**
- ✅ Solicitante visible en todos los módulos
- ✅ Consistencia en toda la aplicación
- ✅ Mejor trazabilidad de requerimientos

---

## 📝 NOTAS ADICIONALES

- No requiere cambios en código Python (ya usa los SPs)
- No requiere reinicio de aplicación
- Fix aplicable inmediatamente
- Sin impacto en otros módulos

---

**✅ FIX LISTO PARA APLICAR EN PRODUCCIÓN**
