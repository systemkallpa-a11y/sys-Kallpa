/**
 * sidebar-accesos.js
 * Construye el menú del sidebar según los accesos del usuario (TblUsuarioAccesos).
 *  - Cada menú con submenús es un grupo desplegable (animado en responsive.css).
 *  - La página actual queda resaltada y su grupo se abre automáticamente.
 *  - Los menús sin ningún submenú no se muestran (no tienen a dónde llevar).
 */

document.addEventListener('DOMContentLoaded', cargarMenuSidebar);

async function cargarMenuSidebar() {
    const contenedor = document.getElementById('menu-container');
    if (!contenedor) return;

    try {
        const response = await fetch('/api/mi-acceso/obtener', {
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        const result = await response.json();
        if (!result.success) throw new Error(result.error || 'Respuesta sin éxito');

        renderizarSidebar(result.menus || [], result.submenus || []);
    } catch (error) {
        console.error('[SIDEBAR] Error al cargar accesos:', error);
        contenedor.innerHTML = `
            <div class="px-3 py-6 text-center text-gray-500 dark:text-gray-400">
                <i class="fas fa-triangle-exclamation text-xl mb-2 block" aria-hidden="true"></i>
                <p class="k-etiqueta text-sm mb-3">No se pudo cargar el menú</p>
                <button type="button" class="k-etiqueta text-sm font-semibold text-violet-600 dark:text-violet-400 hover:underline">Reintentar</button>
            </div>`;
        contenedor.querySelector('button').addEventListener('click', function () {
            contenedor.innerHTML = '<div class="h-10 rounded-lg bg-gray-100 dark:bg-slate-800 animate-pulse"></div>';
            cargarMenuSidebar();
        });
    } finally {
        contenedor.removeAttribute('aria-busy');
    }
}

/** Ruta normalizada sin barra final (para comparar con la página actual). */
function normalizarRuta(ruta) {
    try {
        const p = new URL(ruta, window.location.origin).pathname;
        return p.length > 1 ? p.replace(/\/+$/, '') : p;
    } catch (e) {
        return '';
    }
}

function crearIcono(clase, extra) {
    const i = document.createElement('i');
    i.className = `fas ${clase} ${extra}`;
    i.setAttribute('aria-hidden', 'true');
    return i;
}

function renderizarSidebar(menus, submenus) {
    const contenedor = document.getElementById('menu-container');
    contenedor.innerHTML = '';

    const rutaActual = normalizarRuta(window.location.pathname);
    const grupos = menus
        .map(menu => ({ menu, items: submenus.filter(sm => sm.id_menu === menu.id_menu && sm.ruta) }))
        .filter(g => g.items.length > 0);

    if (grupos.length === 0) {
        contenedor.innerHTML = `
            <div class="px-3 py-6 text-center text-gray-500 dark:text-gray-400">
                <i class="fas fa-lock text-xl mb-2 block" aria-hidden="true"></i>
                <p class="k-etiqueta text-sm">Sin accesos asignados</p>
            </div>`;
        return;
    }

    // Enlace que corresponde a la página actual: coincidencia exacta o la ruta más larga que la contiene
    let mejorRuta = '';
    grupos.forEach(g => g.items.forEach(sm => {
        const r = normalizarRuta(sm.ruta);
        if (r && r !== '/' && (rutaActual === r || rutaActual.startsWith(r + '/')) && r.length > mejorRuta.length) {
            mejorRuta = r;
        }
    }));

    grupos.forEach((grupo, indice) => {
        const { menu, items } = grupo;
        const idPanel = `submenu-${menu.id_menu || indice}`;
        const contieneActual = items.some(sm => normalizarRuta(sm.ruta) === mejorRuta);

        const bloque = document.createElement('div');
        bloque.className = 'k-grupo' + (contieneActual ? ' abierto' : '');

        // Botón del grupo
        const boton = document.createElement('button');
        boton.type = 'button';
        boton.className = 'k-item-menu' + (contieneActual ? ' contiene-actual' : '');
        boton.setAttribute('aria-expanded', String(contieneActual));
        boton.setAttribute('aria-controls', idPanel);
        boton.title = menu.nombre;
        boton.appendChild(crearIcono(menu.icono || 'fa-folder', 'k-icono'));
        const etiqueta = document.createElement('span');
        etiqueta.className = 'k-etiqueta flex-1 text-left truncate';
        etiqueta.textContent = menu.nombre;
        boton.appendChild(etiqueta);
        boton.appendChild(crearIcono('fa-chevron-down', 'k-chevron k-etiqueta'));
        boton.addEventListener('click', () => alternarGrupo(bloque));

        // Panel de submenús (la animación de altura usa grid-template-rows)
        const panel = document.createElement('div');
        panel.className = 'k-submenu';
        panel.id = idPanel;
        const interior = document.createElement('div');
        interior.className = 'k-submenu-interior';

        items.forEach(sm => {
            const enlace = document.createElement('a');
            enlace.href = sm.ruta;
            enlace.className = 'k-subitem';
            enlace.title = sm.nombre;
            if (normalizarRuta(sm.ruta) === mejorRuta) {
                enlace.classList.add('activo');
                enlace.setAttribute('aria-current', 'page');
            }
            enlace.appendChild(crearIcono(sm.icono || 'fa-file', 'k-icono-sub'));
            const texto = document.createElement('span');
            texto.className = 'truncate';
            texto.textContent = sm.nombre;
            enlace.appendChild(texto);
            interior.appendChild(enlace);
        });

        // Un grupo cerrado no debe recibir foco con Tab
        if (!contieneActual) interior.setAttribute('inert', '');

        panel.appendChild(interior);
        bloque.appendChild(boton);
        bloque.appendChild(panel);
        contenedor.appendChild(bloque);
    });
}

/** Abre/cierra un grupo. En modo compacto, primero expande el sidebar y deja el grupo abierto. */
function alternarGrupo(bloque) {
    const sidebar = document.getElementById('sidebar');
    const enCompacto = sidebar && sidebar.classList.contains('sidebar-compacto');
    const abrir = enCompacto ? true : !bloque.classList.contains('abierto');

    if (enCompacto) sidebar.dispatchEvent(new CustomEvent('k-expandir-sidebar'));

    bloque.classList.toggle('abierto', abrir);
    bloque.querySelector('.k-item-menu').setAttribute('aria-expanded', String(abrir));
    const interior = bloque.querySelector('.k-submenu-interior');
    if (abrir) interior.removeAttribute('inert'); else interior.setAttribute('inert', '');
}

/** Compatibilidad: código antiguo que llame a toggleSubmenu(boton). */
function toggleSubmenu(button) {
    const bloque = button && button.closest('.k-grupo');
    if (bloque) alternarGrupo(bloque);
}
