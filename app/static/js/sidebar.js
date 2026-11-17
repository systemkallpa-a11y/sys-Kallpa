/**
 * sidebar.js
 * Controla el sidebar con un solo botón (#mobile-menu-btn, en el header):
 *  - Escritorio (>= 768px): alterna entre expandido y compacto (solo iconos).
 *    El estado se recuerda en localStorage ('sidebar-colapsado').
 *  - Móvil (< 768px): abre/cierra el cajón lateral con su fondo oscuro.
 * Las animaciones están en responsive.css (sección "Sidebar").
 */
(function () {
    const MQ_ESCRITORIO = window.matchMedia('(min-width: 768px)');
    const CLAVE_COMPACTO = 'sidebar-colapsado';

    function guardar(clave, valor) {
        try { localStorage.setItem(clave, valor); } catch (e) { /* sin localStorage */ }
    }

    document.addEventListener('DOMContentLoaded', function () {
        const sidebar = document.getElementById('sidebar');
        const overlay = document.getElementById('sidebar-overlay');
        const boton = document.getElementById('mobile-menu-btn');
        const botonCerrar = document.getElementById('sidebar-cerrar-movil');
        if (!sidebar || !overlay || !boton) return;

        // Activar transiciones después del primer pintado (el estado inicial no se anima)
        requestAnimationFrame(function () {
            requestAnimationFrame(function () { sidebar.classList.remove('k-sin-transicion'); });
        });

        // ---------- Escritorio: modo compacto ----------
        function esCompacto() {
            return sidebar.classList.contains('sidebar-compacto');
        }

        function aplicarCompacto(compacto) {
            sidebar.classList.toggle('sidebar-compacto', compacto);
            guardar(CLAVE_COMPACTO, compacto ? '1' : '0');
            actualizarBoton();
        }

        // ---------- Móvil: cajón ----------
        function cajonAbierto() {
            return sidebar.classList.contains('abierto-movil');
        }

        function abrirCajon() {
            sidebar.classList.add('abierto-movil');
            overlay.classList.add('visible');
            document.body.style.overflow = 'hidden';
            actualizarBoton();
            // Llevar el foco dentro del cajón
            const primerEnlace = sidebar.querySelector('#menu-container a, #menu-container button');
            (primerEnlace || botonCerrar || sidebar).focus({ preventScroll: true });
        }

        function cerrarCajon(devolverFoco) {
            if (!cajonAbierto()) return;
            sidebar.classList.remove('abierto-movil');
            overlay.classList.remove('visible');
            document.body.style.overflow = '';
            actualizarBoton();
            if (devolverFoco) boton.focus();
        }

        // ---------- Estado accesible del botón ----------
        function actualizarBoton() {
            if (MQ_ESCRITORIO.matches) {
                const compacto = esCompacto();
                boton.setAttribute('aria-expanded', String(!compacto));
                boton.setAttribute('aria-label', compacto ? 'Expandir menú lateral' : 'Contraer menú lateral');
                boton.title = compacto ? 'Expandir menú' : 'Contraer menú';
            } else {
                const abierto = cajonAbierto();
                boton.setAttribute('aria-expanded', String(abierto));
                boton.setAttribute('aria-label', abierto ? 'Cerrar menú' : 'Abrir menú');
                boton.title = '';
            }
        }

        // ---------- Eventos ----------
        boton.addEventListener('click', function (e) {
            e.preventDefault();
            if (MQ_ESCRITORIO.matches) {
                aplicarCompacto(!esCompacto());
            } else if (cajonAbierto()) {
                cerrarCajon(false);
            } else {
                abrirCajon();
            }
        });

        overlay.addEventListener('click', function () { cerrarCajon(true); });
        if (botonCerrar) botonCerrar.addEventListener('click', function () { cerrarCajon(true); });

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && !MQ_ESCRITORIO.matches && cajonAbierto()) {
                cerrarCajon(true);
            }
        });

        // En móvil, al navegar a otra página se cierra el cajón
        sidebar.addEventListener('click', function (e) {
            if (MQ_ESCRITORIO.matches) return;
            const enlace = e.target.closest('a[href]');
            if (enlace && enlace.getAttribute('href') !== '#') cerrarCajon(false);
        });

        // Si en modo compacto se pulsa un grupo con submenús, expandir el sidebar
        // (el grupo se abre desde sidebar-accesos.js)
        sidebar.addEventListener('k-expandir-sidebar', function () {
            if (MQ_ESCRITORIO.matches && esCompacto()) aplicarCompacto(false);
        });

        // Al cambiar entre móvil y escritorio, limpiar el estado del otro modo
        MQ_ESCRITORIO.addEventListener('change', function () {
            sidebar.classList.add('k-sin-transicion');
            if (MQ_ESCRITORIO.matches) {
                cerrarCajon(false);
                let guardado = null;
                try { guardado = localStorage.getItem(CLAVE_COMPACTO); } catch (e) { /* nada */ }
                sidebar.classList.toggle('sidebar-compacto', guardado === '1');
            } else {
                sidebar.classList.remove('sidebar-compacto');
            }
            actualizarBoton();
            requestAnimationFrame(function () {
                requestAnimationFrame(function () { sidebar.classList.remove('k-sin-transicion'); });
            });
        });

        actualizarBoton();
    });
})();
