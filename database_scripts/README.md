# database_scripts

Scripts SQL de la base de datos de Kallpa. Ningún archivo de esta carpeta lo
ejecuta la aplicación: son para correr a mano (MySQL Workbench) o como referencia.

| Carpeta | Contenido | Estado |
|---|---|---|
| `estado_actual/` | Definición **vigente** de todos los SP, funciones y vistas, exportada de la BD (`sps_vistas_triggers_AAAAMMDD.sql`). | Referencia principal. Volver a exportar tras cambios grandes. |
| `esquema/` | `CREATE TABLE` de tablas en uso (proveedores de inventario, entregas a personal). | Referencia. |
| `asistencia/` | SP de horas laboradas (referencia). `01_sp_CrearUsuarioCompleto_vigencia.sql`: el alta de usuario guarda la vigencia del horario. `02_reparar_vigencia_horarios.sql`: da inicio de vigencia a los horarios que no lo tienen (usuarios 76 y 78 desde el 14/11/2026) y limpia versiones solapadas (opcional); con respaldo y verificación, termina en COMMIT/ROLLBACK manual. | 01 **aplicado** el 14/11/2026 19:06. 02: paso A **aplicado** el 14/11/2026 (UPDATE de las 14 filas de 76 y 78); pasos B y C (limpieza de solapes) **pendientes, opcionales**. |
| `requerimientos/` | Corrección del SP de crear requerimiento de obra (cantidades). | Aplicado. |
| `movimiento_requerimiento/` | Movió *Requerimiento* del menú Logística a O.T. | Aplicado. |
| `requerimiento_administrativo/` | Tipo de documento 7, flujo (cargo 65) y SP del requerimiento administrativo. | Aplicado; `03_...` es la fuente de esos SP. |
| `items_inventario/` | Plan de ítems de inventario (partes 1–5), pruebas manuales y scripts de reversión. | Aplicado el 13/11/2026. **Temporal**: borrar junto con las tablas `aux_p*` cuando el inventario esté verificado. |
| `mantenimiento/` | Limpieza de tablas `aux_p*` y `respaldo_*` de la BD. | Ejecutar cuando se borre `items_inventario/`. |

## Respaldos de datos

Los volcados `respaldo_previo_*.sql` (con datos reales) se guardan **fuera del
proyecto**, en `sistema3/_respaldos_bd/`, para que no terminen en git.

## Historial eliminado (13/11/2026)

Se quitaron por estar ya aplicados y no ser re-ejecutables (las tablas antiguas
ya no existen): `migracion_inventario/` (TblMateriales → TblInventario),
`fichas_inventario/`, los CSV de mapeo de categorías y las versiones viejas de
`sp_BuscarMateriales` / `sp_ObtenerCategoriasMaterial`. Su documentación sigue
en `docs_sistema/historial/MIGRACION_MATERIALES_A_INVENTARIO.md` y
`docs_sistema/modulos/INVENTARIO.md`; el código vigente está en `estado_actual/`.
