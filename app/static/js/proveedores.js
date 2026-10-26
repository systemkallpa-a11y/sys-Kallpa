/**
 * proveedores.js
 * Gestión de Proveedores
 */

let proveedores = [];
let proveedoresFiltrados = [];
let modoEdicion = false;

// Paginación
let paginaActual = 1;
const registrosPorPagina = 10;

// ============================================================================
// INICIALIZACIÓN
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
    console.log('[PROVEEDORES] Inicializando módulo...');
    
    cargarProveedores();
    configurarEventListeners();
});

/**
 * Configurar Event Listeners
 */
function configurarEventListeners() {
    // Filtros
    document.getElementById('buscar').addEventListener('input', filtrarProveedores);
    document.getElementById('filtro-estado').addEventListener('change', filtrarProveedores);
    
    // Form submit
    document.getElementById('form-proveedor').addEventListener('submit', function(e) {
        e.preventDefault();
        guardarProveedor();
    });
}

// ============================================================================
// CARGAR DATOS
// ============================================================================
/**
 * Cargar todos los proveedores
 */
async function cargarProveedores() {
    try {
        console.log('[PROVEEDORES] Cargando proveedores...');
        
        const response = await fetch('/api/proveedores/obtener');
        const result = await response.json();
        
        if (result.success) {
            proveedores = result.proveedores || [];
            proveedoresFiltrados = [...proveedores];
            paginaActual = 1;
            
            console.log(`[PROVEEDORES] ${proveedores.length} proveedores cargados`);
            
            renderizarTabla();
        } else {
            console.error('[PROVEEDORES] Error:', result.error);
            mostrarNotificacion('Error al cargar proveedores', 'error');
        }
    } catch (error) {
        console.error('[PROVEEDORES] Error al cargar:', error);
        mostrarNotificacion('Error de conexión', 'error');
    }
}

// ============================================================================
// RENDERIZADO
// ============================================================================
/**
 * Renderizar tabla de proveedores
 */
