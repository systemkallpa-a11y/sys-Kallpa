/**
 * Lógica única para crear requerimientos.
 * Se carga tanto en el Dashboard (acción rápida) como en el módulo /requerimiento.
 *
 * Regla: el requerimiento siempre nace de un presupuesto APROBADO.
 * El código y la fecha los genera la base de datos mediante
 * sp_CrearRequerimientoCompleto.
 */
(function () {
    'use strict';

    let itemsRequerimiento = [];
    let ultimosDetallesPresupuesto = [];
    let mostrarItemsSinSaldo = false;

    document.addEventListener('DOMContentLoaded', function () {
        const botonCrear = document.getElementById('btn-crear-requerimiento');
        if (botonCrear) {
            botonCrear.addEventListener('click', abrirModalRequerimiento);
        }

        const formulario = document.getElementById('form-requerimiento');
        if (formulario) {
            formulario.addEventListener('submit', guardarRequerimiento);
        }

        // Permite abrir el modal desde un enlace: /requerimiento?nuevo=1
        const parametros = new URLSearchParams(window.location.search);
        if (parametros.get('nuevo') === '1' && document.getElementById('modal-requerimiento')) {
            abrirModalRequerimiento();
        }
    });

    function abrirModalRequerimiento() {
        const modal = document.getElementById('modal-requerimiento');
        if (!modal) return;

        itemsRequerimiento = [];
        limpiarModal();
        modal.classList.remove('hidden');
    }

    function cerrarModalRequerimiento() {
        const modal = document.getElementById('modal-requerimiento');
        if (!modal) return;

        modal.classList.add('hidden');
        limpiarModal();
    }

    function limpiarModal() {
        const buscador = document.getElementById('buscar-presupuesto');
        if (buscador) buscador.value = '';

        const contenido = document.getElementById('contenido-resultados');
        if (contenido) {
            contenido.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-sm text-center py-4">Realiza una búsqueda</p>';
        }

        const lista = document.getElementById('lista-requerimiento');
        if (lista) {
            lista.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-sm text-center py-4">Agrega items desde el presupuesto</p>';
        }

        const presupuesto = document.getElementById('id_presupuesto_selected');
        if (presupuesto) presupuesto.value = '';

        const descripcion = document.getElementById('descripcion');
        if (descripcion) descripcion.value = '';

        const observaciones = document.getElementById('observaciones');
        if (observaciones) observaciones.value = '';

        itemsRequerimiento = [];
        ultimosDetallesPresupuesto = [];
        mostrarItemsSinSaldo = false;
        actualizarResumen();
    }

    async function buscarPresupuesto() {
        const numero = (document.getElementById('buscar-presupuesto')?.value || '').trim();
        if (!numero) {
            alert('Ingresa número de presupuesto');
            return;
        }

        const contenido = document.getElementById('contenido-resultados');
        const lista = document.getElementById('lista-requerimiento');
        const presupuestoSeleccionado = document.getElementById('id_presupuesto_selected');

        try {
            const response = await fetch(`/api/presupuestos/buscar-por-numero?numero=${encodeURIComponent(numero)}`);
            const data = await response.json();

            if (data.success && data.data) {
                if (presupuestoSeleccionado) {
                    presupuestoSeleccionado.value = data.data.id_presupuesto;
                }

                // No permitir mezclar items de presupuestos distintos.
                itemsRequerimiento = [];
                renderizarItemsRequerimiento();
                actualizarResumen();

                const p = data.data;
                contenido.innerHTML = `
                    <div class="bg-white dark:bg-slate-700 p-4 rounded-lg border border-gray-200 dark:border-slate-600">
                        <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
                            <div>
                                <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">Número</p>
                                <p class="font-semibold text-gray-900 dark:text-white mt-1">${p.numero_presupuesto}</p>
                            </div>
                            <div>
                                <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">Obra</p>
                                <p class="font-semibold text-gray-900 dark:text-white mt-1">${p.nombre_obra || '-'}</p>
                            </div>
                            <div>
                                <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">Monto Total</p>
                                <p class="font-semibold text-gray-900 dark:text-white mt-1">S/ ${parseFloat(p.monto || 0).toFixed(2)}</p>
                            </div>
                            <div>
                                <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">Cant. Consumida</p>
                                <p class="font-semibold text-orange-600 dark:text-orange-400 mt-1">${parseFloat(p.cantidad_consumida || 0).toFixed(2)}</p>
                            </div>
                            <div>
                                <p class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">Cant. Disponible</p>
                                <p class="font-semibold ${parseFloat(p.cantidad_saldo || 0) > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'} mt-1">${parseFloat(p.cantidad_saldo || 0).toFixed(2)}</p>
                            </div>
                        </div>
                    </div>
                `;

                await cargarItemsPresupuesto(data.data.id_presupuesto);
            } else {
                if (presupuestoSeleccionado) presupuestoSeleccionado.value = '';
                itemsRequerimiento = [];
                ultimosDetallesPresupuesto = [];
                mostrarItemsSinSaldo = false;
                actualizarResumen();

                contenido.innerHTML = `
                    <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-900/50 p-4 rounded-lg">
                        <div class="flex items-start gap-3">
                            <i class="fas fa-exclamation-circle text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5"></i>
                            <div>
                                <p class="font-semibold text-red-800 dark:text-red-300 text-sm">No se encontró presupuesto</p>
                                <p class="text-red-700 dark:text-red-400 text-xs mt-1">Solo se pueden buscar presupuestos en estado <strong>APROBADO</strong></p>
                                <ul class="text-red-700 dark:text-red-400 text-xs mt-2 ml-4 list-disc space-y-0.5">
                                    <li>Verifica que el número sea correcto</li>
                                    <li>Asegúrate que el presupuesto esté <strong>APROBADO</strong></li>
                                    <li>Intenta nuevamente con otro número</li>
                                </ul>
                            </div>
                        </div>
                    </div>
                `;
                lista.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-sm text-center py-4">Agrega items desde el presupuesto</p>';
            }
        } catch (error) {
            console.error('Error al buscar presupuesto:', error);
            contenido.innerHTML = `
                <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-900/50 p-4 rounded-lg">
                    <div class="flex items-start gap-3">
                        <i class="fas fa-times-circle text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5"></i>
                        <div>
                            <p class="font-semibold text-red-800 dark:text-red-300 text-sm">Error en la búsqueda</p>
                            <p class="text-red-700 dark:text-red-400 text-xs mt-1">${error.message || 'Verifica tu conexión e intenta de nuevo'}</p>
                        </div>
                    </div>
                </div>
            `;
        }
    }

    async function cargarItemsPresupuesto(idPresupuesto) {
        try {
            const response = await fetch(`/api/presupuestos/obtener-detalles/${idPresupuesto}`);
            const data = await response.json();

            if (!data.success || !data.data || !data.data.detalles) {
                throw new Error(data.error || 'No se pudieron cargar los items del presupuesto');
            }

            ultimosDetallesPresupuesto = data.data.detalles;
            mostrarItemsSinSaldo = false;
            renderizarDetallesPresupuesto();
        } catch (error) {
            console.error('Error al cargar items del presupuesto:', error);
            const contenido = document.getElementById('contenido-resultados');
            contenido.innerHTML = `
                <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-900/50 p-4 rounded-lg">
                    <div class="flex items-start gap-3">
                        <i class="fas fa-times-circle text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5"></i>
                        <div>
                            <p class="font-semibold text-red-800 dark:text-red-300 text-sm">Error al cargar detalles</p>
                            <p class="text-red-700 dark:text-red-400 text-xs mt-1">${error.message || 'Verifica tu conexión e intenta de nuevo'}</p>
                        </div>
                    </div>
                </div>
            `;
        }
    }

    function obtenerSaldoItem(item) {
        const original = item.cantidad_original;
        const tieneOriginal = original !== null && original !== undefined;
        const saldo = parseFloat(item.cantidad_saldo);

        if (tieneOriginal && Number.isFinite(saldo)) {
            return saldo;
        }

        const cantidad = parseFloat(item.cantidad) || 0;
        const consumida = parseFloat(item.cantidad_consumida) || 0;
        return Math.max(cantidad - consumida, 0);
    }

    function renderizarDetallesPresupuesto() {
        const contenido = document.getElementById('contenido-resultados');
        if (!contenido) return;

        if (!ultimosDetallesPresupuesto.length) {
            contenido.innerHTML = `
                <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-900/50 p-4 rounded-lg">
                    <div class="flex items-start gap-3">
                        <i class="fas fa-info-circle text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5"></i>
                        <div>
                            <p class="font-semibold text-amber-800 dark:text-amber-300 text-sm">Presupuesto sin ítems</p>
                            <p class="text-amber-700 dark:text-amber-400 text-xs mt-1">Este presupuesto no tiene materiales ni servicios registrados.</p>
                        </div>
                    </div>
                </div>
            `;
            return;
        }

        const disponibles = ultimosDetallesPresupuesto.filter((item) => obtenerSaldoItem(item) > 0);
        const sinSaldo = ultimosDetallesPresupuesto.filter((item) => obtenerSaldoItem(item) <= 0);
        const visibles = mostrarItemsSinSaldo ? ultimosDetallesPresupuesto : disponibles;

        const resumen = `
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 pb-2 border-b border-gray-200 dark:border-slate-600">
                <p class="text-xs text-gray-600 dark:text-gray-400">
                    <span class="font-semibold text-green-600 dark:text-green-400">${disponibles.length}</span> con saldo disponible
                    · <span class="font-semibold text-red-600 dark:text-red-400">${sinSaldo.length}</span> sin saldo
                </p>
                <label class="inline-flex items-center gap-2 text-xs text-gray-600 dark:text-gray-400 cursor-pointer select-none">
                    <input type="checkbox" id="toggle-sin-saldo" class="rounded border-gray-300 text-slate-600 focus:ring-slate-500" ${mostrarItemsSinSaldo ? 'checked' : ''}>
                    Mostrar sin saldo
                </label>
            </div>
        `;

        if (visibles.length === 0) {
            contenido.innerHTML = resumen + `
                <p class="text-gray-500 dark:text-gray-400 text-sm text-center py-4">
                    Todos los ítems de este presupuesto ya fueron consumidos.
                </p>
            `;
        } else {
            contenido.innerHTML = resumen + visibles.map((item) => {
                const idInventario = item.id_inventario ?? '';
                const esPartida = (item.tipo_item || 'MATERIAL') === 'PARTIDA';
                const nombre = item.nombre_item || item.material_nombre || item.descripcion || 'Sin nombre';
                const saldo = obtenerSaldoItem(item);
                const consumido = parseFloat(item.cantidad_consumida || 0);
                const agregado = itemsRequerimiento.some((seleccionado) => seleccionado.id_detalle_presupuesto === item.id_detalle);
                const sinSaldoItem = saldo <= 0;

                const badgeEstado = agregado
                    ? '<span class="ml-1 px-2 py-0.5 rounded text-[10px] font-semibold bg-green-100 text-green-800">AGREGADO</span>'
                    : (sinSaldoItem ? '<span class="ml-1 px-2 py-0.5 rounded text-[10px] font-semibold bg-red-100 text-red-800">SIN SALDO</span>' : '');

                const boton = agregado
                    ? '<button type="button" disabled class="ml-2 px-3 py-1.5 bg-green-600 text-white rounded text-xs font-medium cursor-not-allowed"><i class="fas fa-check mr-1"></i>Agregado</button>'
                    : (sinSaldoItem
                        ? '<button type="button" disabled class="ml-2 px-3 py-1.5 bg-gray-300 dark:bg-slate-600 text-gray-600 dark:text-gray-300 rounded text-xs font-medium cursor-not-allowed">Sin saldo</button>'
                        : `<button type="button" class="btn-agregar-item ml-2 px-3 py-1.5 bg-slate-600 hover:bg-slate-700 text-white rounded text-xs font-medium transition-colors"
                                data-id-detalle="${item.id_detalle}"
                                data-id-inventario="${idInventario}"
                                data-nombre="${String(nombre).replace(/"/g, '&quot;')}"
                                data-cantidad="${saldo}"
                                data-tipo="${item.tipo_item || 'MATERIAL'}"
                                data-unidad="${item.unidad_nombre || item.unidad_abreviatura || 'und'}">
                            Agregar
                        </button>`);

                return `
                    <div class="bg-white dark:bg-slate-700 p-3 rounded-lg border ${sinSaldoItem ? 'border-red-200 dark:border-red-900/50 opacity-70' : 'border-gray-200 dark:border-slate-600'} flex items-center justify-between">
                        <div class="flex-1 min-w-0">
                            <p class="font-medium text-gray-900 dark:text-white text-sm">${nombre}${esPartida ? ' <span class="ml-1 px-2 py-0.5 rounded text-[10px] font-semibold bg-amber-100 text-amber-800">PARTIDA</span>' : ''}${badgeEstado}</p>
                            <p class="text-xs mt-1">
                                <span class="${saldo > 0 ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'} font-semibold">Disp: ${saldo.toFixed(2)}</span>
                                <span class="text-gray-600 dark:text-gray-400"> ${item.unidad_nombre || item.unidad_abreviatura || 'und'}</span>
                                ${consumido > 0 ? `<span class="text-gray-500 dark:text-gray-400"> · Consumido: ${consumido.toFixed(2)}</span>` : ''}
                            </p>
                        </div>
                        ${boton}
                    </div>
                `;
            }).join('');
        }

        const toggle = document.getElementById('toggle-sin-saldo');
        if (toggle) {
            toggle.addEventListener('change', function () {
                mostrarItemsSinSaldo = this.checked;
                renderizarDetallesPresupuesto();
            });
        }

        contenido.querySelectorAll('.btn-agregar-item').forEach((btn) => {
            btn.addEventListener('click', function () {
                agregarItem(
                    parseInt(this.dataset.idDetalle, 10),
                    this.dataset.nombre,
                    this.dataset.cantidad,
                    this.dataset.tipo,
                    this.dataset.unidad,
                    this.dataset.idInventario ? parseInt(this.dataset.idInventario, 10) : null
                );
            });
        });
    }

    function actualizarBotonesPresupuesto() {
        document.querySelectorAll('#contenido-resultados .btn-agregar-item').forEach((btn) => {
            const id = parseInt(btn.dataset.idDetalle, 10);
            const agregado = itemsRequerimiento.some((item) => item.id_detalle_presupuesto === id);
            if (agregado) {
                btn.disabled = true;
                btn.className = 'ml-2 px-3 py-1.5 bg-green-600 text-white rounded text-xs font-medium cursor-not-allowed';
                btn.innerHTML = '<i class="fas fa-check mr-1"></i>Agregado';
            }
        });
    }

    function agregarItem(idDetalle, nombre, cantidad, tipo, unidad, idInventario) {
        const yaExiste = itemsRequerimiento.some((item) => item.id_detalle_presupuesto === idDetalle);
        if (yaExiste) {
            alert('Este item ya fue agregado al requerimiento.');
            return;
        }

        const cantidadNumerica = parseFloat(cantidad);
        const cantidadFinal = Number.isFinite(cantidadNumerica) ? cantidadNumerica : 1;

        if (cantidadFinal <= 0) {
            alert('Este ítem ya no tiene saldo disponible en el presupuesto.');
            return;
        }

        itemsRequerimiento.push({
            id_detalle_presupuesto: idDetalle,
            id_inventario: idInventario,
            nombre: nombre,
            cantidad: cantidadFinal,
            cantidad_saldo: cantidadFinal,
            tipo_item: tipo || 'MATERIAL',
            unidad: unidad
        });

        renderizarItemsRequerimiento();
        actualizarResumen();
        actualizarBotonesPresupuesto();
    }

    function renderizarItemsRequerimiento() {
        const contenedor = document.getElementById('lista-requerimiento');
        if (!contenedor) return;

        if (itemsRequerimiento.length === 0) {
            contenedor.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-sm text-center py-4">Agrega items desde el presupuesto</p>';
            return;
        }

        contenedor.innerHTML = itemsRequerimiento.map((item, index) => `
            <div class="bg-white dark:bg-slate-700 p-3 rounded-lg border border-gray-200 dark:border-slate-600 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-slate-700/80 transition-colors">
                <div class="flex-1 min-w-0">
                    <p class="font-medium text-gray-900 dark:text-white text-sm truncate">${item.nombre}</p>
                    <p class="text-[11px] text-gray-500 dark:text-gray-400">${item.tipo_item} · ${item.unidad || 'und'} · Disponible: ${parseFloat(item.cantidad_saldo || 0).toFixed(2)}</p>
                </div>
                <div class="flex items-center gap-2 ml-2 flex-shrink-0">
                    <input type="number"
                           value="${item.cantidad}"
                           min="0.01"
                           max="${item.cantidad_saldo}"
                           step="0.01"
                           data-index="${index}"
                           class="input-cantidad w-20 px-2 py-1 border border-gray-300 dark:border-slate-500 rounded text-xs bg-white dark:bg-slate-600 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-slate-500">
                    <button type="button" class="btn-eliminar-item px-2 py-1 text-gray-600 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 rounded transition-colors" data-index="${index}">
                        <i class="fas fa-trash text-sm"></i>
                    </button>
                </div>
            </div>
        `).join('');

        document.querySelectorAll('#lista-requerimiento .input-cantidad').forEach((input) => {
            input.addEventListener('change', function () {
                cambiarCantidad(parseInt(this.dataset.index, 10), this.value);
            });
        });

        document.querySelectorAll('#lista-requerimiento .btn-eliminar-item').forEach((btn) => {
            btn.addEventListener('click', function () {
                eliminarItem(parseInt(this.dataset.index, 10));
            });
        });
    }

    function cambiarCantidad(index, cantidad) {
        const item = itemsRequerimiento[index];
        if (!item) return;

        const cantidadNumerica = parseFloat(cantidad);
        const maximo = parseFloat(item.cantidad_saldo) || 0;
        let cantidadFinal = Number.isFinite(cantidadNumerica) ? cantidadNumerica : 1;

        if (cantidadFinal > maximo) {
            alert(`La cantidad no puede superar el saldo disponible (${maximo.toFixed(2)} ${item.unidad || 'und'}).`);
            cantidadFinal = maximo;
        }

        item.cantidad = cantidadFinal;

        if (cantidadFinal !== cantidadNumerica) {
            renderizarItemsRequerimiento();
        }

        actualizarResumen();
    }

    function eliminarItem(index) {
        itemsRequerimiento.splice(index, 1);
        renderizarItemsRequerimiento();
        actualizarResumen();
        renderizarDetallesPresupuesto();
    }

    function actualizarResumen() {
        const totalItems = itemsRequerimiento.length;
        const materiales = itemsRequerimiento.filter((item) => item.tipo_item === 'MATERIAL').length;
        const servicios = itemsRequerimiento.filter((item) => item.tipo_item === 'SERVICIO' || item.tipo_item === 'PARTIDA').length;

        const elItems = document.getElementById('total-items');
        const elMateriales = document.getElementById('total-materiales');
        const elServicios = document.getElementById('total-servicios');

        if (elItems) elItems.textContent = totalItems;
        if (elMateriales) elMateriales.textContent = materiales;
        if (elServicios) elServicios.textContent = servicios;
    }

    async function guardarRequerimiento(event) {
        event.preventDefault();

        if (itemsRequerimiento.length === 0) {
            alert('Agrega al menos un item al requerimiento.');
            return;
        }

        const descripcion = (document.getElementById('descripcion')?.value || '').trim();
        if (!descripcion) {
            alert('La descripción del requerimiento es obligatoria.');
            return;
        }

        const observaciones = (document.getElementById('observaciones')?.value || '').trim();
        const idPresupuesto = parseInt(document.getElementById('id_presupuesto_selected')?.value || '', 10) || null;

        const itemsFinales = itemsRequerimiento.map((item, index) => {
            const input = document.querySelector(`#lista-requerimiento .input-cantidad[data-index="${index}"]`);
            const cantidadInput = parseFloat(input?.value);
            const cantidad = Number.isFinite(cantidadInput)
                ? cantidadInput
                : (parseFloat(item.cantidad) || 1);

            return {
                id_detalle_presupuesto: item.id_detalle_presupuesto,
                id_inventario: item.id_inventario,
                nombre: item.nombre,
                cantidad: cantidad,
                tipo_item: item.tipo_item
            };
        });

        if (itemsFinales.some((item) => !item.cantidad || item.cantidad <= 0)) {
            alert('Todas las cantidades deben ser mayores a cero.');
            return;
        }

        const itemExcedido = itemsFinales.find((itemFinal, index) => {
            const saldo = parseFloat(itemsRequerimiento[index].cantidad_saldo) || 0;
            return itemFinal.cantidad > saldo;
        });

        if (itemExcedido) {
            alert(`La cantidad de "${itemExcedido.nombre}" supera el saldo disponible en el presupuesto.`);
            return;
        }

        const botonGuardar = document.querySelector('button[form="form-requerimiento"]');
        if (botonGuardar) {
            botonGuardar.disabled = true;
            botonGuardar.innerHTML = '<i class="fas fa-spinner fa-spin text-sm"></i><span>Guardando...</span>';
        }

        try {
            const response = await fetch('/api/requerimientos/crear', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                body: JSON.stringify({
                    descripcion: descripcion,
                    observaciones: observaciones,
                    id_presupuesto: idPresupuesto,
                    items: itemsFinales
                })
            });

            const result = await response.json();

            if (!result.success) {
                throw new Error(result.error || 'No se pudo crear el requerimiento');
            }

            alert('Requerimiento creado correctamente: ' + (result.codigo || '') + '. Ya está disponible en el módulo de Requerimientos.');
            cerrarModalRequerimiento();

            // En el módulo refrescamos la tabla. En el Dashboard no redirigimos:
            // el requerimiento ya quedó registrado y aparece en el módulo.
            if (typeof window.cargarRequerimientos === 'function' && document.getElementById('requerimientos-lista')) {
                window.cargarRequerimientos();
            }
        } catch (error) {
            console.error('Error al crear requerimiento:', error);
            alert('Error al crear el requerimiento: ' + error.message);
        } finally {
            if (botonGuardar) {
                botonGuardar.disabled = false;
                botonGuardar.innerHTML = '<i class="fas fa-save text-sm"></i><span>Guardar</span>';
            }
        }
    }

    // Funciones usadas por onclick dentro del modal
    window.abrirModalRequerimiento = abrirModalRequerimiento;
    window.cerrarModalRequerimiento = cerrarModalRequerimiento;
    window.buscarPresupuesto = buscarPresupuesto;
})();
