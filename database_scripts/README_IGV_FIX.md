# Corrección del Cálculo del IGV en Presupuestos

## Fecha: 05 Agosto 2026 - ACTUALIZACIÓN V2

## Problema Identificado

El IGV (18%) se estaba calculando incorrectamente en los **stored procedures de la base de datos**:
- **Incorrecto**: IGV se calculaba solo sobre Costos Directos (materiales + servicios)
- **Correcto**: IGV debe calcularse sobre SUB TOTAL = Costos Directos + Gastos Generales + Utilidad

## Fórmula Correcta

```
1. Costos Directos = Σ(Materiales) + Σ(Servicios)
2. Gastos Generales (10%) = valor fijo
3. Utilidad (15%) = valor fijo
4. SUB TOTAL = Costos Directos + GG + Utilidad
5. IGV (18%) = SUB TOTAL × 0.18  ← CORRECCIÓN AQUÍ
6. Supervisión de Obra (5%) = valor fijo
7. MONTO TOTAL = SUB TOTAL + IGV + Supervisión
```

## Archivos Modificados

### Base de Datos (⚠️ IMPORTANTE)
- **Script V2**: `database_scripts/fix_igv_calculation_v2.sql` (**USAR ESTE**)
  - Actualiza `sp_CrearPresupuestoCompleto` con cálculo correcto de IGV
  - Actualiza `sp_ActualizarPresupuestoCompleto` con cálculo correcto de IGV
  - Compatible con los parámetros que envía el backend Python
  - Incluye manejo de transacciones y rollback en caso de error

### Frontend (Ya corregido previamente)
- **JavaScript**: `app/static/js/presupuesto.js`
  - Función `actualizarTotales()` - Calcula IGV correctamente en el frontend
- **HTML**: `app/templates/presupuesto.html`
  - Añadido campo visual "SUB TOTAL" para claridad

### PDF Generation
- **Python**: `app/routes/pdf_helpers.py`
  - Word-wrapping para textos largos
  - Uso de `Paragraph` para renderizar HTML correctamente

## Instrucciones de Ejecución

### 1. Ejecutar Script SQL (⚠️ CRÍTICO)

Conectarse a la base de datos MySQL y ejecutar:

```bash
mysql -u kallpasystem -p Kallpa < database_scripts/fix_igv_calculation_v2.sql
```

O desde MySQL Workbench / cliente MySQL:
```sql
SOURCE d:/kallpa/sys-Kallpa/database_scripts/fix_igv_calculation_v2.sql;
```

### 2. Verificar Stored Procedures

Después de ejecutar el script, verificar que ambos SPs estén actualizados:

```sql
-- Ver definición de sp_CrearPresupuestoCompleto
SHOW CREATE PROCEDURE sp_CrearPresupuestoCompleto;

-- Ver definición de sp_ActualizarPresupuestoCompleto
SHOW CREATE PROCEDURE sp_ActualizarPresupuestoCompleto;

-- Verificar que contengan las líneas:
-- SET v_sub_total = v_costos_directos + p_gastos_generales + p_utilidad;
-- SET v_igv = ROUND(v_sub_total * 0.18, 2);
```

### 3. Reiniciar Aplicación

```bash
# En Windows (PowerShell)
cd d:\kallpa\sys-Kallpa\sys-Kallpa
python main.py

# La aplicación debe iniciar sin errores
```

### 4. Verificar Cálculo

Crear o actualizar un presupuesto y verificar que el campo `igv` en la tabla `TblPresupuesto` contenga:
```sql
SELECT 
    id_presupuesto,
    monto AS monto_total,
    gastos_generales,
    utilidad,
    igv,
    supervision_obra,
    -- Verificar cálculo
    ROUND((monto - supervision_obra - igv) * 0.18, 2) AS igv_esperado
FROM TblPresupuesto
WHERE id_presupuesto = [TU_ID_PRESUPUESTO];

-- igv debe ser igual a igv_esperado
```

## Stored Procedures Actualizados (V2)

### sp_CrearPresupuestoCompleto
- **Parámetros IN**: 9 parámetros
  1. `p_id_empresa` (INT)
  2. `p_id_obra` (INT)
  3. `p_num_documento` (VARCHAR)
  4. `p_comentarios` (LONGTEXT)
  5. `p_gastos_generales` (DECIMAL)
  6. `p_utilidad` (DECIMAL)
  7. `p_supervision_obra` (DECIMAL)
  8. `p_materiales_json` (JSON)
  9. `p_servicios_json` (JSON)
- **Parámetro OUT**: `p_id_presupuesto_created` (INT)

**Lógica de Cálculo:**
```sql
v_costos_directos = SUM(materiales) + SUM(servicios)
v_sub_total = v_costos_directos + p_gastos_generales + p_utilidad
v_igv = ROUND(v_sub_total * 0.18, 2)
v_monto_total = v_sub_total + v_igv + p_supervision_obra
```

