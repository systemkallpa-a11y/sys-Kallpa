/**
 * Script: presupuesto-pdf.js
 * Propósito: Manejar descarga de presupuestos en PDF
 * Fecha: 10 Julio 2026
 */

// Variable global para rastrear el ID del presupuesto actual
let currentPresupuestoId = null;

// Función para descargar presupuesto en PDF
async function descargarPresupuestoPDF(idPresupuesto) {
    // Si no se proporciona ID, usar el ID global actual
    if (!idPresupuesto) {
        idPresupuesto = currentPresupuestoId;
    }
    
    if (!idPresupuesto) {
        mostrarNotificacion('No hay presupuesto seleccionado', 'error');
        return;
    }
    
    try {
        console.log(`[PDF] Iniciando descarga de presupuesto ID: ${idPresupuesto}`);
        
        // Mostrar loading en el botón si existe
        const btnDescargar = document.getElementById(`btn-descargar-pdf-${idPresupuesto}`);
        let originalHTML = null;
        
        if (btnDescargar) {
            btnDescargar.disabled = true;
            originalHTML = btnDescargar.innerHTML;
            btnDescargar.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Generando PDF...';
        }
        
        try {
            // Realizar petición
            const response = await fetch(`/api/presupuestos/descargar/${idPresupuesto}`);
            
            if (!response.ok) {
                throw new Error(`Error ${response.status}: ${response.statusText}`);
            }
            
            // Obtener el PDF como blob
            const blob = await response.blob();
            
            // Crear URL temporal
            const url = window.URL.createObjectURL(blob);
            
            // Crear elemento de descarga
            const link = document.createElement('a');
            link.href = url;
            link.download = `Presupuesto_${idPresupuesto}.pdf`;
            
            // Trigger descarga
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            // Limpiar URL
            window.URL.revokeObjectURL(url);
            
            console.log('[PDF] Descarga completada exitosamente');
            
            // Mostrar notificación
            mostrarNotificacion('PDF descargado correctamente', 'success');
            
        } finally {
            // Restaurar botón si existe
            if (btnDescargar && originalHTML) {
                btnDescargar.disabled = false;
                btnDescargar.innerHTML = originalHTML;
            }
        }
        
    } catch (error) {
        console.error('[PDF] Error:', error);
        mostrarNotificacion(`Error descargando PDF: ${error.message}`, 'error');
    }
}

