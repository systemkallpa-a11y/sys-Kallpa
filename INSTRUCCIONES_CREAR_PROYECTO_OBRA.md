# 📋 INSTRUCCIONES: Agregar Botones Crear Proyecto y Crear Obra

## Fecha: 2026-08-04

---

## 🎯 OBJETIVO

Agregar dos botones en `/presupuesto` junto a "Crear Presupuesto":
- **Crear Proyecto** (azul)
- **Crear Obra** (verde)

Cada botón abrirá un modal para crear registros en `TblProyecto` y `TblObra` usando Stored Procedures.

---

## 📊 BASE DE DATOS

### Archivo SQL: `database_scripts/sp_proyecto_obra.sql`

Se crearon 4 Stored Procedures:

1. **`sp_CrearProyecto(...)`** - Crear nuevo proyecto
2. **`sp_CrearObra(...)`** - Crear nueva obra
3. **`sp_ObtenerProyectos()`** - Listar proyectos
4. **`sp_ObtenerObrasPorProyecto(p_id_proyecto)`** - Listar obras de un proyecto

---

## 🔧 PASO 1: MODIFICAR HTML (presupuesto.html)

### Buscar esta línea (aproximadamente línea 1):

```html
<button id="btn-crear-presupuesto" class="flex items-center gap-2 px-6 py-2 bg-slate-600 hover:bg-slate-700 text-white rounded-lg font-medium transition-colors shadow-md hover:shadow-lg">
```

### Reemplazar por:

```html
<div class="flex gap-2">
    <button id="btn-crear-presupuesto" class="flex items-center gap-2 px-6 py-2 bg-slate-600 hover:bg-slate-700 text-white rounded-lg font-medium transition-colors shadow-md hover:shadow-lg">
        <i class="fas fa-plus"></i>
        <span>Crear Presupuesto</span>
    </button>
    <button id="btn-crear-proyecto" class="flex items-center gap-2 px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors shadow-md hover:shadow-lg">
        <i class="fas fa-project-diagram"></i>
        <span>Crear Proyecto</span>
    </button>
    <button id="btn-crear-obra" class="flex items-center gap-2 px-6 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-medium transition-colors shadow-md hover:shadow-lg">
        <i class="fas fa-hard-hat"></i>
        <span>Crear Obra</span>
    </button>
</div>
```

---

## 🎨 PASO 2: AGREGAR MODAL DE CREAR PROYECTO

### Al final de `presupuesto.html`, antes del `</div>` final, agregar:

