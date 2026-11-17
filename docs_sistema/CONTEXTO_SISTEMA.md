# Contexto del sistema Kallpa

**Última actualización:** 13/11/2026 (verificado contra el código y la BD)

Documento de entrada para quien trabaje en el sistema. Los detalles de cada
módulo están en [`modulos/`](modulos/); las guías prácticas en [`guias/`](guias/).

---

## 1. Qué es

Sistema web de gestión para una empresa de construcción/inmobiliaria: RR.HH.
(usuarios, marcación con GPS, reportes, vacaciones, memos), Logística
(requerimientos, órdenes de compra, proveedores), Almacén (inventario,
entregas a personal), O.T. (expediente técnico, presupuestos, requerimientos
de obra), configuración (empresas, roles, flujos de aprobación) y Gerencia.

## 2. Tecnologías

| Componente | Tecnología |
|---|---|
| Backend | Flask 2.0.3 (Python 3.12) |
| Base de datos | MySQL 8.0 en PythonAnywhere (`kallpasystem$kallgwkn_kallpa_bd`) |
| Frontend | Plantillas Jinja2, Tailwind, JavaScript sin framework |
| PDF | reportlab, xhtml2pdf, pdfplumber (importar PDF de presupuesto) |
| Conexión local a la BD | Túnel SSH (sshtunnel 0.4.0 + **paramiko 3.4.0**) |
| Autenticación | SHA-256 + sesiones de Flask |
| Zona horaria | UTC-5 (Perú) |

Dependencias completas: `requirements.txt`.

## 3. Estructura del proyecto

```
sys-Kallpa/
├── main.py                 # Punto de entrada (create_app)
├── passenger_wsgi.py       # Entrada para Passenger (hosting)
├── iniciar.bat             # Arranque local en Windows
├── requirements.txt
├── .env / .env.example     # Variables de entorno (.env nunca va a git)
├── app/
│   ├── __init__.py         # create_app, blueprints, manejo de errores JSON en /api/*
│   ├── config.py           # DatabaseConfig + túnel SSH (singleton)
│   ├── funciones/          # funGeneral.py, validar_flujo_aprobacion.py
│   ├── utils/              # email_sender.py
│   ├── routes/             # Un archivo por módulo (ver tabla de la sección 5)
│   ├── templates/          # Una página por módulo + components/ (modales, sidebar)
│   ├── static/js|css/      # JS por módulo, styles.css, animations.css
│   └── sql/                # SP de asistencia/empresa/proveedores (fuente)
├── database_scripts/       # Scripts SQL manuales (ver su README.md)
├── docs_sistema/           # Esta documentación
└── logs/kallpa_app.log     # Log de la aplicación
```

## 4. Base de datos

- 60 tablas, 118 SP/funciones, 6 vistas (13/11/2026).
- Definición vigente de todos los SP y vistas:
  `database_scripts/estado_actual/sps_vistas_triggers_20261113.sql`.
- PythonAnywhere **no permite triggers**: las reglas se implementan en SP.
- PythonAnywhere **no permite conexión externa directa** a MySQL: en local se
  entra por túnel SSH (`USE_SSH_TUNNEL=True`).

Tablas principales: `TblUsuario`, `TblPersona`, `TblCargo`, `TblArea`,
`TblMenu`, `TblSubMenu`, `TblUsuarioAccesos`, `TblEmpresa`, `TblObra`,
`TblPresupuesto(+Detalle)`, `TblRequerimiento(+Detalle)`,
`TblInventario` (+ secciones por tipo, ver `modulos/INVENTARIO.md`),
`TblMovimientoInventario` (kardex), `TblProveedores`, `TblInventarioProveedor`,
`TblEntregaPersonal(+Detalle)`, `TblMarcacion`, `TblHorarioTrabajo`,
`TblVacaciones`, `TblVacacionSaldo`, `TblTipoDocumentoAprobacion`,
`TblFlujoAprobacionCargos`, `TblRegistroAprobacion`.

> `TblMateriales` ya **no existe**: el catálogo se migró a `TblInventario`
> (ver `historial/MIGRACION_MATERIALES_A_INVENTARIO.md`).

## 5. Menús, rutas y archivos

Los permisos son por **menú / submenú** (`TblUsuarioAccesos`), validados con
`validar_acceso_usuario(num_documento, id_menu, id_submenu)` en `routes/main.py`.
Si `id_submenu` es NULL el usuario tiene acceso a todo el menú.

