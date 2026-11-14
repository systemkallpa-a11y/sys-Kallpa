"""
Ejecutor del plan "Creación y almacenamiento de ítems de inventario".

Uso (desde sys-Kallpa, con el venv activo):
    python database_scripts/items_inventario/aplicar_items.py respaldo
    python database_scripts/items_inventario/aplicar_items.py exportar_sps
    python database_scripts/items_inventario/aplicar_items.py aplicar 1
    python database_scripts/items_inventario/aplicar_items.py verificar 1
    python database_scripts/items_inventario/aplicar_items.py revertir 1

- respaldo:     .sql local con estructura + datos de las tablas de inventario
                (no modifica la BD).
- exportar_sps: .sql local con el código actual de los SPs que tocan inventario
                (no modifica la BD).
- aplicar N:    ejecuta los scripts de la parte N, en orden, y luego verifica.
- verificar N:  consultas de control de la parte N.
- revertir N:   ejecuta el script de reversión de la parte N.
"""

import os
import sys
import datetime
from decimal import Decimal

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, BASE_DIR)

from dotenv import load_dotenv
load_dotenv(os.path.join(BASE_DIR, '.env'))

from app.config import DatabaseConfig
import mysql.connector

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
HOY = datetime.date.today().strftime('%Y%m%d')

TABLAS_RESPALDO = [
    'TblInventario',
    'TblCategoriaInventario',
    'TblUnidadMedida',
    'TblAlmacen',
    'TblInventarioRopa',
    'TblInventarioMaterial',
    'TblInventarioHerramienta',
    'TblInventarioEquipo',
    'TblInventarioTecnologia',
    'TblInventarioConsumible',
    'TblInventarioAtributos',
    'TblInventarioAlmacen',
    'TblInventarioProveedor',
    'TblMovimientoInventario',
    'TblPresupuestoDetalle',
    'TblRequerimientoDetalle',
    'TblEntregaPersonalDetalle',
]

PARTES = {
    '1': {
        'aplicar': [
            'p1_01_unidades.sql',
            'p1_02_conversion_unidades.sql',
            'p1_03_categorias.sql',
            'p1_04_categoria_unidad.sql',
            'p1_05_conversion_item.sql',
        ],
        'revertir': ['p1_99_revertir.sql'],
    },
    '2': {
        'aplicar': [
            'p2_01_auditoria.sql',
            'p2_02_unificar.sql',
            'p2_03_clasificar.sql',
            'p2_04_recodificar.sql',
            'p2_05_generador_codigo.sql',
        ],
        'revertir': ['p2_99_revertir.sql'],
    },
    '3': {
        'aplicar': [
            'p3_01_sp_seccion.sql',
            'p3_02_cargar_secciones.sql',
            'p3_03_conversiones_item.sql',
        ],
        'revertir': ['p3_99_revertir.sql'],
    },
    '4': {
        'aplicar': [
            'p4_01_campos_seccion.sql',
            'p4_02_sp_lectura.sql',
            'p4_03_sp_generar_codigo.sql',
            'p4_04_sp_guardar_item.sql',
        ],
        'revertir': ['p4_99_revertir.sql'],
    },
}

SECCIONES = [
    ('MATERIAL', 'TblInventarioMaterial'),
    ('HERRAMIENTA', 'TblInventarioHerramienta'),
    ('EQUIPO', 'TblInventarioEquipo'),
    ('TECNOLOGIA', 'TblInventarioTecnologia'),
    ('ROPA', 'TblInventarioRopa'),
    ('CONSUMIBLE', 'TblInventarioConsumible'),
]

SQL_SECCIONES_POR_ITEM = " + ".join(
    f"(SELECT COUNT(*) FROM {t} s WHERE s.id_inventario = i.id_inventario)" for _, t in SECCIONES)


def conectar():
    params = DatabaseConfig.get_connection_params()
    print(f"[DB] {params.get('host')} / {params.get('database')}")
    return mysql.connector.connect(**params)


def esc(valor):
    if valor is None:
        return 'NULL'
    if isinstance(valor, bool):
        return '1' if valor else '0'
    if isinstance(valor, (int, float, Decimal)):
        return str(valor)
    if isinstance(valor, datetime.datetime):
        return "'" + valor.strftime('%Y-%m-%d %H:%M:%S') + "'"
    if isinstance(valor, (datetime.date, datetime.timedelta)):
        return "'" + str(valor) + "'"
    if isinstance(valor, (bytes, bytearray)):
        return "0x" + bytes(valor).hex()
    texto = str(valor).replace('\\', '\\\\').replace("'", "\\'")
    return f"'{texto}'"


