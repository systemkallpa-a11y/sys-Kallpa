// ============================================================================
// MODAL: NUEVO MATERIAL (Item de Inventario)
// ============================================================================
// Lógica única del componente components/modal_nuevo_item_inventario.html
// Se usa en el módulo Inventario y en el Dashboard (Requerimiento de Oficina).
// El endpoint es /api/inventario/crear (sp_crear_inventario): genera el código
// automáticamente y deja stocks/precio en 0 si no se envían.
// ============================================================================

let pasoActual = 1;
const totalPasos = 3;

function abrirModalNuevoItem() {
    document.getElementById('modalNuevoItem').classList.remove('hidden');
    cargarUnidadesMedida();
    cargarAlmacenes();
    pasoActual = 1;
    mostrarPaso(1);
}

function cerrarModalNuevoItem() {
    document.getElementById('modalNuevoItem').classList.add('hidden');
    document.getElementById('formNuevoItem').reset();
    pasoActual = 1;
    mostrarPaso(1);
}

function mostrarPaso(paso) {
    // Ocultar todos los pasos
    for (let i = 1; i <= totalPasos; i++) {
        document.getElementById(`paso-${i}`).classList.add('hidden');
    }

    // Mostrar paso actual
    document.getElementById(`paso-${paso}`).classList.remove('hidden');

    // Actualizar indicadores
    actualizarIndicadores(paso);

    // Actualizar botones
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
            // Paso completado
            circle.className = 'w-10 h-10 rounded-full bg-green-500 text-white flex items-center justify-center font-bold';
            circle.innerHTML = '<i class="fas fa-check"></i>';
            texts[0].className = 'text-sm font-semibold text-gray-900 dark:text-white';
            texts[1].className = 'text-xs text-gray-500 dark:text-gray-400';
        } else if (i === paso) {
            // Paso actual
            circle.className = 'w-10 h-10 rounded-full bg-orange-500 text-white flex items-center justify-center font-bold';
            circle.textContent = i;
            texts[0].className = 'text-sm font-semibold text-gray-900 dark:text-white';
            texts[1].className = 'text-xs text-gray-500 dark:text-gray-400';
        } else {
            // Paso pendiente
            circle.className = 'w-10 h-10 rounded-full bg-gray-300 dark:bg-slate-600 text-gray-600 dark:text-gray-400 flex items-center justify-center font-bold';
            circle.textContent = i;
            texts[0].className = 'text-sm font-semibold text-gray-500 dark:text-gray-400';
            texts[1].className = 'text-xs text-gray-400 dark:text-gray-500';
        }
    }
}

