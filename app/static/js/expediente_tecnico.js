/**
 * expediente_tecnico.js
 * Gestión de Expedientes Técnicos
 */

let expedientes = [];
let expedientesFiltrados = [];
let modoEdicion = false;

// ============================================================================
// INICIALIZACIÓN
// ============================================================================
document.addEventListener('DOMContentLoaded', function() {
    console.log('[EXPEDIENTE_TECNICO] Inicializando módulo...');
    
    cargarExpedientes();
    configurarEventListeners();
});

/**
 * Configurar Event Listeners
 */
function configurarEventListeners() {
    // Filtros
    document.getElementById('buscar').addEventListener('input', filtrarExpedientes);
    document.getElementById('filtro-estado').addEventListener('change', filtrarExpedientes);
    
    // Form submit
    document.getElementById('form-expediente').addEventListener('submit', function(e) {
        e.preventDefault();
        guardarExpediente();
    });
}

// ============================================================================
// CARGAR DATOS
// ============================================================================
/**
 * Cargar todos los expedientes técnicos
 */
async function cargarExpedientes() {
    try {
        console.log('[EXPEDIENTE_TECNICO] Cargando expedientes...');
        
        const response = await fetch('/api/expediente-tecnico/obtener');
        const result = await response.json();
        
        if (result.success) {
            expedientes = result.expedientes || [];
            expedientesFiltrados = [...expedientes];
            
            console.log(`[EXPEDIENTE_TECNICO] ${expedientes.length} expedientes cargados`);
            
            renderizarTabla();
        } else {
            console.error('[EXPEDIENTE_TECNICO] Error:', result.error);
            mostrarNotificacion('Error al cargar expedientes', 'error');
        }
    } catch (error) {
        console.error('[EXPEDIENTE_TECNICO] Error al cargar:', error);
        mostrarNotificacion('Error de conexión', 'error');
    }
}

/**
 * Cargar OTs disponibles (sin expediente)
 */
async function cargarOTsDisponibles() {
    try {
        const response = await fetch('/api/expediente-tecnico/ots-disponibles');
        const result = await response.json();
        
        if (result.success) {
            const select = document.getElementById('id-ot');
            select.innerHTML = '<option value="">Selecciona una OT...</option>';
            
            result.ots.forEach(ot => {
                const option = document.createElement('option');
                option.value = ot.id_ot;
                option.textContent = `${ot.codigo_ot} - ${ot.nombre_proyecto} / ${ot.nombre_obra}`;
                select.appendChild(option);
            });
            
            console.log(`[EXPEDIENTE_TECNICO] ${result.ots.length} OTs disponibles cargadas`);
        }
    } catch (error) {
        console.error('[EXPEDIENTE_TECNICO] Error al cargar OTs:', error);
    }
}

// ============================================================================
// RENDERIZADO
// ============================================================================
/**
 * Renderizar tabla de expedientes
 */