def columnas_insertables(cursor, tabla):
    cursor.execute(
        """SELECT COLUMN_NAME, EXTRA FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s
           ORDER BY ORDINAL_POSITION""",
        (tabla,),
    )
    return [n for n, extra in cursor.fetchall()
            if not (extra and 'GENERATED' in extra.upper())]


def respaldar():
    conn = conectar()
    cur = conn.cursor()
    destino = os.path.join(SCRIPTS_DIR, f'respaldo_previo_{HOY}.sql')
    sufijo = f'_backup_{HOY}'

    with open(destino, 'w', encoding='utf-8') as f:
        f.write('-- Respaldo previo al plan de ítems de inventario\n')
        f.write(f'-- Generado: {datetime.datetime.now().isoformat(timespec="seconds")}\n')
        f.write(f'-- Restaura en tablas *{sufijo} (no pisa las tablas reales)\n\n')
        f.write('SET NAMES utf8mb4;\nSET FOREIGN_KEY_CHECKS = 0;\n\n')

        total = 0
        for tabla in TABLAS_RESPALDO:
            cur.execute(f'SHOW CREATE TABLE `{tabla}`')
            create = cur.fetchone()[1]
            f.write(f'-- ------------------------------ {tabla}\n')
            f.write(f'DROP TABLE IF EXISTS `{tabla}{sufijo}`;\n')
            f.write(create.replace(f'CREATE TABLE `{tabla}`',
                                   f'CREATE TABLE `{tabla}{sufijo}`', 1) + ';\n\n')

            cols = columnas_insertables(cur, tabla)
            cur.execute(f'SELECT `{"`, `".join(cols)}` FROM `{tabla}`')
            filas = cur.fetchall()
            total += len(filas)
            for fila in filas:
                valores = ', '.join(esc(v) for v in fila)
                f.write(f'INSERT INTO `{tabla}{sufijo}` (`{"`, `".join(cols)}`) '
                        f'VALUES ({valores});\n')
            print(f'   {tabla}: {len(filas)} filas')
            f.write('\n')

        f.write('SET FOREIGN_KEY_CHECKS = 1;\n')
        f.write(f'-- Total de filas respaldadas: {total}\n')

    cur.close()
    conn.close()
    print(f"[OK] Respaldo: {destino} ({total} filas)")


def exportar_sps():
    conn = conectar()
    cur = conn.cursor()
    cur.execute("""SELECT ROUTINE_NAME, ROUTINE_TYPE FROM information_schema.ROUTINES
                   WHERE ROUTINE_SCHEMA = DATABASE() ORDER BY ROUTINE_NAME""")
    rutinas = cur.fetchall()
    destino = os.path.join(SCRIPTS_DIR, f'sp_inventario_actuales_{HOY}.sql')
    exportados = []

    with open(destino, 'w', encoding='utf-8') as f:
        f.write('-- SPs que tocan inventario, tal como están en la BD\n')
        f.write(f'-- Exportado: {datetime.datetime.now().isoformat(timespec="seconds")}\n\n')
        f.write('DELIMITER $$\n\n')
        for nombre, tipo in rutinas:
            cur.execute(f'SHOW CREATE {tipo} `{nombre}`')
            cuerpo = cur.fetchone()[2] or ''
            if not any(t in cuerpo for t in ('TblInventario', 'TblMovimientoInventario',
                                              'TblEntregaPersonal', 'TblUnidadMedida')):
                continue
            exportados.append(nombre)
            f.write(f'-- ============================================ {nombre}\n')
            f.write(f'DROP {tipo} IF EXISTS `{nombre}`$$\n')
            f.write(cuerpo + '$$\n\n')
        f.write('DELIMITER ;\n')

    cur.close()
    conn.close()
    print(f"[OK] {len(exportados)} rutinas exportadas a {destino}")
    for n in exportados:
        print('   ', n)


def dividir_sql(texto):
    """Divide el script en sentencias. Soporta `DELIMITER $$` para SPs.
    Las líneas que empiezan con `--` se omiten."""
    sentencias, actual, delim = [], [], ';'
    for linea in texto.splitlines():
        limpia = linea.strip()
        if limpia.startswith('--'):
            continue
        if limpia.upper().startswith('DELIMITER '):
            delim = limpia.split()[1]
            continue
        if limpia.endswith(delim):
            actual.append(linea.rstrip()[:-len(delim)])
            sentencia = '\n'.join(actual).strip()
            if sentencia:
                sentencias.append(sentencia)
            actual = []
        else:
            actual.append(linea)
    resto = '\n'.join(actual).strip()
    if resto:
        sentencias.append(resto)
    return sentencias