```html
<!-- ========================================================================== -->
<!-- MODAL: CREAR PROYECTO -->
<!-- ========================================================================== -->
<div id="modal-crear-proyecto" class="hidden fixed inset-0 bg-black/50 z-[60] flex items-center justify-center p-4">
    <div class="bg-white dark:bg-slate-900 rounded-xl shadow-2xl w-full max-w-2xl">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-4 flex items-center justify-between rounded-t-xl">
            <div>
                <h2 class="text-xl font-bold">Crear Nuevo Proyecto</h2>
                <p class="text-blue-100 text-sm">Ingresa los datos del proyecto</p>
            </div>
            <button onclick="cerrarModalProyecto()" class="text-white hover:text-gray-200 p-2">
                <i class="fas fa-times text-xl"></i>
            </button>
        </div>
        
        <!-- Formulario -->
        <form id="form-crear-proyecto" class="p-6 space-y-4">
            <!-- Nombre del Proyecto -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Nombre del Proyecto <span class="text-red-500">*</span>
                </label>
                <input type="text" id="proyecto-nombre" required
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500" 
                    placeholder="Ej: Construcción Edificio Residencial">
            </div>
            
            <!-- Descripción -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Descripción
                </label>
                <textarea id="proyecto-descripcion" rows="3"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 resize-none" 
                    placeholder="Descripción detallada del proyecto..."></textarea>
            </div>
            
            <!-- Fechas -->
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Fecha de Inicio
                    </label>
                    <input type="date" id="proyecto-fecha-inicio"
                        class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Fecha de Fin Estimada
                    </label>
                    <input type="date" id="proyecto-fecha-fin"
                        class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500">
                </div>
            </div>
            
            <!-- Estado -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Estado
                </label>
                <select id="proyecto-estado"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500">
                    <option value="ACTIVO">Activo</option>
                    <option value="EN_PROGRESO">En Progreso</option>
                    <option value="PAUSADO">Pausado</option>
                    <option value="FINALIZADO">Finalizado</option>
                </select>
            </div>
            
            <!-- Botones -->
            <div class="flex gap-3 pt-4">
                <button type="button" onclick="cerrarModalProyecto()"
                    class="flex-1 px-4 py-2 bg-gray-300 dark:bg-slate-700 hover:bg-gray-400 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-200 rounded-lg font-semibold transition-colors">
                    Cancelar
                </button>
                <button type="submit"
                    class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors">
                    <i class="fas fa-save mr-2"></i>Guardar Proyecto
                </button>
            </div>
        </form>
    </div>
</div>

<!-- ========================================================================== -->
<!-- MODAL: CREAR OBRA -->
<!-- ========================================================================== -->
<div id="modal-crear-obra" class="hidden fixed inset-0 bg-black/50 z-[60] flex items-center justify-center p-4">
    <div class="bg-white dark:bg-slate-900 rounded-xl shadow-2xl w-full max-w-2xl">
        <!-- Header -->
        <div class="bg-gradient-to-r from-emerald-600 to-green-700 text-white px-6 py-4 flex items-center justify-between rounded-t-xl">
            <div>
                <h2 class="text-xl font-bold">Crear Nueva Obra</h2>
                <p class="text-emerald-100 text-sm">Ingresa los datos de la obra</p>
            </div>
            <button onclick="cerrarModalObra()" class="text-white hover:text-gray-200 p-2">
                <i class="fas fa-times text-xl"></i>
            </button>
        </div>
        
        <!-- Formulario -->
        <form id="form-crear-obra" class="p-6 space-y-4">
            <!-- Proyecto -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Proyecto <span class="text-red-500">*</span>
                </label>
                <select id="obra-id-proyecto" required
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500">
                    <option value="">Seleccionar proyecto...</option>
                </select>
            </div>
            
            <!-- Nombre de la Obra -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Nombre de la Obra <span class="text-red-500">*</span>
                </label>
                <input type="text" id="obra-nombre" required
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500" 
                    placeholder="Ej: Torre A - Departamentos">
            </div>
            
            <!-- Código de Obra -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Código de Obra
                </label>
                <input type="text" id="obra-codigo"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500" 
                    placeholder="Ej: OB-2026-001">
            </div>
            
            <!-- Descripción -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Descripción
                </label>
                <textarea id="obra-descripcion" rows="3"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500 resize-none" 
                    placeholder="Descripción detallada de la obra..."></textarea>
            </div>
            
            <!-- Dirección -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Dirección
                </label>
                <input type="text" id="obra-direccion"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500" 
                    placeholder="Dirección de la obra">
            </div>
            
            <!-- Fechas -->
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Fecha de Inicio
                    </label>
                    <input type="date" id="obra-fecha-inicio"
                        class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500">
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Fecha de Fin Estimada
                    </label>
                    <input type="date" id="obra-fecha-fin"
                        class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500">
                </div>
            </div>
            
            <!-- Estado -->
            <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Estado
                </label>
                <select id="obra-estado"
                    class="w-full px-4 py-2 border border-gray-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-emerald-500">
                    <option value="ACTIVO">Activo</option>
                    <option value="EN_PROGRESO">En Progreso</option>
                    <option value="PAUSADO">Pausado</option>
                    <option value="FINALIZADO">Finalizado</option>
                </select>
            </div>
            
            <!-- Botones -->
            <div class="flex gap-3 pt-4">
                <button type="button" onclick="cerrarModalObra()"
                    class="flex-1 px-4 py-2 bg-gray-300 dark:bg-slate-700 hover:bg-gray-400 dark:hover:bg-slate-600 text-gray-700 dark:text-gray-200 rounded-lg font-semibold transition-colors">
                    Cancelar
                </button>
                <button type="submit"
                    class="flex-1 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-semibold transition-colors">
                    <i class="fas fa-save mr-2"></i>Guardar Obra
                </button>
            </div>
        </form>
    </div>
</div>
```

