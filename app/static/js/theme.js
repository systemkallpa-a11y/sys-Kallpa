// Theme toggle functionality
const themeToggle = document.getElementById('theme-toggle');
const themeIcon = document.getElementById('theme-icon');
const html = document.documentElement;

function updateThemeIcon() {
    const isDark = html.classList.contains('dark');

    if (themeIcon) {
        themeIcon.classList.remove('fa-moon', 'fa-sun');
        themeIcon.classList.add(isDark ? 'fa-sun' : 'fa-moon');
    }

    if (themeToggle) {
        themeToggle.setAttribute('aria-pressed', String(isDark));
    }

    html.style.colorScheme = isDark ? 'dark' : 'light';

    const themeColor = document.querySelector('meta[name="theme-color"]');
    if (themeColor) {
        themeColor.setAttribute('content', isDark ? '#0f172a' : '#ffffff');
    }
}

// Initialize theme on page load
updateThemeIcon();

// Theme toggle click handler
if (themeToggle) {
    themeToggle.addEventListener('click', () => {
        const isDark = html.classList.contains('dark');

        if (isDark) {
            html.classList.remove('dark');
            localStorage.setItem('theme', 'light');
        } else {
            html.classList.add('dark');
            localStorage.setItem('theme', 'dark');
        }

        updateThemeIcon();
    });
}

// FORZAR SIEMPRE TEMA LIGHT AL CARGAR
window.addEventListener('DOMContentLoaded', () => {
    // SIEMPRE remover dark y establecer light
    html.classList.remove('dark');
    localStorage.setItem('theme', 'light');
    updateThemeIcon();
});
