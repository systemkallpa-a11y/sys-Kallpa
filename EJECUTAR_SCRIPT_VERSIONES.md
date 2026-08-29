# ✅ SCRIPT SQL CORREGIDO - LISTO PARA EJECUTAR

## 📋 RESUMEN DE CORRECCIONES

El script `database_scripts/sistema_versiones_presupuesto.sql` ha sido **completamente corregido** para eliminar todas las referencias a `TblCliente` que NO existe en el sistema.

### ✅ Cambios implementados:

1. **Tabla `TblPresupuestoVersionHistorial`**:
   - ❌ ELIMINADO: `id_cliente`, `nombre_cliente` (tabla TblCliente no existe)
   - ✅ AGREGADO: `id_proyecto INT` (FK a TblProyecto) ✅
   - ✅ AGREGADO: `id_obra INT` (FK a TblObra) ✅
   - ✅ AGREGADO: `nombre_proyecto VARCHAR(255)` (snapshot del nombre)
   - ✅ AGREGADO: `nombre_obra VARCHAR(255)` (snapshot del nombre)
   - ✅ MANTENIDO: `creado_por INT` (FK a TblPersona.num_documento)

2. **SP `sp_CrearPresupuestoCompleto`**:
   - ✅ Crea Versión 1 automáticamente al crear presupuesto
   - ✅ Usa `p_id_obra` directamente (FK)
   - ✅ Obtiene `nombre_obra` y `proyecto` desde TblObra y TblProyecto

3. **SP `sp_GuardarSnapshotAntesDeEditar`**:
   - ✅ Guarda snapshot ANTES de abrir modal de edición
   - ✅ Usa `p.id_obra` desde TblPresupuesto
   - ✅ Obtiene `nombre_obra` y `proyecto` con LEFT JOIN

### 📊 Estructura de relaciones:

```
TblPresupuestoVersionHistorial
    ├─ id_presupuesto → TblPresupuesto (FK)
    ├─ creado_por → TblPersona.num_documento (FK) ✅ Usuario que creó/editó
    ├─ id_proyecto → TblProyecto (FK) ✅ Proyecto del presupuesto
    └─ id_obra → TblObra (FK) ✅ Obra del presupuesto

TblPresupuesto
    ├─ id_empresa → TblEmpresa (FK)
    ├─ id_obra → TblObra (FK) ✅
    └─ num_documento → TblPersona (FK)

TblObra
    └─ id_proyecto → TblProyecto (FK) ✅
```

## 🚀 CÓMO EJECUTAR EL SCRIPT

### ⚠️ IMPORTANTE ANTES DE EJECUTAR

1. **Haz backup de la base de datos** (por seguridad)
2. El script es **seguro** - usa `DROP PROCEDURE IF EXISTS` y `DROP TABLE IF EXISTS`
3. Puedes ejecutarlo **múltiples veces** sin problemas

### Opción 1: Desde CMD (Recomendado)

```cmd
cd d:\kallpa\sys-Kallpa\sys-Kallpa
mysql -u kallpasystem -p kallpasystem$kallgwkn_kallpa_bd < ../database_scripts/sistema_versiones_presupuesto.sql
```

Cuando pida password, ingresa:
```
kallpasystem$kallgwkn_kallpa_bd
```

### Opción 2: Desde MySQL Workbench

1. Abre MySQL Workbench
2. Conecta a: `kallpasystem$kallgwkn_kallpa_bd`
3. File → Open SQL Script
4. Selecciona: `d:\kallpa\sys-Kallpa\database_scripts\sistema_versiones_presupuesto.sql`
5. Click en ⚡ Execute (o Ctrl+Shift+Enter)
6. Verifica que no haya errores en el output

### Opción 3: Desde phpMyAdmin

1. Abre phpMyAdmin
2. Selecciona BD: `kallpasystem$kallgwkn_kallpa_bd`
3. Pestaña "SQL"
4. Abre el archivo y copia todo el contenido
5. Pega en el textarea
6. Click "Continuar"

## ✅ VERIFICAR QUE FUNCIONÓ

### 1. Verificar tablas creadas:

```sql
SHOW TABLES LIKE 'TblPresupuestoVersion%';
```