---

## 📜 PASO 3: AGREGAR JAVASCRIPT

### Al final de `presupuesto.js` o en el `<script>` del HTML, agregar:

```javascript
// ============================================================================
// MODAL: CREAR PROYECTO
// ============================================================================

document.getElementById('btn-crear-proyecto')?.addEventListener('click', function() {
    document.getElementById('modal-crear-proyecto').classList.remove('hidden');
});

function cerrarModalProyecto() {
    document.getElementById('modal-crear-proyecto').classList.add('hidden');
    document.getElementById('form-crear-proyecto').reset();
}

document.getElementById('form-crear-proyecto')?.addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const datos = {
        nombre: document.getElementById('proyecto-nombre').value.trim(),
        descripcion: document.getElementById('proyecto-descripcion').value.trim(),
        fecha_inicio: document.getElementById('proyecto-fecha-inicio').value || null,
        fecha_fin_estimada: document.getElementById('proyecto-fecha-fin').value || null,
        estado: document.getElementById('proyecto-estado').value
    };
    
    try {
        const response = await fetch('/api/proyectos/crear', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify(datos)
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('✅ ' + data.message);
            cerrarModalProyecto();
            // Recargar select de proyectos en el modal de presupuesto
            await cargarProyectos();
        } else {
            alert('❌ Error: ' + data.error);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('❌ Error al crear proyecto');
    }
});

// ============================================================================
// MODAL: CREAR OBRA
// ============================================================================

document.getElementById('btn-crear-obra')?.addEventListener('click', async function() {
    document.getElementById('modal-crear-obra').classList.remove('hidden');
    // Cargar proyectos en el select
    await cargarProyectosParaObra();
});

function cerrarModalObra() {
    document.getElementById('modal-crear-obra').classList.add('hidden');
    document.getElementById('form-crear-obra').reset();
}

async function cargarProyectosParaObra() {
    try {
        const response = await fetch('/api/proyectos/listar', {
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            }
        });
        
        const data = await response.json();
        const select = document.getElementById('obra-id-proyecto');
        select.innerHTML = '<option value="">Seleccionar proyecto...</option>';
        
        if (data.success && data.data) {
            data.data.forEach(proyecto => {
                const option = document.createElement('option');
                option.value = proyecto.id_proyecto;
                option.textContent = proyecto.nombre;
                select.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error:', error);
    }
}

document.getElementById('form-crear-obra')?.addEventListener('submit', async function(e) {
    e.preventDefault();
    
    const datos = {
        id_proyecto: parseInt(document.getElementById('obra-id-proyecto').value),
        nombre: document.getElementById('obra-nombre').value.trim(),
        codigo_obra: document.getElementById('obra-codigo').value.trim(),
        descripcion: document.getElementById('obra-descripcion').value.trim(),
        direccion: document.getElementById('obra-direccion').value.trim(),
        fecha_inicio: document.getElementById('obra-fecha-inicio').value || null,
        fecha_fin_estimada: document.getElementById('obra-fecha-fin').value || null,
        estado: document.getElementById('obra-estado').value
    };
    
    try {
        const response = await fetch('/api/obras/crear', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify(datos)
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('✅ ' + data.message);
            cerrarModalObra();
            // Recargar selects de proyecto/obra en el modal de presupuesto
            await cargarProyectos();
        } else {
            alert('❌ Error: ' + data.error);
        }
    } catch (error) {
        console.error('Error:', error);
        alert('❌ Error al crear obra');
    }
});
```

