# Inventario (Almacén)

**Actualizado:** 13/11/2026

`TblInventario` es el catálogo único de ítems: materiales, herramientas,
equipos, tecnología, ropa/EPP, oficina, servicios y partidas. Desde el
30/10/2026 reemplaza a `TblMateriales` (ver
`../historial/MIGRACION_MATERIALES_A_INVENTARIO.md`).

## 1. Tipos y códigos

El tipo de un ítem es la columna `TblInventario.tipo_inventario`. Cada tipo
físico tiene su tabla de sección:

| `tipo_inventario` | Sección propia |
|---|---|
| MATERIAL | `TblInventarioMaterial` |
| HERRAMIENTA | `TblInventarioHerramienta` |
| EQUIPO | `TblInventarioEquipo` |
| TECNOLOGIA | `TblInventarioTecnologia` |
| ROPA | `TblInventarioRopa` |
| CONSUMIBLE | `TblInventarioConsumible` |
| SERVICIO, PARTIDA | — (no son físicos: sin sección ni stock) |

**Categorías:** `TblCategoriaInventario`, en dos niveles. Las de nivel 1 (sin
padre) son MAT, HER, EQU, TEC, ROP, OFI, SER y PAR.

**Código:** `PREFIJO-001` (mínimo 3 dígitos, crece a 4 sin cortar). El
prefijo es el código de la categoría de nivel 1 del ítem; si no hay, `INV`.
Un tipo nuevo con su categoría raíz genera códigos solo. Los códigos
anteriores a la recodificación del 13/11/2026 quedan en
`TblInventarioCodigoAnterior`.

## 2. Secciones por tipo (fichas)

Cada ítem físico tiene **una fila** en la tabla de su sección (relación 1 a 1
por `id_inventario`), con los datos propios del tipo (talla, marca, potencia,
RAM...).

- Integridad: FK `(id_inventario, tipo_inventario)` hacia `TblInventario` y un
  `CHECK` que fija el tipo de cada sección (una ropa no puede tener ficha de
  material).
- Como PythonAnywhere no permite triggers, la fila se crea con SP:
  `sp_asegurar_seccion_inventario(id)` y
  `sp_sincronizar_secciones_inventario()`.
- El formulario **no tiene campos fijos en el código**: la estructura de cada
  campo se lee de la BD (`information_schema`: tipo, largo, opciones ENUM) y la
  presentación (etiqueta, ayuda, orden, visible) de `TblInventarioCampoSeccion`.
  Una columna nueva en una sección aparece sola en el formulario.
  SP: `sp_obtener_tabla_seccion`, `sp_listar_tipos_inventario`,
  `sp_listar_campos_seccion`, `sp_listar_categorias_tipo`.
- Vistas de consulta para reportes: `vw_inventario_<tipo>` (la app no depende
  de ellas).
- `TblInventarioAtributos` (modelo EAV antiguo) queda como legado de solo
  lectura.

## 3. Unidades de medida

- `TblUnidadMedida` tiene `magnitud` (qué unidades se pueden convertir entre
  sí).
- `TblUnidadConversion`: equivalencias fijas (1 TON = 1000 KG).
- `TblInventarioConversion`: equivalencias por ítem (1 BOLSA de cemento =
  42.5 KG; 1 VARA de acero 1/2" = 8.946 KG). `factor` = cuántas `id_unidad`
  contiene 1 unidad base del ítem.
- `TblCategoriaUnidad`: unidades permitidas por categoría (la subcategoría
  hereda las de su padre si no tiene propias) y una unidad predeterminada.
  SP: `sp_listar_unidades_categoria`.

## 4. Alta de ítems

`POST /api/inventario/crear` → **`sp_guardar_item`**, en una sola transacción:

1. `TblInventario` con el código `PREFIJO-001`.
2. La fila de su sección con los datos de `p_ficha` (JSON).
3. Stock inicial opcional: `stock_actual` + movimiento ENTRADA en el kardex.

Valida todo antes de escribir y devuelve mensajes claros. Desde Presupuesto,
los ítems importados desde PDF/Excel se crean con
`sp_CrearMaterialConCodigoAuto`, que usa el mismo generador de código.

## 5. Stock y kardex

**Regla:** `TblInventario.stock_actual` es el saldo oficial y **toda**
operación que lo cambia deja su movimiento en `TblMovimientoInventario`.

- `sp_registrar_movimiento_stock` es el núcleo (ENTRADA, SALIDA, AJUSTE).
  No abre transacción: se suma a la del llamador. Valida cantidad > 0, que la
  salida no supere el stock y que el ítem sea físico. Genera códigos únicos
  (`ENT-…`, `SAL-…`) y pone el almacén en origen o destino según el tipo.
- `sp_ajustar_stock` (`POST /api/inventario/movimiento`) lo usa para los
  ajustes manuales.
- Las **entregas a personal** (`routes/entregas_personal.py`) registran su
  SALIDA con tipo de documento `ENTREGA_PERSONAL`. Las entregas antiguas, que
  descontaron stock sin movimiento, se completaron en el kardex
  (`SAL-ENT<entrega>-<ítem>`).
- Los **requerimientos administrativos** descuentan stock al crearse y lo
  reponen al rechazarse o eliminarse (ver `REQUERIMIENTOS.md`).
- `sp_verificar_kardex(1)` lista los ítems cuyo saldo no cuadra con la suma
  de movimientos (esperado: 0 filas).

## 6. Proveedores por ítem

Relación muchos a muchos `TblInventarioProveedor` (ítem ↔ `TblProveedores`).

- **Almacén › Inventario**: acción "Proveedores" en cada ítem → modal para ver,
  asociar y desasociar proveedores.
  Endpoints: `GET /api/inventario/<id>/proveedores`,
  `POST /api/inventario/<id>/proveedores/asociar`,
  `DELETE /api/inventario/proveedores/desasociar/<id_relacion>`,
  `GET /api/inventario/proveedores/selector`.
- **Logística › Proveedores**: acción "Ficha de materiales" con los ítems que
  ofrece cada proveedor.

## 7. Scripts

- Plan de ítems aplicado el 13/11/2026 (partes 1–5: unidades, unificación de
  duplicados y recodificación, secciones, formulario dinámico, kardex):
  `database_scripts/items_inventario/` con sus `pX_99_revertir.sql` y pruebas
  manuales (`parte4_prueba_manual.sql`, `parte5_prueba_manual.sql`, se
  ejecutan dentro de una transacción con `ROLLBACK`).
- Esa carpeta es **temporal**: cuando el inventario esté verificado se borra
  junto con las tablas `aux_p*`
  (`database_scripts/mantenimiento/limpieza_tablas_aux_respaldo_20261113.sql`).
- Código vigente de todos los SP: `database_scripts/estado_actual/`.

## 8. Pendiente

- `sp_estadisticas_inventario` no existe en la BD:
  `GET /api/inventario/estadisticas` falla.
