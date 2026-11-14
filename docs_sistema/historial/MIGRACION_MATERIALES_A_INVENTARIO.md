# Historial: migración `TblMateriales` → `TblInventario`

> **Documento histórico (cerrado el 30/10/2026).** Se conserva para saber
> qué se hizo y por qué. Desde el 13/11/2026:
> - Los scripts `database_scripts/migracion_inventario/` se eliminaron (ya
>   aplicados y no re-ejecutables). El código vigente de los SP está en
>   `database_scripts/estado_actual/`.
> - El respaldo citado abajo está en
>   `sistema3/_respaldos_bd/migracion_inventario_respaldo_previo_06_20261030.sql`
>   (fuera del proyecto).
> - Los pendientes de la lista de abajo siguen abiertos; su estado actual
>   está en `CONTEXTO_SISTEMA.md`, sección 8.
> - El estado actual del inventario está en `modulos/INVENTARIO.md`.

Fecha: 2026-10-28  
Base de datos: `kallpasystem$kallgwkn_kallpa_bd`

**Estado general (2026-10-30): MIGRACIÓN COMPLETADA + CIERRE DE TABLAS.**
Fases 0–9 ejecutadas. La BD ya no tiene ninguna tabla antigua de materiales:
las 8 tablas (`TblMateriales_legacy`, `TblCategoriaMaterial_legacy`, los 5
respaldos `_backup_20261028` y `TblMigracionMaterialInventario`) fueron
eliminadas en la Fase 9, tras generar el respaldo de seguridad en archivo
`respaldo_previo_06_20261030.sql` (483 filas, estructura + datos, única vía
de restauración).
Tampoco quedan aliases temporales `id_material`/`codigo_material` en SPs,
backend ni frontend. Pendientes posteriores, no bloqueantes:

1. Corregir los 2 endpoints rotos por SPs inexistentes (preexistentes):
   `PUT /api/requerimientos/actualizar/<id>` (`sp_ActualizarRequerimiento`) y
   `GET /api/presupuestos/visualizar/<id>` (`sp_obtener_presupuesto_detalle_completo`).
2. Corregir `sp_RestaurarVersionPresupuesto` (usa columnas inexistentes; nadie
   lo llama) o eliminarlo.
3. Módulos con esquema faltante (preexistentes): Órdenes de Compra
   (`TblOrdenCompra`/`TblOrdenCompraDetalle` no existen) y Entregas a Personal
   (falta `vw_personal_entregas`).

## Decisiones cerradas

1. **`TblInventario` reemplaza a `TblMateriales`.** No se conservará el catálogo antiguo.
2. **Se permiten `SERVICIO` y `PARTIDA` en presupuestos y en el buscador.**
3. **Se mantienen las rutas API actuales**, especialmente `/api/materiales/...`.
   Solo cambia la implementación interna.
4. **El identificador definitivo es `id_inventario`.**
   `id_material` queda solo como puente temporal durante la migración y se elimina al final.
5. **Servicios y partidas comparten la sección "Servicios" del presupuesto**,
   diferenciados con una etiqueta visual y con `tipo_item`. No se crea una tercera
   sección por ahora; el esquema y los totales actuales no tienen `total_partidas`.
6. **Las partidas suman a `total_servicios`** en el historial de versiones.
7. **Los materiales físicos** (`MATERIAL`, `HERRAMIENTA`, `EQUIPO`, `TECNOLOGIA`,
   `ROPA`, `CONSUMIBLE`) se guardan con `tipo_item = 'MATERIAL'`.

## Mapeo de tipos

| `TblInventario.tipo_inventario` | `TblPresupuestoDetalle.tipo_item` | Sección UI |
|---|---|---|
| `MATERIAL` | `MATERIAL` | Materiales |
| `HERRAMIENTA` | `MATERIAL` | Materiales |
| `EQUIPO` | `MATERIAL` | Materiales |
| `TECNOLOGIA` | `MATERIAL` | Materiales |
| `ROPA` | `MATERIAL` | Materiales |
| `CONSUMIBLE` | `MATERIAL` | Materiales |
| `SERVICIO` | `SERVICIO` | Servicios |
| `PARTIDA` | `PARTIDA` | Servicios (etiqueta PARTIDA) |