def ejecutar_archivos(archivos):
    conn = conectar()
    cur = conn.cursor()
    try:
        for archivo in archivos:
            with open(os.path.join(SCRIPTS_DIR, archivo), encoding='utf-8') as f:
                sentencias = dividir_sql(f.read())
            print(f"\n=== {archivo} ({len(sentencias)} sentencias) ===")
            for i, sentencia in enumerate(sentencias, 1):
                try:
                    cur.execute(sentencia)
                    if cur.with_rows:
                        for fila in cur.fetchall()[:20]:
                            print('   ', fila)
                    else:
                        print(f'  [{i}] OK ({cur.rowcount} filas)')
                except Exception as e:
                    conn.rollback()
                    print(f'  [{i}] ERROR: {e}\n      SQL: {sentencia[:300]}')
                    raise
            conn.commit()
    finally:
        cur.close()
        conn.close()


VERIFICACIONES = {
    '1': [
        ("Unidades activas por magnitud", """
            SELECT magnitud, GROUP_CONCAT(codigo ORDER BY codigo) AS unidades, COUNT(*) n
            FROM TblUnidadMedida WHERE estado = 'ACTIVO' GROUP BY magnitud"""),
        ("Unidades sin magnitud (debe ser vacío)", """
            SELECT codigo FROM TblUnidadMedida WHERE magnitud IS NULL"""),
        ("Abreviaturas repetidas entre activas (debe ser vacío)", """
            SELECT abreviatura, GROUP_CONCAT(codigo) FROM TblUnidadMedida
            WHERE estado = 'ACTIVO' GROUP BY abreviatura HAVING COUNT(*) > 1"""),
        ("Conversiones generales", """
            SELECT o.codigo, '=', c.factor, d.codigo FROM TblUnidadConversion c
            JOIN TblUnidadMedida o ON o.id_unidad = c.id_unidad_origen
            JOIN TblUnidadMedida d ON d.id_unidad = c.id_unidad_destino
            ORDER BY o.magnitud, o.codigo"""),
        ("Conversiones entre magnitudes distintas (debe ser vacío)", """
            SELECT o.codigo, d.codigo FROM TblUnidadConversion c
            JOIN TblUnidadMedida o ON o.id_unidad = c.id_unidad_origen
            JOIN TblUnidadMedida d ON d.id_unidad = c.id_unidad_destino
            WHERE o.magnitud <> d.magnitud"""),
        ("Categorías nuevas o modificadas", """
            SELECT c.codigo, c.nombre, p.codigo AS padre, c.tipo_aplicable, c.icono
            FROM TblCategoriaInventario c
            LEFT JOIN TblCategoriaInventario p ON p.id_categoria = c.id_categoria_padre
            WHERE c.codigo IN ('MAT-AGR','MAT-CONCRETO','MAT-LAD','MAT-FER','MAT-DRY',
                               'HER-SEN','EQU-MEN','SER','PAR')"""),
        ("Unidades efectivas por categoría (propias o heredadas)", """
            SELECT c.codigo,
                   IF(EXISTS(SELECT 1 FROM TblCategoriaUnidad x WHERE x.id_categoria = c.id_categoria),
                      'propia', 'hereda') AS origen,
                   GROUP_CONCAT(CONCAT(u.codigo, IF(cu.predeterminada = 1, '*', ''))
                                ORDER BY cu.predeterminada DESC, u.codigo) AS unidades
            FROM TblCategoriaInventario c
            JOIN TblCategoriaUnidad cu ON cu.id_categoria = IF(
                 EXISTS(SELECT 1 FROM TblCategoriaUnidad x WHERE x.id_categoria = c.id_categoria),
                 c.id_categoria, c.id_categoria_padre)
            JOIN TblUnidadMedida u ON u.id_unidad = cu.id_unidad
            WHERE c.estado = 'ACTIVO'
            GROUP BY c.id_categoria, c.codigo ORDER BY c.codigo"""),
        ("Categorías activas sin ninguna unidad (debe ser vacío)", """
            SELECT c.codigo FROM TblCategoriaInventario c
            WHERE c.estado = 'ACTIVO'
              AND NOT EXISTS (SELECT 1 FROM TblCategoriaUnidad x WHERE x.id_categoria = c.id_categoria)
              AND NOT EXISTS (SELECT 1 FROM TblCategoriaUnidad x WHERE x.id_categoria = c.id_categoria_padre)"""),
        ("Tabla de conversiones por ítem creada", """
            SELECT TABLE_NAME, TABLE_ROWS FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'TblInventarioConversion'"""),
        ("Sin cambios en ítems (debe seguir en 78)", "SELECT COUNT(*) FROM TblInventario"),
    ],
    '2': [
        ("Presupuestos cuyo total o cantidad cambió (debe ser vacío)", """
            SELECT a.id_presupuesto, a.total AS antes, d.total AS despues
            FROM aux_p2_totales_presupuesto a
            LEFT JOIN (SELECT id_presupuesto, COUNT(*) lineas, SUM(cantidad) cantidad, SUM(subtotal) total
                       FROM TblPresupuestoDetalle GROUP BY id_presupuesto) d
              ON d.id_presupuesto = a.id_presupuesto
            WHERE NOT (a.lineas <=> d.lineas AND a.cantidad <=> d.cantidad AND a.total <=> d.total)"""),
        ("Requerimientos cuya cantidad cambió (debe ser vacío)", """
            SELECT a.id_requerimiento FROM aux_p2_totales_requerimiento a
            LEFT JOIN (SELECT id_requerimiento, COUNT(*) lineas, SUM(cantidad) cantidad
                       FROM TblRequerimientoDetalle GROUP BY id_requerimiento) d
              ON d.id_requerimiento = a.id_requerimiento
            WHERE NOT (a.lineas <=> d.lineas AND a.cantidad <=> d.cantidad)"""),
        ("Referencias que siguen apuntando a duplicados (debe ser vacío)", """
            SELECT 'presupuesto', COUNT(*) FROM TblPresupuestoDetalle d
              JOIN TblInventarioUnificacion u ON u.id_duplicado = d.id_inventario AND u.id_conservado IS NOT NULL
            UNION ALL SELECT 'requerimiento', COUNT(*) FROM TblRequerimientoDetalle d
              JOIN TblInventarioUnificacion u ON u.id_duplicado = d.id_inventario AND u.id_conservado IS NOT NULL
            UNION ALL SELECT 'movimiento', COUNT(*) FROM TblMovimientoInventario d
              JOIN TblInventarioUnificacion u ON u.id_duplicado = d.id_inventario AND u.id_conservado IS NOT NULL
            UNION ALL SELECT 'historial', COUNT(*) FROM TblPresupuestoVersionDetalleHistorial d
              JOIN TblInventarioUnificacion u ON u.id_duplicado = d.id_inventario AND u.id_conservado IS NOT NULL"""),
        ("Stock total sin cambios (antes vs después)", """
            SELECT (SELECT SUM(stock_actual) FROM aux_p2_items_antes) AS antes,
                   (SELECT SUM(stock_actual) FROM TblInventario) AS despues"""),
        ("Tipo distinto al de su categoría (debe ser vacío)", """
            SELECT i.id_inventario, i.tipo_inventario, c.codigo, c.tipo_aplicable
            FROM TblInventario i JOIN TblCategoriaInventario c ON c.id_categoria = i.id_categoria
            WHERE i.estado = 'ACTIVO' AND c.tipo_aplicable <> i.tipo_inventario"""),
        ("Ítems activos con unidad no permitida en su categoría (debe ser vacío)", """
            SELECT i.id_inventario, i.nombre, c.codigo, u.codigo
            FROM TblInventario i
            JOIN TblCategoriaInventario c ON c.id_categoria = i.id_categoria
            JOIN TblUnidadMedida u ON u.id_unidad = i.id_unidad
            WHERE i.estado = 'ACTIVO' AND NOT EXISTS (
              SELECT 1 FROM TblCategoriaUnidad cu
              WHERE cu.id_unidad = i.id_unidad
                AND cu.id_categoria = IF(EXISTS(SELECT 1 FROM TblCategoriaUnidad x
                                                WHERE x.id_categoria = c.id_categoria),
                                         c.id_categoria, c.id_categoria_padre))"""),
        ("Códigos con prefijo que no corresponde (debe ser vacío)", """
            SELECT i.id_inventario, i.codigo, COALESCE(p.codigo, c.codigo) AS prefijo
            FROM TblInventario i
            JOIN TblCategoriaInventario c ON c.id_categoria = i.id_categoria
            LEFT JOIN TblCategoriaInventario p ON p.id_categoria = c.id_categoria_padre
            WHERE i.codigo NOT REGEXP CONCAT('^', COALESCE(p.codigo, c.codigo), '-[0-9]{3,}$')"""),
        ("Ítems por tipo y estado", """
            SELECT tipo_inventario, estado, COUNT(*), MIN(codigo), MAX(codigo)
            FROM TblInventario GROUP BY tipo_inventario, estado ORDER BY 1, 2"""),
        ("Ítems activos (resultado final)", """
            SELECT i.codigo, i.nombre, c.codigo AS categoria, u.codigo AS unidad, i.stock_actual
            FROM TblInventario i
            JOIN TblCategoriaInventario c ON c.id_categoria = i.id_categoria
            JOIN TblUnidadMedida u ON u.id_unidad = i.id_unidad
            WHERE i.estado = 'ACTIVO' ORDER BY i.codigo"""),
    ],
    '4': [
        ("SPs de la Parte 4 instalados", """
            SELECT ROUTINE_NAME FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME IN (
              'sp_obtener_tabla_seccion','sp_listar_tipos_inventario','sp_listar_categorias_tipo',
              'sp_listar_unidades_categoria','sp_listar_campos_seccion','sp_generar_material','sp_guardar_item')
            ORDER BY ROUTINE_NAME"""),
        ("Campos con presentación registrada por tipo", """
            SELECT tipo_inventario, COUNT(*), SUM(visible) AS visibles
            FROM TblInventarioCampoSeccion GROUP BY tipo_inventario"""),
        ("Columnas de sección sin presentación registrada (aparecen con nombre formateado)", """
            SELECT c.TABLE_NAME, c.COLUMN_NAME FROM information_schema.COLUMNS c
            WHERE c.TABLE_SCHEMA = DATABASE()
              AND c.TABLE_NAME IN ('TblInventarioRopa','TblInventarioMaterial','TblInventarioHerramienta',
                                   'TblInventarioEquipo','TblInventarioTecnologia','TblInventarioConsumible')
              AND c.COLUMN_NAME NOT IN ('id_inventario','tipo_inventario','fecha_actualizacion')
              AND NOT EXISTS (SELECT 1 FROM TblInventarioCampoSeccion m
                              WHERE m.columna = CONVERT(c.COLUMN_NAME USING utf8mb4) COLLATE utf8mb4_unicode_ci)"""),
    ],
    '3': [
        ("SPs de sección instalados", """
            SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA = DATABASE()
              AND ROUTINE_NAME IN ('sp_asegurar_seccion_inventario', 'sp_sincronizar_secciones_inventario',
                                   'sp_crear_inventario', 'sp_CrearMaterialConCodigoAuto')
            ORDER BY ROUTINE_NAME"""),
        ("Ítems físicos sin sección o con más de una (debe ser vacío)", f"""
            SELECT i.id_inventario, i.codigo, i.tipo_inventario, ({SQL_SECCIONES_POR_ITEM}) AS n
            FROM TblInventario i
            WHERE i.tipo_inventario NOT IN ('SERVICIO','PARTIDA')
              AND ({SQL_SECCIONES_POR_ITEM}) <> 1"""),
        ("Servicios o partidas con sección (debe ser vacío)", f"""
            SELECT i.id_inventario, i.codigo FROM TblInventario i
            WHERE i.tipo_inventario IN ('SERVICIO','PARTIDA') AND ({SQL_SECCIONES_POR_ITEM}) > 0"""),
        ("Filas por sección", " UNION ALL ".join(
            f"SELECT '{t}', COUNT(*) FROM {t}" for _, t in SECCIONES)),
        ("Sección Material (activos)", """
            SELECT i.codigo, i.nombre, m.presentacion, m.marca, m.tipo, m.medida, m.color,
                   m.peso_unitario_kg, m.largo_cm
            FROM TblInventarioMaterial m JOIN TblInventario i ON i.id_inventario = m.id_inventario
            WHERE i.estado = 'ACTIVO' ORDER BY i.codigo"""),
        ("Sección Herramienta (activos)", """
            SELECT i.codigo, i.nombre, h.tipo_herramienta, h.peso_kg, h.alto_cm
            FROM TblInventarioHerramienta h JOIN TblInventario i ON i.id_inventario = h.id_inventario
            WHERE i.estado = 'ACTIVO' ORDER BY i.codigo"""),
        ("Sección Tecnología", """
            SELECT i.codigo, i.estado, t.marca, t.procesador, t.ram, t.almacenamiento, t.pantalla
            FROM TblInventarioTecnologia t JOIN TblInventario i ON i.id_inventario = t.id_inventario
            ORDER BY i.codigo"""),
        ("Sección Ropa", """
            SELECT i.codigo, i.nombre, r.color, r.tipo_proteccion
            FROM TblInventarioRopa r JOIN TblInventario i ON i.id_inventario = r.id_inventario
            ORDER BY i.codigo"""),
        ("Conversiones por ítem (con equivalencia derivada a otra unidad)", """
            SELECT i.codigo, i.nombre, CONCAT('1 ', ub.codigo, ' = ', TRIM(TRAILING '.' FROM TRIM(TRAILING '0' FROM c.factor)), ' ', ua.codigo) AS conversion,
                   (SELECT GROUP_CONCAT(CONCAT('1 ', ub.codigo, ' = ',
                           ROUND(c.factor / g.factor, 4), ' ', o.codigo) SEPARATOR ' | ')
                    FROM TblUnidadConversion g JOIN TblUnidadMedida o ON o.id_unidad = g.id_unidad_origen
                    WHERE g.id_unidad_destino = c.id_unidad) AS derivada,
                   c.observaciones
            FROM TblInventarioConversion c
            JOIN TblInventario i ON i.id_inventario = c.id_inventario
            JOIN TblUnidadMedida ub ON ub.id_unidad = i.id_unidad
            JOIN TblUnidadMedida ua ON ua.id_unidad = c.id_unidad
            ORDER BY i.codigo"""),
    ],
}


