// ============================================================================
// GESTIÓN DE UBICACIONES DE MARCACIÓN
// ============================================================================

let mapaUbicaciones = null;
let marcadorUbicacion = null;
let circuloRango = null;
let usuarioActualUbicacion = null;
let ubicacionesUsuario = [];

// ============================================================================
// ABRIR MODAL DE UBICACIONES
// ============================================================================
async function abrirModalUbicaciones(numDocumento, nombreUsuario) {
    usuarioActualUbicacion = numDocumento;
    
    document.getElementById('ubicacion-usuario-nombre').textContent = nombreUsuario;
    document.getElementById('modal-ubicaciones').classList.remove('hidden');
    
    // Inicializar mapa después de que el modal sea visible
    setTimeout(() => {
        inicializarMapa();
        cargarUbicacionesUsuario(numDocumento);
    }, 100);
}

// ============================================================================
// CERRAR MODAL
// ============================================================================
function cerrarModalUbicaciones() {
    document.getElementById('modal-ubicaciones').classList.add('hidden');
    if (mapaUbicaciones) {
        mapaUbicaciones.remove();
        mapaUbicaciones = null;
    }
}

// ============================================================================
// INICIALIZAR MAPA CON LEAFLET (OpenStreetMap)
// ============================================================================
function inicializarMapa() {
    if (mapaUbicaciones) {
        mapaUbicaciones.remove();
    }
    
    // Coordenadas de Lima, Perú (centro por defecto)
    const latInicial = -12.0464;
    const lonInicial = -77.0428;
    
    // Crear mapa
    mapaUbicaciones = L.map('mapa-ubicacion').setView([latInicial, lonInicial], 13);
    
    // Capa de OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19
    }).addTo(mapaUbicaciones);
    
    // Evento: Click en el mapa para colocar marcador
    mapaUbicaciones.on('click', function(e) {
        colocarMarcador(e.latlng.lat, e.latlng.lng);
    });
}

// ============================================================================
// COLOCAR MARCADOR Y CÍRCULO DE RANGO
// ============================================================================
function colocarMarcador(lat, lon) {
    // Remover marcador y círculo previos
    if (marcadorUbicacion) {
        mapaUbicaciones.removeLayer(marcadorUbicacion);
    }
    if (circuloRango) {
        mapaUbicaciones.removeLayer(circuloRango);
    }
    
    // Obtener radio actual del input
    const radio = parseInt(document.getElementById('ubicacion-radio').value) || 100;
    
    // Crear nuevo marcador
    marcadorUbicacion = L.marker([lat, lon], {
        draggable: true,
        icon: L.icon({
            iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
            shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
            iconSize: [25, 41],
            iconAnchor: [12, 41],
            popupAnchor: [1, -34],
            shadowSize: [41, 41]
        })
    }).addTo(mapaUbicaciones);
    
    // Crear círculo de rango
    circuloRango = L.circle([lat, lon], {
        color: 'red',
        fillColor: '#f03',
        fillOpacity: 0.2,
        radius: radio
    }).addTo(mapaUbicaciones);
    
    // Actualizar coordenadas en inputs
    document.getElementById('ubicacion-latitud').value = lat.toFixed(8);
    document.getElementById('ubicacion-longitud').value = lon.toFixed(8);
    
    // Evento: Cuando se arrastra el marcador
    marcadorUbicacion.on('dragend', function(e) {
        const pos = e.target.getLatLng();
        colocarMarcador(pos.lat, pos.lng);
    });
    
    // Popup con información
    marcadorUbicacion.bindPopup(`
        <b>Centro de la zona</b><br>
        Lat: ${lat.toFixed(6)}<br>
        Lon: ${lon.toFixed(6)}<br>
        Radio: ${radio}m
    `).openPopup();
}

// ============================================================================
// ACTUALIZAR RADIO DEL CÍRCULO
// ============================================================================
function actualizarRadioCirculo() {
    const radio = parseInt(document.getElementById('ubicacion-radio').value) || 100;
    document.getElementById('ubicacion-radio-display').textContent = radio;
    
    // Si hay un marcador colocado, actualizar el círculo
    if (marcadorUbicacion && circuloRango) {
        const pos = marcadorUbicacion.getLatLng();
        mapaUbicaciones.removeLayer(circuloRango);
        
        circuloRango = L.circle([pos.lat, pos.lng], {
            color: 'red',
            fillColor: '#f03',
            fillOpacity: 0.2,
            radius: radio
        }).addTo(mapaUbicaciones);
        
        // Actualizar popup
        marcadorUbicacion.getPopup().setContent(`
            <b>Centro de la zona</b><br>
            Lat: ${pos.lat.toFixed(6)}<br>
            Lon: ${pos.lng.toFixed(6)}<br>
            Radio: ${radio}m
        `);
    }
}

