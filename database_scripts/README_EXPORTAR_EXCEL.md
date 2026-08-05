# EXPORTACIÓN DE MARCACIONES A EXCEL

**FECHA**: 05 Agosto 2026  
**ESTADO**: ⚠️ REQUIERE ACTUALIZACIÓN EN SERVIDOR

---

## 📋 RESUMEN

Se implementó la funcionalidad de exportar marcaciones detalladas a Excel con filtros por mes/año.

---

## ⚠️ PROBLEMA ACTUAL

El SP en producción está usando la versión incorrecta que intenta leer columnas de `TblUsuario` en lugar de `TblPersona`.

### Error actual:
```
[EXPORTAR_EXCEL] ❌ Error SQL: 1054 (42S22): Unknown column 'u.nombres' in 'field list'
```

### Causa:
El SP en el servidor NO tiene el `INNER JOIN` con `TblPersona` y está intentando acceder a columnas que no existen en `TblUsuario`.

---

## ✅ SOLUCIÓN

Ejecutar nuevamente el archivo **corregido**: `sp_ExportarMarcacionDetallada.sql`

### Cambios en la versión corregida:

1. **Agregado INNER JOIN con TblPersona**:
```sql
FROM TblUsuario u

-- JOIN con TblPersona para obtener nombres
INNER JOIN TblPersona p ON u.num_documento = p.num_documento
```

2. **Usa campos de TblPersona**:
```sql
CONCAT(
    COALESCE(p.nombres, ''), ' ',
    COALESCE(p.apellido_paterno, ''), ' ',
    COALESCE(p.apellido_materno, '')
) AS 'Nombres Completos',
```

3. **GROUP BY y ORDER BY actualizados**:
```sql
GROUP BY 
    u.num_documento,
    p.nombres,
    p.apellido_paterno,
    p.apellido_materno,
    fechas.fecha_generada

ORDER BY 
    p.apellido_paterno,
    p.apellido_materno,
    p.nombres,
    fechas.fecha_generada
```

---

## 🚀 CÓMO EJECUTAR

### Opción 1: Desde línea de comandos MySQL

```bash
mysql -u usuario -p nombre_base_datos < sp_ExportarMarcacionDetallada.sql
```

### Opción 2: Desde MySQL Workbench / phpMyAdmin

1. Abrir el archivo `sp_ExportarMarcacionDetallada.sql`
2. Copiar todo el contenido
3. Ejecutar en la base de datos

### Opción 3: PowerShell (Windows)

```powershell
.\ejecutar_sp_exportar.ps1
```

---

## 📊 ESTRUCTURA DEL EXCEL EXPORTADO

El archivo Excel generado contiene las siguientes columnas:

| Columna            | Descripción                                    |
|--------------------|------------------------------------------------|
| Número Documento   | DNI del usuario                                |
| Nombres Completos  | Nombre completo del usuario (de TblPersona)    |
| Fecha              | Fecha de la marcación                          |
| Entrada 1          | Hora de entrada turno mañana (antes 13:00)     |
| Salida 1           | Hora de salida turno mañana (antes 14:00)      |
| Entrada 2          | Hora de entrada turno tarde (después 13:00)    |
| Salida 2           | Hora de salida turno tarde (después 14:00)     |
| Estado             | ASISTIO, TARDE, ASISTIO +5, o SIN MARCA        |

### Colores de estado:
- 🟢 **ASISTIO**: Verde claro
- 🟡 **TARDE**: Amarillo
- 🔴 **ASISTIO +5**: Rojo claro
- ⚪ **SIN MARCA**: Gris

---

## 🔗 ARCHIVOS RELACIONADOS

### Backend:
- **`app/routes/marcacion.py`**: Ruta `/api/marcacion/exportar-excel`
  - Llama al SP
  - Genera archivo Excel con openpyxl
  - Aplica estilos y formatos

### Frontend:
- **`app/templates/reporte_asistencia.html`**: 
  - Botón "Exportar a Excel"
  - Función JavaScript `exportarExcel()`
  - Descarga archivo usando fetch + blob

### Base de datos:
- **`database_scripts/sp_ExportarMarcacionDetallada.sql`**: SP corregido

---

## 🧪 CÓMO PROBAR

1. **Ejecutar el SP corregido** en el servidor
2. Ir a: `http://127.0.0.1:5000/marcacion`
3. Seleccionar **mes y año**
4. Hacer clic en **"Exportar a Excel"**
5. Verificar que se descargue el archivo `.xlsx`
6. Abrir el Excel y verificar:
   - ✅ Columnas correctas
   - ✅ Nombres completos desde TblPersona
   - ✅ Turnos organizados (Entrada 1, Salida 1, Entrada 2, Salida 2)
   - ✅ Estados con colores
   - ✅ Incluye días SIN MARCA

---

## 📝 EJEMPLO DE SALIDA

```
╔════════════════════╦═══════════════════════╦════════════╦═══════════╦══════════╦═══════════╦══════════╦═══════════════╗
║ Número Documento   ║ Nombres Completos     ║ Fecha      ║ Entrada 1 ║ Salida 1 ║ Entrada 2 ║ Salida 2 ║ Estado        ║
╠════════════════════╬═══════════════════════╬════════════╬═══════════╬══════════╬═══════════╬══════════╬═══════════════╣
║ 12345678           ║ Juan Pérez López      ║ 2026-08-01 ║ 08:00:00  ║ 12:30:00 ║ 14:00:00  ║ 18:00:00 ║ ASISTIO       ║
║ 12345678           ║ Juan Pérez López      ║ 2026-08-02 ║ 08:15:00  ║ 12:25:00 ║           ║          ║ TARDE         ║
║ 12345678           ║ Juan Pérez López      ║ 2026-08-03 ║           ║          ║           ║          ║ SIN MARCA     ║
║ 87654321           ║ María García Torres   ║ 2026-08-01 ║ 08:05:00  ║ 12:00:00 ║ 13:30:00  ║ 17:30:00 ║ ASISTIO       ║
╚════════════════════╩═══════════════════════╩════════════╩═══════════╩══════════╩═══════════╩══════════╩═══════════════╝
```

---

## 🔄 PRÓXIMOS PASOS

1. ⚠️ **URGENTE**: Ejecutar `sp_ExportarMarcacionDetallada.sql` en el servidor
2. ✅ Probar la exportación en desarrollo
3. ✅ Validar que los nombres completos aparezcan correctamente
4. ✅ Verificar turnos y estados
5. 📤 Subir cambios al git (cuando funcione correctamente)

---

## 📞 SOPORTE

Si hay problemas:
1. Verificar que `TblPersona` tenga los campos: `nombres`, `apellido_paterno`, `apellido_materno`
2. Verificar que `TblPersona.num_documento` sea la clave foránea con `TblUsuario.num_documento`
3. Revisar logs de Python para errores específicos

**Versión**: 1.0 (Corregida)  
**Última actualización**: 05 Agosto 2026