## Contrato JSON

### Materiales

```json
{
  "id_inventario": 12,
  "nombre": "CEMENTO PORTLAND TIPO I",
  "cantidad": 10,
  "precio_unitario": 25.5
}
```

### Servicios y partidas

```json
{
  "id_inventario": 72,
  "tipo_item": "SERVICIO",
  "descripcion": "FLETE TERRESTRE",
  "cantidad": 1,
  "precio_unitario": 350
}
```

```json
{
  "id_inventario": 43,
  "tipo_item": "PARTIDA",
  "descripcion": "LIMPIEZA MANUAL EN TERRENO NORMAL",
  "cantidad": 1,
  "precio_unitario": 1200
}
```

Un servicio manual (sin catálogo) envía `id_inventario: null`.

## Compatibilidad temporal

Histórico (ya cerrado en la Fase 8). Durante la transición:

- Los SPs de lectura devolvían `id_inventario` y también
  `id_inventario AS id_material` con el mismo valor.
- Devolvían `codigo` y también `codigo AS codigo_material`.
- Los SPs de escritura leían `$.id_inventario` y, si no existía, usaban
  `$.id_material` como respaldo.
- El backend aceptaba ambos nombres y normalizaba a `id_inventario`.

**Cerrado (Fase 8):** los alias fueron eliminados de SPs, backend y frontend.
El backend conserva únicamente **tolerancia de ENTRADA** a `id_material`
(`presupuesto.py` y `ordenes_compra.py` normalizan la entrada por si el
navegador tiene JS cacheado), pero ya no emite ese campo en ninguna respuesta.
`id_inventario` es el único identificador y `codigo` el único código.

## Fases

### Fase 0 — Respaldo

Estado: ✅ Completada

Respaldar:

- `TblMateriales`
- `TblCategoriaMaterial`
- `TblPresupuestoDetalle`
- `TblRequerimientoDetalle`
- `TblPresupuestoVersionDetalleHistorial`
- Definiciones de los SPs afectados

### Fase 1 — Esquema

Estado: ✅ Ejecutada (2026-10-29) — 32/32 statements OK

Script: `database_scripts/migracion_inventario/01_preparar_esquema.sql`

- Crear tablas de respaldo.
- Ampliar `TblPresupuestoDetalle.tipo_item` a
  `ENUM('MATERIAL','SERVICIO','PARTIDA')`.
- Agregar `id_inventario` a `TblPresupuestoVersionDetalleHistorial`.
- Completar `id_inventario` faltantes usando `TblMigracionMaterialInventario`.
- Corregir `tipo_item` de las líneas existentes que apuntan a servicios o partidas.

Resultados de validación:

| Chequeo | Resultado |
|---|---|
| Respaldo `TblMateriales` | 73 filas |
| Respaldo `TblPresupuestoDetalle` | 145 filas |
| `TblPresupuestoDetalle` con `id_inventario` | 109/145 (36 líneas de servicio sin ID) |
| `tipo_item = PARTIDA` | 30 líneas |
| `TblRequerimientoDetalle` con `id_inventario` | 5/5 |
| Historial con `id_inventario` | 22/64 (solo MATERIAL) |
| Líneas MATERIAL apuntando a SERVICIO/PARTIDA | **0** |

Ajustes hechos durante la ejecución (ya incorporados al script):

- El respaldo de `TblPresupuestoDetalle` lista solo columnas almacenables:
  `cantidad_saldo` y `subtotal` son columnas generadas y no aceptan valores.
- Los `UPDATE` de corrección de `tipo_item` usan `COLLATE utf8mb4_unicode_ci`
  porque `tipo_item` es `utf8mb4_unicode_ci` y `tipo_inventario` es
  `utf8mb4_0900_ai_ci`.
- El `ADD COLUMN` del historial usa DDL condicional (`PREPARE`/`EXECUTE`),
  porque MySQL no admite `ADD COLUMN IF NOT EXISTS`.
- El script quedó idempotente: se puede re-ejecutar sin errores.

### Fase 2 — SPs de lectura

