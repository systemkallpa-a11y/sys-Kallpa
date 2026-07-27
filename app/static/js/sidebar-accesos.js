/**
 * sidebar-accesos.js
 * Carga dinámicamente el sidebar basado en los accesos del usuario desde TblUsuarioAccesos
 */

document.addEventListener('DOMContentLoaded', async function() {
    console.log('[SIDEBAR-ACCESOS] Inicializando carga de accesos...');
    
    try {
        // Obtener accesos del usuario actual
        const response = await fetch('/api/mi-acceso/obtener');
        const result = await response.json();
        
        console.log('[SIDEBAR-ACCESOS] Respuesta API:', result);
        
        if (!result.success) {
            console.error('[SIDEBAR-ACCESOS] Error al obtener accesos:', result.error);
            return;
        }
        
        const menus = result.menus || [];
        const submenus = result.submenus || [];
        const menusCompletos = result.menus_completos || [];
        
        console.log('[SIDEBAR-ACCESOS] Accesos obtenidos:', {
            menus: menus.length,
            submenus: submenus.length,
            menusCompletos: menusCompletos.length
        });
        
        console.log('[SIDEBAR-ACCESOS] Menus:', menus);
        console.log('[SIDEBAR-ACCESOS] Submenus:', submenus);
        console.log('[SIDEBAR-ACCESOS] Menus Completos:', menusCompletos);
        
        // Renderizar el sidebar con los accesos
        renderizarSidebar(menus, submenus, menusCompletos);
        
    } catch (error) {
        console.error('[SIDEBAR-ACCESOS] Error al cargar accesos:', error);
    }
});

/**
 * Renderiza el sidebar dinámicamente basado en accesos
 */
function renderizarSidebar(menus, submenus, menusCompletos) {
    const menuContainer = document.getElementById('menu-container');
    
    if (!menuContainer) {
        console.error('[SIDEBAR-ACCESOS] No se encontró #menu-container');
        return;
    }
    
    // Limpiar contenedor
    menuContainer.innerHTML = '';
    
    // Si no hay menús, mostrar mensaje
    if (menus.length === 0) {
        menuContainer.innerHTML = `
            <div class="px-4 py-6 text-center text-gray-500 dark:text-gray-400">
                <i class="fas fa-lock text-2xl mb-2 block"></i>
                <p class="text-sm">Sin accesos asignados</p>
            </div>
        `;
        console.warn('[SIDEBAR-ACCESOS] Usuario sin accesos asignados');
        return;
    }
    
    // Mapear accesos por menú
    const accesosPorMenu = {};
    menus.forEach(menu => {
        accesosPorMenu[menu.id_menu] = {
            menu: menu,
            submenus: submenus.filter(sm => sm.id_menu === menu.id_menu),
            esMenuCompleto: menusCompletos.includes(menu.id_menu)
        };
    });
    
    console.log('[SIDEBAR-ACCESOS] Accesos organizados por menú:', accesosPorMenu);
    
    // Renderizar cada menú con sus submenús
    menus.forEach(menu => {
        const acceso = accesosPorMenu[menu.id_menu];
        const submenusDatos = acceso.submenus;
        const esMenuCompleto = acceso.esMenuCompleto;
        
        console.log(`[SIDEBAR-ACCESOS] Procesando menú: ${menu.nombre}, completo: ${esMenuCompleto}, submenus: ${submenusDatos.length}`);
        
        // Crear estructura del menú
        const divMenu = document.createElement('div');
        divMenu.className = 'space-y-0';
        
        // Si el usuario tiene acceso completo al menú pero no hay submenús específicos, mostrar como botón simple
        // Si tiene submenús específicos, mostrar menú colapsible con esos submenús
        if (submenusDatos.length > 0) {
            // Tiene submenús - mostrar como colapsible
            console.log(`[SIDEBAR-ACCESOS] ${menu.nombre} tiene ${submenusDatos.length} submenus`);
            
            divMenu.innerHTML = `
                <button class="w-full flex items-center justify-between px-4 py-3 rounded-xl font-medium transition-all duration-200 group text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800 submenuToggle" onclick="toggleSubmenu(this)">
                    <span class="flex items-center gap-3">
                        <i class="fas ${menu.icono} w-5 text-center text-gray-400 group-hover:text-[#4D148C] transition-colors"></i>
                        <span>${menu.nombre}</span>
                    </span>
                    <i class="fas fa-chevron-down text-sm transition-transform duration-300 text-gray-400"></i>
                </button>
                <div class="submenu hidden pl-4 mt-1 space-y-1">
                    <!-- Submenús se cargarán aquí -->
                </div>
            `;
            
            const submenuContainer = divMenu.querySelector('.submenu');
            
            // Agregar submenús permitidos
            submenusDatos.forEach(submenu => {
                const submenuLink = document.createElement('a');
                
                // Usar la ruta del submenú directamente
                const ruta = submenu.ruta || '#';
                
                console.log(`[SIDEBAR-ACCESOS] Agregando submenú: ${submenu.nombre} -> ${ruta}`);
                
                submenuLink.href = ruta;
                submenuLink.className = 'flex items-center w-full px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 group text-gray-600 dark:text-gray-400 hover:bg-[#4D148C]/10 dark:hover:bg-[#4D148C]/30 hover:text-[#4D148C] dark:hover:text-[#4D148C]';
                submenuLink.innerHTML = `
                    <i class="fas ${submenu.icono || 'fa-file'} w-4 text-center text-gray-400 group-hover:text-[#4D148C] transition-colors"></i>
                    <span class="ml-3">${submenu.nombre}</span>
                `;
                submenuContainer.appendChild(submenuLink);
            });
        } else if (esMenuCompleto) {
            // Menú sin submenús específicos pero con acceso completo - mostrar como botón simple
            console.log(`[SIDEBAR-ACCESOS] ${menu.nombre} es acceso directo (sin submenus específicos)`);
            
            divMenu.innerHTML = `
                <a href="#" class="flex items-center w-full px-4 py-3 rounded-xl font-medium transition-all duration-200 group text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-slate-800">
                    <i class="fas ${menu.icono} w-5 text-center text-gray-400 group-hover:text-[#4D148C] transition-colors"></i>
                    <span class="ml-3">${menu.nombre}</span>
                </a>
            `;
        } else {
            // No tiene acceso válido - no mostrar
            console.log(`[SIDEBAR-ACCESOS] ${menu.nombre} no tiene datos de acceso válidos, omitiendo...`);
            return;
        }
        
        menuContainer.appendChild(divMenu);
    });
    
    console.log('[SIDEBAR-ACCESOS] Sidebar renderizado exitosamente');
}

/**
 * Toggle submenu (función reutilizada)
 */
function toggleSubmenu(button) {
    const submenu = button.nextElementSibling;
    const chevron = button.querySelector('.fa-chevron-down');
    
    if (submenu && submenu.classList.contains('submenu')) {
        submenu.classList.toggle('hidden');
        if (chevron) {
            chevron.style.transform = submenu.classList.contains('hidden') ? 'rotate(0deg)' : 'rotate(180deg)';
        }
    }
}
