/**
 * requerimiento_administrativo.js
 *
 * Funcionalidad propia del Requerimiento Administrativo (y consulta de obras desde Logística).
 * Se carga en base.html porque la campana de notificaciones lo usa desde cualquier página.
 *
 *   RQA.verDetalle(id)       -> detalle administrativo con Aprobar / Rechazar / Editar / Eliminar según permisos
 *   RQA.verDetalleObra(id)   -> detalle de obra SOLO CONSULTA (se gestiona en O.T)
 *   RQA.descargarPDF(id)     -> PDF (mismo generador que obras)
 *   RQA.editar(id) / RQA.eliminar(id) / RQA.aprobar(id) / RQA.rechazar(id)
 *
 * Tras cualquier cambio dispara el evento 'rqa:actualizado' en document (la pantalla de
 * Logística lo escucha para recargar la tabla) y refresca la campana si está disponible.
 */
(function () {
    'use strict';

    const API = '/api/requerimientos/administrativo';
    const MODAL_ID = 'modal-rqa-detalle';

    // ------------------------------------------------------------------ utilidades
    function esc(valor) {
        return String(valor ?? '')
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function fecha(valor, conHora = false) {
        if (!valor) return '-';
        const d = new Date(valor);
        if (isNaN(d)) return '-';
        return conHora
            ? d.toLocaleString('es-PE', { dateStyle: 'short', timeStyle: 'short' })
            : d.toLocaleDateString('es-PE');
    }

    function numero(valor) {
        const n = parseFloat(valor);
        return isNaN(n) ? '0.00' : n.toFixed(2);
    }

    const BADGES = {
        PENDIENTE: 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
        APROBADO: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
        RECHAZADO: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
    };

    function badge(estado) {
        const clase = BADGES[estado] || 'bg-gray-100 text-gray-800 dark:bg-slate-700 dark:text-gray-200';
        return `<span class="px-3 py-1 rounded-full text-xs font-bold ${clase}">${esc(estado || '-')}</span>`;
    }

    async function pedir(url, opciones = {}) {
        const response = await fetch(url, {
            headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
            ...opciones,
        });
        let data = {};
        try { data = await response.json(); } catch (e) { /* respuesta sin JSON */ }
        if (!response.ok || !data.success) {
            throw new Error(data.error || data.message || `Error ${response.status}`);
        }
        return data;
    }

    function notificarCambio() {
        document.dispatchEvent(new CustomEvent('rqa:actualizado'));
        if (typeof window.loadNotifications === 'function') {
            window.loadNotifications();
        }
    }

    function cerrarModal() {
        document.getElementById(MODAL_ID)?.remove();
    }

    // ------------------------------------------------------------------ piezas del modal
    function htmlPasos(pasos) {
        if (!pasos || pasos.length === 0) {
            return '<p class="text-sm text-gray-500 dark:text-gray-400">Sin pasos de aprobación.</p>';
        }
        return `<ol class="space-y-3">${pasos.map(p => {
            const icono = p.estado === 'APROBADO' ? 'fa-check-circle text-green-600'
                : p.estado === 'RECHAZADO' ? 'fa-times-circle text-red-600'
                : 'fa-clock text-yellow-500';
            return `
                <li class="flex items-start gap-3">
                    <i class="fas ${icono} mt-1"></i>
                    <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-gray-900 dark:text-white">
                            Paso ${esc(p.numero_paso)} · ${esc(p.nombre_cargo || p.nombre_paso || '')}
                            <span class="ml-2">${badge(p.estado)}</span>
                        </p>
                        ${p.nombre_aprobador ? `<p class="text-xs text-gray-600 dark:text-gray-400 mt-1">${esc(p.nombre_aprobador)} · ${fecha(p.fecha_aprobacion, true)}</p>` : ''}
                        ${p.comentario ? `<p class="text-xs text-gray-700 dark:text-gray-300 mt-1 italic">"${esc(p.comentario)}"</p>` : ''}
                    </div>
                </li>`;
        }).join('')}</ol>`;
    }

    function htmlItems(detalles) {
        if (!detalles || detalles.length === 0) {
            return '<p class="text-sm text-gray-500 dark:text-gray-400 text-center py-4">Sin items registrados</p>';
        }
        return `
            <div class="overflow-x-auto border border-gray-200 dark:border-slate-700 rounded-lg">
                <table class="w-full text-xs md:text-sm">
                    <thead class="bg-gray-100 dark:bg-slate-800">
                        <tr>
                            <th class="px-4 py-2 text-left font-bold text-gray-700 dark:text-gray-300">Código</th>
                            <th class="px-4 py-2 text-left font-bold text-gray-700 dark:text-gray-300">Descripción</th>
                            <th class="px-4 py-2 text-center font-bold text-gray-700 dark:text-gray-300">Cantidad</th>
                            <th class="px-4 py-2 text-center font-bold text-gray-700 dark:text-gray-300">Unidad</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200 dark:divide-slate-700">
                        ${detalles.map(d => `
                            <tr>
                                <td class="px-4 py-2 text-gray-600 dark:text-gray-400">${esc(d.material_codigo || '-')}</td>
                                <td class="px-4 py-2 text-gray-800 dark:text-gray-200">${esc(d.descripcion || d.material_nombre || '-')}</td>
                                <td class="px-4 py-2 text-center font-semibold text-gray-800 dark:text-gray-200">${numero(d.cantidad)}</td>
                                <td class="px-4 py-2 text-center text-gray-700 dark:text-gray-300">${esc(d.unidad_abreviatura || d.unidad_nombre || 'UND')}</td>
                            </tr>`).join('')}
                    </tbody>
                </table>
            </div>`;
    }

    function abrirModal({ titulo, subtitulo, colorHeader, cuerpo, botones }) {
        cerrarModal();
        const modal = document.createElement('div');
        modal.id = MODAL_ID;
        modal.className = 'fixed inset-0 bg-black/50 z-[90] flex items-center justify-center p-2 md:p-4 backdrop-blur-sm';
        modal.innerHTML = `
            <div class="bg-white dark:bg-slate-900 rounded-lg shadow-2xl max-w-4xl w-full max-h-[95vh] flex flex-col overflow-hidden">
                <div class="${colorHeader} text-white px-6 py-4 flex items-center justify-between flex-shrink-0">
                    <div class="min-w-0">
                        <h2 class="text-xl font-bold">${titulo}</h2>
                        <p class="text-white/80 text-sm mt-1">${subtitulo}</p>
                    </div>
                    <button type="button" data-rqa="cerrar" class="p-2 rounded-lg hover:bg-white/10" aria-label="Cerrar">
                        <i class="fas fa-times text-lg"></i>
                    </button>
                </div>
                <div class="flex-1 overflow-y-auto bg-gray-50 dark:bg-slate-950 p-4 md:p-6 space-y-4">${cuerpo}</div>
                <div class="bg-white dark:bg-slate-800 border-t border-gray-200 dark:border-slate-700 px-4 md:px-6 py-3 flex flex-wrap gap-2 justify-between items-center flex-shrink-0">
                    <div class="flex flex-wrap gap-2" data-rqa="acciones"></div>
                    <button type="button" data-rqa="cerrar" class="px-5 py-2 bg-gray-300 hover:bg-gray-400 dark:bg-slate-600 dark:hover:bg-slate-500 text-gray-900 dark:text-white rounded-lg text-sm font-medium">
                        <i class="fas fa-times mr-1"></i>Cerrar
                    </button>
                </div>
            </div>`;

        const acciones = modal.querySelector('[data-rqa="acciones"]');
        botones.forEach(b => {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = `px-4 py-2 ${b.clase} text-white rounded-lg text-sm font-medium flex items-center gap-2`;
            btn.innerHTML = `<i class="fas ${b.icono}"></i><span>${b.texto}</span>`;
            btn.addEventListener('click', b.accion);
            acciones.appendChild(btn);
        });

        modal.addEventListener('click', e => {
            if (e.target === modal || e.target.closest('[data-rqa="cerrar"]')) cerrarModal();
        });
        document.body.appendChild(modal);
    }

    function tarjeta(titulo, contenido) {
        return `
            <div class="bg-white dark:bg-slate-900 rounded-lg shadow-sm border border-gray-200 dark:border-slate-700 p-4">
                ${titulo ? `<h3 class="text-sm font-semibold text-gray-900 dark:text-white mb-3">${titulo}</h3>` : ''}
                ${contenido}
            </div>`;
    }

    function dato(etiqueta, valor) {
        return `
            <div>
                <p class="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-1">${etiqueta}</p>
                <div class="text-sm text-gray-900 dark:text-white">${valor}</div>
            </div>`;
    }

    // ------------------------------------------------------------------ detalle administrativo
    async function verDetalle(id) {
        document.getElementById('modal-detalles-pendientes')?.remove();
        let data;
        try {
            data = (await pedir(`${API}/${id}`)).data;
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo abrir', text: e.message });
            return;
        }

        const req = data.requerimiento;
        const permisos = data.permisos || {};

        const cuerpo = [
            tarjeta('', `
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                    ${dato('Código', `<span class="font-bold text-orange-600 dark:text-orange-400">${esc(req.codigo)}</span>`)}
                    ${dato('Tipo', 'Administrativo')}
                    ${dato('Estado', badge(req.estado))}
                    ${dato('Fecha de solicitud', fecha(req.fecha_creacion))}
                </div>`),
            `<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="md:col-span-2">${tarjeta('Descripción', `<p class="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">${esc(req.descripcion || '-')}</p>`)}</div>
                ${tarjeta('Solicitante', `<p class="text-sm font-medium text-gray-900 dark:text-white">${esc(req.usuario_completo || '-')}</p>`)}
            </div>`,
            tarjeta(`Materiales (${data.detalles.length})`, htmlItems(data.detalles)),
            req.observaciones ? tarjeta('Observaciones', `<p class="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">${esc(req.observaciones)}</p>`) : '',
            tarjeta('Flujo de aprobación', htmlPasos(data.pasos)),
        ].join('');

        const botones = [{ texto: 'PDF', icono: 'fa-file-pdf', clase: 'bg-orange-500 hover:bg-orange-600', accion: () => descargarPDF(id) }];
        if (permisos.puede_aprobar) {
            botones.push({ texto: 'Aprobar', icono: 'fa-check', clase: 'bg-green-600 hover:bg-green-700', accion: () => aprobar(id) });
            botones.push({ texto: 'Rechazar', icono: 'fa-times', clase: 'bg-red-600 hover:bg-red-700', accion: () => rechazar(id) });
        }
        if (permisos.puede_editar) {
            botones.push({ texto: 'Editar', icono: 'fa-edit', clase: 'bg-blue-600 hover:bg-blue-700', accion: () => editar(id, req) });
        }
        if (permisos.puede_eliminar) {
            botones.push({ texto: 'Eliminar', icono: 'fa-trash', clase: 'bg-gray-600 hover:bg-gray-700', accion: () => eliminar(id, req.codigo) });
        }

        abrirModal({
            titulo: 'Requerimiento Administrativo',
            subtitulo: esc(req.codigo),
            colorHeader: 'bg-gradient-to-r from-orange-600 to-orange-700',
            cuerpo,
            botones,
        });
    }

    // ------------------------------------------------------------------ detalle de obra (solo consulta)
    async function verDetalleObra(id) {
        let req, detalles, pasos;
        try {
            const resp = await pedir(`/api/requerimientos/obtener/${id}`);
            req = resp.data.requerimiento;
            detalles = resp.data.detalles || [];
            const flujo = await pedir(`/api/requerimientos/flujo/${id}`).catch(() => ({ data: [] }));
            pasos = flujo.data || [];
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo abrir', text: e.message });
            return;
        }

        const cuerpo = [
            `<div class="flex items-start gap-3 rounded-lg border border-blue-200 dark:border-blue-900/60 bg-blue-50 dark:bg-blue-900/20 px-4 py-3">
                <i class="fas fa-info-circle text-blue-600 dark:text-blue-400 mt-0.5"></i>
                <p class="text-xs text-blue-800 dark:text-blue-300">Requerimiento de obra en <strong>modo consulta</strong>. Se gestiona en <strong>O.T &rsaquo; Requerimiento de Obras</strong>.</p>
            </div>`,
            tarjeta('', `
                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                    ${dato('Código', `<span class="font-bold text-emerald-600 dark:text-emerald-400">${esc(req.codigo)}</span>`)}
                    ${dato('Presupuesto', esc(req.numero_presupuesto || '-'))}
                    ${dato('Estado', badge(req.estado))}
                    ${dato('Fecha', fecha(req.fecha_creacion))}
                </div>`),
            `<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="md:col-span-2">${tarjeta('Descripción', `<p class="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">${esc(req.descripcion || '-')}</p>`)}</div>
                ${tarjeta('Solicitante', `<p class="text-sm font-medium text-gray-900 dark:text-white">${esc((req.usuario_completo || '-').replace(/\s+/g, ' '))}</p>`)}
            </div>`,
            tarjeta(`Items (${detalles.length})`, htmlItems(detalles)),
            req.observaciones ? tarjeta('Observaciones', `<p class="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">${esc(req.observaciones)}</p>`) : '',
            tarjeta('Flujo de aprobación', htmlPasos(pasos.map(p => ({ ...p, estado: p.estado || 'PENDIENTE' })))),
        ].join('');

        abrirModal({
            titulo: 'Requerimiento de Obra',
            subtitulo: `${esc(req.codigo)} · solo consulta`,
            colorHeader: 'bg-gradient-to-r from-emerald-700 to-emerald-800',
            cuerpo,
            botones: [{ texto: 'PDF', icono: 'fa-file-pdf', clase: 'bg-orange-500 hover:bg-orange-600', accion: () => descargarPDF(id) }],
        });
    }

    // ------------------------------------------------------------------ PDF
    async function descargarPDF(id) {
        try {
            const response = await fetch(`/api/requerimientos/descargar/${id}`);
            if (!response.ok) throw new Error(`Error ${response.status}`);
            const blob = await response.blob();
            const disposition = response.headers.get('Content-Disposition') || '';
            const match = disposition.match(/filename="?([^"]+)"?/);
            const enlace = document.createElement('a');
            enlace.href = URL.createObjectURL(blob);
            enlace.download = match ? match[1] : `requerimiento-${id}.pdf`;
            document.body.appendChild(enlace);
            enlace.click();
            enlace.remove();
            setTimeout(() => URL.revokeObjectURL(enlace.href), 1000);
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'Error', text: 'No se pudo descargar el PDF' });
        }
    }

    // ------------------------------------------------------------------ acciones
    async function aprobar(id) {
        const confirmacion = await Swal.fire({
            icon: 'question',
            title: '¿Aprobar el requerimiento?',
            input: 'textarea',
            inputPlaceholder: 'Comentario (opcional)',
            showCancelButton: true,
            confirmButtonText: 'Aprobar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#16a34a',
        });
        if (!confirmacion.isConfirmed) return;

        try {
            const data = await pedir(`${API}/${id}/aprobar`, {
                method: 'PUT',
                body: JSON.stringify({ comentario: confirmacion.value || '' }),
            });
            cerrarModal();
            notificarCambio();
            Swal.fire({ icon: 'success', title: 'Aprobado', text: data.message });
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo aprobar', text: e.message });
        }
    }

    async function rechazar(id) {
        const confirmacion = await Swal.fire({
            icon: 'warning',
            title: '¿Rechazar el requerimiento?',
            text: 'El stock descontado se repondrá al almacén.',
            input: 'textarea',
            inputPlaceholder: 'Motivo del rechazo (obligatorio)',
            inputValidator: v => (!v || !v.trim()) ? 'Debe indicar el motivo del rechazo' : undefined,
            showCancelButton: true,
            confirmButtonText: 'Rechazar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#dc2626',
        });
        if (!confirmacion.isConfirmed) return;

        try {
            const data = await pedir(`${API}/${id}/rechazar`, {
                method: 'PUT',
                body: JSON.stringify({ comentario: confirmacion.value.trim() }),
            });
            cerrarModal();
            notificarCambio();
            Swal.fire({ icon: 'success', title: 'Rechazado', text: data.message });
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo rechazar', text: e.message });
        }
    }

    async function editar(id, req) {
        if (!req) {
            try {
                req = (await pedir(`${API}/${id}`)).data.requerimiento;
            } catch (e) {
                Swal.fire({ icon: 'error', title: 'No se pudo abrir', text: e.message });
                return;
            }
        }

        const resultado = await Swal.fire({
            title: `Editar ${esc(req.codigo)}`,
            html: `
                <div class="text-left space-y-3">
                    <label class="block text-sm font-semibold">Descripción <span class="text-red-500">*</span></label>
                    <textarea id="rqa-edit-descripcion" rows="3" class="swal2-textarea" style="margin:0;width:100%">${esc(req.descripcion || '')}</textarea>
                    <label class="block text-sm font-semibold">Observaciones</label>
                    <textarea id="rqa-edit-observaciones" rows="3" class="swal2-textarea" style="margin:0;width:100%">${esc(req.observaciones || '')}</textarea>
                    <p class="text-xs text-gray-500">Los materiales y cantidades no se pueden modificar.</p>
                </div>`,
            showCancelButton: true,
            confirmButtonText: 'Guardar',
            cancelButtonText: 'Cancelar',
            focusConfirm: false,
            preConfirm: () => {
                const descripcion = document.getElementById('rqa-edit-descripcion').value.trim();
                if (!descripcion) {
                    Swal.showValidationMessage('La descripción es obligatoria');
                    return false;
                }
                return {
                    descripcion,
                    observaciones: document.getElementById('rqa-edit-observaciones').value.trim(),
                };
            },
        });
        if (!resultado.isConfirmed) return;

        try {
            const data = await pedir(`${API}/${id}`, { method: 'PUT', body: JSON.stringify(resultado.value) });
            cerrarModal();
            notificarCambio();
            Swal.fire({ icon: 'success', title: 'Actualizado', text: data.message, timer: 2000 });
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo actualizar', text: e.message });
        }
    }

    async function eliminar(id, codigo) {
        const confirmacion = await Swal.fire({
            icon: 'warning',
            title: `¿Eliminar ${esc(codigo || 'el requerimiento')}?`,
            text: 'Se eliminará el requerimiento y el stock descontado se repondrá al almacén. Esta acción no se puede deshacer.',
            showCancelButton: true,
            confirmButtonText: 'Eliminar',
            cancelButtonText: 'Cancelar',
            confirmButtonColor: '#dc2626',
        });
        if (!confirmacion.isConfirmed) return;

        try {
            const data = await pedir(`${API}/${id}`, { method: 'DELETE' });
            cerrarModal();
            notificarCambio();
            Swal.fire({ icon: 'success', title: 'Eliminado', text: data.message });
        } catch (e) {
            Swal.fire({ icon: 'error', title: 'No se pudo eliminar', text: e.message });
        }
    }

    window.RQA = { verDetalle, verDetalleObra, descargarPDF, aprobar, rechazar, editar, eliminar, esc, badge, fecha };
})();