def probar_secciones(conn):
    """Simula los flujos reales (alta y cambio de tipo como lo hace
    app/routes/inventario.py) y revisa la sección en cada paso.
    Todo dentro de una transacción que se deshace al final (no deja datos)."""
    cur = conn.cursor()
    print("\n== Prueba de SPs de sección (transacción con ROLLBACK, no deja datos) ==")

    def secciones(id_inv):
        res = []
        for tipo, tabla in SECCIONES:
            cur.execute(f"SELECT COUNT(*) FROM {tabla} WHERE id_inventario = %s", (id_inv,))
            if cur.fetchone()[0]:
                res.append(tipo)
        return res

    def cambiar_tipo(id_inv, tipo_viejo, tipo_nuevo, cat):
        # Mismo orden que actualizar_item: borrar ficha vieja, actualizar, asegurar sección
        tabla_vieja = dict(SECCIONES).get(tipo_viejo)
        if tabla_vieja:
            cur.execute(f"DELETE FROM {tabla_vieja} WHERE id_inventario = %s", (id_inv,))
        cur.execute("""
            UPDATE TblInventario i JOIN TblCategoriaInventario c ON c.codigo = %s
            SET i.tipo_inventario = %s, i.id_categoria = c.id_categoria
            WHERE i.id_inventario = %s""", (cat, tipo_nuevo, id_inv))
        cur.callproc('sp_asegurar_seccion_inventario', [id_inv])

    conn.rollback()  # cierra la transacción implícita de las consultas previas
    try:
        conn.start_transaction()
        cur.execute("""
            INSERT INTO TblInventario (codigo, nombre, tipo_inventario, id_categoria, id_unidad,
                                       stock_actual, stock_minimo, stock_maximo, estado)
            SELECT 'PRUEBA-SEC', 'Prueba de sección', 'ROPA', c.id_categoria, u.id_unidad, 0, 0, 0, 'ACTIVO'
            FROM TblCategoriaInventario c, TblUnidadMedida u
            WHERE c.codigo = 'ROP-EPP' AND u.codigo = 'UND'""")
        id_prueba = cur.lastrowid
        print(f"   0. INSERT directo (sin SP)  -> secciones: {secciones(id_prueba)}  (esperado: [])")

        cur.callproc('sp_asegurar_seccion_inventario', [id_prueba])
        print(f"   1. Asegurar sección ROPA    -> secciones: {secciones(id_prueba)}  (esperado: ['ROPA'])")

        cur.callproc('sp_asegurar_seccion_inventario', [id_prueba])
        print(f"   2. Asegurar otra vez        -> secciones: {secciones(id_prueba)}  (esperado: ['ROPA'], sin duplicar)")

        cambiar_tipo(id_prueba, 'ROPA', 'HERRAMIENTA', 'HER-MAN')
        print(f"   3. Cambio a HERRAMIENTA     -> secciones: {secciones(id_prueba)}  (esperado: ['HERRAMIENTA'])")

        cambiar_tipo(id_prueba, 'HERRAMIENTA', 'SERVICIO', 'SER')
        print(f"   4. Cambio a SERVICIO        -> secciones: {secciones(id_prueba)}  (esperado: [])")

        cur.execute("UPDATE TblInventario i JOIN TblCategoriaInventario c ON c.codigo = 'ROP-EPP' "
                    "SET i.tipo_inventario = 'ROPA', i.id_categoria = c.id_categoria "
                    "WHERE i.id_inventario = %s", (id_prueba,))
        res = cur.callproc('sp_sincronizar_secciones_inventario', [0])
        print(f"   5. Sincronizar (red seguridad) -> creadas: {res[0]}, secciones: {secciones(id_prueba)}  (esperado: 1, ['ROPA'])")
    finally:
        conn.rollback()
        cur.execute("SELECT COUNT(*) FROM TblInventario WHERE codigo = 'PRUEBA-SEC'")
        print(f"   ROLLBACK aplicado. Ítems de prueba restantes: {cur.fetchone()[0]} (esperado: 0)")

    print("\n== Los 2 SPs de alta llaman a sp_asegurar_seccion_inventario ==")
    for sp in ('sp_crear_inventario', 'sp_CrearMaterialConCodigoAuto'):
        cur.execute(f"SHOW CREATE PROCEDURE `{sp}`")
        cuerpo = cur.fetchone()[2] or ''
        print(f"   {sp:32} -> {'SÍ' if 'sp_asegurar_seccion_inventario' in cuerpo else 'NO'}")
    cur.close()