function renderizarTabla() {
    const tbody = document.getElementById('tabla-expedientes');
    const sinExpedientes = document.getElementById('sin-expedientes');
    
    // Si no hay expedientes
    if (expedientesFiltrados.length === 0) {
        tbody.innerHTML = '';
        sinExpedientes.classList.remove('hidden');
        return;
    }
    
    sinExpedientes.classList.add('hidden');
    
    // Renderizar filas
    tbody.innerHTML = expedientesFiltrados.map(exp => {
        const badgeEstado = obtenerBadgeEstado(exp.estado);
        const fechaFin = exp.fecha_fin ? formatearFecha(exp.fecha_fin) : '<span class="text-gray-400">No definida</span>';
        
        return `
            <tr class="hover:bg-gray-50 dark:hover:bg-slate-800 transition-colors">
                <td class="px-6 py-4">
                    <div class="font-medium text-gray-900 dark:text-white">${exp.codigo_ot}</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">${truncarTexto(exp.descripcion_ot, 40)}</div>
                </td>
                <td class="px-6 py-4">
                    <div class="font-medium text-gray-700 dark:text-gray-300">${exp.nombre_proyecto}</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">${exp.nombre_obra}</div>
                </td>
                <td class="px-6 py-4 text-gray-700 dark:text-gray-300">
                    ${formatearFecha(exp.fecha_inicio)}
                </td>
                <td class="px-6 py-4 text-gray-700 dark:text-gray-300">
                    ${fechaFin}
                </td>
                <td class="px-6 py-4">
                    <span class="font-semibold text-green-600 dark:text-green-400">
                        S/ ${formatearNumero(exp.presupuesto_aprobado)}
                    </span>
                </td>
                <td class="px-6 py-4">
                    ${badgeEstado}
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center justify-center gap-2">
                        <button onclick="verDetalles(${exp.id_expediente})" 
                                class="p-2 text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg transition-colors"
                                title="Ver detalles">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button onclick="editarExpediente(${exp.id_expediente})" 
                                class="p-2 text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-900/20 rounded-lg transition-colors"
                                title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button onclick="eliminarExpediente(${exp.id_expediente})" 
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
 * Filtrar expedientes según criterios
 */
function filtrarExpedientes() {
    const buscar = document.getElementById('buscar').value.toLowerCase();
    const estado = document.getElementById('filtro-estado').value;
    
    expedientesFiltrados = expedientes.filter(exp => {
        // Filtro de búsqueda
        const coincideBusqueda = buscar === '' || 
            exp.codigo_ot.toLowerCase().includes(buscar) ||
            exp.nombre_obra.toLowerCase().includes(buscar) ||
            exp.nombre_proyecto.toLowerCase().includes(buscar);
        
        // Filtro de estado
        const coincideEstado = estado === '' || exp.estado === estado;
        
        return coincideBusqueda && coincideEstado;
    });
    
    console.log(`[EXPEDIENTE_TECNICO] Filtrado: ${expedientesFiltrados.length} de ${expedientes.length}`);
    renderizarTabla();
}

/**
 * Limpiar filtros
 */
function limpiarFiltros() {
    document.getElementById('buscar').value = '';
    document.getElementById('filtro-estado').value = '';
    filtrarExpedientes();
}

// ============================================================================
// MODAL
// ============================================================================
/**
 * Abrir modal para crear nuevo expediente
 */
async function abrirModalCrear() {
    modoEdicion = false;
    document.getElementById('modal-titulo').textContent = 'Crear Expediente Técnico';
    document.getElementById('btn-guardar-texto').textContent = 'Crear Expediente';
    document.getElementById('es-edicion').value = 'false';
    document.getElementById('campo-estado').classList.add('hidden');
    
    // Limpiar formulario
    document.getElementById('form-expediente').reset();
    document.getElementById('id-expediente').value = '';
    
    // Cargar OTs disponibles
    await cargarOTsDisponibles();
    
    // Mostrar modal
    document.getElementById('modal-expediente').classList.remove('hidden');
}

/**
 * Editar expediente existente
 */
async function editarExpediente(id) {
    try {
        const response = await fetch(`/api/expediente-tecnico/obtener/${id}`);
        const result = await response.json();
        
        if (result.success) {
            const exp = result.expediente;
            
            modoEdicion = true;
            document.getElementById('modal-titulo').textContent = 'Editar Expediente Técnico';
            document.getElementById('btn-guardar-texto').textContent = 'Guardar Cambios';
            document.getElementById('es-edicion').value = 'true';
            document.getElementById('campo-estado').classList.remove('hidden');
            
            // Llenar formulario
            document.getElementById('id-expediente').value = exp.id_expediente;
            document.getElementById('fecha-inicio').value = exp.fecha_inicio;
            document.getElementById('fecha-fin').value = exp.fecha_fin || '';
            document.getElementById('presupuesto-aprobado').value = exp.presupuesto_aprobado;
            document.getElementById('estado').value = exp.estado;
            document.getElementById('observaciones').value = exp.observaciones || '';
            
            // Cargar select de OT y seleccionar la actual
            const select = document.getElementById('id-ot');
            select.innerHTML = `<option value="${exp.id_ot}">${exp.codigo_ot} - ${exp.nombre_proyecto} / ${exp.nombre_obra}</option>`;
            select.disabled = true; // No permitir cambiar OT en edición
            
            // Mostrar modal
            document.getElementById('modal-expediente').classList.remove('hidden');
        }
    } catch (error) {
        console.error('[EXPEDIENTE_TECNICO] Error al cargar expediente:', error);
        mostrarNotificacion('Error al cargar expediente', 'error');
    }
}

/**
 * Cerrar modal
 */
function cerrarModal() {
    document.getElementById('modal-expediente').classList.add('hidden');
    document.getElementById('form-expediente').reset();
    document.getElementById('id-ot').disabled = false;
}

// ============================================================================
// GUARDAR
// ============================================================================
/**
 * Guardar expediente (crear o actualizar)
 */
async function guardarExpediente() {
    const esEdicion = document.getElementById('es-edicion').value === 'true';
    const idExpediente = document.getElementById('id-expediente').value;
    
    // Recopilar datos
    const datos = {
        id_ot: parseInt(document.getElementById('id-ot').value),
        fecha_inicio: document.getElementById('fecha-inicio').value,
        fecha_fin: document.getElementById('fecha-fin').value || null,
        presupuesto_aprobado: parseFloat(document.getElementById('presupuesto-aprobado').value),
        observaciones: document.getElementById('observaciones').value || ''
    };
    
    if (esEdicion) {
        datos.estado = document.getElementById('estado').value;
    }
    
    try {
        const url = esEdicion 
            ? `/api/expediente-tecnico/actualizar/${idExpediente}`
            : '/api/expediente-tecnico/crear';
        
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
            cargarExpedientes();
        } else {
            mostrarNotificacion(result.error, 'error');
        }
    } catch (error) {
        console.error('[EXPEDIENTE_TECNICO] Error al guardar:', error);
        mostrarNotificacion('Error al guardar expediente', 'error');
    }
}

// ============================================================================
// ELIMINAR
// ============================================================================
/**
 * Eliminar expediente (soft delete)
 */
async function eliminarExpediente(id) {
    if (!confirm('¿Estás seguro de eliminar este expediente técnico?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/expediente-tecnico/eliminar/${id}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (result.success) {
            mostrarNotificacion(result.message, 'success');
            cargarExpedientes();
        } else {
            mostrarNotificacion(result.error, 'error');
        }
    } catch (error) {
        console.error('[EXPEDIENTE_TECNICO] Error al eliminar:', error);
        mostrarNotificacion('Error al eliminar expediente', 'error');
    }
}

// ============================================================================
// VER DETALLES
// ============================================================================
/**
 * Ver detalles completos del expediente
 */
function verDetalles(id) {
    const exp = expedientes.find(e => e.id_expediente === id);
    if (!exp) return;
    
    const detalles = `
        <div class="space-y-4">
            <div><strong>Código OT:</strong> ${exp.codigo_ot}</div>
            <div><strong>Proyecto:</strong> ${exp.nombre_proyecto}</div>
            <div><strong>Obra:</strong> ${exp.nombre_obra}</div>
            <div><strong>Descripción OT:</strong> ${exp.descripcion_ot}</div>
            <div><strong>Fecha Inicio:</strong> ${formatearFecha(exp.fecha_inicio)}</div>
            <div><strong>Fecha Fin:</strong> ${exp.fecha_fin ? formatearFecha(exp.fecha_fin) : 'No definida'}</div>
            <div><strong>Presupuesto:</strong> S/ ${formatearNumero(exp.presupuesto_aprobado)}</div>
            <div><strong>Estado:</strong> ${exp.estado}</div>
            <div><strong>Creado por:</strong> ${exp.creado_por || 'N/A'}</div>
            <div><strong>Fecha Creación:</strong> ${formatearFechaHora(exp.fecha_creacion)}</div>
            ${exp.observaciones ? `<div><strong>Observaciones:</strong> ${exp.observaciones}</div>` : ''}
        </div>
    `;
    
    // Aquí podrías abrir un modal más detallado
    alert(`Detalles del Expediente #${exp.id_expediente}\n\n${detalles.replace(/<[^>]+>/g, '\n')}`);
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
        'EN_PROGRESO': 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
        'FINALIZADO': 'bg-gray-100 text-gray-800 dark:bg-gray-900/30 dark:text-gray-400',
        'SUSPENDIDO': 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400'
    };
    
    const clases = estados[estado] || 'bg-gray-100 text-gray-800';
    const textos = {
        'ACTIVO': 'Activo',
        'EN_PROGRESO': 'En Progreso',
        'FINALIZADO': 'Finalizado',
        'SUSPENDIDO': 'Suspendido'
    };
    
    return `<span class="px-3 py-1 rounded-full text-xs font-semibold ${clases}">${textos[estado] || estado}</span>`;
}

/**
 * Formatear fecha (YYYY-MM-DD -> DD/MM/YYYY)
 */
function formatearFecha(fecha) {
    if (!fecha) return '';
    const [y, m, d] = fecha.split('T')[0].split('-');
    return `${d}/${m}/${y}`;
}

/**
 * Formatear fecha y hora
 */
function formatearFechaHora(fechaHora) {
    if (!fechaHora) return '';
    const fecha = new Date(fechaHora);
    return fecha.toLocaleString('es-PE');
}

/**
 * Formatear número con separador de miles
 */
function formatearNumero(num) {
    return parseFloat(num).toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * Truncar texto
 */
function truncarTexto(texto, max) {
    if (!texto) return '';
    return texto.length > max ? texto.substring(0, max) + '...' : texto;
}

/**
 * Mostrar notificación
 */
function mostrarNotificacion(mensaje, tipo = 'info') {
    // Crear notificación toast
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
