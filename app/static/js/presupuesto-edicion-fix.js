// ============================================================================
// FIX PARA EDICIÓN DE PRESUPUESTOS
// Script adicional para corregir el mapeo de datos en la edición
// ============================================================================

// Override de la función de carga de detalles
async function cargarDatosPresupuestoParaEditar(id_presupuesto) {
    try {
        console.log('[EDITAR] Cargando presupuesto:', id_presupuesto);
        
        // Llamar al nuevo endpoint mejorado
        const response = await fetch(`/api/presupuestos/obtener-para-editar/${id_presupuesto}`);
        const result = await response.json();
        
        if (!result.success) {
            console.error('[EDITAR] Error:', result.error);
            mostrarError('Error al cargar presupuesto');
            return;
        }
        
        const { presupuesto, data } = result.data;
        
        console.log('[EDITAR] ✓ Presupuesto cargado:', presupuesto);
        console.log('[EDITAR] ✓ Detalles:', data);
        
        // Limpiar arrays globales
        materiales_agregados = [];
        servicios_agregados = [];
        id_contador_material = 0;
        id_contador_servicio = 0;
        
        // RECARGAR MATERIALES CORRECTAMENTE
        if (data.materiales && Array.isArray(data.materiales)) {
            console.log('[EDITAR] Procesando', data.materiales.length, 'materiales');
            data.materiales.forEach(m => {
                id_contador_material++;
                materiales_agregados.push({
                    id_temporal: id_contador_material,
                    id_detalle: m.id_detalle,
                    id_material: m.id_material,
                    nombre: m.nombre || 'Sin nombre',  // ← AQUI ESTÁ EL FIX
                    codigo: m.codigo || '',
                    categoria: m.categoria || '',
                    unidad: m.unidad || 'und',
                    cantidad: parseFloat(m.cantidad) || 0,
                    precio_unitario: parseFloat(m.precio_unitario) || 0,
                    subtotal: parseFloat(m.subtotal) || 0
                });
                console.log('[EDITAR] Material agregado:', m.nombre);
            });
        }
        
        // RECARGAR SERVICIOS CORRECTAMENTE
        if (data.servicios && Array.isArray(data.servicios)) {
            console.log('[EDITAR] Procesando', data.servicios.length, 'servicios');
            data.servicios.forEach(s => {
                id_contador_servicio++;
                servicios_agregados.push({
                    id_temporal: id_contador_servicio,
                    id_detalle: s.id_detalle,
                    descripcion: s.descripcion || '',
                    cantidad: parseFloat(s.cantidad) || 0,
                    precio_unitario: parseFloat(s.precio_unitario) || 0,
                    subtotal: parseFloat(s.subtotal) || 0
                });
                console.log('[EDITAR] Servicio agregado:', s.descripcion);
            });
        }
        
        // Rellenar el formulario
        document.getElementById('id_empresa').value = presupuesto.id_empresa || '';
        document.getElementById('id_proyecto').value = presupuesto.id_proyecto || '';
        document.getElementById('id_obra').value = presupuesto.id_obra || '';
        document.getElementById('comentarios').value = presupuesto.observaciones || '';
        
        // Actualizar modal
        document.getElementById('modal-titulo').textContent = `Editar Presupuesto #${presupuesto.numero_presupuesto}`;
        document.getElementById('form-presupuesto').dataset.id_presupuesto = id_presupuesto;
        document.getElementById('form-presupuesto').dataset.modo = 'edicion';
        
        // Renderizar tablas
        renderizarMateriales();
        renderizarServicios();
        actualizarTotales();
        
        // Mostrar modal
        document.getElementById('modal-presupuesto').classList.remove('hidden');
        
        console.log('[EDITAR] ✓ Presupuesto cargado correctamente');
        console.log('[EDITAR] Total materiales:', materiales_agregados.length);
        console.log('[EDITAR] Total servicios:', servicios_agregados.length);
        
    } catch (error) {
        console.error('[EDITAR] Error:', error);
        mostrarError('Error al cargar presupuesto: ' + error.message);
    }
}

// Asegurar que la función se llama cuando se edita
// Esto sobrescribe la anterior que podría tener datos incompletos
console.log('[PRESUPUESTO-EDICION-FIX] Script cargado - Fix aplicado para edición de presupuestos');