def verificar(parte):
    conn = conectar()
    cur = conn.cursor()
    for titulo, sql in VERIFICACIONES.get(parte, []):
        print(f"\n== {titulo} ==")
        cur.execute(sql)
        filas = cur.fetchall()
        for fila in filas:
            print('  ', fila)
        if not filas:
            print('   (vacío)')
    if parte == '2':
        print("\n== Próximo código que generaría sp_generar_material (no inserta nada) ==")
        for tipo in ('MATERIAL', 'HERRAMIENTA', 'EQUIPO', 'TECNOLOGIA', 'ROPA',
                     'CONSUMIBLE', 'SERVICIO', 'PARTIDA'):
            res = cur.callproc('sp_generar_material', [tipo, ''])
            print(f'   {tipo:12} -> {res[1]}')
    cur.close()
    if parte == '3':
        probar_secciones(conn)
    if parte == '4':
        probar_lectura(conn)
        probar_guardar_item(conn)
    conn.close()


def _resultados(cur):
    filas = []
    for r in cur.stored_results():
        filas.extend(r.fetchall())
    return filas


def probar_lectura(conn):
    cur = conn.cursor()
    print("\n== sp_listar_tipos_inventario(1)  (solo físicos) ==")
    cur.callproc('sp_listar_tipos_inventario', [1])
    for f in _resultados(cur):
        print('  ', f)
    print("\n== sp_listar_tipos_inventario(0)  (todos) ==")
    cur.callproc('sp_listar_tipos_inventario', [0])
    print('   ', [f[0] for f in _resultados(cur)])

    for tipo in ('MATERIAL', 'ROPA', 'TECNOLOGIA', 'SERVICIO'):
        cur.callproc('sp_listar_categorias_tipo', [tipo])
        cats = _resultados(cur)
        print(f"\n== sp_listar_categorias_tipo('{tipo}') -> {len(cats)} categorías ==")
        for f in cats[:6]:
            print('  ', f)
        if len(cats) > 6:
            print(f'   ... {len(cats) - 6} más')

    for cod in ('MAT-AGR', 'TEC-COM', 'ROP-EPP', 'PAR'):
        cur.execute("SELECT id_categoria FROM TblCategoriaInventario WHERE codigo = %s", (cod,))
        idc = cur.fetchone()[0]
        cur.callproc('sp_listar_unidades_categoria', [idc])
        unidades = [f"{f[1]}{'*' if f[5] else ''}({f[6][0]})" for f in _resultados(cur)]
        print(f"\n== sp_listar_unidades_categoria({cod}) -> {', '.join(unidades)}")

    for tipo in ('ROPA', 'HERRAMIENTA', 'SERVICIO'):
        cur.callproc('sp_listar_campos_seccion', [tipo])
        campos = _resultados(cur)
        print(f"\n== sp_listar_campos_seccion('{tipo}') -> {len(campos)} campos ==")
        for f in campos:
            print('  ', f)
    cur.close()


