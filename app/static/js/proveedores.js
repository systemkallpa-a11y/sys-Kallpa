/**
 * proveedores.js
 * Gestión de Proveedores
 */

let proveedores = [];
let proveedoresFiltrados = [];
let modoEdicion = false;

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
        return;
    }
    
    sinProveedores.classList.add('hidden');
    
    // Renderizar filas
    tbody.innerHTML = proveedoresFiltrados.map(prov => {
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
                    </div>
                </td>
            </tr>
        `;
    }).join('');
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
            document.getElementById('ruc').disabled = true; // RUC no se puede editar
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
        const url = esEdicion 
            ? `/api/proveedores/actualizar/${ruc}`
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
 * Ver detalles completos del proveedor
 */
function verDetalles(ruc) {
    const prov = proveedores.find(p => p.ruc === ruc);
    if (!prov) return;
    
    const detalles = `
RUC: ${prov.ruc}
Razón Social: ${prov.razon_social}
Nombre Comercial: ${prov.nombre_comercial || 'N/A'}
Teléfono: ${prov.telefono || 'N/A'}
Email: ${prov.email || 'N/A'}
Dirección: ${prov.direccion_fiscal || 'N/A'}

CONTACTO:
Nombre: ${prov.contacto_nombre || 'N/A'}
Teléfono: ${prov.contacto_telefono || 'N/A'}
Email: ${prov.contacto_email || 'N/A'}

INFORMACIÓN BANCARIA:
Banco: ${prov.banco_1 || 'N/A'}
Cuenta: ${prov.cuenta_banco_1 || 'N/A'}

Estado: ${prov.estado}
Creado por: ${prov.creado_por_nombre || 'N/A'}
    `.trim();
    
    alert(`Detalles del Proveedor ${prov.ruc}\n\n${detalles}`);
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
