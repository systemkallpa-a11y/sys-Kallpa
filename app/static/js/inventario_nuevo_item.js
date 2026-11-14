// ============================================================================
// MODAL: NUEVO MATERIAL (Item de Inventario) + utilidades compartidas
// ============================================================================
// Lógica del componente components/modal_nuevo_item_inventario.html.
// Se usa en Inventario (alta y edición) y en el Dashboard (Requerimiento).
//
// NADA está escrito a mano: tipos, categorías, unidades y campos técnicos se
// leen de la BD a través de:
//   GET /api/inventario/tipos                   -> tipos (categorías de nivel 1)
//   GET /api/inventario/categorias?tipo=X       -> categorías agrupadas por padre
//   GET /api/inventario/unidades?id_categoria=N -> unidades permitidas (+ predeterminada)
//   GET /api/inventario/campos?tipo=X           -> campos de la sección del tipo
// El alta es POST /api/inventario/crear (sp_guardar_item): guarda el ítem, su
// sección y el stock inicial en una sola transacción.
// ============================================================================

let pasoActual = 1;
const totalPasos = 3;

// ----------------------------------------------------------------------------
// Utilidades compartidas (también las usa templates/inventario.html)
// ----------------------------------------------------------------------------

// Escapa texto libre antes de insertarlo en HTML/atributos
function escProv(v) {
    return String(v === null || v === undefined ? '' : v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

const _cacheInventario = { tipos: {}, campos: {} };

async function _getJson(url) {
    const response = await fetch(url, { headers: { 'X-Requested-With': 'XMLHttpRequest' } });
    const data = await response.json();
    if (!data.success) {
        throw new Error(data.message || data.error || 'Error al consultar ' + url);
    }
    return data;
}

// Tipos de inventario (por defecto solo los físicos: sin Servicio ni Partida)
async function obtenerTiposInventario(soloFisicos = true) {
    const clave = soloFisicos ? '1' : '0';
    if (!_cacheInventario.tipos[clave]) {
        const data = await _getJson(`/api/inventario/tipos?solo_fisicos=${clave}`);
        _cacheInventario.tipos[clave] = data.tipos || [];
    }
    return _cacheInventario.tipos[clave];
}

// Campos técnicos de la sección de un tipo (estructura real de la BD)
async function obtenerCamposSeccion(tipo) {
    if (!tipo) return [];
    if (!_cacheInventario.campos[tipo]) {
        const data = await _getJson(`/api/inventario/campos?tipo=${encodeURIComponent(tipo)}`);
        _cacheInventario.campos[tipo] = data.campos || [];
    }
    return _cacheInventario.campos[tipo];
}

// Llena un <select> con los tipos de inventario
async function cargarTiposEnSelect(select, valorActual = '', soloFisicos = true) {
    select.innerHTML = '<option value="">Cargando...</option>';
    try {
        const tipos = await obtenerTiposInventario(soloFisicos);
        select.innerHTML = '<option value="">Seleccione un tipo...</option>';
        tipos.forEach(t => select.add(new Option(t.nombre, t.tipo_inventario)));
        // Un ítem existente de un tipo no listado (ej. SERVICIO) se muestra igual
        if (valorActual && !tipos.some(t => t.tipo_inventario === valorActual)) {
            select.add(new Option(valorActual, valorActual));
        }
        select.value = valorActual || '';
    } catch (error) {
        console.error('Error al cargar tipos:', error);
        select.innerHTML = '<option value="">Error al cargar tipos</option>';
    }
}

// Llena un <select> con las categorías del tipo, agrupadas por categoría padre
async function cargarCategoriasEnSelect(select, tipo, valorActual = '') {
    if (!tipo) {
        select.innerHTML = '<option value="">Primero seleccione un tipo</option>';
        return;
    }
    select.innerHTML = '<option value="">Cargando...</option>';
    try {
        const data = await _getJson(`/api/inventario/categorias?tipo=${encodeURIComponent(tipo)}`);
        select.innerHTML = '<option value="">Seleccione una categoría...</option>';
        const grupos = {};
        (data.categorias || []).forEach(cat => {
            const grupo = cat.grupo || '';
            if (!grupos[grupo]) {
                grupos[grupo] = document.createElement('optgroup');
                grupos[grupo].label = grupo;
                select.appendChild(grupos[grupo]);
            }
            grupos[grupo].appendChild(new Option(cat.nombre, cat.id_categoria));
        });
        if (valorActual) select.value = String(valorActual);
    } catch (error) {
        console.error('Error al cargar categorías:', error);
        select.innerHTML = '<option value="">Error al cargar</option>';
    }
}

// Llena un <select> con las unidades permitidas en la categoría.
// Sin valor actual, preselecciona la unidad predeterminada de la categoría.
async function cargarUnidadesEnSelect(select, idCategoria, valorActual = '') {
    if (!idCategoria) {
        select.innerHTML = '<option value="">Primero seleccione una categoría</option>';
        return;
    }
    select.innerHTML = '<option value="">Cargando...</option>';
    try {
        const data = await _getJson(`/api/inventario/unidades?id_categoria=${encodeURIComponent(idCategoria)}`);
        const unidades = data.unidades || [];
        select.innerHTML = '<option value="">Seleccione...</option>';
        unidades.forEach(u => select.add(new Option(`${u.nombre} (${u.abreviatura})`, u.id_unidad)));

        const permitida = valorActual && unidades.some(u => String(u.id_unidad) === String(valorActual));
        if (permitida) {
            select.value = String(valorActual);
        } else {
            const pred = unidades.find(u => Number(u.predeterminada) === 1);
            select.value = pred ? String(pred.id_unidad) : '';
        }
    } catch (error) {
        console.error('Error al cargar unidades:', error);
        select.innerHTML = '<option value="">Error al cargar</option>';
    }
}

// Dibuja los campos técnicos de la sección dentro de `container`.
// Los controles salen de la estructura real: lista (ENUM), número (entero o
// decimal, mínimo 0) o texto (con su largo máximo).
async function renderCamposEspecificos(container, tipo, valores = {}) {
    if (!tipo) {
        container.innerHTML = `
            <div class="md:col-span-2 text-center py-8 text-gray-500 dark:text-gray-400">
                <i class="fas fa-info-circle text-3xl mb-2"></i>
                <p>Seleccione un tipo de inventario para ver los campos específicos</p>
            </div>`;
        return;
    }

    container.innerHTML = `
        <div class="md:col-span-2 text-center py-8 text-gray-500 dark:text-gray-400">
            <i class="fas fa-spinner fa-spin text-2xl"></i>
        </div>`;

    let campos = [];
    try {
        campos = await obtenerCamposSeccion(tipo);
    } catch (error) {
        console.error('Error al cargar campos:', error);
        container.innerHTML = `<div class="md:col-span-2 text-red-600">No se pudieron cargar los campos técnicos</div>`;
        return;
    }

    if (campos.length === 0) {
        container.innerHTML = `
            <div class="md:col-span-2 text-center py-8 text-gray-500 dark:text-gray-400">
                <i class="fas fa-info-circle text-3xl mb-2"></i>
                <p>Este tipo no tiene especificaciones técnicas</p>
            </div>`;
        return;
    }

    const clases = 'w-full px-4 py-2.5 bg-white dark:bg-slate-700 border-2 border-gray-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent text-gray-900 dark:text-white';

    container.innerHTML = campos.map(campo => {
        const valor = valores[campo.columna] ?? '';
        const nombre = `ficha_${escProv(campo.columna)}`;
        const placeholder = escProv(campo.placeholder || '');
        let control;

        if (campo.control === 'select') {
            control = `
                <select name="${nombre}" class="${clases}">
                    <option value="">Seleccione...</option>
                    ${(campo.opciones || []).map(op =>
                        `<option value="${escProv(op)}" ${String(valor).toUpperCase() === op.toUpperCase() ? 'selected' : ''}>${escProv(op)}</option>`
                    ).join('')}
                </select>`;
        } else if (campo.control === 'numero') {
            const paso = campo.decimales > 0 ? (1 / Math.pow(10, campo.decimales)) : 1;
            control = `<input type="number" step="${paso}" min="${campo.minimo ?? 0}" name="${nombre}"
                       value="${escProv(valor)}" placeholder="${placeholder}" class="${clases}">`;
        } else if (campo.control === 'fecha') {
            control = `<input type="date" name="${nombre}" value="${escProv(valor)}" class="${clases}">`;
        } else {
            const largo = campo.largo_maximo ? `maxlength="${campo.largo_maximo}"` : '';
            control = `<input type="text" ${largo} name="${nombre}"
                       value="${escProv(valor)}" placeholder="${placeholder}" class="${clases}">`;
        }

        return `
            <div>
                <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                    ${escProv(campo.etiqueta)}
                </label>
                ${control}
            </div>`;
    }).join('');
}

// Lee los campos ficha_* de un formulario como objeto {columna: valor}
function leerFichaFormulario(formData) {
    const ficha = {};
    for (const [key, value] of formData.entries()) {
        if (key.startsWith('ficha_')) {
            ficha[key.replace('ficha_', '')] = value;
        }
    }
    return ficha;
}

// ----------------------------------------------------------------------------
// Modal Nuevo Material
// ----------------------------------------------------------------------------

async function abrirModalNuevoItem() {
    document.getElementById('modalNuevoItem').classList.remove('hidden');
    pasoActual = 1;
    mostrarPaso(1);
    document.getElementById('id_categoria').innerHTML = '<option value="">Primero seleccione un tipo</option>';
    document.getElementById('id_unidad').innerHTML = '<option value="">Primero seleccione una categoría</option>';
    await Promise.all([
        cargarTiposEnSelect(document.getElementById('tipo_inventario')),
        cargarAlmacenes()
    ]);
    renderCamposEspecificos(document.getElementById('campos-especificos'), '');
}

function cerrarModalNuevoItem() {
    document.getElementById('modalNuevoItem').classList.add('hidden');
    document.getElementById('formNuevoItem').reset();
    pasoActual = 1;
    mostrarPaso(1);
}

function mostrarPaso(paso) {
    for (let i = 1; i <= totalPasos; i++) {
        document.getElementById(`paso-${i}`).classList.add('hidden');
    }
    document.getElementById(`paso-${paso}`).classList.remove('hidden');
    actualizarIndicadores(paso);
    document.getElementById('btnAnterior').classList.toggle('hidden', paso === 1);
    document.getElementById('btnSiguiente').classList.toggle('hidden', paso === totalPasos);
    document.getElementById('btnGuardar').classList.toggle('hidden', paso !== totalPasos);
}

function actualizarIndicadores(paso) {
    for (let i = 1; i <= totalPasos; i++) {
        const indicator = document.getElementById(`paso-${i}-indicator`);
        const circle = indicator.querySelector('div:first-child');
        const texts = indicator.querySelectorAll('p');

        if (i < paso) {
            circle.className = 'w-10 h-10 rounded-full bg-green-500 text-white flex items-center justify-center font-bold';
            circle.innerHTML = '<i class="fas fa-check"></i>';
            texts[0].className = 'text-sm font-semibold text-gray-900 dark:text-white';
            texts[1].className = 'text-xs text-gray-500 dark:text-gray-400';
        } else if (i === paso) {
            circle.className = 'w-10 h-10 rounded-full bg-orange-500 text-white flex items-center justify-center font-bold';
            circle.textContent = i;
            texts[0].className = 'text-sm font-semibold text-gray-900 dark:text-white';
            texts[1].className = 'text-xs text-gray-500 dark:text-gray-400';
        } else {
            circle.className = 'w-10 h-10 rounded-full bg-gray-300 dark:bg-slate-600 text-gray-600 dark:text-gray-400 flex items-center justify-center font-bold';
            circle.textContent = i;
            texts[0].className = 'text-sm font-semibold text-gray-500 dark:text-gray-400';
            texts[1].className = 'text-xs text-gray-400 dark:text-gray-500';
        }
    }
}

function siguientePaso() {
    if (pasoActual === 1) {
        const tipo = document.getElementById('tipo_inventario').value;
        const nombre = document.getElementById('nombre').value.trim();
        const categoria = document.getElementById('id_categoria').value;
        const unidad = document.getElementById('id_unidad').value;

        if (!tipo || !nombre || !categoria || !unidad) {
            Swal.fire({
                icon: 'warning',
                title: 'Campos incompletos',
                text: 'Por favor complete todos los campos obligatorios del Paso 1'
            });
            return;
        }
    }

    if (pasoActual === 2) {
        const min = parseFloat(document.getElementById('stock_minimo').value || 0);
        const max = parseFloat(document.getElementById('stock_maximo').value || 0);
        if (max > 0 && min > max) {
            Swal.fire({
                icon: 'warning',
                title: 'Stock mínimo y máximo',
                text: 'El stock mínimo no puede ser mayor que el stock máximo'
            });
            return;
        }
    }

    if (pasoActual < totalPasos) {
        pasoActual++;
        mostrarPaso(pasoActual);
    }
}

function anteriorPaso() {
    if (pasoActual > 1) {
        pasoActual--;
        mostrarPaso(pasoActual);
    }
}

// Paso 1: al cambiar el tipo se recargan categorías y campos técnicos
async function cambiarTipoInventario() {
    const tipo = document.getElementById('tipo_inventario').value;
    document.getElementById('id_unidad').innerHTML = '<option value="">Primero seleccione una categoría</option>';
    await Promise.all([
        cargarCategoriasEnSelect(document.getElementById('id_categoria'), tipo),
        renderCamposEspecificos(document.getElementById('campos-especificos'), tipo)
    ]);
}

// Paso 1: al cambiar la categoría solo se ofrecen sus unidades permitidas
async function cambiarCategoriaNuevoItem() {
    const idCategoria = document.getElementById('id_categoria').value;
    await cargarUnidadesEnSelect(document.getElementById('id_unidad'), idCategoria);
}

function guardarItem() {
    const form = document.getElementById('formNuevoItem');
    const formData = new FormData(form);
    const data = {
        nombre: (formData.get('nombre') || '').trim(),
        descripcion: formData.get('descripcion'),
        id_categoria: formData.get('id_categoria'),
        tipo_inventario: formData.get('tipo_inventario'),
        id_unidad: formData.get('id_unidad'),
        stock_inicial: formData.get('stock_inicial'),
        stock_minimo: formData.get('stock_minimo'),
        stock_maximo: formData.get('stock_maximo'),
        precio_compra: formData.get('precio_compra'),
        id_almacen: formData.get('id_almacen'),
        ubicacion_fisica: formData.get('ubicacion_fisica'),
        ficha: leerFichaFormulario(formData)
    };

    if (!data.nombre || !data.tipo_inventario || !data.id_categoria || !data.id_unidad) {
        Swal.fire({
            icon: 'warning',
            title: 'Campos incompletos',
            text: 'Por favor complete todos los campos obligatorios'
        });
        return;
    }

    const btnGuardar = document.getElementById('btnGuardar');
    btnGuardar.disabled = true;

    // Etiqueta de unidad seleccionada (para el listado del llamador)
    const selectUnidad = document.getElementById('id_unidad');
    const unidadLabel = selectUnidad.selectedIndex >= 0
        ? selectUnidad.options[selectUnidad.selectedIndex].text
        : 'UND';

    fetch('/api/inventario/crear', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
        body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            Swal.fire({
                icon: 'success',
                title: '¡Éxito!',
                text: result.message || 'Item creado correctamente',
                timer: 2500
            });
            cerrarModalNuevoItem();

            const itemCreado = {
                id_inventario: result.id_inventario,
                codigo: result.codigo || '',
                nombre: data.nombre,
                tipo_inventario: data.tipo_inventario,
                id_unidad: parseInt(data.id_unidad, 10),
                unidad: unidadLabel,
                stock_actual: parseFloat(result.stock_actual || 0)
            };

            // Hook: el llamador decide qué hacer con el material creado.
            // En Inventario se refresca la tabla; en el Dashboard se agrega
            // a la lista de "Materiales Requeridos".
            if (typeof window.onItemInventarioCreado === 'function') {
                window.onItemInventarioCreado(itemCreado);
            } else if (typeof cargarInventario === 'function') {
                cargarInventario();
            }
        } else {
            // Mensaje claro del servidor (unidad no permitida, nombre repetido,
            // valor técnico inválido, etc.). El modal queda abierto para corregir.
            Swal.fire({
                icon: 'error',
                title: 'No se guardó el ítem',
                text: result.message || result.error || 'No se pudo crear el item'
            });
        }
    })
    .catch(error => {
        console.error('Error al crear item:', error);
        Swal.fire({
            icon: 'error',
            title: 'Error',
            text: 'Error de conexión al crear el item'
        });
    })
    .finally(() => {
        btnGuardar.disabled = false;
    });
}

// ----------------------------------------------------------------------------
// Combos: almacenes (no dependen del tipo)
// ----------------------------------------------------------------------------

async function cargarAlmacenes() {
    try {
        const data = await _getJson('/api/inventario/almacenes');
        const select = document.getElementById('id_almacen');
        select.innerHTML = '<option value="">Seleccione...</option>';
        (data.almacenes || []).forEach(almacen => {
            select.add(new Option(`${almacen.nombre} (${almacen.codigo})`, almacen.id_almacen));
        });
    } catch (error) {
        console.error('Error al cargar almacenes:', error);
    }
}