def probar_guardar_item(conn):
    """Crea ítems reales 'PRUEBA P4' con sp_guardar_item (hace COMMIT interno),
    revisa las 3 tablas y los BORRA al final."""
    cur = conn.cursor()
    creados = []

    def ids(cod):
        cur.execute("SELECT id_categoria FROM TblCategoriaInventario WHERE codigo = %s", (cod,))
        return cur.fetchone()[0]

    def uni(cod):
        cur.execute("SELECT id_unidad FROM TblUnidadMedida WHERE codigo = %s", (cod,))
        return cur.fetchone()[0]

    def guardar(nombre, tipo, cat, unidad, ficha, stock=0, smin=0, smax=0, precio=0):
        args = [nombre, 'Ítem de prueba de la Parte 4', tipo, ids(cat), uni(unidad),
                smin, smax, precio, 1, None, ficha, stock, 0, 0, '', 0, '']
        r = cur.callproc('sp_guardar_item', args)
        conn.commit()
        if r[13]:
            creados.append(r[15])
        return r[13], r[14], r[15], r[16]

    print("\n== Prueba de sp_guardar_item (crea ítems 'PRUEBA P4' y los borra al final) ==")
    try:
        ok = guardar('PRUEBA P4 Botas T42', 'ROPA', 'ROP-EPP', 'PARES',
                     '{"talla":"42","color":"Negro","genero":"UNISEX","tipo_proteccion":"Pies","campo_inexistente":"x"}',
                     stock=10, precio=85)
        print(f"   1. Ropa con ficha y stock 10   -> {ok[:2]}")
        if ok[0]:
            cur.execute("SELECT codigo, stock_actual, id_unidad FROM TblInventario WHERE id_inventario = %s", (ok[2],))
            print(f"      TblInventario       : {cur.fetchone()}")
            cur.execute("SELECT talla, color, genero, tipo_proteccion FROM TblInventarioRopa WHERE id_inventario = %s", (ok[2],))
            print(f"      TblInventarioRopa   : {cur.fetchone()}")
            cur.execute("SELECT codigo_movimiento, tipo_movimiento, cantidad, id_almacen_destino, tipo_documento, costo_total "
                        "FROM TblMovimientoInventario WHERE id_inventario = %s", (ok[2],))
            print(f"      Movimiento (kardex) : {cur.fetchall()}")

        ok = guardar('PRUEBA P4 Laptop', 'TECNOLOGIA', 'TEC-COM', 'UND',
                     '{"marca":"Lenovo","ram":"16GB","garantia_meses":"12","peso_kg":"1.6"}')
        print(f"   2. Tecnología sin stock        -> {ok[:2]}")
        if ok[0]:
            cur.execute("SELECT marca, ram, garantia_meses, peso_kg FROM TblInventarioTecnologia WHERE id_inventario = %s", (ok[2],))
            print(f"      TblInventarioTecnologia: {cur.fetchone()}")
            cur.execute("SELECT COUNT(*) FROM TblMovimientoInventario WHERE id_inventario = %s", (ok[2],))
            print(f"      Movimientos: {cur.fetchone()[0]} (esperado 0)")

        ok = guardar('PRUEBA P4 Servicio', 'SERVICIO', 'SER', 'GLB', None)
        print(f"   3. Servicio (sin sección)      -> {ok[:2]}")

        print("   -- Rechazos esperados (no deben crear nada) --")
        print(f"   4. Laptop en KG                -> {guardar('PRUEBA P4 X', 'TECNOLOGIA', 'TEC-COM', 'KG', None)[:2]}")
        print(f"   5. Tipo distinto a categoría   -> {guardar('PRUEBA P4 X', 'ROPA', 'TEC-COM', 'UND', None)[:2]}")
        print(f"   6. Nombre repetido             -> {guardar('Arena gruesa', 'MATERIAL', 'MAT-AGR', 'M3', None)[:2]}")
        print(f"   7. Mínimo mayor que máximo     -> {guardar('PRUEBA P4 X', 'MATERIAL', 'MAT-AGR', 'M3', None, smin=10, smax=5)[:2]}")
        print(f"   8. Género fuera de la lista    -> {guardar('PRUEBA P4 X', 'ROPA', 'ROP-EPP', 'UND', '{\"genero\":\"NIÑO\"}')[:2]}")
        print(f"   9. Número inválido en ficha    -> {guardar('PRUEBA P4 X', 'TECNOLOGIA', 'TEC-COM', 'UND', '{\"peso_kg\":\"abc\"}')[:2]}")
        cur.execute("SELECT COUNT(*) FROM TblInventario WHERE nombre = 'PRUEBA P4 X'")
        print(f"      Ítems 'PRUEBA P4 X' creados por los rechazos: {cur.fetchone()[0]} (esperado 0)")
    finally:
        for id_inv in creados:
            cur.execute("DELETE FROM TblMovimientoInventario WHERE id_inventario = %s", (id_inv,))
            for _, tabla in SECCIONES:
                cur.execute(f"DELETE FROM {tabla} WHERE id_inventario = %s", (id_inv,))
            cur.execute("DELETE FROM TblInventario WHERE id_inventario = %s", (id_inv,))
        conn.commit()
        cur.execute("SELECT COUNT(*) FROM TblInventario WHERE nombre LIKE 'PRUEBA P4%'")
        print(f"   Limpieza: {len(creados)} ítems de prueba borrados. Restantes: {cur.fetchone()[0]} (esperado 0)")
        cur.close()


if __name__ == '__main__':
    accion = sys.argv[1] if len(sys.argv) > 1 else ''
    parte = sys.argv[2] if len(sys.argv) > 2 else ''

    if accion == 'respaldo':
        respaldar()
    elif accion == 'exportar_sps':
        exportar_sps()
    elif accion == 'aplicar' and parte in PARTES:
        ejecutar_archivos(PARTES[parte]['aplicar'])
        verificar(parte)
    elif accion == 'verificar' and parte in PARTES:
        verificar(parte)
    elif accion == 'revertir' and parte in PARTES:
        ejecutar_archivos(PARTES[parte]['revertir'])
    else:
        print(__doc__)