Deberías ver:
- `TblPresupuestoVersionHistorial`
- `TblPresupuestoVersionDetalleHistorial`

### 2. Verificar estructura de tabla:

```sql
DESCRIBE TblPresupuestoVersionHistorial;
```

Deberías ver estos campos:
- `id_version` (PK)
- `id_presupuesto` (FK)
- `creado_por` (FK a TblPersona.num_documento) ✅
- `id_proyecto` (FK a TblProyecto) ✅
- `id_obra` (FK a TblObra) ✅
- `nombre_proyecto` (VARCHAR)
- `nombre_obra` (VARCHAR)
- ❌ NO debe existir: `id_cliente`, `nombre_cliente`

### 3. Verificar SPs creados:

```sql
SHOW PROCEDURE STATUS WHERE Db = 'kallpasystem$kallgwkn_kallpa_bd' 
AND Name LIKE '%Presupuesto%Version%';
```

Deberías ver:
- `sp_CrearPresupuestoCompleto` ✅ (MODIFICADO - crea Versión 1)
- `sp_GuardarSnapshotAntesDeEditar` ✅
- `sp_ObtenerHistorialVersiones`
- `sp_ObtenerVersionPresupuesto`
- `sp_ObtenerVersionActual`
- `sp_CompararVersionesPresupuesto`

## 🧪 PROBAR EL SISTEMA

### 1. Reiniciar servidor Python:

```cmd
cd d:\kallpa\sys-Kallpa\sys-Kallpa
python main.py
```

### 2. Crear nuevo presupuesto:

1. Abre: `http://127.0.0.1:5000/presupuestos`
2. Click en "Crear Nuevo Presupuesto"
3. Llena los campos:
   - Empresa
   - Proyecto
   - Obra ✅ (importante)
   - Materiales/Servicios
4. Click en "Guardar"

### 3. Verificar en consola Python:

Deberías ver:
```
[CREAR_PRESUPUESTO] [OK] Presupuesto creado con ID: XX
```

**SIN errores de** `TblCliente doesn't exist` ✅

### 4. Verificar Versión 1 en BD:

```sql
SELECT 
    v.numero_version,
    v.id_proyecto,
    v.id_obra,
    v.nombre_proyecto,
    v.nombre_obra,
    v.creado_por,
    v.motivo_cambio
FROM TblPresupuestoVersionHistorial v
WHERE v.id_presupuesto = (SELECT MAX(id_presupuesto) FROM TblPresupuesto)
ORDER BY v.numero_version;
```

Deberías ver:
- `numero_version`: 1
- `id_proyecto`: [ID del proyecto] ✅
- `id_obra`: [ID de la obra] ✅
- `nombre_proyecto`: [Nombre del proyecto] ✅
- `nombre_obra`: [Nombre de la obra] ✅
- `creado_por`: [num_documento del usuario] ✅
- `motivo_cambio`: "Versión 1 - Creación inicial del presupuesto"

## ❌ SI HAY ERRORES

### Error: "Table 'TblCliente' doesn't exist"

**Causa**: El script no se ejecutó correctamente

**Solución**:
1. Verifica que ejecutaste el script COMPLETO
2. Revisa logs de MySQL para ver qué línea falló
3. Ejecuta el script nuevamente

### Error: "Duplicate column name 'id_obra'"

**Causa**: La tabla ya existe con estructura anterior

**Solución**:
```sql
DROP TABLE IF EXISTS TblPresupuestoVersionDetalleHistorial;
DROP TABLE IF EXISTS TblPresupuestoVersionHistorial;
```
Luego ejecuta el script nuevamente.

### Error: "Foreign key constraint fails"

**Causa**: Las tablas referenciadas no existen

**Solución**: Verifica que existan:
- `TblPresupuesto`
- `TblPersona`
- `TblObra`

## 📝 RESUMEN

✅ Script corregido y listo
✅ Sin referencias a TblCliente
✅ FK correctas: `creado_por` → TblPersona, `id_proyecto` → TblProyecto, `id_obra` → TblObra
✅ Sistema de versiones completo
✅ Creación automática de Versión 1

**Próximo paso**: Ejecutar el script y probar creando un presupuesto.