function siguientePaso() {
    // Validar campos del paso actual antes de avanzar
    if (pasoActual === 1) {
        const tipo = document.getElementById('tipo_inventario').value;
        const nombre = document.getElementById('nombre').value;
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

function guardarItem() {
    // Validar todo el formulario
    const formData = new FormData(document.getElementById('formNuevoItem'));
    const data = {
        nombre: formData.get('nombre'),
        descripcion: formData.get('descripcion'),
        id_categoria: formData.get('id_categoria'),
        tipo_inventario: formData.get('tipo_inventario'),
        id_unidad: formData.get('id_unidad'),
        stock_minimo: formData.get('stock_minimo'),
        stock_maximo: formData.get('stock_maximo'),
        precio_compra: formData.get('precio_compra'),
        id_almacen: formData.get('id_almacen'),
        ubicacion_fisica: formData.get('ubicacion_fisica'),
        ficha: {},
        atributos: {}
    };

    // Validar campos requeridos (el código se genera automáticamente en el SP)
    if (!data.nombre || !data.tipo_inventario || !data.id_categoria || !data.id_unidad) {
        Swal.fire({
            icon: 'warning',
            title: 'Campos incompletos',
            text: 'Por favor complete todos los campos obligatorios'
        });
        return;
    }

    // Recopilar la ficha técnica del tipo (campos ficha_*) y los atributos legados (attr_*)
    for (let [key, value] of formData.entries()) {
        if (key.startsWith('ficha_')) {
            data.ficha[key.replace('ficha_', '')] = value;
        } else if (key.startsWith('attr_') && value) {
            data.atributos[key.replace('attr_', '')] = value;
        }
    }

    // Etiqueta de unidad seleccionada (para el listado del llamador)
    const selectUnidad = document.getElementById('id_unidad');
    const unidadLabel = selectUnidad.selectedIndex >= 0
        ? selectUnidad.options[selectUnidad.selectedIndex].text
        : 'UND';

    // Enviar petición
    fetch('/api/inventario/crear', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    })
    .then(response => response.json())
    .then(result => {
        if (result.success) {
            Swal.fire({
                icon: 'success',
                title: '¡Éxito!',
                text: 'Item creado correctamente',
                timer: 2000
            });
            cerrarModalNuevoItem();

            const itemCreado = {
                id_inventario: result.id_inventario,
                codigo: result.codigo || '',
                nombre: data.nombre,
                tipo_inventario: data.tipo_inventario,
                id_unidad: parseInt(data.id_unidad, 10),
                unidad: unidadLabel
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
            Swal.fire({
                icon: 'error',
                title: 'Error',
                text: result.message || 'No se pudo crear el item'
            });
        }
    })
    .catch(error => {
        console.error('Error al crear item:', error);
        Swal.fire({
            icon: 'error',
            title: 'Error',
            text: 'Error al crear el item'
        });
    });
}

// ============================================================================
// TIPO DE INVENTARIO, CATEGORÍAS Y FICHA TÉCNICA
// ============================================================================

async function cambiarTipoInventario() {
    const tipo = document.getElementById('tipo_inventario').value;
    const selectCategoria = document.getElementById('id_categoria');
    const camposEspecificos = document.getElementById('campos-especificos');

    // Limpiar categorías
    selectCategoria.innerHTML = '<option value="">Cargando...</option>';

    if (!tipo) {
        selectCategoria.innerHTML = '<option value="">Primero seleccione un tipo</option>';
        camposEspecificos.innerHTML = `
            <div class="md:col-span-2 text-center py-8 text-gray-500 dark:text-gray-400">
                <i class="fas fa-info-circle text-3xl mb-2"></i>
                <p>Seleccione un tipo de inventario en el Paso 1 para ver los campos específicos</p>
            </div>
        `;
        return;
    }

    // Cargar categorías por tipo
    try {
        const response = await fetch(`/api/inventario/categorias?tipo=${tipo}`);
        const data = await response.json();

        if (data.success && data.categorias) {
            selectCategoria.innerHTML = '<option value="">Seleccione una categoría...</option>';
            data.categorias.forEach(cat => {
                const option = document.createElement('option');
                option.value = cat.id_categoria;
                option.textContent = cat.nombre;
                selectCategoria.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error al cargar categorías:', error);
        selectCategoria.innerHTML = '<option value="">Error al cargar</option>';
    }

    // Generar campos específicos
    camposEspecificos.innerHTML = generarCamposEspecificos(tipo);
}

// Campos de la ficha técnica por tipo. Deben coincidir con app/routes/inventario.py (FICHAS).
const FICHA_CAMPOS = {
    ROPA: [
        { nombre: 'talla', label: 'Talla', type: 'text', placeholder: 'Ej: M, L, XL' },
        { nombre: 'color', label: 'Color', type: 'text', placeholder: 'Color de la prenda' },
        { nombre: 'genero', label: 'Género', type: 'select', opciones: ['HOMBRE', 'MUJER', 'UNISEX', 'OTRO'] },
        { nombre: 'material_tela', label: 'Material / Tela', type: 'text', placeholder: 'Ej: Algodón 100%' },
        { nombre: 'norma_certificacion', label: 'Norma (EPP)', type: 'text', placeholder: 'Ej: ANSI Z89.1' },
        { nombre: 'tipo_proteccion', label: 'Tipo de Protección', type: 'text', placeholder: 'Ej: Cabeza, Manos' }
    ],
    MATERIAL: [
        { nombre: 'presentacion', label: 'Presentación', type: 'text', placeholder: 'Ej: Bolsa 42.5 kg' },
        { nombre: 'marca', label: 'Marca', type: 'text' },
        { nombre: 'tipo', label: 'Tipo', type: 'text' },
        { nombre: 'norma', label: 'Norma', type: 'text', placeholder: 'Ej: NTP 334.009' },
        { nombre: 'medida', label: 'Medida', type: 'text', placeholder: 'Ej: 1/2", 42.5 kg' },
        { nombre: 'color', label: 'Color', type: 'text' },
        { nombre: 'resistencia', label: 'Resistencia', type: 'text', placeholder: 'Ej: 4200 PSI' },
        { nombre: 'lote', label: 'Lote', type: 'text' },
        { nombre: 'peso_unitario_kg', label: 'Peso por unidad (kg)', type: 'number' },
        { nombre: 'largo_cm', label: 'Largo (cm)', type: 'number' },
        { nombre: 'ancho_cm', label: 'Ancho (cm)', type: 'number' },
        { nombre: 'alto_cm', label: 'Alto (cm)', type: 'number' }
    ],
    HERRAMIENTA: [
        { nombre: 'marca', label: 'Marca', type: 'text', placeholder: 'Marca de la herramienta' },
        { nombre: 'modelo', label: 'Modelo', type: 'text' },
        { nombre: 'tipo_herramienta', label: 'Tipo de Herramienta', type: 'select', opciones: ['MANUAL', 'ELECTRICA', 'BATERIA', 'NEUMATICA', 'OTRO'] },
        { nombre: 'potencia', label: 'Potencia', type: 'text', placeholder: 'Ej: 850W' },
        { nombre: 'voltaje', label: 'Voltaje', type: 'text', placeholder: 'Ej: 220V' },
        { nombre: 'numero_serie', label: 'Número de Serie', type: 'text' },
        { nombre: 'peso_kg', label: 'Peso (kg)', type: 'number' },
        { nombre: 'largo_cm', label: 'Largo (cm)', type: 'number' },
        { nombre: 'ancho_cm', label: 'Ancho (cm)', type: 'number' },
        { nombre: 'alto_cm', label: 'Alto (cm)', type: 'number' }
    ],
    EQUIPO: [
        { nombre: 'marca', label: 'Marca', type: 'text' },
        { nombre: 'modelo', label: 'Modelo', type: 'text' },
        { nombre: 'capacidad', label: 'Capacidad', type: 'text', placeholder: 'Ej: 9 m3' },
        { nombre: 'potencia', label: 'Potencia', type: 'text', placeholder: 'Ej: 5 HP' },
        { nombre: 'numero_serie', label: 'Número de Serie', type: 'text' },
        { nombre: 'anio_fabricacion', label: 'Año de Fabricación', type: 'number' },
        { nombre: 'placa', label: 'Placa', type: 'text' },
        { nombre: 'peso_kg', label: 'Peso (kg)', type: 'number' },
        { nombre: 'largo_cm', label: 'Largo (cm)', type: 'number' },
        { nombre: 'ancho_cm', label: 'Ancho (cm)', type: 'number' },
        { nombre: 'alto_cm', label: 'Alto (cm)', type: 'number' }
    ],
    TECNOLOGIA: [
        { nombre: 'marca', label: 'Marca', type: 'text' },
        { nombre: 'modelo', label: 'Modelo', type: 'text' },
        { nombre: 'procesador', label: 'Procesador', type: 'text', placeholder: 'Ej: Intel Core i7 11va Gen' },
        { nombre: 'ram', label: 'Memoria RAM', type: 'text', placeholder: 'Ej: 16GB DDR4' },
        { nombre: 'almacenamiento', label: 'Almacenamiento', type: 'text', placeholder: 'Ej: 512GB SSD' },
        { nombre: 'pantalla', label: 'Pantalla', type: 'text', placeholder: 'Ej: 15.6" Full HD' },
        { nombre: 'sistema_operativo', label: 'Sistema Operativo', type: 'text', placeholder: 'Ej: Windows 11 Pro' },
        { nombre: 'numero_serie', label: 'Número de Serie', type: 'text' },
        { nombre: 'garantia_meses', label: 'Garantía (meses)', type: 'number' },
        { nombre: 'peso_kg', label: 'Peso (kg)', type: 'number' },
        { nombre: 'largo_cm', label: 'Largo (cm)', type: 'number' },
        { nombre: 'ancho_cm', label: 'Ancho (cm)', type: 'number' },
        { nombre: 'alto_cm', label: 'Alto (cm)', type: 'number' }
    ],
    CONSUMIBLE: [
        { nombre: 'marca', label: 'Marca', type: 'text' },
        { nombre: 'presentacion', label: 'Presentación', type: 'text', placeholder: 'Ej: Caja x 10' },
        { nombre: 'tamano', label: 'Tamaño', type: 'text', placeholder: 'Ej: A4, Carta' },
        { nombre: 'gramaje', label: 'Gramaje', type: 'number', placeholder: 'Ej: 75' },
        { nombre: 'color', label: 'Color', type: 'text' },
        { nombre: 'unidades_paquete', label: 'Unidades por Paquete', type: 'number' },
        { nombre: 'blancura_pct', label: 'Blancura %', type: 'number' }
    ]
};

function generarCamposEspecificos(tipo, valores = {}) {
    const campos = FICHA_CAMPOS[tipo] || [];

    if (campos.length === 0) {
        return `
            <div class="md:col-span-2 text-center py-8 text-gray-500 dark:text-gray-400">
                <i class="fas fa-info-circle text-3xl mb-2"></i>
                <p>No hay campos específicos para este tipo de inventario</p>
            </div>
        `;
    }

    const clases = 'w-full px-4 py-2.5 bg-white dark:bg-slate-700 border-2 border-gray-300 dark:border-slate-600 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent text-gray-900 dark:text-white';

    return campos.map(campo => {
        const valor = valores[campo.nombre] ?? '';
        let control;

        if (campo.type === 'select') {
            control = `
                <select name="ficha_${campo.nombre}" class="${clases}">
                    <option value="">Seleccione...</option>
                    ${campo.opciones.map(op => `<option value="${op}" ${String(valor) === op ? 'selected' : ''}>${op}</option>`).join('')}
                </select>`;
        } else if (campo.type === 'number') {
            const enteros = ['anio_fabricacion', 'garantia_meses', 'unidades_paquete'];
            const paso = enteros.includes(campo.nombre) ? '1' : '0.01';
            control = `<input type="number" step="${paso}" min="0" name="ficha_${campo.nombre}"
                       value="${escProv(valor)}" placeholder="${campo.placeholder || ''}" class="${clases}">`;
        } else {
            control = `<input type="text" name="ficha_${campo.nombre}"
                       value="${escProv(valor)}" placeholder="${campo.placeholder || ''}" class="${clases}">`;
        }

        return `
            <div>
                <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                    ${campo.label}
                </label>
                ${control}
            </div>`;
    }).join('');
}

// ============================================================================
// COMBOS: UNIDADES DE MEDIDA Y ALMACENES
// ============================================================================

async function cargarUnidadesMedida() {
    try {
        const response = await fetch('/api/inventario/unidades');
        const data = await response.json();

        if (data.success && data.unidades) {
            const select = document.getElementById('id_unidad');
            select.innerHTML = '<option value="">Seleccione...</option>';
            data.unidades.forEach(unidad => {
                const option = document.createElement('option');
                option.value = unidad.id_unidad;
                option.textContent = `${unidad.nombre} (${unidad.abreviatura})`;
                select.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error al cargar unidades:', error);
    }
}

async function cargarAlmacenes() {
    try {
        const response = await fetch('/api/inventario/almacenes');
        const data = await response.json();

        if (data.success && data.almacenes) {
            const select = document.getElementById('id_almacen');
            select.innerHTML = '<option value="">Seleccione...</option>';
            data.almacenes.forEach(almacen => {
                const option = document.createElement('option');
                option.value = almacen.id_almacen;
                option.textContent = `${almacen.nombre} (${almacen.codigo})`;
                select.appendChild(option);
            });
        }
    } catch (error) {
        console.error('Error al cargar almacenes:', error);
    }
}

// Escapa texto libre antes de insertarlo en HTML/atributos
function escProv(v) {
    return String(v === null || v === undefined ? '' : v)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
