/**
 * Kallpa - Tablas responsivas
 *
 * 1. Contenedores .overflow-x-auto con tabla: agrega las clases k-scroll-izq /
 *    k-scroll-der cuando hay columnas ocultas a un lado (fundido en el borde).
 * 2. Tablas con data-movil="tarjetas": copia el texto de cada <th> al atributo
 *    data-label de sus celdas, para mostrarlas como tarjetas en móvil.
 *
 * Funciona con filas generadas por JS (innerHTML) gracias a MutationObserver.
 * Los estilos están en static/css/responsive.css.
 */
(function () {
    'use strict';

    const contenedoresIniciados = new WeakSet();
    const tablasIniciadas = new WeakSet();

    // ---- 1. Indicador de scroll horizontal ---------------------------------

    function actualizarIndicador(contenedor) {
        const maxScroll = contenedor.scrollWidth - contenedor.clientWidth;
        const hayScroll = maxScroll > 2;
        contenedor.classList.toggle('k-scroll-izq', hayScroll && contenedor.scrollLeft > 2);
        contenedor.classList.toggle('k-scroll-der', hayScroll && contenedor.scrollLeft < maxScroll - 2);
    }

    const observadorTamano = typeof ResizeObserver !== 'undefined'
        ? new ResizeObserver(function (entradas) {
            entradas.forEach(function (entrada) {
                const contenedor = entrada.target.closest('.overflow-x-auto') || entrada.target;
                actualizarIndicador(contenedor);
            });
        })
        : null;

    function iniciarContenedor(contenedor) {
        if (contenedoresIniciados.has(contenedor)) return;
        const tabla = contenedor.querySelector(':scope > table');
        if (!tabla) return;
        contenedoresIniciados.add(contenedor);
        observarCeldas(tabla);

        let pendiente = false;
        contenedor.addEventListener('scroll', function () {
            if (pendiente) return;
            pendiente = true;
            requestAnimationFrame(function () {
                pendiente = false;
                actualizarIndicador(contenedor);
            });
        }, { passive: true });

        if (observadorTamano) {
            observadorTamano.observe(contenedor);
            observadorTamano.observe(tabla);
        } else {
            window.addEventListener('resize', function () { actualizarIndicador(contenedor); });
        }
        actualizarIndicador(contenedor);
    }

    // ---- 1b. Celdas cortas en una sola línea --------------------------------
    // Códigos, montos, fechas y estados no deben partirse en dos líneas;
    // los textos largos (descripciones) sí se ajustan.
    const LARGO_MAXIMO_SIN_CORTE = 16;

    function marcarCeldasCortas(tabla) {
        Array.from(tabla.tBodies).forEach(function (tbody) {
            Array.from(tbody.rows).forEach(function (fila) {
                Array.from(fila.cells).forEach(function (celda) {
                    if (celda.colSpan > 1 || celda.hasAttribute('data-k-medida')) return;
                    celda.setAttribute('data-k-medida', '');
                    const texto = celda.textContent.replace(/\s+/g, ' ').trim();
                    if (texto.length <= LARGO_MAXIMO_SIN_CORTE) celda.classList.add('k-sin-corte');
                });
            });
        });
    }

    function observarCeldas(tabla) {
        marcarCeldasCortas(tabla);
        let pendiente = false;
        new MutationObserver(function () {
            if (pendiente) return;
            pendiente = true;
            requestAnimationFrame(function () {
                pendiente = false;
                marcarCeldasCortas(tabla);
            });
        }).observe(tabla, { childList: true, subtree: true });
    }

    // ---- 2. Etiquetas para el modo tarjetas --------------------------------

    function obtenerEtiquetas(tabla) {
        const filasEncabezado = tabla.tHead ? tabla.tHead.rows : [];
        if (!filasEncabezado.length) return [];
        const ultimaFila = filasEncabezado[filasEncabezado.length - 1];
        const etiquetas = [];
        Array.from(ultimaFila.cells).forEach(function (th) {
            const texto = th.textContent.replace(/\s+/g, ' ').trim();
            const span = th.colSpan || 1;
            for (let i = 0; i < span; i++) etiquetas.push(texto);
        });
        return etiquetas;
    }

    function etiquetarFilas(tabla) {
        const etiquetas = obtenerEtiquetas(tabla);
        if (!etiquetas.length) return;
        Array.from(tabla.tBodies).forEach(function (tbody) {
            Array.from(tbody.rows).forEach(function (fila) {
                let indice = 0;
                Array.from(fila.cells).forEach(function (celda) {
                    const etiqueta = etiquetas[indice];
                    // Las filas de mensaje (colspan) y las columnas sin título no llevan etiqueta
                    if (celda.colSpan === 1 && etiqueta) {
                        if (celda.getAttribute('data-label') !== etiqueta) {
                            celda.setAttribute('data-label', etiqueta);
                        }
                    }
                    indice += celda.colSpan || 1;
                });
            });
        });
    }

    function iniciarTablaTarjetas(tabla) {
        if (tablasIniciadas.has(tabla)) return;
        tablasIniciadas.add(tabla);
        etiquetarFilas(tabla);

        let pendiente = false;
        new MutationObserver(function () {
            if (pendiente) return;
            pendiente = true;
            requestAnimationFrame(function () {
                pendiente = false;
                etiquetarFilas(tabla);
            });
        }).observe(tabla, { childList: true, subtree: true });
    }

    // ---- Inicialización -----------------------------------------------------

    function escanear(raiz) {
        raiz.querySelectorAll('.overflow-x-auto').forEach(iniciarContenedor);
        raiz.querySelectorAll('table[data-movil="tarjetas"]').forEach(iniciarTablaTarjetas);
    }

    function iniciar() {
        escanear(document);

        // Tablas que se crean después (modales, contenido generado por JS)
        let pendiente = false;
        new MutationObserver(function () {
            if (pendiente) return;
            pendiente = true;
            requestAnimationFrame(function () {
                pendiente = false;
                escanear(document);
            });
        }).observe(document.body, { childList: true, subtree: true });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }
})();