| Menú (id) | Submenú (id) | Ruta | Backend |
|---|---|---|---|
| RR.HH (1) | Usuario (1) | `/usuarios` | `usuarios.py` |
| | Marcación (2) | `/marcacion` | `marcacion.py`, `memo_pdf.py`, `sunafil_pdf.py` |
| | Reportes (3) | `/reportes` | `marcacion.py` |
| | Vacaciones (12) | `/vacaciones` | `vacaciones.py` |
| Logística (2) | Requerimiento General (16) | `/requerimiento-logistica` | `requerimiento_logistica.py` |
| | Órdenes de Compra (5) | `/ordenes-compra` | `ordenes_compra.py` |
| | Proveedores (14) | `/proveedores` | `proveedores.py` |
| Almacén (3) | Inventario (6) | `/inventario` | `inventario.py`, `materiales.py` |
| | Entregas a Personal (15) | `/entregas-personal` | `entregas_personal.py` |
| Configuración (4) | Empresa (7) | `/empresa` | `empresa.py`, `empresa_logo.py` |
| | Rol y Accesos (8) | `/roles` | `roles.py` |
| | Flujo de Aprobación (10) | `/flujo-de-aprobacion` | `flujo_aprobacion.py`, `guardar_cambios_flujo.py` |
| O.T (5) | Expediente Técnico (13) | `/expediente-tecnico` | `expediente_tecnico.py` |
| | Presupuesto (9) | `/presupuesto` | `presupuesto.py`, `presupuesto_pdf.py` |
| | Requerimiento O.T (4) | `/requerimiento` | `requerimientos.py`, `requerimientos_pdf.py` |
| Gerencia (6) | Proceso de Abastecimiento (11) | `/proceso-de-abastecimiento` | `gerencia.py` |

Fuera del menú: `/` y Dashboard (`main.py`), login (`auth.py`), marcación
móvil `/marcacion-kallpa`.

## 6. Flujos de aprobación

Configurables desde **Configuración › Flujo de Aprobación**
(`TblFlujoAprobacionCargos`). Estado al 13/11/2026:

| Tipo de documento (id) | Paso 1 | Paso 2 |
|---|---|---|
| Presupuesto (1) | Jefe de OT (57) | Gerente General (63) |
| Requerimiento de obra (2) | Jefe de Logística Obras (73) | Gerente General (63) |
| Orden de Compra (6) | Jefe de OT (57) | — |
| Requerimiento Administrativo (7) | Jefe de Logística Administrativo (65) | — |

Al crear el documento, su SP inserta un registro `PENDIENTE` por paso/cargo en
`TblRegistroAprobacion`. La campana de notificaciones muestra a cada usuario
los pendientes de **su cargo** cuyo paso anterior ya está aprobado. Detalle en
`modulos/REQUERIMIENTOS.md`.

## 7. Módulos (resumen)

- **Requerimientos** (obra y administrativo): `modulos/REQUERIMIENTOS.md`.
- **Inventario** (ítems, secciones por tipo, unidades, kardex, proveedores):
  `modulos/INVENTARIO.md`.
- **Memos de amonestación**: `modulos/MEMO_AMONESTACIONES.md`.
- **Presupuestos**: CRUD con versiones, PDF, flujo de aprobación (tipo 1) e
  importación desde PDF/Excel (`POST /api/presupuestos/importar-pdf`, con
  pdfplumber). Los ítems que no existen se crean en `TblInventario` con
  `sp_CrearMaterialConCodigoAuto`. El SP `sp_ReportePresupuestos` devuelve
  varios result sets (leerlos todos con `stored_results()`).
- **Marcación**: entrada/salida con GPS y foto; reporte de asistencia con
  justificaciones, memos y PDF SUNAFIL. Los horarios tienen vigencia
  (`fecha_vigencia_inicio/fin` en `TblHorarioTrabajo`) para que un cambio de
  horario no recalcule días pasados (caso de prueba en `pruebas/`).
- **Vacaciones**: solicitar, aprobar, rechazar; saldo de 30 días/año; las
  aprobadas aparecen como VACACIONES en el reporte de asistencia.
- **Usuarios**: CRUD, empresa, cargo y horarios (2 turnos por día).

## 8. Pendientes conocidos (verificado 13/11/2026)

La app llama a estos SP/tablas, pero **no existen en la BD**; el endpoint
correspondiente falla con error 500:

| Falta en BD | Lo usa | Efecto |
|---|---|---|
| `sp_ActualizarRequerimiento` | `PUT /api/requerimientos/actualizar/<id>` | No se puede editar un requerimiento de obra |
| `sp_RechazarRequerimiento` | `PUT /api/requerimientos/rechazar/<id>` | No se puede rechazar un requerimiento de obra |
| `sp_obtener_presupuesto_detalle_completo` | `GET /api/presupuestos/visualizar/<id>` | Visualizar presupuesto |
| `sp_ObtenerRequerimientosAprobados` | `ordenes_compra.py` | Combo de requerimientos en OC |
| `TblOrdenCompra`, `TblOrdenCompraDetalle` | `ordenes_compra.py` | Módulo de Órdenes de Compra sin tablas |
| `sp_estadisticas_inventario` | `inventario.py` | Estadísticas de inventario |
| `sp_ObtenerNotificacionesPendientes` | `GET /api/notificaciones/contar` | Endpoint sin uso en el frontend |
| `TblExpedienteTecnico`, `TblOT` | `expediente_tecnico.py`, `ot.py` | O.T › Expediente Técnico abre, pero su listado falla |
| `TblUsuarios` (la tabla real es `TblUsuario`) | `entregas_personal.py` (`/api/entregas-personal/buscar-personal`) | Endpoint sin uso en el frontend; corregir el nombre |