// Función para mostrar modal con detalles del presupuesto
async function visualizarPresupuestoDetalle(idPresupuesto) {
    try {
        console.log(`[DETALLE] Cargando presupuesto ID: ${idPresupuesto}`);
        
        // Guardar ID actual para el botón descargar
        currentPresupuestoId = idPresupuesto;
        
        // Obtener datos del presupuesto
        const response = await fetch(`/api/presupuestos/visualizar/${idPresupuesto}`);
        
        if (!response.ok) {
            throw new Error(`Error ${response.status}: ${response.statusText}`);
        }
        
        const result = await response.json();
        
        if (!result.success) {
            throw new Error(result.error || 'Error desconocido');
        }
        
        const data = result.data;
        const presupuesto = data.presupuesto;
        const detalles = data.detalles || [];
        const resumen = data.resumen || {};
        
        console.log('[DETALLE] Presupuesto:', presupuesto);
        console.log('[DETALLE] Detalles:', detalles);
        console.log('[DETALLE] Resumen:', resumen);
        
        // Llenar el modal existente con los datos
        document.getElementById('vis-numero').textContent = presupuesto.numero_presupuesto || '-';
        document.getElementById('vis-estado').innerHTML = `<span class="inline-block px-3 py-1 rounded-full text-xs font-semibold ${getEstadoBadgeClass(presupuesto.estado)}">${presupuesto.estado || '-'}</span>`;
        document.getElementById('vis-proyecto').textContent = presupuesto.nombre_proyecto || '-';
        document.getElementById('vis-obra').textContent = presupuesto.nombre_obra || '-';
        document.getElementById('vis-usuario').textContent = `${presupuesto.usuario_nombres || '-'} ${presupuesto.apellido_paterno || ''}`.trim();
        
        const fechaCreacion = presupuesto.fecha_creacion 
            ? new Date(presupuesto.fecha_creacion).toLocaleDateString('es-PE')
            : '-';
        document.getElementById('vis-fecha').textContent = fechaCreacion;
        
        // Llenar tabla de materiales
        const tablaMateriales = document.getElementById('vis-tabla-materiales');
        if (detalles.length > 0) {
            tablaMateriales.innerHTML = detalles.map((detalle, idx) => `
                <tr class="hover:bg-gray-50 dark:hover:bg-slate-800/50">
                    <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">${detalle.material_nombre || 'N/A'}</td>
                    <td class="px-4 py-3 text-sm text-center text-gray-900 dark:text-white">${parseFloat(detalle.cantidad).toFixed(2)}</td>
                    <td class="px-4 py-3 text-sm text-right text-gray-900 dark:text-white">S/. ${parseFloat(detalle.precio_unitario).toFixed(2)}</td>
                    <td class="px-4 py-3 text-sm text-right font-semibold text-slate-600 dark:text-slate-400">S/. ${parseFloat(detalle.subtotal).toFixed(2)}</td>
                </tr>
            `).join('');
        } else {
            tablaMateriales.innerHTML = `
                <tr>
                    <td colspan="4" class="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                        No hay materiales registrados
                    </td>
                </tr>
            `;
        }
        
        // Llenar resumen
        document.getElementById('vis-cantidad-items').textContent = detalles.length || '0';
        document.getElementById('vis-monto-total').textContent = `S/. ${parseFloat(presupuesto.monto || 0).toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
        
        // Llenar observaciones
        document.getElementById('vis-observaciones').textContent = presupuesto.observaciones || '-';
        
        // Mostrar el modal existente
        const modal = document.getElementById('modal-visualizar-presupuesto');
        if (modal) {
            modal.classList.remove('hidden');
            console.log('[DETALLE] Modal mostrado exitosamente');
        } else {
            console.error('[DETALLE] Modal no encontrado en el DOM');
        }
        
    } catch (error) {
        console.error('[DETALLE] Error:', error);
        mostrarNotificacion(`Error cargando presupuesto: ${error.message}`, 'error');
    }
}

// Función para cerrar modal de detalles
function cerrarModalVisualizacion() {
    const modal = document.getElementById('modal-visualizar-presupuesto');
    if (modal) {
        modal.classList.add('hidden');
    }
}

// Función para obtener clase de badge según estado
function getEstadoBadgeClass(estado) {
    const classes = {
        'PENDIENTE': 'bg-yellow-100 dark:bg-yellow-900 text-yellow-800 dark:text-yellow-200',
        'APROBADO': 'bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200',
        'RECHAZADO': 'bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-200',
        'EJECUTANDO': 'bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200',
        'COMPLETADO': 'bg-emerald-100 dark:bg-emerald-900 text-emerald-800 dark:text-emerald-200',
        'CANCELADO': 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200',
    };
    return classes[estado] || 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-200';
}

// Función auxiliar para notificaciones
function mostrarNotificacion(mensaje, tipo = 'info') {
    console.log(`[NOTIF] ${tipo.toUpperCase()}: ${mensaje}`);
    
    // Intentar usar la función mostrarExito/mostrarError si existen
    if (tipo === 'success' && window.mostrarExito) {
        window.mostrarExito(mensaje);
    } else if (tipo === 'error' && window.mostrarError) {
        window.mostrarError(mensaje);
    } else {
        // Crear notificación simple si no existen las funciones
        const notification = document.createElement('div');
        notification.className = `fixed top-4 right-4 px-6 py-3 rounded-lg text-white font-medium z-50 ${
            tipo === 'success' ? 'bg-green-500' : tipo === 'error' ? 'bg-red-500' : 'bg-blue-500'
        }`;
        notification.textContent = mensaje;
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }
}
