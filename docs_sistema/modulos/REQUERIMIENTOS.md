# Requerimientos (obra y administrativo)

**Actualizado:** 13/11/2026

Hay dos tipos de requerimiento en la misma tabla `TblRequerimiento`:

| | Obra | Administrativo |
|---|---|---|
| `id_tipo_requerimiento` | 2 | 1 |
| Tipo de documento de aprobación | 2 (Requerimiento) | 7 (Requerimiento Administrativo) |
| Origen de los ítems | Un presupuesto **APROBADO** | Stock de almacén (`TblInventario`) |
| Al crearse | Consume saldo del presupuesto | **Descuenta stock** y registra SALIDA en el kardex |
| Dónde se crea | Dashboard o O.T › Requerimiento O.T | Dashboard |
| Dónde se gestiona | O.T › Requerimiento O.T (menú 5 / submenú 4) | Logística › Requerimiento General (menú 2 / submenú 16) |
| Aprobadores | Paso 1: Jefe de Logística Obras (73) · Paso 2: Gerente General (63) | Paso 1: Jefe de Logística Administrativo (65) |

Los aprobadores salen de `TblFlujoAprobacionCargos` y se cambian desde
Configuración › Flujo de Aprobación (valores al 13/11/2026).

---

## 1. Requerimiento de obra

**Crear:** un solo modal (`templates/components/modal_crear_requerimiento.html`
+ `static/js/requerimiento_crear.js`) usado por el Dashboard y por el módulo.

1. Se busca un presupuesto por número; solo se aceptan los `APROBADO`.
2. Se cargan sus ítems con el saldo disponible (opción "Mostrar sin saldo").
   Un ítem no se puede agregar dos veces ni pedir más que su saldo.
3. `POST /api/requerimientos/crear` → `sp_CrearRequerimientoCompleto`:
   genera el código `REQ-00001`, inserta cabecera y detalle con las cantidades
   digitadas, consume el presupuesto y crea los pasos `PENDIENTE` del flujo.
4. Desde el Dashboard no se redirige al módulo: se muestra la confirmación.

**Endpoints** (`routes/requerimientos.py`): `GET /api/requerimientos/obtener`,
`/obtener/<id>`, `/obtener-detalles/<id>`, `/flujo/<id>`, `/puede-aprobar/<id>`,
`PUT /aprobar/<id>`, `PUT /rechazar/<id>`, `PUT /actualizar/<id>`,
`DELETE /eliminar/<id>`.

> ⚠️ `sp_ActualizarRequerimiento` y `sp_RechazarRequerimiento` **no existen en
> la BD**: editar y rechazar un requerimiento de obra fallan (error 500).
> La solución propuesta para el rechazo, las preguntas pendientes al cliente y
> la corrección del orden de aprobación están en `../CONTEXTO_SISTEMA.md`,
> sección 8.1.

SQL: `database_scripts/requerimientos/01_fix_sp_crear_requerimiento_cantidades.sql`
y `database_scripts/requerimiento_administrativo/02_ajustes_obra.sql`.

## 2. Requerimiento administrativo

**Crear** (Dashboard, cualquier usuario autenticado):
`POST /api/requerimientos/administrativo/crear` →
`sp_CrearRequerimientoAdministrativo`. En una transacción:

1. Valida que haya ítems y que el stock alcance para cada uno (si no, error
   con el nombre del ítem).
2. Inserta cabecera (`PENDIENTE`) y detalle.
3. Descuenta `stock_actual` y registra la SALIDA en `TblMovimientoInventario`.
4. Crea los pasos `PENDIENTE` del flujo (tipo 7).

**Endpoints** (`routes/requerimiento_logistica.py`):

| Acción | Endpoint | Quién |
|---|---|---|
| Listado general (obra + administrativo) | `GET /api/requerimientos/logistica/obtener` | Acceso al submenú 16 |
| Ver detalle | `GET /api/requerimientos/administrativo/<id>` | Submenú 16, el solicitante o un aprobador |
| Aprobar / rechazar | `PUT .../<id>/aprobar` · `PUT .../<id>/rechazar` | El cargo del paso pendiente (validado en el SP) |
| Editar (solo descripción y observaciones) | `PUT .../<id>` | Submenú 16 y estado `PENDIENTE` |
| Eliminar | `DELETE .../<id>` | Submenú 16 y estado `PENDIENTE`; repone el stock |

Si hay varios cargos en el mismo paso, **todos** deben aprobar (cada uno tiene
su registro). **Rechazar y eliminar reponen el stock** (`sp_RQA_ReponerStock`).

SQL: `database_scripts/requerimiento_administrativo/01..03` (03 es la fuente
de los SP).

## 3. Logística › Requerimiento General

Lista **todos** los requerimientos (obra y administrativos). Los de obra son
solo consulta. Acceso por permiso de menú (submenú 16), no por cargo.

**Filtro "Tipo" automático:** al entrar, el filtro se pone según el flujo en
el que participa el cargo del usuario (`_filtro_tipo_por_cargo()`):

| El cargo está en el flujo de… | Filtro inicial |
|---|---|
| Solo obra (tipo 2) | Obra |
| Solo administrativo (tipo 7) | Administrativo |
| Ambos o ninguno | Todos |

Es solo el valor inicial; el usuario puede cambiarlo.

## 4. Notificaciones (campana)

No hay correo ni push: la campana del encabezado (`templates/base.html`)
consulta `GET /api/notificaciones/pendientes` al cargar cada página y cada
30 segundos.

- El endpoint toma el **cargo** del usuario y cuenta los registros `PENDIENTE`
  de `TblRegistroAprobacion` de ese cargo, agrupados por tipo de documento.
- Un paso solo aparece cuando **todos los pasos anteriores están aprobados**.
- Lo ven **todos** los usuarios activos con ese cargo.
- No se filtra por obra: todos los usuarios del cargo ven los requerimientos
  de todas las obras.
- Al hacer clic en un tipo, `GET /api/notificaciones/detalles/<tipo>` abre la
  tabla de pendientes con la acción para aprobar o rechazar.
- El solicitante no recibe aviso cuando aprueban o rechazan su requerimiento.

## 5. Cambiar los aprobadores

Configuración › Flujo de Aprobación → tipo de documento → agregar o quitar
cargos por paso → guardar.

- Para que el cargo pueda **entrar** a Requerimiento General también necesita
  permiso al submenú 16 (Rol y Accesos).
- Los cambios aplican a requerimientos **nuevos**: los registros de
  aprobación se crean al crear el requerimiento, y el reinicio automático al
  guardar el flujo (`guardar_cambios_flujo.py`) solo se aplica a presupuestos.

## 6. Pruebas recomendadas

1. Crear un requerimiento de obra desde el Dashboard y desde el módulo:
   mismo modal, código generado por la BD, cantidad guardada = la digitada,
   saldo del presupuesto descontado, flujo `PENDIENTE`.
2. Crear un requerimiento administrativo: stock descontado, movimiento SALIDA
   en el kardex, notificación al cargo 65.
3. Aprobar / rechazar con el cargo correcto y con uno incorrecto (debe
   rechazar la acción). Al rechazar, el stock vuelve.
4. Entrar a Requerimiento General con un usuario de cada flujo y revisar el
   filtro inicial.