### sp_ActualizarPresupuestoCompleto
- **Parámetros IN**: 10 parámetros
  1. `p_id_presupuesto` (INT)
  2. `p_id_empresa` (INT)
  3. `p_id_obra` (INT)
  4. `p_num_documento` (INT)
  5. `p_comentarios` (LONGTEXT)
  6. `p_gastos_generales` (DECIMAL)
  7. `p_utilidad` (DECIMAL)
  8. `p_supervision_obra` (DECIMAL)
  9. `p_materiales_json` (JSON)
  10. `p_servicios_json` (JSON)

**Lógica de Cálculo:** (idéntica a sp_CrearPresupuestoCompleto)

## Ejemplo de Cálculo Correcto

```
Materiales:          S/. 6,000.00
Servicios:           S/. 2,486.00
─────────────────────────────────────
Costos Directos:     S/. 8,486.00

Gastos Generales:    S/. 1,463.60 (10%)
Utilidad:            S/. 2,195.40 (15%)
─────────────────────────────────────
SUB TOTAL:           S/. 14,631.08

IGV (18%):           S/. 2,633.59  ← Calculado sobre SUB TOTAL ✓

Supervisión:         S/. 731.55 (5%)
─────────────────────────────────────
MONTO TOTAL:         S/. 17,996.22
```

## Verificación Post-Implementación

### 1. Probar Crear Presupuesto
1. Ir a **Gestión de Presupuestos**
2. Click en **Crear Presupuesto**
3. Agregar materiales y servicios
4. Click en **Calcular % Automático**
5. Verificar que:
   - SUB TOTAL = Costos Directos + GG + Utilidad
   - IGV = SUB TOTAL × 0.18
   - TOTAL = SUB TOTAL + IGV + Supervisión
6. **Guardar Presupuesto**
7. Verificar en BD que el campo `igv` sea correcto

### 2. Probar Editar Presupuesto
1. Abrir un presupuesto existente
2. Modificar materiales/servicios
3. Click en **Calcular % Automático**
4. Verificar cálculos
5. **Guardar Presupuesto**
6. Verificar en BD que el campo `igv` se actualizó correctamente

### 3. Verificar PDF
1. Generar PDF de un presupuesto
2. Verificar que el desglose financiero muestre:
   - COSTOS DIRECTOS
   - GASTOS GENERALES (10%)
   - UTILIDAD (15%)
   - **SUB TOTAL**
   - **IGV (18%)**
   - SUPERVISIÓN DE OBRA (5%)
   - **PRESUPUESTO DE EJECUCIÓN**

## Diferencias entre V1 y V2

| Aspecto | V1 (fix_igv_calculation.sql) | V2 (fix_igv_calculation_v2.sql) |
|---------|------------------------------|--------------------------------|
| **sp_CrearPresupuestoCompleto** | 8 parámetros (sin num_documento) | ✅ 9 parámetros (con num_documento) |
| **sp_ActualizarPresupuestoCompleto** | 9 parámetros | ✅ 10 parámetros |
| **Compatibilidad con Python** | ❌ No coincide | ✅ Coincide perfectamente |
| **Cálculo IGV** | ✅ Correcto | ✅ Correcto |
| **Manejo de errores** | Básico | ✅ Con rollback y transacciones |

## Troubleshooting

### Problema: IGV no se guarda correctamente en BD
**Solución**: Ejecutar `fix_igv_calculation_v2.sql`

### Problema: Error "Wrong number of arguments"
**Causa**: Stored procedure desactualizado
**Solución**: Ejecutar `fix_igv_calculation_v2.sql`

### Problema: Frontend calcula bien, BD guarda mal
**Causa**: Stored procedures no actualizados
**Solución**: Ejecutar `fix_igv_calculation_v2.sql`

### Problema: PDF muestra etiquetas HTML literales
**Causa**: Cache de Python
**Solución**: 
```powershell
Remove-Item -Path "app\routes\__pycache__\*.pyc" -Force
```

## Notas Importantes

1. ✅ Frontend calcula IGV correctamente desde el principio
2. ✅ Backend (stored procedures) ahora calcula IGV correctamente
3. ✅ PDF genera desglose correcto
4. ⚠️ **CRÍTICO**: Ejecutar `fix_igv_calculation_v2.sql` para que los cambios se guarden en BD
5. 📌 El IGV se calcula automáticamente y no puede editarse manualmente
6. 📌 Supervisión de Obra NO se incluye en la base para calcular IGV

## Soporte

Si hay problemas, verificar en este orden:
1. ✅ Script SQL V2 ejecutado correctamente
2. ✅ Stored procedures actualizados (ver verificación arriba)
3. ✅ Cache de Python limpiado
4. ✅ Navegador recargado (Ctrl+F5)
5. ✅ Servidor reiniciado

Revisar logs:
- **Backend**: `[CREAR_PRESUPUESTO]` / `[ACTUALIZAR_PRESUPUESTO]`
- **Frontend**: Console → `[CALCULOS] Totales finales`
- **Base de Datos**: Verificar campo `igv` en tabla `TblPresupuesto`