function renderizarTabla() {
    const tbody = document.getElementById('tabla-proveedores');
    const sinProveedores = document.getElementById('sin-proveedores');
    
    // Si no hay proveedores
    if (proveedoresFiltrados.length === 0) {
        tbody.innerHTML = '';
        sinProveedores.classList.remove('hidden');
        renderPaginacion();
        return;
    }
    
    sinProveedores.classList.add('hidden');
    
    // Calcular paginación
    const totalRegistros = proveedoresFiltrados.length;
    const totalPaginas = Math.ceil(totalRegistros / registrosPorPagina);
    if (paginaActual > totalPaginas) paginaActual = totalPaginas;
    if (paginaActual < 1) paginaActual = 1;
    const inicio = (paginaActual - 1) * registrosPorPagina;
    const registrosPagina = proveedoresFiltrados.slice(inicio, inicio + registrosPorPagina);
    
    // Renderizar filas de la página actual
    tbody.innerHTML = registrosPagina.map(prov => {
        const badgeEstado = obtenerBadgeEstado(prov.estado);
        
        return `
            <tr class="hover:bg-gray-50 dark:hover:bg-slate-800 transition-colors">
                <td class="px-6 py-4">
                    <span class="font-mono text-gray-900 dark:text-white">${escapeHtml(prov.ruc)}</span>
                </td>
                <td class="px-6 py-4">
                    <div class="font-semibold text-gray-900 dark:text-white">${escapeHtml(prov.razon_social)}</div>
                </td>
                <td class="px-6 py-4 text-gray-700 dark:text-gray-300">
                    ${escapeHtml(prov.nombre_comercial || '-')}
                </td>
                <td class="px-6 py-4">
                    <div class="text-gray-900 dark:text-white">${escapeHtml(prov.contacto_nombre || '-')}</div>
                    ${prov.contacto_email ? `<div class="text-sm text-gray-500 dark:text-gray-400">${escapeHtml(prov.contacto_email)}</div>` : ''}
                </td>
                <td class="px-6 py-4 text-gray-700 dark:text-gray-300">
                    ${escapeHtml(prov.telefono || '-')}
                </td>
                <td class="px-6 py-4">
                    ${badgeEstado}
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center justify-center gap-2">
                        <button onclick="verDetalles('${escapeHtml(prov.ruc)}')" 
                                class="p-2 text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg transition-colors"
                                title="Ver detalles">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button onclick="editarProveedor('${escapeHtml(prov.ruc)}')" 
                                class="p-2 text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-900/20 rounded-lg transition-colors"
                                title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button onclick="eliminarProveedor('${escapeHtml(prov.ruc)}')" 
                                class="p-2 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                                title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                        <button onclick="abrirFichaMateriales('${escapeHtml(prov.ruc)}', '${escapeHtml(prov.razon_social)}')" 
                                class="p-2 text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-900/20 rounded-lg transition-colors"
                                title="Ficha de materiales">
                            <i class="fas fa-boxes"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
    
    renderPaginacion();
}

// ============================================================================
// PAGINACIÓN
// ============================================================================
/**
 * Renderizar los controles de paginación
 */
function renderPaginacion() {
    const contenedor = document.getElementById('paginacion-controles');
    if (!contenedor) return;
    
    const totalRegistros = proveedoresFiltrados.length;
    if (totalRegistros === 0) {
        contenedor.innerHTML = '';
        return;
    }
    
    const totalPaginas = Math.ceil(totalRegistros / registrosPorPagina);
    if (paginaActual > totalPaginas) paginaActual = totalPaginas;
    const inicio = (paginaActual - 1) * registrosPorPagina + 1;
    const fin = Math.min(paginaActual * registrosPorPagina, totalRegistros);
    
    const btnBase = 'px-2 py-1 rounded text-xs font-medium transition-colors';
    const btnDisabled = `${btnBase} bg-gray-100 dark:bg-slate-700 text-gray-400 dark:text-gray-500 cursor-not-allowed`;
    const btnNormal = `${btnBase} bg-white dark:bg-slate-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-700 border border-gray-300 dark:border-slate-600`;
    const btnActivo = `${btnBase} bg-[#4D148C] text-white`;
    
    // Botón anterior
    let botones = `
        <button onclick="irAPagina(1)" ${paginaActual === 1 ? 'disabled' : ''} class="${paginaActual === 1 ? btnDisabled : btnNormal}" title="Primera página">&laquo;</button>
        <button onclick="irAPagina(${paginaActual - 1})" ${paginaActual === 1 ? 'disabled' : ''} class="${paginaActual === 1 ? btnDisabled : btnNormal}" title="Anterior">&lsaquo;</button>`;
    
    // Páginas alrededor de la actual
    let startPage = Math.max(1, paginaActual - 2);
    let endPage = Math.min(totalPaginas, startPage + 4);
    startPage = Math.max(1, endPage - 4);
    
    if (startPage > 1) botones += `<span class="px-1 py-1 text-xs text-gray-500 dark:text-gray-400">...</span>`;
    for (let i = startPage; i <= endPage; i++) {
        botones += `
        <button onclick="irAPagina(${i})" class="${i === paginaActual ? btnActivo : btnNormal}">${i}</button>`;
    }
    if (endPage < totalPaginas) botones += `<span class="px-1 py-1 text-xs text-gray-500 dark:text-gray-400">...</span>`;
    
    // Botón siguiente
    botones += `
        <button onclick="irAPagina(${paginaActual + 1})" ${paginaActual === totalPaginas ? 'disabled' : ''} class="${paginaActual === totalPaginas ? btnDisabled : btnNormal}" title="Siguiente">&rsaquo;</button>
        <button onclick="irAPagina(${totalPaginas})" ${paginaActual === totalPaginas ? 'disabled' : ''} class="${paginaActual === totalPaginas ? btnDisabled : btnNormal}" title="Última página">&raquo;</button>`;
    
    contenedor.innerHTML = `
        <div class="flex flex-col sm:flex-row items-center justify-between gap-3">
            <span class="text-xs text-gray-600 dark:text-gray-400">
                Mostrando <span class="font-semibold">${inicio}</span>-<span class="font-semibold">${fin}</span>
                de <span class="font-semibold">${totalRegistros}</span> proveedores
            </span>
            <div class="flex items-center gap-1">${botones}</div>
        </div>`;
}

/**
 * Ir a una página de la tabla
 */
function irAPagina(pagina) {
    paginaActual = pagina;
    renderizarTabla();
    const tabla = document.getElementById('tabla-proveedores');
    if (tabla) tabla.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// ============================================================================
// FILTROS
// ============================================================================
/**
 * Filtrar proveedores según criterios
 */
function filtrarProveedores() {
    const buscar = document.getElementById('buscar').value.toLowerCase();
    const estado = document.getElementById('filtro-estado').value;
    
    proveedoresFiltrados = proveedores.filter(prov => {
        // Filtro de búsqueda
        const coincideBusqueda = buscar === '' || 
            prov.ruc.toLowerCase().includes(buscar) ||
            prov.razon_social.toLowerCase().includes(buscar) ||
            (prov.nombre_comercial && prov.nombre_comercial.toLowerCase().includes(buscar));
        
        // Filtro de estado
        const coincideEstado = estado === '' || prov.estado === estado;
        
        return coincideBusqueda && coincideEstado;
    });
    
    console.log(`[PROVEEDORES] Filtrado: ${proveedoresFiltrados.length} de ${proveedores.length}`);
    paginaActual = 1;
    renderizarTabla();
}

/**
 * Limpiar filtros
 */
function limpiarFiltros() {
    document.getElementById('buscar').value = '';
    document.getElementById('filtro-estado').value = '';
    filtrarProveedores();
}

// ============================================================================
// MODAL
// ============================================================================
/**
 * Abrir modal para crear nuevo proveedor
 */
function abrirModalCrear() {
    modoEdicion = false;
    document.getElementById('modal-titulo').textContent = 'Nuevo Proveedor';
    document.getElementById('btn-guardar-texto').textContent = 'Guardar Proveedor';
    document.getElementById('es-edicion').value = 'false';
    document.getElementById('campo-estado').classList.add('hidden');
    
    // Limpiar formulario
    document.getElementById('form-proveedor').reset();
    document.getElementById('id-proveedor').value = '';
    document.getElementById('ruc').disabled = false;
    
    // Mostrar modal
    document.getElementById('modal-proveedor').classList.remove('hidden');
}

/**
 * Editar proveedor existente
 */
async function editarProveedor(ruc) {
    try {
        const response = await fetch(`/api/proveedores/obtener/${ruc}`);
        const result = await response.json();
        
        if (result.success) {
            const prov = result.proveedor;
            
            modoEdicion = true;
            document.getElementById('modal-titulo').textContent = 'Editar Proveedor';
            document.getElementById('btn-guardar-texto').textContent = 'Guardar Cambios';
            document.getElementById('es-edicion').value = 'true';
            document.getElementById('campo-estado').classList.remove('hidden');
            
            // Llenar formulario
            document.getElementById('id-proveedor').value = prov.ruc;
            document.getElementById('ruc').value = prov.ruc;
            document.getElementById('ruc').disabled = false; // RUC editable también en edición
            document.getElementById('razon-social').value = prov.razon_social;
            document.getElementById('nombre-comercial').value = prov.nombre_comercial || '';
            document.getElementById('telefono').value = prov.telefono || '';
            document.getElementById('email').value = prov.email || '';
            document.getElementById('direccion').value = prov.direccion_fiscal || '';
            document.getElementById('contacto-nombre').value = prov.contacto_nombre || '';
            document.getElementById('contacto-telefono').value = prov.contacto_telefono || '';
            document.getElementById('contacto-email').value = prov.contacto_email || '';
            document.getElementById('banco').value = prov.banco_1 || '';
            document.getElementById('cuenta-bancaria').value = prov.cuenta_banco_1 || '';
            document.getElementById('estado').value = prov.estado;
            
            // Mostrar modal
            document.getElementById('modal-proveedor').classList.remove('hidden');
        }
    } catch (error) {
        console.error('[PROVEEDORES] Error al cargar proveedor:', error);
        mostrarNotificacion('Error al cargar proveedor', 'error');
    }
}

/**
 * Cerrar modal
 */
function cerrarModal() {
    document.getElementById('modal-proveedor').classList.add('hidden');
    document.getElementById('form-proveedor').reset();
    document.getElementById('ruc').disabled = false; // Rehabilitar RUC al cerrar
}

// ============================================================================
// GUARDAR
// ============================================================================
/**
 * Guardar proveedor (crear o actualizar)
 */
async function guardarProveedor() {
    const esEdicion = document.getElementById('es-edicion').value === 'true';
    const ruc = document.getElementById('ruc').value;
    
    // Validación de RUC (solo 11 dígitos numéricos)
    const errorRuc = validarRUC(ruc);
    if (errorRuc) {
        mostrarNotificacion(errorRuc, 'error');
        document.getElementById('ruc').focus();
        return;
    }
    
    // Recopilar datos
    const datos = {
        ruc: ruc,
        razon_social: document.getElementById('razon-social').value,
        nombre_comercial: document.getElementById('nombre-comercial').value,
        telefono: document.getElementById('telefono').value,
        email: document.getElementById('email').value,
        direccion_fiscal: document.getElementById('direccion').value,
        contacto_nombre: document.getElementById('contacto-nombre').value,
        contacto_telefono: document.getElementById('contacto-telefono').value,
        contacto_email: document.getElementById('contacto-email').value,
        banco_1: document.getElementById('banco').value,
        cuenta_banco_1: document.getElementById('cuenta-bancaria').value
    };
    
    if (esEdicion) {
        datos.estado = document.getElementById('estado').value;
    }
    
    try {
        // En edición la URL lleva el RUC original (llave primaria); el body, el nuevo
        const rucOriginal = document.getElementById('id-proveedor').value || ruc;
        const url = esEdicion 
            ? `/api/proveedores/actualizar/${rucOriginal}`
            : '/api/proveedores/crear';
        
        const method = esEdicion ? 'PUT' : 'POST';
        
        const response = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        
        const result = await response.json();
        
        if (result.success) {
            mostrarNotificacion(result.message, 'success');
            cerrarModal();
            cargarProveedores();
        } else {
            mostrarNotificacion(result.error, 'error');
        }
    } catch (error) {
        console.error('[PROVEEDORES] Error al guardar:', error);
        mostrarNotificacion('Error al guardar proveedor', 'error');
    }
}

// ============================================================================
// ELIMINAR
// ============================================================================
/**
 * Eliminar proveedor (soft delete)
 */
async function eliminarProveedor(ruc) {
    if (!confirm('¿Estás seguro de eliminar este proveedor?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/proveedores/eliminar/${ruc}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (result.success) {
            mostrarNotificacion(result.message, 'success');
            cargarProveedores();
        } else {
            mostrarNotificacion(result.error, 'error');
        }
    } catch (error) {
        console.error('[PROVEEDORES] Error al eliminar:', error);
        mostrarNotificacion('Error al eliminar proveedor', 'error');
    }
}

// ============================================================================
// VER DETALLES
// ============================================================================
/**
 * Ver detalles completos del proveedor (modal con diseño propio)
 */
async function verDetalles(ruc) {
    document.getElementById('detalle-cargando').classList.remove('hidden');
    document.getElementById('detalle-contenido').classList.add('hidden');
    document.getElementById('detalle-titulo').textContent = 'Detalle del Proveedor';
    document.getElementById('detalle-ruc').textContent = ruc;
    document.getElementById('detalle-estado').innerHTML = '';
    document.getElementById('modal-detalles').classList.remove('hidden');
    
    try {
        const response = await fetch(`/api/proveedores/obtener/${ruc}`);
        const result = await response.json();
        if (!result.success || !result.proveedor) {
            throw new Error(result.error || 'Proveedor no encontrado');
        }
        renderDetalles(result.proveedor);
    } catch (error) {
        console.error('[PROVEEDORES] Error al cargar detalles:', error);
        cerrarModalDetalles();
        mostrarNotificacion(error.message || 'Error al cargar los detalles del proveedor', 'error');
    }
}

/**
 * Rellenar el modal de detalles con la información del proveedor
 */
function renderDetalles(p) {
    const o = v => (v !== null && v !== undefined && String(v).trim() !== '') ? String(v) : '—';
    const set = (id, valor) => { document.getElementById(id).textContent = valor; };
    const combo = (...vals) => {
        const partes = vals.filter(v => v !== null && v !== undefined && String(v).trim() !== '');
        return partes.length ? partes.join(' · ') : '—';
    };
    
    document.getElementById('detalle-titulo').textContent = p.razon_social || 'Proveedor';
    document.getElementById('detalle-ruc').textContent = p.ruc || '—';
    document.getElementById('detalle-estado').innerHTML = obtenerBadgeEstado(p.estado);
    
    // Datos generales
    set('d-razon-social', o(p.razon_social));
    set('d-nombre-comercial', o(p.nombre_comercial));
    set('d-rubro', o(p.rubro_negocio));
    set('d-categoria', o(p.categoria));
    set('d-condicion-pago', o(p.condicion_pago));
    set('d-plazo-entrega', o(p.plazo_entrega));
    
    // Contacto de la empresa
    set('d-telefono', o(p.telefono));
    set('d-email', o(p.email));
    set('d-direccion', o(p.direccion_fiscal));
    set('d-ubigeo-texto', combo(p.distrito, p.provincia, p.departamento));
    
    // Persona de contacto
    set('d-contacto-nombre', o(p.contacto_nombre));
    set('d-contacto-cargo', o(p.contacto_cargo));
    set('d-contacto-telefono', o(p.contacto_telefono));
    set('d-contacto-email', o(p.contacto_email));
    
    // Cuentas bancarias
    set('d-banco-1', o(p.banco_1));
    set('d-cuenta-1', o(p.cuenta_banco_1));
    set('d-tipo-moneda-1', combo(p.tipo_cuenta_1, p.moneda_1));
    set('d-cci-1', o(p.cci_1));
    
    const tieneCuenta2 = [p.banco_2, p.cuenta_banco_2, p.cci_2]
        .some(v => v !== null && v !== undefined && String(v).trim() !== '');
    document.getElementById('detalle-cuenta-2').classList.toggle('hidden', !tieneCuenta2);
    if (tieneCuenta2) {
        set('d-banco-2', o(p.banco_2));
        set('d-cuenta-2', o(p.cuenta_banco_2));
        set('d-tipo-moneda-2', combo(p.tipo_cuenta_2, p.moneda_2));
        set('d-cci-2', o(p.cci_2));
    }
    
    // Registro del sistema
    set('d-creado-por', o(p.creado_por_nombre));
    set('d-fecha-creacion', formatearFecha(p.fecha_creacion));
    set('d-actualizado-por', o(p.actualizado_por_nombre));
    set('d-fecha-actualizacion', formatearFecha(p.fecha_actualizacion));
    
    document.getElementById('detalle-cargando').classList.add('hidden');
    document.getElementById('detalle-contenido').classList.remove('hidden');
}

/**
 * Cerrar modal de detalles
 */
function cerrarModalDetalles() {
    document.getElementById('modal-detalles').classList.add('hidden');
}

/**
 * Abrir el modal de edición desde el detalle
 */
function editarDesdeDetalles() {
    const ruc = document.getElementById('detalle-ruc').textContent.trim();
    cerrarModalDetalles();
    if (ruc && ruc !== '—') {
        editarProveedor(ruc);
    }
}

/**
 * Formatear fecha (formato local) o mostrar "—"
 */
function formatearFecha(fecha) {
    if (!fecha) return '—';
    const d = new Date(String(fecha).replace(' ', 'T'));
    if (isNaN(d.getTime())) return String(fecha);
    return d.toLocaleString('es-PE', {
        day: '2-digit', month: '2-digit', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

// ============================================================================
// UTILIDADES
// ============================================================================
/**
 * Obtener badge de estado
 */
function obtenerBadgeEstado(estado) {
    const estados = {
        'ACTIVO': 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
        'INACTIVO': 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400'
    };
    
    const clases = estados[estado] || 'bg-gray-100 text-gray-800';
    const textos = {
        'ACTIVO': 'Activo',
        'INACTIVO': 'Inactivo'
    };
    
    return `<span class="px-3 py-1 rounded-full text-xs font-semibold ${clases}">${textos[estado] || estado}</span>`;
}

/**
 * Validar RUC: solo se exige que tenga exactamente 11 dígitos numéricos
 * (no se valida contra SUNAT ni dígito verificador)
 * @returns {string|null} mensaje de error, o null si el RUC es válido
 */
function validarRUC(ruc) {
    if (!ruc || !/^\d{11}$/.test(String(ruc))) {
        return 'El RUC debe tener exactamente 11 dígitos numéricos';
    }
    return null;
}

/**
 * Escape HTML
 */
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

/**
 * Mostrar notificación
 */
function mostrarNotificacion(mensaje, tipo = 'info') {
    const colores = {
        success: 'bg-green-500',
        error: 'bg-red-500',
        info: 'bg-blue-500'
    };
    
    const iconos = {
        success: 'fa-check-circle',
        error: 'fa-exclamation-circle',
        info: 'fa-info-circle'
    };
    
    const toast = document.createElement('div');
    toast.className = `fixed top-4 right-4 ${colores[tipo]} text-white px-6 py-4 rounded-lg shadow-lg flex items-center gap-3 z-50 animate-fade-in`;
    toast.innerHTML = `
        <i class="fas ${iconos[tipo]}"></i>
        <span>${mensaje}</span>
    `;
    
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 3000);
}


// ============================================================================
// FICHA DE MATERIALES DEL PROVEEDOR
// ============================================================================

async function abrirFichaMateriales(ruc, razonSocial) {
    // Crear modal dinámicamente si no existe
    let modal = document.getElementById('modal-ficha-materiales');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'modal-ficha-materiales';
        modal.innerHTML = `
            <div class="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl max-w-3xl w-full max-h-[85vh] flex flex-col">
                <div class="bg-gradient-to-r from-indigo-600 to-indigo-700 p-6 rounded-t-2xl flex items-center justify-between flex-shrink-0">
                    <div>
                        <h2 class="text-xl font-bold text-white"><i class="fas fa-boxes mr-2"></i>Materiales del proveedor</h2>
                        <p id="ficha-subtitulo" class="text-indigo-200 text-sm mt-0.5 font-medium"></p>
                    </div>
                    <button onclick="cerrarFichaMateriales()" class="text-white hover:text-gray-200 p-2 hover:bg-white/10 rounded-lg">
                        <i class="fas fa-times text-xl"></i>
                    </button>
                </div>
                <div class="flex-1 overflow-y-auto p-6">
                    <div id="ficha-contenido"></div>
                </div>
                <div class="flex-shrink-0 p-6 pt-0 flex justify-end">
                    <button onclick="cerrarFichaMateriales()"
                            class="px-6 py-2.5 bg-gray-200 dark:bg-slate-700 text-gray-700 dark:text-gray-300 rounded-xl font-medium hover:bg-gray-300 transition-colors">
                        Cerrar
                    </button>
                </div>
            </div>`;
        modal.className = 'hidden fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4';
        document.body.appendChild(modal);
    }

    document.getElementById('ficha-subtitulo').textContent = razonSocial;
    modal.classList.remove('hidden');

    const contenido = document.getElementById('ficha-contenido');
    contenido.innerHTML = '<div class="text-center py-12"><i class="fas fa-spinner fa-spin text-3xl text-indigo-500 mb-3"></i><p class="text-gray-500">Cargando materiales...</p></div>';

    try {
        const r = await fetch(`/api/proveedores/${encodeURIComponent(ruc)}/materiales`);
        const data = await r.json();

        if (!data.success) {
            contenido.innerHTML = '<p class="text-center text-red-500 py-8">Error al cargar los materiales.</p>';
            return;
        }

        if (data.materiales.length === 0) {
            contenido.innerHTML = `
                <div class="text-center py-12 text-gray-400 dark:text-gray-500">
                    <i class="fas fa-boxes text-5xl mb-3 opacity-40"></i>
                    <p class="font-medium">Sin materiales asociados</p>
                    <p class="text-sm mt-1">Los materiales se vincularán desde el módulo de Inventario.</p>
                </div>`;
            return;
        }

        contenido.innerHTML = `
            <table class="w-full text-sm">
                <thead class="bg-gray-50 dark:bg-slate-700/50">
                    <tr>
                        <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Código</th>
                        <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Material</th>
                        <th class="px-4 py-2 text-left text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Categoría</th>
                        <th class="px-4 py-2 text-center text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Stock</th>
                        <th class="px-4 py-2 text-right text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Precio</th>
                        <th class="px-4 py-2 text-center text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Tipo</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
                    ${data.materiales.map(m => `
                        <tr class="hover:bg-gray-50 dark:hover:bg-slate-700/40 transition-colors">
                            <td class="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">${m.codigo || '—'}</td>
                            <td class="px-4 py-3">
                                <p class="font-semibold text-gray-900 dark:text-white">${escapeHtml(m.nombre)}</p>
                                <p class="text-xs text-gray-500 dark:text-gray-400">${m.tipo_inventario}</p>
                            </td>
                            <td class="px-4 py-3 text-gray-700 dark:text-gray-300">${escapeHtml(m.categoria || '—')}</td>
                            <td class="px-4 py-3 text-center text-gray-700 dark:text-gray-300">
                                ${parseFloat(m.stock_actual || 0).toFixed(2)} ${m.unidad_abrev || ''}
                            </td>
                            <td class="px-4 py-3 text-right font-medium text-gray-900 dark:text-white">
                                ${m.precio_compra ? `${m.moneda === 'DOLARES' ? '$' : 'S/'} ${parseFloat(m.precio_compra).toFixed(2)}` : '—'}
                            </td>
                            <td class="px-4 py-3 text-center">
                                ${(m.es_principal == 1) ? '<span class="px-2 py-0.5 bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300 rounded-full text-xs font-semibold">Principal</span>' : '<span class="px-2 py-0.5 bg-gray-100 text-gray-600 dark:bg-slate-600 dark:text-gray-300 rounded-full text-xs font-semibold">Secundario</span>'}
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>`;
    } catch (e) {
        contenido.innerHTML = '<p class="text-center text-red-500 py-8">Error de conexión.</p>';
    }
}

function cerrarFichaMateriales() {
    const modal = document.getElementById('modal-ficha-materiales');
    if (modal) modal.classList.add('hidden');
}
