// ============================================================================
// VISUALIZACIÓN DEL FLUJO DE APROBACIÓN PROGRESIVO
// ============================================================================

/**
 * Abre modal mostrando el flujo de aprobación de un presupuesto
 */
async function abrirFlujoaprobacion(id_presupuesto) {
    try {
        console.log(`[FLUJO] Abriendo flujo para presupuesto: ${id_presupuesto}`);
        
        // Obtener información del presupuesto y flujo
        const response = await fetch(`/api/presupuestos/flujo/${id_presupuesto}`);
        const data = await response.json();
        
        if (!data.success) {
            alert('Error: ' + data.error);
            return;
        }
        
        const { presupuesto, flujo, historial } = data.data;
        
        // Crear modal HTML
        crearModalFlujo(presupuesto, flujo, historial);
        
    } catch (error) {
        console.error('[FLUJO] Error:', error);
        alert('Error al cargar flujo de aprobación');
    }
}

/**
 * Crea el modal visual del flujo de aprobación
 */
function crearModalFlujo(presupuesto, flujo, historial) {
    const modal = document.createElement('div');
    modal.id = 'modal-flujo-aprobacion';
    modal.className = 'fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4';
    modal.innerHTML = `
        <div class="bg-white dark:bg-slate-900 rounded-xl shadow-2xl w-full max-w-4xl max-h-[95vh] overflow-hidden flex flex-col">
            <!-- Header -->
            <div class="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-5 flex items-center justify-between border-b border-blue-800 flex-shrink-0">
                <div>
                    <h2 class="text-lg font-semibold">Flujo de Aprobación Progresivo</h2>
                    <p class="text-blue-100 text-sm mt-1">Presupuesto: ${presupuesto.numero_presupuesto}</p>
                </div>
                <button onclick="cerrarModalFlujo()" class="text-blue-200 hover:text-white transition-colors">
                    <i class="fas fa-times text-2xl"></i>
                </button>
            </div>
            
            <!-- Contenido -->
            <div class="flex-1 overflow-y-auto p-6">
                <!-- Resumen del Presupuesto -->
                <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-6">
                    <div class="grid grid-cols-4 gap-4">
                        <div>
                            <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Número</p>
                            <p class="text-sm font-bold text-gray-900 dark:text-white">${presupuesto.numero_presupuesto}</p>
                        </div>
                        <div>
                            <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Monto</p>
                            <p class="text-sm font-bold text-gray-900 dark:text-white">S/. ${parseFloat(presupuesto.monto).toLocaleString('es-PE', {minimumFractionDigits: 2})}</p>
                        </div>
                        <div>
                            <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Estado</p>
                            <p class="text-sm font-bold ${getColorEstado(presupuesto.estado)}">${presupuesto.estado}</p>
                        </div>
                        <div>
                            <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase">Progreso</p>
                            <p class="text-sm font-bold text-gray-900 dark:text-white">${historial.filter(h => h.estado_aprobacion === 'APROBADO').length}/${flujo.pasos_totales}</p>
                        </div>
                    </div>
                </div>
                
                <!-- Barra de Progreso -->
                <div class="mb-6">
                    <p class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">Progreso de Aprobación</p>
                    <div class="w-full bg-gray-200 dark:bg-slate-700 rounded-full h-3">
                        <div class="bg-gradient-to-r from-green-500 to-green-600 h-3 rounded-full transition-all" style="width: ${(historial.filter(h => h.estado_aprobacion === 'APROBADO').length / flujo.pasos_totales) * 100}%"></div>
                    </div>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">${historial.filter(h => h.estado_aprobacion === 'APROBADO').length} de ${flujo.pasos_totales} pasos aprobados</p>
                </div>
                
                <!-- Línea de Tiempo del Flujo -->
                <div class="mb-6">
                    <p class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-4">Pasos de Aprobación</p>
                    <div class="space-y-4">
                        ${flujo.pasos.map((paso, index) => {
                            const aprobacion = historial.find(h => h.numero_paso === paso.numero_paso);
                            const estado = aprobacion ? aprobacion.estado_aprobacion : 'PENDIENTE';
                            const isLast = index === flujo.pasos.length - 1;
                            
                            return `
                                <div class="relative">
                                    <!-- Línea conectora -->
                                    ${!isLast ? `<div class="absolute left-6 top-16 w-1 h-12 bg-gray-300 dark:bg-slate-600"></div>` : ''}
                                    
                                    <!-- Card del paso -->
                                    <div class="flex gap-4">
                                        <!-- Indicador -->
                                        <div class="flex flex-col items-center">
                                            <div class="w-12 h-12 rounded-full flex items-center justify-center font-bold text-white ${getColorPaso(estado)} shadow-md">
                                                ${estado === 'APROBADO' ? '<i class="fas fa-check"></i>' : estado === 'RECHAZADO' ? '<i class="fas fa-times"></i>' : paso.numero_paso}
                                            </div>
                                        </div>
                                        
                                        <!-- Contenido -->
                                        <div class="flex-1 bg-white dark:bg-slate-800 rounded-lg border border-gray-200 dark:border-slate-700 p-4">
                                            <div class="flex items-start justify-between mb-2">
                                                <div>
                                                    <h4 class="font-semibold text-gray-900 dark:text-white">${paso.nombre_paso}</h4>
                                                    <p class="text-xs text-gray-500 dark:text-gray-400">Paso ${paso.numero_paso} ${paso.es_final ? '(Final)' : ''}</p>
                                                </div>
                                                <span class="px-3 py-1 rounded-full text-xs font-semibold ${getColorEstadoBadge(estado)}">
                                                    ${estado}
                                                </span>
                                            </div>
                                            
                                            <p class="text-sm text-gray-600 dark:text-gray-300 mb-3">${paso.descripcion || 'Sin descripción'}</p>
                                            
                                            <!-- Información del aprobador -->
                                            ${aprobacion ? `
                                                <div class="bg-gray-50 dark:bg-slate-900/50 rounded p-3 text-sm">
                                                    <p class="text-gray-700 dark:text-gray-300"><strong>Aprobador:</strong> ${aprobacion.num_documento_aprobador || 'N/A'}</p>
                                                    <p class="text-gray-700 dark:text-gray-300"><strong>Fecha:</strong> ${new Date(aprobacion.fecha_aprobacion).toLocaleString('es-PE')}</p>
                                                    ${aprobacion.comentario ? `<p class="text-gray-700 dark:text-gray-300 mt-2"><strong>Comentario:</strong> ${aprobacion.comentario}</p>` : ''}
                                                </div>
                                            ` : `
                                                <div class="bg-yellow-50 dark:bg-yellow-900/20 rounded p-3 text-sm text-yellow-700 dark:text-yellow-300">
                                                    <i class="fas fa-clock mr-2"></i>Pendiente de aprobación
                                                </div>
                                            `}
                                        </div>
                                    </div>
                                </div>
                            `;
                        }).join('')}
                    </div>
                </div>
                
                <!-- Historial Completo -->
                ${historial.length > 0 ? `
                    <div class="bg-gray-50 dark:bg-slate-800/50 rounded-lg p-4 border border-gray-200 dark:border-slate-700">
                        <h4 class="font-semibold text-gray-900 dark:text-white mb-3">Historial de Cambios</h4>
                        <div class="space-y-2 max-h-32 overflow-y-auto">
                            ${historial.map(h => `
                                <div class="text-xs text-gray-600 dark:text-gray-400 flex justify-between">
                                    <span>${new Date(h.fecha_aprobacion).toLocaleString('es-PE')}</span>
                                    <span><strong>${h.estado_aprobacion}</strong> - Paso ${h.numero_paso}</span>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                ` : ''}
            </div>
            
            <!-- Footer -->
            <div class="flex gap-3 justify-end p-4 border-t border-gray-200 dark:border-slate-700 bg-white dark:bg-slate-900 flex-shrink-0">
                <button onclick="cerrarModalFlujo()" class="px-5 py-2 bg-gray-200 hover:bg-gray-300 dark:bg-slate-700 dark:hover:bg-slate-600 text-gray-900 dark:text-white rounded font-medium text-sm transition-colors">
                    Cerrar
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    modal.addEventListener('click', function(e) {
        if (e.target === modal) {
            cerrarModalFlujo();
        }
    });
}

/**
 * Cierra el modal del flujo
 */
function cerrarModalFlujo() {
    const modal = document.getElementById('modal-flujo-aprobacion');
    if (modal) {
        modal.remove();
    }
}

/**
 * Retorna clase de color según estado
 */
function getColorPaso(estado) {
    const colores = {
        'APROBADO': 'bg-green-500 dark:bg-green-600',
        'RECHAZADO': 'bg-red-500 dark:bg-red-600',
        'PENDIENTE': 'bg-yellow-500 dark:bg-yellow-600'
    };
    return colores[estado] || colores['PENDIENTE'];
}

/**
 * Retorna clase badge según estado
 */
function getColorEstadoBadge(estado) {
    const colores = {
        'APROBADO': 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300',
        'RECHAZADO': 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300',
        'PENDIENTE': 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300'
    };
    return colores[estado] || colores['PENDIENTE'];
}

/**
 * Retorna clase de color para estado principal
 */
function getColorEstado(estado) {
    const colores = {
        'APROBADO': 'text-green-600 dark:text-green-400',
        'RECHAZADO': 'text-red-600 dark:text-red-400',
        'PENDIENTE': 'text-yellow-600 dark:text-yellow-400'
    };
    return colores[estado] || colores['PENDIENTE'];
}
