/**
 * Script: ordenes_compra.js
 * Propósito: Manejar gestión de órdenes de compra
 * Fecha: 30 Julio 2026
 */

// Variables globales
let detalles_orden = [];
let id_contador_detalle = 0;
let currentOrdenId = null;

// Inicializar
document.addEventListener('DOMContentLoaded', function() {
    console.log('[OC] Script de órdenes de compra cargado');
});

/**
 * Crear nueva orden de compra
 */
async function crearOrdenCompra(idRequerimiento, detalles, observaciones = '') {
    try {
        console.log('[OC] Creando nueva orden de compra...');
        
        const response = await fetch('/api/ordenes-compra/crear', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id_requerimiento: idRequerimiento,
                detalles: detalles,
                observaciones: observaciones
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[OC] ✓ Orden creada:', result.numero_oc);
            mostrarExito('Orden de compra creada exitosamente');
            return result.id;
        } else {
            throw new Error(result.error);
        }
    } catch (error) {
        console.error('[OC] Error:', error);
        mostrarError('Error al crear orden: ' + error.message);
        return null;
    }
}

/**
 * Actualizar orden de compra
 */
async function actualizarOrdenCompra(idOrden, detalles, observaciones = '') {
    try {
        console.log('[OC] Actualizando orden de compra:', idOrden);
        
        const response = await fetch(`/api/ordenes-compra/actualizar/${idOrden}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                detalles: detalles,
                observaciones: observaciones
            })
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[OC] ✓ Orden actualizada');
            mostrarExito('Orden actualizada exitosamente');
            return true;
        } else {
            throw new Error(result.error);
        }
    } catch (error) {
        console.error('[OC] Error:', error);
        mostrarError('Error al actualizar orden: ' + error.message);
        return false;
    }
}

/**
 * Cambiar estado de orden de compra
 */
async function cambiarEstadoOrden(idOrden, nuevoEstado) {
    try {
        console.log('[OC] Cambiando estado de orden:', idOrden, 'a', nuevoEstado);
        
        const response = await fetch(`/api/ordenes-compra/cambiar-estado/${idOrden}/${nuevoEstado}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[OC] ✓ Estado cambiado a', nuevoEstado);
            mostrarExito('Estado actualizado');
            return true;
        } else {
            throw new Error(result.error);
        }
    } catch (error) {
        console.error('[OC] Error:', error);
        mostrarError('Error al cambiar estado: ' + error.message);
        return false;
    }
}

/**
 * Mostrar error
 */
function mostrarError(mensaje) {
    console.error('[OC] ERROR:', mensaje);
    if (typeof alert !== 'undefined') {
        alert('❌ ' + mensaje);
    }
}

/**
 * Mostrar éxito
 */
function mostrarExito(mensaje) {
    console.log('[OC] SUCCESS:', mensaje);
    if (typeof alert !== 'undefined') {
        alert('✅ ' + mensaje);
    }
}

/**
 * Agregar detalle de orden
 */
function agregarDetalleOrden(descripcion, cantidad, precioUnitario, idMaterial = null, observaciones = '') {
    const subtotal = cantidad * precioUnitario;
    
    const detalle = {
        id_temporal: ++id_contador_detalle,
        id_material: idMaterial,
        descripcion: descripcion,
        cantidad: cantidad,
        precio_unitario: precioUnitario,
        subtotal: subtotal,
        observaciones: observaciones
    };
    
    detalles_orden.push(detalle);
    console.log('[OC] Detalle agregado:', detalle);
    
    return detalle;
}

/**
 * Remover detalle de orden
 */
function removerDetalleOrden(idTemporal) {
    detalles_orden = detalles_orden.filter(d => d.id_temporal !== idTemporal);
    console.log('[OC] Detalle removido');
}

/**
 * Calcular total de orden
 */
function calcularTotalOrden() {
    return detalles_orden.reduce((sum, d) => sum + (d.subtotal || 0), 0);
}

/**
 * Limpiar detalles de orden
 */
function limpiarDetalles() {
    detalles_orden = [];
    id_contador_detalle = 0;
    console.log('[OC] Detalles limpios');
}