---

## 🔧 PASO 4: AGREGAR APIS EN BACKEND (presupuesto.py)

### Al final de `app/routes/presupuesto.py`, agregar:

```python
# ============================================================================
# API: CREAR PROYECTO
# ============================================================================
@presupuesto_bp.route('/api/proyectos/crear', methods=['POST'])
@login_required
def crear_proyecto():
    """Crear nuevo proyecto usando SP"""
    try:
        data = request.get_json()
        
        if not data.get('nombre'):
            return jsonify({'success': False, 'error': 'El nombre es obligatorio'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            creado_por = session.get('user_documento')
            
            cursor.execute("""
                CALL sp_CrearProyecto(
                    %s, %s, %s, %s, %s, %s,
                    @p_id_proyecto, @p_mensaje
                )
            """, (
                data['nombre'],
                data.get('descripcion'),
                data.get('fecha_inicio'),
                data.get('fecha_fin_estimada'),
                data.get('estado', 'ACTIVO'),
                creado_por
            ))
            
            cursor.execute("SELECT @p_id_proyecto as id_proyecto, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            if resultado and resultado['id_proyecto'] > 0:
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_proyecto': resultado['id_proyecto']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': resultado['mensaje'] if resultado else 'Error al crear proyecto'
                }), 400
        
        except Error as e:
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# ============================================================================
# API: CREAR OBRA
# ============================================================================
@presupuesto_bp.route('/api/obras/crear', methods=['POST'])
@login_required
def crear_obra():
    """Crear nueva obra usando SP"""
    try:
        data = request.get_json()
        
        if not data.get('id_proyecto') or not data.get('nombre'):
            return jsonify({'success': False, 'error': 'Proyecto y nombre son obligatorios'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'error': 'Error de conexión'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            creado_por = session.get('user_documento')
            
            cursor.execute("""
                CALL sp_CrearObra(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    @p_id_obra, @p_mensaje
                )
            """, (
                data['id_proyecto'],
                data['nombre'],
                data.get('codigo_obra'),
                data.get('descripcion'),
                data.get('direccion'),
                data.get('fecha_inicio'),
                data.get('fecha_fin_estimada'),
                data.get('estado', 'ACTIVO'),
                creado_por
            ))
            
            cursor.execute("SELECT @p_id_obra as id_obra, @p_mensaje as mensaje")
            resultado = cursor.fetchone()
            
            while cursor.nextset():
                pass
            
            cursor.close()
            connection.close()
            
            if resultado and resultado['id_obra'] > 0:
                return jsonify({
                    'success': True,
                    'message': resultado['mensaje'],
                    'id_obra': resultado['id_obra']
                }), 201
            else:
                return jsonify({
                    'success': False,
                    'error': resultado['mensaje'] if resultado else 'Error al crear obra'
                }), 400
        
        except Error as e:
            cursor.close()
            connection.close()
            return jsonify({'success': False, 'error': str(e)}), 500
    
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
```

---

## ✅ RESUMEN

1. ✅ SQL con Stored Procedures creado
2. ✅ HTML de botones y modales documentado
3. ✅ JavaScript de funcionalidad documentado
4. ✅ APIs backend documentadas

## 🚀 IMPLEMENTACIÓN

1. Ejecutar script SQL: `database_scripts/sp_proyecto_obra.sql`
2. Modificar `presupuesto.html` según instrucciones
3. Agregar JavaScript al archivo correspondiente
4. Agregar APIs en `presupuesto.py`
5. Probar funcionalidad

---

**Nota:** El archivo `presupuesto.html` está minificado, por lo que será más fácil implementar estos cambios manualmente siguiendo las instrucciones paso a paso.