Estado: ✅ Ejecutada (2026-10-29) — 12/12 statements OK, prueba de humo OK

Script: `database_scripts/migracion_inventario/02_sp_lectura.sql`

- `sp_BuscarMateriales`
- `sp_BuscarMaterialesAutocompletado`
- `sp_BuscarMaterialPorNombre`
- `sp_ObtenerCategoriasMaterial`
- `sp_ObtenerPresupuestoPDF`
- `sp_ObtenerRequerimientoDetalles`

Verificado con `CALL`: devuelven `id_inventario` + alias `id_material`,
`codigo` + alias `codigo_material`, y los 3 result sets del PDF.

### Fase 3 — SPs de escritura

Estado: ✅ Ejecutada (2026-10-29) — 10/10 statements OK

Script: `database_scripts/migracion_inventario/03_sp_escritura.sql`

- `sp_CrearMaterialConCodigoAuto`
- `sp_CrearPresupuestoCompleto`
- `sp_ActualizarPresupuestoCompleto`
- `sp_CrearRequerimientoCompleto`
- `sp_GuardarSnapshotAntesDeEditar`

Auditoría posterior: **0 SPs** referencian `TblMateriales` o
`TblCategoriaMaterial`. Único residual con tablas viejas:
`sp_CrearNuevaVersionPresupuesto` (se elimina en la Fase 7).

### Fase 4 — Backend

Estado: ✅ Completada (2026-10-29)

- `app/routes/materiales.py` ✅
- `app/routes/presupuesto.py` ✅
- `app/routes/requerimientos.py` ✅
- `app/routes/presupuesto_pdf.py` ✅
- `app/routes/requerimientos_pdf.py` ✅
- `app/routes/ordenes_compra.py` ✅ (módulo inoperativo, se dejó preparado)
- `app/routes/pdf_helpers.py` ✅ (etiqueta PARTIDA en el PDF)

Detalles:

- Todas las rutas API se conservan igual, incluida `/api/materiales/...`.
- Se agregó `normalizar_items_presupuesto()` en `presupuesto.py`: acepta
  `id_inventario` (definitivo) o `id_material` (puente temporal) y limita
  `tipo_item` a `MATERIAL`, `SERVICIO` o `PARTIDA`.
- Los endpoints de lectura devuelven `id_inventario` y el alias `id_material`,
  más `codigo` y el alias `codigo_material`.

### Fase 5 — Frontend

Estado: ✅ Completada (2026-10-29)

- `app/static/js/presupuesto.js` ✅
- `app/templates/presupuesto.html` (script inline de edición) ✅
- `app/static/js/presupuesto-edicion-fix.js` ✅
- `app/templates/dashboard.html` ✅
- `app/templates/requerimiento.html` ✅
- `app/templates/ordenes_compra.html` ✅

Cambios:

- `id_material` → `id_inventario`.
- Se envía `tipo_item` en materiales, servicios y partidas.
- Los resultados de búsqueda con `tipo_inventario` `SERVICIO` o `PARTIDA`
  se agregan a la sección Servicios con su etiqueta.
- Se muestra la etiqueta `PARTIDA` en la tabla, en el buscador, en el
  requerimiento y en el PDF.

### Fase 5.5 — Validación de sintaxis

Estado: ✅ OK (2026-10-29)

- `py_compile` de los 5 módulos Python: OK.
- `node --check` de `presupuesto.js`, `presupuesto-edicion-fix.js`: OK.
- `node --check` de los scripts inline de `presupuesto.html`,
  `requerimiento.html`, `dashboard.html`, `ordenes_compra.html`,
  `inventario.html`: OK.

### Fase 6 — Pruebas

Estado: ✅ Completada (2026-10-29) — 3 suites, todo en verde

- Crear material.
- Buscar material, servicio y partida.
- Crear presupuesto con materiales, servicios y partidas.
- Editar presupuesto.
- Crear requerimiento.
- Descargar PDF de presupuesto y de requerimiento.
- Importar PDF y Excel.
- Ver historial y detalle de versiones.
- Buscar desde el dashboard.

Suites ejecutadas (autolimpian los registros de prueba):