// ============================================================================
// CARGAR UBICACIONES DEL USUARIO
// ============================================================================
async function cargarUbicacionesUsuario(numDocumento) {
    try {
        const response = await fetch(`/api/ubicaciones/obtener/${numDocumento}`, {
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            ubicacionesUsuario = data.data;
            renderizarListaUbicaciones();
        } else {
            console.error('Error al cargar ubicaciones:', data.error);
        }
    } catch (error) {
        console.error('Error:', error);
    }
}

// ============================================================================
// RENDERIZAR LISTA DE UBICACIONES
// ============================================================================
function renderizarListaUbicaciones() {
    const lista = document.getElementById('lista-ubicaciones');
    
    if (ubicacionesUsuario.length === 0) {
        lista.innerHTML = `
            <div class="text-center py-8 text-gray-500 dark:text-gray-400">
                <i class="fas fa-map-marker-slash text-3xl mb-2 opacity-50"></i>
                <p class="text-sm">No hay ubicaciones configuradas</p>
                <p class="text-xs mt-1">Sin restricción de ubicación para marcación</p>
            </div>
        `;
        return;
    }
    
    let html = '';
    ubicacionesUsuario.forEach(ubicacion => {
        const estadoClass = ubicacion.estado === 'ACTIVO' 
            ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' 
            : 'bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400';
        
        const tipoIcono = {
            'OFICINA': 'fa-building',
            'OBRA': 'fa-hard-hat',
            'PROYECTO': 'fa-project-diagram',
            'CLIENTE': 'fa-handshake',
            'OTRO': 'fa-map-marker-alt'
        };
        
        html += `
            <div class="bg-gray-50 dark:bg-slate-800/50 border border-gray-200 dark:border-slate-700 rounded-lg p-4">
                <div class="flex items-start justify-between mb-3">
                    <div class="flex items-center gap-3">
                        <div class="w-10 h-10 bg-slate-600 rounded-lg flex items-center justify-center text-white">
                            <i class="fas ${tipoIcono[ubicacion.tipo_zona] || 'fa-map-marker-alt'}"></i>
                        </div>
                        <div>
                            <h4 class="font-semibold text-gray-900 dark:text-white">${ubicacion.nombre_zona}</h4>
                            <span class="text-xs px-2 py-0.5 rounded-full ${estadoClass} font-medium">
                                ${ubicacion.estado}
                            </span>
                        </div>
                    </div>
                    <div class="flex gap-2">
                        <button onclick="verUbicacionEnMapa(${ubicacion.id_ubicacion})" 
                            class="text-blue-600 dark:text-blue-400 hover:text-blue-700 p-2" 
                            title="Ver en mapa">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button onclick="editarUbicacion(${ubicacion.id_ubicacion})" 
                            class="text-yellow-600 dark:text-yellow-400 hover:text-yellow-700 p-2" 
                            title="Editar">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button onclick="eliminarUbicacion(${ubicacion.id_ubicacion})" 
                            class="text-red-600 dark:text-red-400 hover:text-red-700 p-2" 
                            title="Eliminar">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </div>
                <div class="grid grid-cols-2 gap-2 text-xs text-gray-600 dark:text-gray-400">
                    <div>
                        <i class="fas fa-circle-dot mr-1"></i>
                        <span class="font-medium">Centro:</span> ${parseFloat(ubicacion.latitud_centro).toFixed(6)}, ${parseFloat(ubicacion.longitud_centro).toFixed(6)}
                    </div>
                    <div>
                        <i class="fas fa-expand-arrows-alt mr-1"></i>
                        <span class="font-medium">Radio:</span> ${ubicacion.radio_metros}m
                    </div>
                    ${ubicacion.direccion_referencia ? `
                    <div class="col-span-2">
                        <i class="fas fa-map-pin mr-1"></i>
                        <span class="font-medium">Dirección:</span> ${ubicacion.direccion_referencia}
                    </div>
                    ` : ''}
                </div>
            </div>
        `;
    });
    
    lista.innerHTML = html;
}

// ============================================================================
// VER UBICACIÓN EN MAPA
// ============================================================================
function verUbicacionEnMapa(idUbicacion) {
    const ubicacion = ubicacionesUsuario.find(u => u.id_ubicacion === idUbicacion);
    if (!ubicacion) return;
    
    const lat = parseFloat(ubicacion.latitud_centro);
    const lon = parseFloat(ubicacion.longitud_centro);
    const radio = parseInt(ubicacion.radio_metros);
    
    // Centrar mapa en la ubicación
    mapaUbicaciones.setView([lat, lon], 16);
    
    // Colocar marcador
    colocarMarcador(lat, lon);
    
    // Actualizar inputs
    document.getElementById('ubicacion-radio').value = radio;
    actualizarRadioCirculo();
}

// ============================================================================
// EDITAR UBICACIÓN
// ============================================================================
function editarUbicacion(idUbicacion) {
    const ubicacion = ubicacionesUsuario.find(u => u.id_ubicacion === idUbicacion);
    if (!ubicacion) return;
    
    // Llenar formulario
    document.getElementById('ubicacion-id').value = ubicacion.id_ubicacion;
    document.getElementById('ubicacion-nombre').value = ubicacion.nombre_zona;
    document.getElementById('ubicacion-tipo').value = ubicacion.tipo_zona;
    document.getElementById('ubicacion-direccion').value = ubicacion.direccion_referencia || '';
    document.getElementById('ubicacion-descripcion').value = ubicacion.descripcion || '';
    document.getElementById('ubicacion-estado').value = ubicacion.estado;
    document.getElementById('ubicacion-radio').value = ubicacion.radio_metros;
    
    // Mostrar en mapa
    verUbicacionEnMapa(idUbicacion);
    
    // Cambiar texto del botón
    document.getElementById('btn-guardar-ubicacion').innerHTML = '<i class="fas fa-save mr-2"></i>Actualizar Ubicación';
}

// ============================================================================
// NUEVA UBICACIÓN
// ============================================================================
function nuevaUbicacion() {
    // Limpiar formulario
    document.getElementById('ubicacion-id').value = '';
    document.getElementById('ubicacion-nombre').value = '';
    document.getElementById('ubicacion-tipo').value = 'OFICINA';
    document.getElementById('ubicacion-direccion').value = '';
    document.getElementById('ubicacion-descripcion').value = '';
    document.getElementById('ubicacion-estado').value = 'ACTIVO';
    document.getElementById('ubicacion-radio').value = 100;
    document.getElementById('ubicacion-latitud').value = '';
    document.getElementById('ubicacion-longitud').value = '';
    
    // Limpiar mapa
    if (marcadorUbicacion) {
        mapaUbicaciones.removeLayer(marcadorUbicacion);
        marcadorUbicacion = null;
    }
    if (circuloRango) {
        mapaUbicaciones.removeLayer(circuloRango);
        circuloRango = null;
    }
    
    // Cambiar texto del botón
    document.getElementById('btn-guardar-ubicacion').innerHTML = '<i class="fas fa-save mr-2"></i>Guardar Ubicación';
    
    actualizarRadioCirculo();
}

// ============================================================================
// GUARDAR UBICACIÓN
// ============================================================================
async function guardarUbicacion() {
    const idUbicacion = document.getElementById('ubicacion-id').value;
    const nombre = document.getElementById('ubicacion-nombre').value.trim();
    const tipo = document.getElementById('ubicacion-tipo').value;
    const latitud = document.getElementById('ubicacion-latitud').value;
    const longitud = document.getElementById('ubicacion-longitud').value;
    const radio = document.getElementById('ubicacion-radio').value;
    const direccion = document.getElementById('ubicacion-direccion').value.trim();
    const descripcion = document.getElementById('ubicacion-descripcion').value.trim();
    const estado = document.getElementById('ubicacion-estado').value;
    
    // Validaciones
    if (!nombre) {
        mostrarAlerta('Error', 'El nombre de la zona es obligatorio', 'error');
        return;
    }
    
    if (!latitud || !longitud) {
        mostrarAlerta('Error', 'Debes marcar una ubicación en el mapa', 'error');
        return;
    }
    
    const datos = {
        num_documento: usuarioActualUbicacion,
        nombre_zona: nombre,
        tipo_zona: tipo,
        latitud_centro: parseFloat(latitud),
        longitud_centro: parseFloat(longitud),
        radio_metros: parseInt(radio),
        direccion_referencia: direccion || null,
        descripcion: descripcion || null,
        estado: estado
    };
    
    try {
        const url = idUbicacion 
            ? `/api/ubicaciones/actualizar/${idUbicacion}`
            : '/api/ubicaciones/crear';
        
        const method = idUbicacion ? 'PUT' : 'POST';
        
        const response = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
            },
            body: JSON.stringify(datos)
        });
        
        const data = await response.json();
        
        if (data.success) {
            mostrarAlerta('Éxito', data.message, 'success');
            nuevaUbicacion();
            cargarUbicacionesUsuario(usuarioActualUbicacion);
        } else {
            mostrarAlerta('Error', data.error, 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        mostrarAlerta('Error', 'Error al guardar la ubicación', 'error');
    }
}

