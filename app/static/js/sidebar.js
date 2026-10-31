// Mobile sidebar toggle - Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', function() {
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const sidebar = document.getElementById('sidebar');
    const sidebarOverlay = document.getElementById('sidebar-overlay');
    const desktopSidebarToggle = document.getElementById('sidebar-toggle-desktop');
    const desktopSidebarIcon = document.getElementById('sidebar-toggle-icon');
    const SIDEBAR_COLLAPSED_KEY = 'sidebar-colapsado';
    
    // Only initialize if elements exist
    if (!mobileMenuBtn || !sidebar || !sidebarOverlay) {
        console.error('✗ Mobile menu elements not found. Check HTML structure.');
        return;
    }
    
    console.log('✓ Mobile menu elements found, initializing...');

    // Mostrar u ocultar el sidebar en escritorio
    function aplicarSidebarColapsado(colapsado) {
        sidebar.classList.toggle('sidebar-colapsado', colapsado);

        if (desktopSidebarToggle) {
            desktopSidebarToggle.classList.toggle('sidebar-colapsado', colapsado);
            desktopSidebarToggle.setAttribute('aria-expanded', String(!colapsado));
            desktopSidebarToggle.setAttribute('aria-label', colapsado ? 'Mostrar menú lateral' : 'Ocultar menú lateral');
        }

        if (desktopSidebarIcon) {
            desktopSidebarIcon.classList.toggle('fa-chevron-left', !colapsado);
            desktopSidebarIcon.classList.toggle('fa-chevron-right', colapsado);
        }

        localStorage.setItem(SIDEBAR_COLLAPSED_KEY, colapsado ? '1' : '0');
    }

    if (desktopSidebarToggle) {
        aplicarSidebarColapsado(localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === '1');

        desktopSidebarToggle.addEventListener('click', function() {
            aplicarSidebarColapsado(!sidebar.classList.contains('sidebar-colapsado'));
        });
    }
    
    // Ensure sidebar has position fixed for mobile view
    function updateSidebarPosition() {
        if (window.innerWidth < 768) {
            // Mobile: make sidebar fixed with inline styles
            sidebar.style.position = 'fixed';
            sidebar.style.inset = '0';
            sidebar.style.zIndex = '40';
            sidebar.classList.add('md:relative');
            console.log('✓ Sidebar en modo MOBILE (fixed)');
        } else {
            // Desktop: make sidebar normal
            sidebar.style.position = '';
            sidebar.style.inset = '';
            sidebar.style.zIndex = '';
            sidebar.classList.add('md:relative');
            sidebar.classList.remove('hidden');
            sidebarOverlay.classList.add('hidden');
            mobileMenuBtn.setAttribute('aria-expanded', 'false');
            mobileMenuBtn.setAttribute('aria-label', 'Abrir menú');
            console.log('✓ Sidebar en modo DESKTOP (relative)');
        }
    }
    
    // Initial setup
    updateSidebarPosition();
    
    // Toggle sidebar on mobile menu button click
    mobileMenuBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        
        const isMobile = window.innerWidth < 768;
        if (!isMobile) return;
        
        const isHidden = sidebar.classList.contains('hidden');
        
        if (isHidden) {
            sidebar.classList.remove('hidden');
            sidebarOverlay.classList.remove('hidden');
            mobileMenuBtn.setAttribute('aria-expanded', 'true');
            mobileMenuBtn.setAttribute('aria-label', 'Cerrar menú');
            console.log('✓ Sidebar ABIERTO');
        } else {
            sidebar.classList.add('hidden');
            sidebarOverlay.classList.add('hidden');
            mobileMenuBtn.setAttribute('aria-expanded', 'false');
            mobileMenuBtn.setAttribute('aria-label', 'Abrir menú');
            console.log('✓ Sidebar CERRADO');
        }
    });
    
    // Close sidebar when clicking overlay
    sidebarOverlay.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        sidebar.classList.add('hidden');
        sidebarOverlay.classList.add('hidden');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
        mobileMenuBtn.setAttribute('aria-label', 'Abrir menú');
        mobileMenuBtn.focus();
        console.log('✓ Sidebar cerrado por overlay click');
    });

    // Cerrar sidebar con Escape
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && window.innerWidth < 768 && !sidebar.classList.contains('hidden')) {
            sidebar.classList.add('hidden');
            sidebarOverlay.classList.add('hidden');
            mobileMenuBtn.setAttribute('aria-expanded', 'false');
            mobileMenuBtn.setAttribute('aria-label', 'Abrir menú');
            mobileMenuBtn.focus();
        }
    });
    
    // Close sidebar when clicking navigation links (no toggle buttons)
    sidebar.addEventListener('click', function(e) {
        const isMobile = window.innerWidth < 768;
        if (!isMobile) return;
        
        // Check if it's a toggle button
        const toggleButton = e.target.closest('.toggle-submenu');
        if (toggleButton) {
            console.log('✓ Toggle button - keep sidebar open');
            e.stopPropagation();
            return;
        }
        
        // Find the closest link
        const link = e.target.closest('a');
        if (!link) return;
        
        // Don't close if it's an anchor link (#)
        if (link.href.endsWith('#')) {
            console.log('✓ Anchor link - keep sidebar open');
            return;
        }
        
        // Close sidebar for navigation links
        console.log('✓ Navigation link clicked - cerrando sidebar:', link.textContent.trim());
        sidebar.classList.add('hidden');
        sidebarOverlay.classList.add('hidden');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
        mobileMenuBtn.setAttribute('aria-label', 'Abrir menú');
    });
    
    // Handle window resize
    window.addEventListener('resize', function() {
        updateSidebarPosition();
    });
});