| Suite | Resultado |
|---|---|
| `test_regresion_inventario.py` | 37/37 OK (EXIT=0) |
| `test_importaciones.py` | 14/14 OK (EXIT=0) |
| `test_versiones.py` (ronda extra) | 9/9 OK (EXIT=0) |

Cobertura: búsquedas (`/api/materiales/buscar`, combos), crear material
(`sp_CrearMaterialConCodigoAuto` → `TblInventario`), crear/editar presupuesto
con MATERIAL+SERVICIO+PARTIDA, historial de versiones (`sp_GuardarSnapshotAntesDeEditar`,
`sp_ObtenerHistorialVersiones`, `sp_ObtenerVersionPresupuesto`,
`sp_ObtenerVersionActual`, `sp_CompararVersionesPresupuesto`), requerimiento,
PDFs de presupuesto y requerimiento, dashboard, buscador global e importaciones
PDF/Excel (creación automática de materiales en `TblInventario`).

Verificado tras las pruebas: 0 huérfanos en detalle/versiones, `TblInventario`
de vuelta a 78 ítems.

Hallazgos durante la Fase 6 (corregidos o documentados):

1. **Bug real corregido**: `app/routes/requerimientos_pdf.py` lanzaba
   `UnboundLocalError: default_logo_path` cuando la empresa tenía logo en BLOB
   (el PDF de requerimiento devolvía 500). Inicializado a `None` al inicio.
2. **PDFs del sistema no reimportables**: el importador de PDF solo entiende el
   formato de terceros `01.01.01 DESCRIPCION unidad cantidad precio subtotal`;
   los PDFs generados por el propio sistema (`MAT-xxx`) no se reimportan.
   Comportamiento esperado, no regresión.
3. **`sp_ActualizarRequerimiento` no existe** en la BD ni en el repo, y
   `requerimientos.py` pasa `[None]` como parámetro OUT (mysql.connector lo
   rechaza): `PUT /api/requerimientos/actualizar/<id>` siempre devolvió 500.
   Preexistente, ajeno a la migración. Requiere crear el SP en una tarea aparte.
4. **`sp_obtener_presupuesto_detalle_completo` no existe** en la BD ni en el
   repo: `GET /api/presupuestos/visualizar/<id>` devuelve error controlado 500.
   Preexistente, ajeno a la migración.
5. `sp_RestaurarVersionPresupuesto` y `sp_CrearNuevaVersionPresupuesto` usan
   columnas/tablas inexistentes (`unidad`, `id_cliente`, `total_materiales`,
   `costos_directos`, `porcentaje_gg`, `supervision`, `TblMaterial`); ninguno los
   llama el backend. `sp_CrearNuevaVersionPresupuesto` se elimina en la Fase 7;
   `sp_RestaurarVersionPresupuesto` queda documentado como roto.
6. `sp_ObtenerVersionPresupuesto` devuelve `vdh.*` (ya incluye `id_inventario`)
   — no necesitó migración.

### Fase 7 — Corte final

Estado: ✅ Ejecutada (2026-10-29) — 24/24 statements OK, 3 suites de regresión en verde tras el corte

Script: `database_scripts/migracion_inventario/04_corte_legacy.sql`

Ejecutado tras confirmar auditorías en cero:

- Recreados `sp_CrearPresupuestoCompleto`, `sp_ActualizarPresupuestoCompleto` y
  `sp_GuardarSnapshotAntesDeEditar` **sin** las columnas `id_material` /
  `id_partida_original` (antes del `DROP COLUMN`; siempre insertaban NULL ahí).
- Quitada la FK `fk_presupuesto_material`.
- Eliminadas las columnas `id_material` de `TblPresupuestoDetalle` y
  `TblRequerimientoDetalle`, y `id_partida_original` de
  `TblPresupuestoVersionDetalleHistorial`.
- Eliminado `sp_CrearNuevaVersionPresupuesto` (roto, sin llamadas del backend).
- Renombradas `TblMateriales` → `TblMateriales_legacy` y
  `TblCategoriaMaterial` → `TblCategoriaMaterial_legacy` (DROP definitivo
  pendiente a 1-2 semanas; rollback escrito en el script).