// ============================================================================
// ELIMINAR UBICACIÓN
// ============================================================================
async function eliminarUbicacion(idUbicacion) {
    if (!confirm('¿Estás seguro de eliminar esta ubicación?')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/ubicaciones/eliminar/${idUbicacion}`, {
            method: 'DELETE',
            headers: {
                'X-Requested-With': 'XMLHttpRequest'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            mostrarAlerta('Éxito', 'Ubicación eliminada correctamente', 'success');
            cargarUbicacionesUsuario(usuarioActualUbicacion);
            nuevaUbicacion();
        } else {
            mostrarAlerta('Error', data.error, 'error');
        }
    } catch (error) {
        console.error('Error:', error);
        mostrarAlerta('Error', 'Error al eliminar la ubicación', 'error');
    }
}

// ============================================================================
// BUSCAR MI UBICACIÓN ACTUAL (GEOLOCALIZACIÓN)
// ============================================================================
function buscarMiUbicacion() {
    if (!navigator.geolocation) {
        mostrarAlerta('Error', 'Tu navegador no soporta geolocalización', 'error');
        return;
    }
    
    const btn = document.querySelector('button[onclick="buscarMiUbicacion()"]');
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Buscando...';
    
    navigator.geolocation.getCurrentPosition(
        (position) => {
            const lat = position.coords.latitude;
            const lon = position.coords.longitude;
            
            mapaUbicaciones.setView([lat, lon], 16);
            colocarMarcador(lat, lon);
            
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-crosshairs mr-2"></i>Mi Ubicación';
        },
        (error) => {
            console.error('Error de geolocalización:', error);
            mostrarAlerta('Error', 'No se pudo obtener tu ubicación actual', 'error');
            btn.disabled = false;
            btn.innerHTML = '<i class="fas fa-crosshairs mr-2"></i>Mi Ubicación';
        },
        {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 0
        }
    );
}

// ============================================================================
// UTILIDAD: MOSTRAR ALERTAS
// ============================================================================
function mostrarAlerta(titulo, mensaje, tipo) {
    const color = tipo === 'success' ? 'green' : tipo === 'error' ? 'red' : 'blue';
    const icono = tipo === 'success' ? 'check-circle' : tipo === 'error' ? 'exclamation-circle' : 'info-circle';
    
    // Crear alerta temporal
    const alerta = document.createElement('div');
    alerta.className = `fixed top-4 right-4 z-[60] bg-${color}-100 border border-${color}-400 text-${color}-700 px-6 py-4 rounded-lg shadow-lg max-w-md`;
    alerta.innerHTML = `
        <div class="flex items-center gap-3">
            <i class="fas fa-${icono} text-xl"></i>
            <div>
                <p class="font-bold">${titulo}</p>
                <p class="text-sm">${mensaje}</p>
            </div>
        </div>
    `;
    
    document.body.appendChild(alerta);
    
    setTimeout(() => {
        alerta.remove();
    }, 3000);
}

// ============================================================================
// EVENT LISTENERS
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
    // Listener para el slider de radio
    const radioInput = document.getElementById('ubicacion-radio');
    if (radioInput) {
        radioInput.addEventListener('input', actualizarRadioCirculo);
    }
});
