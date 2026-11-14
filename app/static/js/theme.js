// Tema del sistema: solo oscuro.
// La clase "dark" ya viene en el <html> de base.html; esto la asegura
// y limpia la preferencia antigua guardada en el navegador.
(function () {
    const html = document.documentElement;
    html.classList.add('dark');
    html.style.colorScheme = 'dark';

    try {
        localStorage.removeItem('theme');
    } catch (e) {
        // Navegador sin acceso a localStorage: no afecta al tema
    }
})();