Validación post-corte:

| Chequeo | Resultado |
|---|---|
| SPs con `TblMateriales`/`TblCategoriaMaterial` | 0 |
| Tablas legacy presentes | 2 |
| Tablas originales ausentes | 0 |
| Columnas `id_material`/`id_partida_original` | 0 |
| FKs hacia `TblMateriales` | 0 |
| `TblInventario` | 78 ítems |
| Suites regresión/importaciones/versiones | 3/3 EXIT=0 |

### Fase 8 — Limpieza de aliases temporales

Estado: ✅ Ejecutada (2026-10-30) — 16/16 statements OK, 3 suites de regresión en verde

Script: `database_scripts/migracion_inventario/05_limpieza_aliases.sql`

Elimina por completo los aliases temporales `id_material`/`codigo_material`,
siguiendo el orden seguro SPs → backend → frontend:

**BD (8 SPs recreados):**

- `sp_BuscarMateriales`, `sp_BuscarMaterialesAutocompletado`,
  `sp_BuscarMaterialPorNombre`, `sp_ObtenerRequerimientoDetalles`: quitadas las
  líneas `AS id_material` y `AS codigo_material` de los `SELECT`.
- `sp_ObtenerPresupuestoPDF`: quitados 2 alias `AS id_material` y 1
  `AS codigo_material`.
- `sp_CrearMaterialConCodigoAuto`: OUT param renombrado de
  `p_id_material_creado` a `p_id_inventario_creado` (los CALL usan parámetros
  posicionales: cambio compatible; los 3 call sites del backend actualizados).
- `sp_CrearPresupuestoCompleto` y `sp_ActualizarPresupuestoCompleto`: quitado el
  respaldo `$.id_material` del JSON de entrada (el backend normaliza siempre a
  `$.id_inventario` antes de llamar al SP).

**Backend (sin emisión de aliases, con tolerancia de entrada):**

- `materiales.py`: sin referencias legacy (docstring, variables `@p_*`, SELECT).
- `presupuesto.py`: normalizador sin re-emisión de `id_material`; SELECT y
  dicts sin aliases; importadores PDF/Excel sin alias. Se conserva la
  tolerancia de entrada en `normalizar_items_presupuesto` y en
  `data.get('id_inventario') or data.get('id_material')`.
- `ordenes_compra.py`: SELECT de detalles sin aliases; se conserva tolerancia
  de entrada al insertar detalles.

**Frontend (sin emisiones ni fallbacks):**

- `presupuesto.js`, `presupuesto-edicion-fix.js`: eliminados los fallbacks
  `?? m.id_material` y las emisiones `id_material:` (compat temporal).
- `presupuesto.html` (script inline): normalización y emisiones limpiadas.
- `dashboard.html`, `requerimiento.html`, `ordenes_compra.html`,
  `ordenes_compra.js`: eliminados los fallbacks `|| codigo_material` /
  `?? id_material` y las emisiones.
- **No tocado:** `entregas_personal.html` y `entregas_personal.py`, que usan
  `codigo_material` de `sp_kardex_personal` (módulo Entregas a Personal, fuera
  de alcance de esta migración).

Validación post-limpieza:

| Chequeo | Resultado |
|---|---|
| SPs con `id_material`/`codigo_material` | 1 (`sp_kardex_personal`, fuera de alcance) |
| Backend que emite aliases (SELECT/dict) | 0 |
| Frontend con emisiones/fallbacks | 0 |
| `TblInventario` | 78 ítems |
| Suites regresión/importaciones/versiones | 3/3 EXIT=0 (37/37, 14/14, 9/9) |

Nota: las suites de prueba se actualizaron invirtiendo las aserciones de alias
(ahora verifican que el alias **no** existe). Además se corrigió un `SELECT` de
`test_regresion_inventario.py` que leía la columna `id_material` de
`TblPresupuestoDetalle`, ya eliminada en la Fase 7.

**Fin de la migración.** El identificador definitivo es `id_inventario` y el
código es `codigo`.

### Fase 9 — Cierre definitivo (DROP de tablas antiguas)

