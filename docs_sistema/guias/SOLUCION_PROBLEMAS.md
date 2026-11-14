# Solución de problemas

**Actualizado:** 13/11/2026. Reúne los problemas ya resueltos que pueden
volver a aparecer.

---

## 1. Error 500 en todas las páginas: no conecta a la BD

**Síntoma:** el login falla o todas las APIs devuelven 500. En el log:
`Conexión directa a kallpasystem.mysql... (túnel no disponible)` o
`AttributeError: module 'paramiko' has no attribute 'DSSKey'`.

PythonAnywhere **no acepta conexiones MySQL externas**: en local la única vía
es el túnel SSH. Revisar en orden:

1. `.env` tiene `USE_SSH_TUNNEL=True` y las variables `SSH_*` correctas.
2. **Versión de paramiko:** `sshtunnel 0.4.0` usa `paramiko.DSSKey`, que no
   existe desde paramiko 4.0. Debe ser `paramiko==3.4.0`
   (`pip install paramiko==3.4.0`).
3. `app/config.py` lee `USE_SSH_TUNNEL` en tiempo de ejecución con
   `get_use_ssh_tunnel()` (classmethod). No convertirlo en atributo de clase:
   se evaluaría antes de `load_dotenv()` y quedaría siempre en `False`.
4. La cuenta SSH de PythonAnywhere no está bloqueada.

El túnel es un singleton: se crea una vez y se reutiliza entre requests.
En el servidor de producción no hace falta túnel (`USE_SSH_TUNNEL=False`).

## 2. `SyntaxError: Unexpected token '<' ... is not valid JSON`

**Causa:** una API devolvió HTML (página de error o login) en vez de JSON.

`app/__init__.py` ya lo evita: un `before_request` devuelve JSON 401 a las
llamadas `/api/*` sin sesión, y los `errorhandler` 404/405/500 responden JSON
en `/api/*`. **Regla:** todo endpoint `/api/*` responde JSON, también en error.

Si vuelve a pasar: ver la respuesta en F12 › Red, y revisar que la sesión siga
activa.

## 3. Los cambios no se ven después de reiniciar

**Causa:** quedó un proceso Python viejo ocupando el puerto 5000 (sin
`DEBUG`, Flask no recarga solo).

```powershell
Get-Process python* | Stop-Process -Force
Get-NetTCPConnection -LocalPort 5000     # debe estar libre
```

Si el cambio es de JS/CSS y no se ve: subir `ASSETS_VERSION` en
`app/__init__.py` (caché del navegador).

## 4. `Use multi=True when executing multiple statements` / `Unread result found`

**Causa:** un SP que devuelve varios result sets (por ejemplo
`sp_ReportePresupuestos`) se ejecutó sin leerlos todos, y el cursor quedó
inválido.

```python
cursor.callproc('sp_ReportePresupuestos')
for result in cursor.stored_results():
    filas = result.fetchall()
```

Si se necesita una consulta de respaldo después de un error, crear un cursor
nuevo.

## 5. Error de collation (1267 / 1270) en scripts SQL

Algunas tablas tienen collations distintas. No mezclar columnas de
`TblInventario` con tablas auxiliares en `COALESCE`, `IN` o `JOIN` sin
`COLLATE` explícito.

## 6. "No se puede crear trigger" en PythonAnywhere

PythonAnywhere no permite triggers (requieren `SUPER` con binlog activo). Las
reglas se implementan en SP (por ejemplo `sp_asegurar_seccion_inventario`).

## 7. Un endpoint devuelve 500 por un SP inexistente

Varios endpoints llaman a SP que no están en la BD (lista en
`CONTEXTO_SISTEMA.md`, sección 8). Para comprobar uno:

```sql
SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name = 'sp_xxx';
```
