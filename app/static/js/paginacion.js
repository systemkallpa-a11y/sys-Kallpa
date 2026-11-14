/**
 * Kallpa - Paginación común para tablas
 *
 * Uso: agregar data-paginar="20" a la <table> (el número son las filas por página).
 * - Funciona con filas generadas por JS: cuando el tbody cambia, se recalcula.
 * - Si cambia la cantidad de filas (filtro nuevo) vuelve a la página 1;
 *   si solo se refrescan los datos, se mantiene en la página actual.
 * - Las filas de mensaje ("Cargando...", "No hay datos", con colspan) no cuentan.
 * - Debajo de la tabla agrega: "Mostrando X-Y de Z", selector de filas por página
 *   y botones « ‹ 1 2 3 › ».
 */
(function () {
    'use strict';

    const TAMANOS = [10, 20, 50];
    const MAX_BOTONES = 5;

    const CLASE_BTN = 'min-w-[2rem] h-8 px-2 rounded text-xs font-medium transition-colors';
    const CLASE_NORMAL = CLASE_BTN + ' bg-white dark:bg-slate-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-700 border border-gray-300 dark:border-slate-600';
    const CLASE_ACTIVO = CLASE_BTN + ' bg-blue-600 text-white border border-blue-600';
    const CLASE_INACTIVO = CLASE_BTN + ' bg-gray-100 dark:bg-slate-800/60 text-gray-400 dark:text-slate-600 border border-gray-200 dark:border-slate-700 cursor-not-allowed';

    function esFilaMensaje(fila) {
        return fila.cells.length === 1 && fila.cells[0].colSpan > 1;
    }

    function Paginador(tabla) {
        this.tabla = tabla;
        this.tbody = tabla.tBodies[0];
        // En celular (modo tarjetas) cada fila ocupa mucho alto: 10 por página
        const esMovil = window.matchMedia('(max-width: 639.98px)').matches;
        this.porPagina = esMovil ? TAMANOS[0] : (parseInt(tabla.getAttribute('data-paginar'), 10) || 20);
        this.pagina = 1;
        this.total = -1;

        this.pie = document.createElement('nav');
        this.pie.setAttribute('aria-label', 'Paginación de la tabla');
        this.pie.className = 'k-paginacion hidden px-4 py-3 bg-gray-50 dark:bg-slate-800/60 border-t border-gray-200 dark:border-slate-700';
        const ancla = tabla.closest('.overflow-x-auto') || tabla;
        ancla.insertAdjacentElement('afterend', this.pie);

        const self = this;
        this.pie.addEventListener('click', function (e) {
            const boton = e.target.closest('button[data-pagina]');
            if (!boton || boton.disabled) return;
            self.irA(parseInt(boton.getAttribute('data-pagina'), 10));
        });
        this.pie.addEventListener('change', function (e) {
            if (!e.target.matches('select')) return;
            self.porPagina = parseInt(e.target.value, 10);
            self.pagina = 1;
            self.actualizar();
        });

        let pendiente = false;
        new MutationObserver(function () {
            if (pendiente) return;
            pendiente = true;
            requestAnimationFrame(function () {
                pendiente = false;
                self.actualizar();
            });
        }).observe(this.tbody, { childList: true });

        this.actualizar();
    }

    Paginador.prototype.filas = function () {
        return Array.from(this.tbody.rows).filter(function (f) { return !esFilaMensaje(f); });
    };

    Paginador.prototype.irA = function (pagina) {
        this.pagina = pagina;
        this.actualizar();
        // Llevar la vista al inicio de la tabla si quedó fuera de pantalla
        const caja = this.tabla.getBoundingClientRect();
        if (caja.top < 0) {
            this.tabla.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    };

    Paginador.prototype.actualizar = function () {
        const filas = this.filas();
        if (filas.length !== this.total) {
            this.total = filas.length;
            this.pagina = 1;
        }

        const totalPaginas = Math.max(1, Math.ceil(this.total / this.porPagina));
        if (this.pagina > totalPaginas) this.pagina = totalPaginas;
        const inicio = (this.pagina - 1) * this.porPagina;
        const fin = Math.min(inicio + this.porPagina, this.total);

        filas.forEach(function (fila, i) {
            fila.classList.toggle('k-pag-oculta', i < inicio || i >= fin);
        });

        this.dibujar(inicio, fin, totalPaginas);
    };

    Paginador.prototype.dibujar = function (inicio, fin, totalPaginas) {
        if (this.total === 0) {
            this.pie.classList.add('hidden');
            this.pie.innerHTML = '';
            return;
        }
        this.pie.classList.remove('hidden');

        const resumen = totalPaginas > 1
            ? 'Mostrando <span class="font-semibold text-gray-700 dark:text-gray-200">' + (inicio + 1) + '-' + fin +
              '</span> de <span class="font-semibold text-gray-700 dark:text-gray-200">' + this.total + '</span> registros'
            : 'Mostrando <span class="font-semibold text-gray-700 dark:text-gray-200">' + this.total + '</span> registro' + (this.total !== 1 ? 's' : '');

        let selector = '';
        if (this.total > TAMANOS[0]) {
            const porPagina = this.porPagina;
            selector =
                '<label class="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">Filas' +
                '<select class="h-8 px-2 rounded border border-gray-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-gray-700 dark:text-gray-200 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500" aria-label="Filas por página">' +
                TAMANOS.map(function (n) {
                    return '<option value="' + n + '"' + (n === porPagina ? ' selected' : '') + '>' + n + '</option>';
                }).join('') +
                '</select></label>';
        }

        let botones = '';
        if (totalPaginas > 1) {
            const p = this.pagina;
            const boton = function (destino, contenido, etiqueta, deshabilitado, activo) {
                const clase = activo ? CLASE_ACTIVO : (deshabilitado ? CLASE_INACTIVO : CLASE_NORMAL);
                return '<button type="button" data-pagina="' + destino + '" aria-label="' + etiqueta + '"' +
                    (activo ? ' aria-current="page"' : '') + (deshabilitado ? ' disabled' : '') +
                    ' class="' + clase + '">' + contenido + '</button>';
            };
            const puntos = '<span class="px-1 text-xs text-gray-400" aria-hidden="true">…</span>';

            let desde = Math.max(1, p - Math.floor(MAX_BOTONES / 2));
            const hasta = Math.min(totalPaginas, desde + MAX_BOTONES - 1);
            desde = Math.max(1, hasta - MAX_BOTONES + 1);

            botones += boton(1, '<i class="fas fa-angle-double-left" aria-hidden="true"></i>', 'Primera página', p === 1);
            botones += boton(p - 1, '<i class="fas fa-angle-left" aria-hidden="true"></i>', 'Página anterior', p === 1);
            if (desde > 1) botones += puntos;
            for (let i = desde; i <= hasta; i++) {
                botones += boton(i, String(i), 'Página ' + i, false, i === p);
            }
            if (hasta < totalPaginas) botones += puntos;
            botones += boton(p + 1, '<i class="fas fa-angle-right" aria-hidden="true"></i>', 'Página siguiente', p === totalPaginas);
            botones += boton(totalPaginas, '<i class="fas fa-angle-double-right" aria-hidden="true"></i>', 'Última página', p === totalPaginas);
        }

        this.pie.innerHTML =
            '<div class="flex flex-col sm:flex-row items-center justify-between gap-3">' +
                '<div class="flex items-center gap-4">' +
                    '<span class="text-xs text-gray-500 dark:text-gray-400" aria-live="polite">' + resumen + '</span>' +
                    selector +
                '</div>' +
                (botones ? '<div class="flex flex-wrap items-center justify-center gap-1">' + botones + '</div>' : '') +
            '</div>';
    };

    const iniciadas = new WeakSet();

    function escanear() {
        document.querySelectorAll('table[data-paginar]').forEach(function (tabla) {
            if (iniciadas.has(tabla) || !tabla.tBodies[0]) return;
            iniciadas.add(tabla);
            new Paginador(tabla);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', escanear);
    } else {
        escanear();
    }
})();