### 8.1 Propuesta: rechazar requerimiento de obra (en espera)

**Estado:** documentado, **no implementado**. Se espera que el cliente defina
cómo debe funcionar el rechazo para su personal (ver preguntas abajo).
Estimación: 2–3 horas con pruebas.

**Qué existe hoy:** el botón "Rechazar" con su motivo
(`templates/requerimiento.html`, función `rechazarRequerimiento()`) y el
endpoint `PUT /api/requerimientos/rechazar/<id>` (`routes/requerimientos.py`).
Solo falta el SP `sp_RechazarRequerimiento` en la BD, por eso hoy da error 500.

**Firma que espera el backend:**
`sp_RechazarRequerimiento(p_id_requerimiento, p_num_documento, p_comentario, OUT p_success, OUT p_mensaje)`.
Debe terminar con un `SELECT` de `success` y `mensaje` (el endpoint lee un
result set, no los OUT).

**Solución propuesta** (script nuevo en `database_scripts/requerimientos/`,
mismo estilo que `sp_RechazarRequerimientoAdministrativo`):

1. Obtener el cargo del usuario (`TblUsuario`, activo).
2. Validar que ese cargo tenga un paso `PENDIENTE` del requerimiento
   (`TblRegistroAprobacion`, tipo 2) y que **todos los pasos anteriores estén
   aprobados**.
3. Marcar ese paso `RECHAZADO` con comentario, aprobador y fecha.
4. Pasar `TblRequerimiento.estado` a `RECHAZADO`.
5. **Devolver el saldo al presupuesto**: restar las cantidades del
   requerimiento de `TblPresupuestoDetalle.cantidad_consumida` y de
   `TblPresupuesto.cantidad_consumida` (lo inverso de
   `sp_CrearRequerimientoCompleto`).
6. Todo en una transacción; errores de negocio con `SIGNAL SQLSTATE '45000'`.
7. Prueba manual dentro de `START TRANSACTION … ROLLBACK`.

**Detalle técnico a resolver:** `TblRequerimientoDetalle` guarda
`id_inventario`, pero no la línea del presupuesto de la que salió. El saldo se
devolvería emparejando **presupuesto + ítem**. Si un mismo ítem aparece en
dos líneas del mismo presupuesto, hay que definir a cuál se devuelve, o
agregar la columna `id_detalle_presupuesto` al detalle del requerimiento.

**Preguntas para el cliente antes de implementar:**

1. Al rechazar, ¿se devuelve el saldo al presupuesto para poder volver a
   pedir esos ítems?
2. ¿El rechazo es definitivo, o el solicitante puede **corregir y reenviar**
   el mismo requerimiento (reiniciando el flujo desde el paso 1)?
3. ¿Puede rechazar cualquier paso (Jefe de Logística Obras y Gerente General)
   o solo algunos?
4. ¿El motivo del rechazo es obligatorio?
5. ¿Hay que avisar al solicitante? Hoy la campana solo avisa a los
   aprobadores; el solicitante no recibe aviso al aprobarse o rechazarse.

**Corregir junto con esto:** `sp_AprobarRequerimiento` (obra) **no valida que
los pasos anteriores estén aprobados**: el Gerente General (paso 2) podría
aprobar antes que el Jefe de Logística Obras (paso 1). La campana no se lo
muestra, pero la BD lo permite. Agregar la misma validación del punto 2
(unos 15 minutos).

## 9. Reglas para desarrollar

1. `.env` nunca se sube a git. **Ningún documento debe contener contraseñas,
   claves ni `SECRET_KEY` reales**: usar `<...>`.
2. Todo endpoint `/api/*` responde JSON, también en errores (lo garantizan
   `before_request` y los `errorhandler` de `app/__init__.py`).
3. Lógica de datos en SP; errores de negocio con `SIGNAL SQLSTATE '45000'`
   (el backend los devuelve como 400 con su mensaje).
4. Al cambiar archivos estáticos, subir `ASSETS_VERSION` en `app/__init__.py`.
5. Cambios en la BD: script en `database_scripts/<tema>/`, idempotente y con
   respaldo previo; los volcados con datos van a `sistema3/_respaldos_bd/`.
6. Tras cambios grandes en SP, volver a exportar `database_scripts/estado_actual/`.