Estado: ✅ Ejecutada (2026-10-30) — 12/12 statements OK, 3 suites de regresión en verde tras el DROP

Script: `database_scripts/migracion_inventario/06_cierre_final.sql`

Pre-vuelo (0 referencias): 0 FKs entrantes desde otras tablas, 0 SPs, 0 vistas
y 0 referencias en código Python/JS/HTML. La única FK era la interna
`TblMateriales_legacy → TblCategoriaMaterial_legacy`, resuelta dropeando
materiales antes que categorías (reforzado con `FOREIGN_KEY_CHECKS = 0/1`).

**Respaldo de seguridad previo:** `respaldo_previo_06_20261030.sql` (mismo
directorio) con estructura + datos de las 8 tablas — 483 filas totales.
Única vía de restauración, ya que el DDL de MySQL no permite rollback.

**8 tablas eliminadas:**

| Tabla | Filas |
|---|---|
| `TblMateriales_legacy` | 73 |
| `TblCategoriaMaterial_legacy` | 25 |
| `TblMateriales_backup_20261028` | 73 |
| `TblCategoriaMaterial_backup_20261028` | 25 |
| `TblPresupuestoDetalle_backup_20261028` | 145 |
| `TblRequerimientoDetalle_backup_20261028` | 5 |
| `TblPresupuestoVersionDetalleHistorial_backup_20261028` | 64 |
| `TblMigracionMaterialInventario` | 73 |

Validación post-cierre:

| Chequeo | Resultado |
|---|---|
| Tablas relacionadas con material/categoría/backup/legacy/migración | 0 |
| `TblInventario` | 78 ítems (intacta) |
| `TblCategoriaInventario` | 44 categorías |
| Suites regresión/importaciones/versiones | 3/3 EXIT=0 (37/37, 14/14, 9/9) |

## Consultas de auditoría

```sql
-- SPs que todavía mencionan TblMateriales (debe devolver 0)
SELECT ROUTINE_TYPE, ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_DEFINITION LIKE '%TblMateriales%';

-- FKs que apuntan a TblMateriales (debe devolver 0)
SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA = DATABASE()
  AND REFERENCED_TABLE_NAME = 'TblMateriales';

-- Tablas antigas de materiales / backups / mapa (debe devolver 0 tras la Fase 9)
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND (TABLE_NAME LIKE '%Materiales%'
       OR TABLE_NAME LIKE '%CategoriaMaterial%'
       OR TABLE_NAME LIKE '%backup%'
       OR TABLE_NAME LIKE '%legacy%'
       OR TABLE_NAME LIKE '%Migracion%');

-- Columnas id_material/codigo_material en cualquier tabla (debe devolver 0
-- tras la Fase 9; antes solo existian en respaldos y el mapa, ya eliminados)
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME IN ('id_material', 'codigo_material');

-- SPs con aliases temporales id_material/codigo_material
-- (debe devolver solo sp_kardex_personal, modulo Entregas a Personal fuera de alcance)
SELECT ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
  AND ROUTINE_TYPE = 'PROCEDURE'
  AND (ROUTINE_DEFINITION LIKE '%id_material%'
       OR ROUTINE_DEFINITION LIKE '%codigo_material%');

-- Código Python/JS que todavía menciona id_material
-- (revisión manual con grep: solo debe quedar la tolerancia de entrada
--  del backend y el modulo Entregas a Personal)
```

## Riesgos controlados

- **IDs distintos:** `TblMateriales` usa 1–73; `TblInventario` usa 6–78.
  `TblMigracionMaterialInventario` es el puente y ya está completa.
- **34 líneas de presupuesto** apuntan a ítems que en inventario son
  `SERVICIO` o `PARTIDA` pero están guardadas como `MATERIAL`. La Fase 1 las
  corrige; los montos no cambian.
- **36 líneas de servicio libre** no tienen `id_inventario`. Se quedan así.
- **Órdenes de compra:** las tablas no existen; el módulo sigue inoperativo.
  No forma parte del corte, pero el código se deja sin referencias a
  `TblMateriales`.
- **Entregas a personal:** sigue pendiente de ejecutar sus tablas y su vista.
