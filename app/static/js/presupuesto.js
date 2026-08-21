// ============================================================================
// GESTIÓN DE PRESUPUESTOS CON MATERIALES Y SERVICIOS
// ============================================================================

// Estado global
let materiales_agregados = [];
let servicios_agregados = [];
let id_contador_material = 0;
let id_contador_servicio = 0;
let materiales_disponibles = [];
let desglose_editado_manualmente = false; // ⭐ Detecta si usuario editó campos manualmente

// Porcentajes extraídos del PDF (valores por defecto si no se extraen)
let porcentajes_pdf = {
    gastos_generales: 10,  // Default 10%
    utilidad: 15,          // Default 15%
    supervision: 5,        // Default 5% (no está en PDF)
    igv: 18                // Default 18%
};

// Inicializar cuando carga la página
document.addEventListener('DOMContentLoaded', function() {
    // ⭐ CONFIGURAR EVENT LISTENERS PARA BÚSQUEDA DE MATERIALES INMEDIATAMENTE
    const buscadorMaterial = document.getElementById('buscador-material');
    const filtroCategoria = document.getElementById('filtro-categoria');
    
    if (buscadorMaterial) {
        console.log('[INIT] Configurando event listener para buscador de materiales');
        buscadorMaterial.addEventListener('input', function() {
            console.log('[BUSCAR] Input detectado:', this.value);
            buscarMaterialesDinamico();
        });
    } else {
        console.warn('[INIT] ❌ No se encontró el elemento buscador-material');
    }
    
    if (filtroCategoria) {
        console.log('[INIT] Configurando event listener para filtro de categorías');
        filtroCategoria.addEventListener('change', function() {
            console.log('[BUSCAR] Cambio de categoría detectado:', this.value);
            buscarMaterialesDinamico();
        });
    } else {
        console.warn('[INIT] ❌ No se encontró el elemento filtro-categoria');
    }
    
    // ⭐ AGREGAR EVENT LISTENERS PARA CAMPOS EDITABLES DEL DESGLOSE
    const campos_desglose = ['gastos-generales', 'utilidad', 'supervision-obra'];
    
    campos_desglose.forEach(campo_id => {
        const campo = document.getElementById(campo_id);
        if (campo) {
            // ⭐ MARCAR COMO EDITADO MANUALMENTE cuando el usuario cambia el valor
            campo.addEventListener('input', function() {
                // Solo marcar como editado si el usuario realmente escribió algo
                // (no cuando se actualiza programáticamente)
                if (document.activeElement === this) {
                    desglose_editado_manualmente = true;
                    console.log('[DESGLOSE] Campo editado manualmente:', campo_id, '→ bandera = true');
                }
                actualizarTotales();
            });
            
            campo.addEventListener('change', actualizarTotales);
            
            // ⭐ SELECCIONAR TODO AL HACER FOCUS (facilita reemplazar valor)
            campo.addEventListener('focus', function() {
                this.select();
            });
            
            // ⭐ PREVENIR QUE ENTER GUARDE EL FORMULARIO
            campo.addEventListener('keydown', function(e) {
                if (e.key === 'Enter') {
                    e.preventDefault(); // Evitar que se envíe el formulario
                    console.log('[DESGLOSE] Enter presionado en', campo_id, '- Prevención activada');
                }
            });
        }
    });
    
    // ⭐ TAMBIÉN PREVENIR ENTER EN OTROS CAMPOS NUMÉRICOS
    const campos_numericos = ['servicio-cantidad', 'servicio-precio'];
    
    campos_numericos.forEach(campo_id => {
        const campo = document.getElementById(campo_id);
        if (campo) {
            campo.addEventListener('keydown', function(e) {
                if (e.key === 'Enter') {
                    e.preventDefault(); // Evitar que se envíe el formulario
                    console.log('[FORM] Enter presionado en', campo_id, '- Prevención activada');
                }
            });
        }
    });
});

// ============================================================================
// FUNCIÓN MEJORADA DE CARGA DE DATOS PARA EDITAR
// ============================================================================

async function cargarDatosPresupuestoParaEditar(id_presupuesto) {
    try {
        console.log('[EDITAR] Cargando presupuesto:', id_presupuesto);
        
        // ⭐ RESETEAR BANDERA DE EDICIÓN MANUAL
        desglose_editado_manualmente = false;
        
        // Usar el nuevo endpoint mejorado que retorna datos listos
        const response = await fetch(`/api/presupuestos/obtener-para-editar/${id_presupuesto}`);
        const result = await response.json();
        
        if (!result.success) {
            console.error('[EDITAR] Error:', result.error);
            mostrarError('Error al cargar presupuesto');
            return;
        }
        
        const { presupuesto, data } = result.data;
        
        console.log('[EDITAR] ✓ Presupuesto cargado:', presupuesto);
        console.log('[EDITAR] ✓ Detalles:', data);
        
        // Limpiar arrays globales
        limpiarForm();
        materiales_agregados = [];
        servicios_agregados = [];
        id_contador_material = 0;
        id_contador_servicio = 0;
        
        console.log('[EDITAR] Cargando datos maestros...');
        await cargarEmpresas();
        await cargarProyectos();
        await cargarCategorias();
        
        // Rellenar campos del formulario
        document.getElementById('id_empresa').value = presupuesto.id_empresa || '';
        document.getElementById('id_proyecto').value = presupuesto.id_proyecto || '';
        document.getElementById('id_obra').value = presupuesto.id_obra || '';
        document.getElementById('comentarios').value = presupuesto.observaciones || '';
        
        // ⭐ CARGAR CAMPOS DEL DESGLOSE FINANCIERO
        console.log('[EDITAR] Valores de desglose recibidos:', {
            gastos_generales: presupuesto.gastos_generales,
            utilidad: presupuesto.utilidad,
            supervision_obra: presupuesto.supervision_obra,
            igv: presupuesto.igv
        });
        
        // ⭐ FORZAR CARGA CON VALORES POR DEFECTO SI ESTÁN VACÍOS
        const gastos_valor = parseFloat(presupuesto.gastos_generales || 0);
        const utilidad_valor = parseFloat(presupuesto.utilidad || 0);
        const supervision_valor = parseFloat(presupuesto.supervision_obra || 0);
        
        document.getElementById('gastos-generales').value = gastos_valor.toFixed(2);
        document.getElementById('utilidad').value = utilidad_valor.toFixed(2);
        document.getElementById('supervision-obra').value = supervision_valor.toFixed(2);
        
        console.log('[EDITAR] ✓ Campos de desglose cargados:', {
            gastos_generales_input: document.getElementById('gastos-generales').value,
            utilidad_input: document.getElementById('utilidad').value,
            supervision_obra_input: document.getElementById('supervision-obra').value
        });
        
        // ⭐ VERIFICAR QUE LOS ELEMENTOS EXISTEN
        const elementos = ['gastos-generales', 'utilidad', 'supervision-obra'];
        elementos.forEach(id => {
            const elemento = document.getElementById(id);
            if (!elemento) {
                console.error(`[EDITAR] ❌ Elemento '${id}' NO ENCONTRADO en el DOM`);
            } else {
                console.log(`[EDITAR] ✓ Elemento '${id}' encontrado, valor: ${elemento.value}`);
            }
        });
        
        // PROCESAR MATERIALES CORRECTAMENTE
        if (data.materiales && Array.isArray(data.materiales)) {
            console.log('[EDITAR] Procesando', data.materiales.length, 'materiales');
            data.materiales.forEach(m => {
                id_contador_material++;
                materiales_agregados.push({
                    id_temporal: id_contador_material,
                    id_detalle: m.id_detalle,
                    id_material: m.id_material,
                    nombre: m.nombre || 'Sin nombre',
                    codigo: m.codigo || '',
                    categoria: m.categoria || '',
                    unidad: m.unidad || 'und',
                    cantidad: parseFloat(m.cantidad) || 0,
                    precio_unitario: parseFloat(m.precio_unitario) || 0,
                    subtotal: parseFloat(m.subtotal) || 0
                });
                console.log('[EDITAR] ✓ Material:', m.nombre);
            });
        }
        
        // PROCESAR SERVICIOS CORRECTAMENTE
        if (data.servicios && Array.isArray(data.servicios)) {
            console.log('[EDITAR] Procesando', data.servicios.length, 'servicios');
            data.servicios.forEach(s => {
                id_contador_servicio++;
                servicios_agregados.push({
                    id_temporal: id_contador_servicio,
                    id_detalle: s.id_detalle,
                    descripcion: s.descripcion || '',
                    cantidad: parseFloat(s.cantidad) || 0,
                    precio_unitario: parseFloat(s.precio_unitario) || 0,
                    subtotal: parseFloat(s.subtotal) || 0
                });
                console.log('[EDITAR] ✓ Servicio:', s.descripcion);
            });
        }
        
        console.log('[EDITAR] Total materiales cargados:', materiales_agregados.length);
        console.log('[EDITAR] Total servicios cargados:', servicios_agregados.length);
        
        // Renderizar tablas
        renderizarMateriales();
        renderizarServicios();
        
        // ⭐ FORZAR RECÁLCULO INICIAL AL ABRIR MODAL DE EDITAR
        console.log('[EDITAR] Forzando recálculo inicial...');
        setTimeout(() => {
            actualizarTotales();
            console.log('[EDITAR] ✓ Recálculo inicial completado');
        }, 100);
        
        // Actualizar modal
        document.getElementById('modal-titulo').textContent = `Editar Presupuesto #${presupuesto.numero_presupuesto}`;
        document.getElementById('form-presupuesto').dataset.id_presupuesto = id_presupuesto;
        document.getElementById('form-presupuesto').dataset.modo = 'edicion';
        document.getElementById('modal-presupuesto').classList.remove('hidden');
        
        console.log('[EDITAR] ✓ Presupuesto cargado correctamente en modo edición');
        
    } catch (error) {
        console.error('[EDITAR] Error:', error);
        mostrarError('Error al cargar presupuesto: ' + error.message);
    }
}

// ============================================================================
// BÚSQUEDA Y CARGA DE MATERIALES
// ============================================================================

async function cargarMaterialesDisponibles() {
    // Esta función ya no carga todo
    // Los materiales se cargan dinámicamente con la búsqueda
    console.log('[DEBUG] cargarMaterialesDisponibles() - Ya no necesario');
}

async function cargarCategorias() {
    try {
        const response = await fetch('/api/presupuestos/combo/categorias');
        const data = await response.json();
        
        if (data.success) {
            const select = document.getElementById('filtro-categoria');
            select.innerHTML = '<option value="">Categoría</option>';
            data.data.forEach(c => {
                select.innerHTML += `<option value="${c.id_categoria}">${c.nombre}</option>`;
            });
        }
    } catch (error) {
        console.error('Error al cargar categorías:', error);
    }
}

// Búsqueda dinámica mientras escribe
async function buscarMaterialesDinamico() {
    const buscador = document.getElementById('buscador-material')?.value.trim() || '';
    const categoria = document.getElementById('filtro-categoria')?.value || '';
    
    console.log('🔍 [BUSCAR_MATERIALES] === FUNCIÓN EJECUTADA ===');
    console.log('[BUSCAR_MATERIALES] Input:', { buscador, categoria });
    console.log('[BUSCAR_MATERIALES] Elementos DOM:', {
        buscador_elem: !!document.getElementById('buscador-material'),
        categoria_elem: !!document.getElementById('filtro-categoria'),
        resultados_elem: !!document.getElementById('resultados-materiales'),
        lista_elem: !!document.getElementById('lista-resultados-materiales')
    });
    
    // Si no hay búsqueda, no mostrar resultados
    if (!buscador) {
        console.log('[BUSCAR_MATERIALES] ⚠️ Sin término de búsqueda, ocultando resultados');
        const resultados = document.getElementById('resultados-materiales');
        if (resultados) {
            resultados.classList.add('hidden');
        }
        return;
    }
    
    console.log('[BUSCAR_MATERIALES] ✅ Buscando:', buscador, 'Categoría:', categoria || '(todas)');
    
    try {
        // Construir URL - categoría es OPCIONAL, defaultea a 0 si no hay
        let url = `/api/presupuestos/combo/materiales?termino=${encodeURIComponent(buscador)}&categoria=${categoria || '0'}`;
        
        console.log('[BUSCAR_MATERIALES] 📡 URL:', url);
        console.log('[BUSCAR_MATERIALES] 📡 Iniciando fetch...');
        
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000);
        
        let response;
        try {
            response = await fetch(url, {
                method: 'GET',
                signal: controller.signal,
                headers: {
                    'Accept': 'application/json'
                }
            });
        } catch (fetchError) {
            console.error('[BUSCAR_MATERIALES] ❌ Fetch error:', fetchError.message);
            console.error('[BUSCAR_MATERIALES] ❌ Error type:', fetchError.constructor.name);
            if (fetchError instanceof TypeError) {
                console.error('[BUSCAR_MATERIALES] ❌ TypeError - Posible error de CORS o conexión rechazada');
            }
            throw fetchError;
        }
        
        clearTimeout(timeoutId);
        
        console.log('[BUSCAR_MATERIALES] 📊 Response recibido:', response.status, response.statusText);
        
        if (!response.ok) {
            console.error('[BUSCAR_MATERIALES] ❌ HTTP Error:', response.status);
            console.error('[BUSCAR_MATERIALES] ❌ Status text:', response.statusText);
            
            let errorText = '';
            try {
                errorText = await response.text();
                console.error('[BUSCAR_MATERIALES] ❌ Error body:', errorText);
            } catch (e) {
                console.error('[BUSCAR_MATERIALES] ❌ No se pudo leer el error body');
            }
            
            mostrarResultadosMateriales([]);
            return;
        }
        
        let data;
        try {
            data = await response.json();
        } catch (jsonError) {
            console.error('[BUSCAR_MATERIALES] ❌ Error parsing JSON:', jsonError.message);
            console.error('[BUSCAR_MATERIALES] ❌ Response:', response);
            mostrarResultadosMateriales([]);
            return;
        }
        
        console.log('[BUSCAR_MATERIALES] 📋 Respuesta JSON:', data);
        
        if (data.success && Array.isArray(data.data)) {
            console.log('[BUSCAR_MATERIALES] ✅ Éxito:', data.data.length, 'materiales encontrados');
            if (data.data.length > 0) {
                console.log('[BUSCAR_MATERIALES] 📄 Primer material:', data.data[0]);
            }
            mostrarResultadosMateriales(data.data);
        } else {
            console.error('[BUSCAR_MATERIALES] ❌ Error en respuesta:', data.error || 'Sin datos');
            mostrarResultadosMateriales([]);
        }
    } catch (error) {
        if (error.name === 'AbortError') {
            console.error('[BUSCAR_MATERIALES] ❌ Timeout - La solicitud tardó más de 10 segundos');
        } else {
            console.error('[BUSCAR_MATERIALES] ❌ Error:', error.message);
            console.error('[BUSCAR_MATERIALES] ❌ Error type:', error.constructor.name);
            console.error('[BUSCAR_MATERIALES] ❌ Stack:', error.stack);
        }
        mostrarResultadosMateriales([]);
    }
}

function mostrarResultadosMateriales(materiales) {
    console.log('🎨 [MOSTRAR_RESULTADOS] === FUNCIÓN EJECUTADA ===');
    console.log('[MOSTRAR_RESULTADOS] Materiales recibidos:', materiales?.length || 0);
    
    const lista = document.getElementById('lista-resultados-materiales');
    const contenedor = document.getElementById('resultados-materiales');
    
    console.log('[MOSTRAR_RESULTADOS] Elementos DOM:', {
        lista: !!lista,
        contenedor: !!contenedor
    });
    
    if (!lista || !contenedor) {
        console.error('[MOSTRAR_RESULTADOS] ❌ Faltan elementos del DOM');
        return;
    }
    
    if (!Array.isArray(materiales) || materiales.length === 0) {
        console.log('[MOSTRAR_RESULTADOS] ℹ️ Sin materiales, mostrando mensaje vacío');
        lista.innerHTML = `
            <div class="px-4 py-6 text-center text-gray-500 dark:text-gray-400">
                <i class="fas fa-inbox mr-2"></i>No se encontraron materiales
            </div>
        `;
        contenedor.classList.remove('hidden');
        contenedor.style.display = 'block';
        console.log('[MOSTRAR_RESULTADOS] ✅ Contenedor visible con mensaje vacío');
        return;
    }
    
    console.log('[MOSTRAR_RESULTADOS] 📋 Procesando', materiales.length, 'materiales...');
    
    // Filtrar materiales que ya estén agregados
    const filtrados = materiales.filter(m => 
        !materiales_agregados.some(ma => ma.id_material === m.id_material)
    );
    
    console.log('[MOSTRAR_RESULTADOS] 📋 Después del filtrado:', filtrados.length, 'materiales únicos');
    
    if (filtrados.length === 0) {
        console.log('[MOSTRAR_RESULTADOS] ℹ️ Todos los materiales ya están agregados');
        lista.innerHTML = `
            <div class="px-4 py-6 text-center text-gray-500 dark:text-gray-400">
                <i class="fas fa-check-circle mr-2"></i>Todos estos materiales ya están agregados
            </div>
        `;
        contenedor.classList.remove('hidden');
        contenedor.style.display = 'block';
        console.log('[MOSTRAR_RESULTADOS] ✅ Contenedor visible con mensaje "ya agregados"');
        return;
    }
    
    try {
        console.log('[MOSTRAR_RESULTADOS] 🔨 Generando HTML...');
        
        lista.innerHTML = filtrados.map((m, idx) => {
            const id_material = m.id_material || `temp_${Date.now()}_${idx}`;
            const materialKey = `material_${Date.now()}_${idx}`;
            window[materialKey] = {
                id: id_material,
                nombre: m.nombre || 'Sin nombre',
                codigo: m.codigo_material || m.codigo || '',
                categoria: m.categoria || 'Sin categoría',
                unidad: m.unidad_medida || m.unidad || 'Unidad'
            };
            
            return `
            <div class="px-4 py-3 hover:bg-gray-100 dark:hover:bg-slate-700 cursor-pointer border-b border-gray-200 dark:border-slate-700 transition-colors flex items-center justify-between group" 
                 onclick="agregarMaterialDeBusquedaSeguro('${materialKey}')" 
                 title="Click para agregar">
                <div class="flex-1">
                    <div class="font-medium text-gray-900 dark:text-white">${m.nombre || 'Sin nombre'}</div>
                    <div class="text-sm text-gray-600 dark:text-gray-400">
                        ${m.codigo_material || m.codigo || 'S/C'} • ${m.categoria || 'Sin categoría'} • ${m.unidad_medida || m.unidad || 'Unidad'}
                    </div>
                </div>
                <button type="button" class="ml-2 px-3 py-1 bg-green-500 hover:bg-green-600 text-white rounded text-xs font-medium opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap flex items-center gap-1">
                    <i class="fas fa-plus text-xs"></i>
                    <span>Agregar</span>
                </button>
            </div>
            `;
        }).join('');
        
        console.log('[MOSTRAR_RESULTADOS] ✅ HTML generado, longitud:', lista.innerHTML.length);
        console.log('[MOSTRAR_RESULTADOS] 📄 Preview HTML:', lista.innerHTML.substring(0, 200) + '...');
        
    } catch (error) {
        console.error('[MOSTRAR_RESULTADOS] ❌ Error al renderizar:', error);
        lista.innerHTML = `<div class="px-4 py-6 text-center text-red-500">Error al mostrar resultados</div>`;
    }
    
    // Mostrar contenedor
    contenedor.classList.remove('hidden');
    contenedor.style.display = 'block';
    
    console.log('[MOSTRAR_RESULTADOS] ✅ Contenedor visible con', filtrados.length, 'materiales');
    console.log('[MOSTRAR_RESULTADOS] 📊 Estado final:', {
        contenedor_visible: !contenedor.classList.contains('hidden'),
        contenedor_display: contenedor.style.display,
        lista_html_length: lista.innerHTML.length
    });
}

function agregarMaterialDeBusquedaSeguro(materialKey) {
    const materialData = window[materialKey];
    if (!materialData) {
        console.error('[AGREGAR_MATERIAL] Material no encontrado:', materialKey);
        return;
    }
    
    console.log('[AGREGAR_MATERIAL] Agregando:', materialData);
    agregarMaterialDeBusqueda(materialData.id, materialData.nombre, materialData.codigo, materialData.categoria, materialData.unidad);
}

function agregarMaterialDeBusqueda(id_material, nombre, codigo, categoria, unidad) {
    console.log('[AGREGAR_MATERIAL] Agregando:', { id_material, nombre, codigo, categoria, unidad });
    
    // Limpiar búsqueda
    document.getElementById('buscador-material').value = '';
    document.getElementById('filtro-categoria').value = '';
    document.getElementById('resultados-materiales').classList.add('hidden');
    
    // Agregar material con valores vacíos para cantidad y precio
    id_contador_material++;
    
    const material = {
        id_temporal: id_contador_material,
        id_material: id_material,
        nombre: nombre,
        codigo: codigo,
        categoria: categoria,
        unidad: unidad,
        cantidad: 1,
        precio_unitario: 0,
        subtotal: 0
    };
    
    console.log('[AGREGAR_MATERIAL] Material creado:', material);
    
    materiales_agregados.push(material);
    renderizarMateriales();
    actualizarTotales();
    
    console.log('[AGREGAR_MATERIAL] ✓ Material agregado. Total en lista:', materiales_agregados.length);
}

// ============================================================================
// RENDERIZAR MATERIALES
// ============================================================================

function renderizarMateriales() {
    const tabla = document.getElementById('tabla-materiales');
    const sin_materiales = document.getElementById('sin-materiales');
    
    // Actualizar contador
    const contador = document.getElementById('count-materiales');
    if (contador) {
        contador.textContent = `(${materiales_agregados.length} item${materiales_agregados.length !== 1 ? 's' : ''})`;
    }
    
    if (materiales_agregados.length === 0) {
        tabla.innerHTML = '';
        sin_materiales.style.display = 'block';
        return;
    }
    
    sin_materiales.style.display = 'none';
    tabla.innerHTML = materiales_agregados.map(m => `
        <tr class="hover:bg-gray-50 dark:hover:bg-slate-800/50">
            <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">${m.nombre}</td>
            <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">${m.categoria || '-'}</td>
            <td class="px-4 py-3 text-sm text-center text-gray-600 dark:text-gray-400">${m.unidad || 'Unidad'}</td>
            <td class="px-4 py-3 text-sm text-center text-gray-600 dark:text-gray-400">
                <input type="number" value="${m.cantidad}" step="0.01" min="0.01" 
                       onchange="actualizarCantidadMaterial(${m.id_temporal}, this.value)"
                       onkeydown="if(event.key==='Enter'){event.preventDefault();}"
                       class="w-20 px-2 py-1 border border-gray-300 dark:border-slate-600 rounded bg-white dark:bg-slate-800 text-gray-900 dark:text-white text-center text-sm">
            </td>
            <td class="px-4 py-3 text-sm text-right">
                <input type="number" value="${Number(m.precio_unitario).toFixed(2)}" step="0.01" min="0"
                       onchange="actualizarPrecioMaterial(${m.id_temporal}, this.value)"
                       onkeydown="if(event.key==='Enter'){event.preventDefault();}"
                       class="w-24 px-2 py-1 border border-gray-300 dark:border-slate-600 rounded bg-white dark:bg-slate-800 text-gray-900 dark:text-white text-right text-sm">
            </td>
            <td class="px-4 py-3 text-sm text-right font-semibold text-gray-900 dark:text-white">
                S/. ${(m.cantidad * m.precio_unitario).toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </td>
            <td class="px-4 py-3 text-sm text-center">
                <button type="button" onclick="eliminarMaterial(${m.id_temporal})" 
                        class="px-2 py-1 bg-red-500 hover:bg-red-600 text-white rounded text-xs transition-colors">
                    <i class="fas fa-trash-alt"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function actualizarCantidadMaterial(id_temporal, cantidad) {
    const material = materiales_agregados.find(m => m.id_temporal === id_temporal);
    if (material) {
        material.cantidad = parseFloat(cantidad) || 0;
        material.subtotal = material.cantidad * material.precio_unitario;
        renderizarMateriales();
        actualizarTotales();
    }
}

function actualizarPrecioMaterial(id_temporal, precio) {
    const material = materiales_agregados.find(m => m.id_temporal === id_temporal);
    if (material) {
        material.precio_unitario = parseFloat(precio) || 0;
        material.subtotal = material.cantidad * material.precio_unitario;
        renderizarMateriales();
        actualizarTotales();
    }
}

function eliminarMaterial(id_temporal) {
    materiales_agregados = materiales_agregados.filter(m => m.id_temporal !== id_temporal);
    renderizarMateriales();
    actualizarTotales();
}

// ============================================================================
// SERVICIOS
// ============================================================================

function agregarServicio() {
    const descripcion = document.getElementById('servicio-descripcion').value.trim();
    const cantidad = parseFloat(document.getElementById('servicio-cantidad').value) || 1;
    const precio = parseFloat(document.getElementById('servicio-precio').value) || 0;
    
    if (!descripcion) {
        mostrarError('Ingresa una descripción para el servicio');
        return;
    }
    
    id_contador_servicio++;
    
    const servicio = {
        id_temporal: id_contador_servicio,
        descripcion: descripcion,
        cantidad: cantidad,
        precio_unitario: precio,
        subtotal: cantidad * precio
    };
    
    servicios_agregados.push(servicio);
    
    // Limpiar campos
    document.getElementById('servicio-descripcion').value = '';
    document.getElementById('servicio-cantidad').value = '1';
    document.getElementById('servicio-precio').value = '';
    
    renderizarServicios();
    actualizarTotales();
}

function renderizarServicios() {
    const tabla = document.getElementById('tabla-servicios');
    const sin_servicios = document.getElementById('sin-servicios');
    
    // Actualizar contador
    const contador = document.getElementById('count-servicios');
    if (contador) {
        contador.textContent = `(${servicios_agregados.length} item${servicios_agregados.length !== 1 ? 's' : ''})`;
    }
    
    if (servicios_agregados.length === 0) {
        tabla.innerHTML = '';
        sin_servicios.style.display = 'block';
        return;
    }
    
    sin_servicios.style.display = 'none';
    tabla.innerHTML = servicios_agregados.map(s => `
        <tr class="hover:bg-gray-50 dark:hover:bg-slate-800/50">
            <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">${s.descripcion}</td>
            <td class="px-4 py-3 text-sm text-center">
                <input type="number" value="${s.cantidad}" step="0.01" min="0.01"
                       onchange="actualizarCantidadServicio(${s.id_temporal}, this.value)"
                       onkeydown="if(event.key==='Enter'){event.preventDefault();}"
                       class="w-20 px-2 py-1 border border-gray-300 dark:border-slate-600 rounded bg-white dark:bg-slate-800 text-gray-900 dark:text-white text-center text-sm">
            </td>
            <td class="px-4 py-3 text-sm text-right">
                <input type="number" value="${Number(s.precio_unitario).toFixed(2)}" step="0.01" min="0"
                       onchange="actualizarPrecioServicio(${s.id_temporal}, this.value)"
                       onkeydown="if(event.key==='Enter'){event.preventDefault();}"
                       class="w-24 px-2 py-1 border border-gray-300 dark:border-slate-600 rounded bg-white dark:bg-slate-800 text-gray-900 dark:text-white text-right text-sm">
            </td>
            <td class="px-4 py-3 text-sm text-right font-semibold text-gray-900 dark:text-white">
                S/. ${(s.cantidad * s.precio_unitario).toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}
            </td>
            <td class="px-4 py-3 text-sm text-center">
                <button type="button" onclick="eliminarServicio(${s.id_temporal})"
                        class="px-2 py-1 bg-red-500 hover:bg-red-600 text-white rounded text-xs transition-colors">
                    <i class="fas fa-trash-alt"></i>
                </button>
            </td>
        </tr>
    `).join('');
}

function actualizarCantidadServicio(id_temporal, cantidad) {
    const servicio = servicios_agregados.find(s => s.id_temporal === id_temporal);
    if (servicio) {
        servicio.cantidad = parseFloat(cantidad) || 0;
        servicio.subtotal = servicio.cantidad * servicio.precio_unitario;
        renderizarServicios();
        actualizarTotales();
    }
}

function actualizarPrecioServicio(id_temporal, precio) {
    const servicio = servicios_agregados.find(s => s.id_temporal === id_temporal);
    if (servicio) {
        servicio.precio_unitario = parseFloat(precio) || 0;
        servicio.subtotal = servicio.cantidad * servicio.precio_unitario;
        renderizarServicios();
        actualizarTotales();
    }
}

function eliminarServicio(id_temporal) {
    servicios_agregados = servicios_agregados.filter(s => s.id_temporal !== id_temporal);
    renderizarServicios();
    actualizarTotales();
}

// ============================================================================
// CÁLCULOS DE TOTALES Y DESGLOSE FINANCIERO
// ============================================================================

function actualizarTotales() {
    const total_materiales = materiales_agregados.reduce((sum, m) => sum + (m.cantidad * m.precio_unitario), 0);
    const total_servicios = servicios_agregados.reduce((sum, s) => sum + (s.cantidad * s.precio_unitario), 0);
    const subtotal_base = total_materiales + total_servicios;
    
    // ⭐ VERIFICAR SI LOS CAMPOS ESTÁN VACÍOS/CERO Y RECALCULAR AUTOMÁTICAMENTE
    const gastos_actuales = parseFloat(document.getElementById('gastos-generales').value) || 0;
    const utilidad_actuales = parseFloat(document.getElementById('utilidad').value) || 0;
    const supervision_actuales = parseFloat(document.getElementById('supervision-obra').value) || 0;
    
    // ⭐ SIEMPRE RECALCULAR SI EL SUBTOTAL CAMBIÓ (más flexible)
    const suma_actual = gastos_actuales + utilidad_actuales + supervision_actuales;
    const suma_esperada = (subtotal_base * 0.30); // 10% + 15% + 5% = 30%
    const diferencia = Math.abs(suma_actual - suma_esperada);
    
    // ⭐ FIX: Si todos los campos están en CERO exacto, SIEMPRE recalcular cuando hay subtotal
    // Esto permite que después de "Limpiar Desglose", los campos se actualicen al cambiar materiales
    const todos_en_cero = (gastos_actuales === 0 && utilidad_actuales === 0 && supervision_actuales === 0);
    
    // ⭐ NO RECALCULAR si el usuario editó manualmente (a menos que todos estén en cero)
    // Si la diferencia es mayor a 1 sol O todos están en cero, recalcular
    const debe_recalcular = !desglose_editado_manualmente && (todos_en_cero || diferencia > 1.0) && subtotal_base > 0;
    
    let gastos_generales, utilidad, supervision_obra;
    
    if (debe_recalcular) {
        // ⭐ RECALCULAR AUTOMÁTICAMENTE con porcentajes del PDF
        const pct_gg = porcentajes_pdf.gastos_generales / 100;
        const pct_util = porcentajes_pdf.utilidad / 100;
        const pct_superv = porcentajes_pdf.supervision / 100;
        
        gastos_generales = Math.round(subtotal_base * pct_gg * 100) / 100;
        utilidad = Math.round(subtotal_base * pct_util * 100) / 100;
        supervision_obra = Math.round(subtotal_base * pct_superv * 100) / 100;
        
        // Actualizar los inputs con los nuevos valores
        document.getElementById('gastos-generales').value = gastos_generales.toFixed(2);
        document.getElementById('utilidad').value = utilidad.toFixed(2);
        document.getElementById('supervision-obra').value = supervision_obra.toFixed(2);
        
        console.log('[CALCULOS] ⭐ Recálculo automático aplicado:', {
            subtotal_base: subtotal_base.toFixed(2),
            gastos_generales: gastos_generales.toFixed(2),
            utilidad: utilidad.toFixed(2),
            supervision_obra: supervision_obra.toFixed(2),
            motivo: debe_recalcular ? 'Cambio significativo detectado' : 'Campos en cero',
            desglose_editado: desglose_editado_manualmente
        });
    } else {
        // ⭐ USAR VALORES EXISTENTES (editados por el usuario)
        gastos_generales = gastos_actuales;
        utilidad = utilidad_actuales;
        supervision_obra = supervision_actuales;
        
        console.log('[CALCULOS] ⭐ Usando valores editados por usuario:', {
            gastos_generales: gastos_generales.toFixed(2),
            utilidad: utilidad.toFixed(2),
            supervision_obra: supervision_obra.toFixed(2),
            suma_actual: suma_actual.toFixed(2),
            suma_esperada: suma_esperada.toFixed(2),
            diferencia: diferencia.toFixed(2),
            desglose_editado: desglose_editado_manualmente
        });
    }
    
    // ⭐ CÁLCULO CORRECTO DEL SUB TOTAL: Costos Directos + GG + Utilidad (SIN supervisión)
    const sub_total = subtotal_base + gastos_generales + utilidad;
    
    // ⭐ IGV se calcula sobre el SUB TOTAL con porcentaje del PDF
    const pct_igv = porcentajes_pdf.igv / 100;
    const igv = sub_total * pct_igv;
    
    // Calcular totales finales
    const total_desglose = gastos_generales + utilidad + supervision_obra + igv;
    const monto_total = subtotal_base + total_desglose;
    
    // Actualizar displays
    document.getElementById('total-materiales').textContent = `S/. ${total_materiales.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('total-servicios').textContent = `S/. ${total_servicios.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('subtotal-base').textContent = `S/. ${subtotal_base.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    // Actualizar displays de desglose (mostrar los valores de los inputs)
    document.getElementById('display-gastos').textContent = `S/. ${gastos_generales.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('display-utilidad').textContent = `S/. ${utilidad.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('display-supervision').textContent = `S/. ${supervision_obra.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    // ⭐ MOSTRAR SUB TOTAL
    document.getElementById('display-subtotal').textContent = `S/. ${sub_total.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    // ⭐ MOSTRAR IGV
    document.getElementById('display-igv').textContent = `S/. ${igv.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    // Actualizar total desglose y total presupuesto
    document.getElementById('total-desglose').textContent = `S/. ${total_desglose.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('total-presupuesto').textContent = `S/. ${monto_total.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    console.log('[CALCULOS] Totales finales:', {
        subtotal_base: subtotal_base.toFixed(2),
        gastos_generales: gastos_generales.toFixed(2),
        utilidad: utilidad.toFixed(2),
        sub_total: sub_total.toFixed(2),
        igv: igv.toFixed(2),
        supervision_obra: supervision_obra.toFixed(2),
        total_desglose: total_desglose.toFixed(2),
        monto_total: monto_total.toFixed(2),
        // ⭐ VERIFICAR QUE LOS ELEMENTOS EXISTAN
        elementos_encontrados: {
            'gastos-generales': !!document.getElementById('gastos-generales'),
            'utilidad': !!document.getElementById('utilidad'),  
            'supervision-obra': !!document.getElementById('supervision-obra'),
            'display-gastos': !!document.getElementById('display-gastos'),
            'display-utilidad': !!document.getElementById('display-utilidad'),
            'display-supervision': !!document.getElementById('display-supervision'),
            'display-subtotal': !!document.getElementById('display-subtotal'),
            'display-igv': !!document.getElementById('display-igv')
        }
    });
}

// ============================================================================
// FUNCIONES PARA CAMPOS EDITABLES DEL DESGLOSE
// ============================================================================

function calcularPorcentajesAutomaticos() {
    // Calcular subtotal base
    const total_materiales = materiales_agregados.reduce((sum, m) => sum + (m.cantidad * m.precio_unitario), 0);
    const total_servicios = servicios_agregados.reduce((sum, s) => sum + (s.cantidad * s.precio_unitario), 0);
    const subtotal_base = total_materiales + total_servicios;
    
    if (subtotal_base === 0) {
        mostrarError('Primero agrega materiales o servicios para calcular los porcentajes');
        return;
    }
    
    // ⭐ RESETEAR BANDERA: el usuario pidió cálculo automático
    desglose_editado_manualmente = false;
    console.log('[CALCULAR_AUTO] Bandera reseteada → desglose_editado_manualmente = false');
    
    // Calcular porcentajes automáticos usando porcentajes del PDF
    const pct_gg = porcentajes_pdf.gastos_generales / 100;
    const pct_util = porcentajes_pdf.utilidad / 100;
    const pct_superv = porcentajes_pdf.supervision / 100;
    
    const gastos_generales = subtotal_base * pct_gg;
    const utilidad = subtotal_base * pct_util;
    const supervision_obra = subtotal_base * pct_superv;
    
    // Actualizar campos
    document.getElementById('gastos-generales').value = gastos_generales.toFixed(2);
    document.getElementById('utilidad').value = utilidad.toFixed(2);
    document.getElementById('supervision-obra').value = supervision_obra.toFixed(2);
    
    // Recalcular totales
    actualizarTotales();
    
    mostrarExito(`Porcentajes aplicados: Gastos Generales (${porcentajes_pdf.gastos_generales}%), Utilidad (${porcentajes_pdf.utilidad}%), Supervisión (${porcentajes_pdf.supervision}%)`);
}

function limpiarDesglose() {
    // ⭐ RESETEAR BANDERA: el usuario pidió limpiar
    desglose_editado_manualmente = false;
    console.log('[LIMPIAR_DESGLOSE] Bandera reseteada → desglose_editado_manualmente = false');
    
    // Limpiar campos editables a 0
    document.getElementById('gastos-generales').value = '0.00';
    document.getElementById('utilidad').value = '0.00';
    document.getElementById('supervision-obra').value = '0.00';
    
    // ⭐ NO llamar actualizarTotales() aquí para evitar recálculo inmediato
    // ⭐ En su lugar, actualizar manualmente los displays con valores en 0
    
    const total_materiales = materiales_agregados.reduce((sum, m) => sum + (m.cantidad * m.precio_unitario), 0);
    const total_servicios = servicios_agregados.reduce((sum, s) => sum + (s.cantidad * s.precio_unitario), 0);
    const subtotal_base = total_materiales + total_servicios;
    
    // IGV sobre el subtotal base solamente (sin desglose)
    const pct_igv = porcentajes_pdf.igv / 100;
    const igv = subtotal_base * pct_igv;
    
    // Totales con desglose en 0
    const total_desglose = 0 + 0 + 0 + igv; // gastos + utilidad + supervision + igv
    const monto_total = subtotal_base + total_desglose;
    
    // Actualizar displays de desglose a 0
    document.getElementById('display-gastos').textContent = 'S/. 0.00';
    document.getElementById('display-utilidad').textContent = 'S/. 0.00';
    document.getElementById('display-supervision').textContent = 'S/. 0.00';
    document.getElementById('display-igv').textContent = `S/. ${igv.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    // Actualizar totales
    document.getElementById('total-desglose').textContent = `S/. ${total_desglose.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('total-presupuesto').textContent = `S/. ${monto_total.toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    console.log('[LIMPIAR_DESGLOSE] Campos puestos en 0. Esperando cambios de usuario para recalcular.');
    
    mostrarExito('Desglose limpiado. Todos los campos en 0');
}

// ============================================================================
// FUNCIONES DE UTILIDAD
// ============================================================================

function mostrarError(mensaje) {
    alert(`❌ ${mensaje}`);
}

function mostrarExito(mensaje) {
    alert(`✅ ${mensaje}`);
}

function cerrarModalPresupuesto() {
    document.getElementById('modal-presupuesto').classList.add('hidden');
    limpiarForm(); // Esto ya limpia los arrays
}

function limpiarForm() {
    console.log('[LIMPIAR_FORM] Iniciando limpieza completa...');
    
    // ⭐ RESETEAR BANDERA DE EDICIÓN MANUAL
    desglose_editado_manualmente = false;
    
    // ⭐ RESETEAR PORCENTAJES A VALORES POR DEFECTO
    porcentajes_pdf = {
        gastos_generales: 10,
        utilidad: 15,
        supervision: 5,
        igv: 18
    };
    
    // ⭐ 1. LIMPIAR FORMULARIO BASE
    const form = document.getElementById('form-presupuesto');
    if (form) {
        form.reset();
    }
    
    // ⭐ 2. LIMPIAR ARRAYS GLOBALES
    materiales_agregados = [];
    servicios_agregados = [];
    id_contador_material = 0;
    id_contador_servicio = 0;
    
    // ⭐ 3. LIMPIAR CAMPOS ESPECÍFICOS (incluso después del reset)
    const campos = {
        'id_empresa': '',
        'id_proyecto': '',
        'id_obra': '',
        'comentarios': '',
        'gastos-generales': '0.00',
        'utilidad': '0.00',
        'supervision-obra': '0.00',
        'servicio-descripcion': '',
        'servicio-cantidad': '1',
        'servicio-precio': '',
        'buscador-material': '',
        'filtro-categoria': ''
    };
    
    Object.keys(campos).forEach(id => {
        const elemento = document.getElementById(id);
        if (elemento) {
            elemento.value = campos[id];
        }
    });
    
    // ⭐ 4. OCULTAR RESULTADOS DE BÚSQUEDA
    const resultados = document.getElementById('resultados-materiales');
    if (resultados) {
        resultados.classList.add('hidden');
        resultados.style.display = 'none';
    }
    
    // ⭐ 5. RENDERIZAR TABLAS VACÍAS
    renderizarMateriales();
    renderizarServicios();
    
    // ⭐ 6. ACTUALIZAR TOTALES (todo en cero)
    actualizarTotales();
    
    console.log('[LIMPIAR_FORM] ✅ Limpieza completa terminada:', {
        materiales: materiales_agregados.length,
        servicios: servicios_agregados.length,
        contador_material: id_contador_material,
        contador_servicio: id_contador_servicio
    });
}

function abrirModalNuevoMaterial() {
    console.log('[NUEVO_MATERIAL] Abriendo formulario...');
    
    // Crear un modal simple para agregar material manualmente
    const nombre = prompt('Nombre del material:');
    if (!nombre) return;
    
    const codigo = prompt('Código del material (opcional):');
    const cantidad = prompt('Cantidad:', '1');
    const precio = prompt('Precio unitario:', '0');
    
    if (!cantidad || isNaN(cantidad) || !precio || isNaN(precio)) {
        mostrarError('Cantidad y precio deben ser números válidos');
        return;
    }
    
    // Agregar material manual (sin id_material, será como un servicio pero tipo MATERIAL)
    id_contador_material++;
    const subtotal = parseFloat(cantidad) * parseFloat(precio);
    
    materiales_agregados.push({
        id_temporal: id_contador_material,
        id_material: null,  // Sin ID porque es nuevo/manual
        nombre: nombre,
        codigo: codigo || '',
        categoria: 'Manual',
        unidad: 'Unidad',
        cantidad: parseFloat(cantidad),
        precio_unitario: parseFloat(precio),
        subtotal: subtotal
    });
    
    console.log('[NUEVO_MATERIAL] Material agregado:', materiales_agregados[materiales_agregados.length - 1]);
    
    renderizarMateriales();
    actualizarTotales();
    mostrarExito('Material agregado exitosamente');
}

// ============================================================================
// MODAL: ABRIR Y CERRAR
// ============================================================================

function abrirModalPresupuesto() {
    console.log('[ABRIR_MODAL] Abriendo modal de presupuesto');
    limpiarForm();
    document.getElementById('modal-presupuesto').classList.remove('hidden');
    cargarCategorias();
}

// ============================================================================
// CARGAR DROPDOWNS
// ============================================================================

async function cargarEmpresas() {
    try {
        console.log('[CARGAR_EMPRESAS] Iniciando...');
        const response = await fetch('/api/presupuestos/empresas/listar');
        const data = await response.json();
        
        if (data.success && data.data) {
            const select = document.getElementById('id_empresa');
            select.innerHTML = '<option value="">Seleccionar empresa...</option>';
            data.data.forEach(e => {
                select.innerHTML += `<option value="${e.id_empresa}">${e.nombre}</option>`;
            });
            console.log('[CARGAR_EMPRESAS] ✓ Cargadas', data.data.length, 'empresas');
        }
    } catch (error) {
        console.error('[CARGAR_EMPRESAS] Error:', error);
    }
}

async function cargarProyectos() {
    try {
        console.log('[CARGAR_PROYECTOS] Iniciando...');
        const response = await fetch('/api/presupuestos/proyectos/listar');
        const data = await response.json();
        
        if (data.success && data.data) {
            const select = document.getElementById('id_proyecto');
            select.innerHTML = '<option value="">Seleccionar proyecto...</option>';
            data.data.forEach(p => {
                select.innerHTML += `<option value="${p.id_proyecto}">${p.nombre}</option>`;
            });
            console.log('[CARGAR_PROYECTOS] ✓ Cargados', data.data.length, 'proyectos');
        }
    } catch (error) {
        console.error('[CARGAR_PROYECTOS] Error:', error);
    }
}

async function cargarObras() {
    try {
        console.log('[CARGAR_OBRAS] Iniciando...');
        const idProyecto = document.getElementById('id_proyecto').value;
        console.log('[CARGAR_OBRAS] ID Proyecto:', idProyecto);
        
        if (!idProyecto) {
            console.log('[CARGAR_OBRAS] ⚠ Sin proyecto seleccionado, limpiando obras');
            const select = document.getElementById('id_obra');
            select.innerHTML = '<option value="">Seleccionar obra...</option>';
            return;
        }
        
        const response = await fetch(`/api/presupuestos/obras/listar?id_proyecto=${idProyecto}`);
        const data = await response.json();
        
        if (data.success && data.data) {
            const select = document.getElementById('id_obra');
            select.innerHTML = '<option value="">Seleccionar obra...</option>';
            data.data.forEach(o => {
                select.innerHTML += `<option value="${o.id_obra}">${o.nombre}</option>`;
            });
            console.log('[CARGAR_OBRAS] ✓ Cargadas', data.data.length, 'obras para proyecto', idProyecto);
        }
    } catch (error) {
        console.error('[CARGAR_OBRAS] Error:', error);
    }
}

// ============================================================================
// GUARDAR PRESUPUESTO - FUNCIÓN PRINCIPAL
// ============================================================================

async function guardarPresupuestoCompleto(e) {
    e.preventDefault();
    
    console.log('\n' + '='.repeat(80));
    console.log('[GUARDAR_PRESUPUESTO] Iniciando validación y guardado');
    console.log('='.repeat(80));
    
    try {
        // Obtener valores del formulario
        const id_empresa = document.getElementById('id-empresa').value;
        const id_obra = document.getElementById('id-obra').value;
        const comentarios = document.getElementById('observaciones').value;
        
        console.log('[GUARDAR_PRESUPUESTO] Datos del formulario:');
        console.log('  • id_empresa:', id_empresa);
        console.log('  • id_obra:', id_obra);
        console.log('  • comentarios:', comentarios.substring(0, 50) + (comentarios.length > 50 ? '...' : ''));
        
        // VALIDACIÓN 1: Empresa y Obra obligatorias
        if (!id_empresa || !id_obra) {
            console.log('[GUARDAR_PRESUPUESTO] ❌ Error: Falta empresa u obra');
            mostrarError('Por favor selecciona Empresa y Obra');
            return;
        }
        
        console.log('[GUARDAR_PRESUPUESTO] ✓ Empresa y Obra válidas');
        
        // VALIDACIÓN 2: Al menos 1 material o servicio
        if (materiales_agregados.length === 0 && servicios_agregados.length === 0) {
            console.log('[GUARDAR_PRESUPUESTO] ❌ Error: Sin materiales ni servicios');
            mostrarError('Por favor agrega al menos un material o servicio');
            return;
        }
        
        console.log('[GUARDAR_PRESUPUESTO] ✓ Tiene materiales/servicios');
        console.log('  • Materiales:', materiales_agregados.length);
        console.log('  • Servicios:', servicios_agregados.length);
        
        // Preparar datos para enviar
        const datosEnvio = {
            id_empresa: parseInt(id_empresa),
            id_obra: parseInt(id_obra),
            comentarios: comentarios || '',
            // ⭐ AGREGAR CAMPOS DEL DESGLOSE FINANCIERO
            gastos_generales: parseFloat(document.getElementById('gastos-generales').value) || 0,
            utilidad: parseFloat(document.getElementById('utilidad').value) || 0,
            supervision_obra: parseFloat(document.getElementById('supervision-obra').value) || 0,
            materiales: materiales_agregados.map(m => ({
                id_material: m.id_material,
                nombre: m.nombre,
                cantidad: m.cantidad,
                precio_unitario: m.precio_unitario
            })),
            servicios: servicios_agregados.map(s => ({
                descripcion: s.descripcion,
                cantidad: s.cantidad,
                precio_unitario: s.precio_unitario
            }))
        };
        
        console.log('[GUARDAR_PRESUPUESTO] Datos a enviar:');
        console.log(JSON.stringify(datosEnvio, null, 2));
        
        console.log('[GUARDAR_PRESUPUESTO] Enviando POST a /api/presupuestos/crear...');
        
        // Enviar al backend
        const response = await fetch('/api/presupuestos/crear', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(datosEnvio)
        });
        
        const resultado = await response.json();
        
        if (!response.ok) {
            console.log('[GUARDAR_PRESUPUESTO] ❌ Error del servidor:', resultado.error);
            mostrarError('Error: ' + (resultado.error || 'Error desconocido'));
            return;
        }
        
        console.log('[GUARDAR_PRESUPUESTO] ✅ Presupuesto creado exitosamente');
        console.log('  • ID presupuesto:', resultado.id_presupuesto);
        console.log('  • Mensaje:', resultado.message);
        
        mostrarExito('Presupuesto creado exitosamente');
        cerrarModalPresupuesto();
        
        // Recargar tabla
        console.log('[GUARDAR_PRESUPUESTO] Recargando tabla...');
        await cargarPresupuestos();
        
        console.log('[GUARDAR_PRESUPUESTO] ✅ COMPLETADO');
        console.log('='.repeat(80) + '\n');
        
    } catch (error) {
        console.error('[GUARDAR_PRESUPUESTO] ❌ Error en catch:', error);
        mostrarError('Error: ' + error.message);
    }
}

// ============================================================================
// CARGAR TABLA DE PRESUPUESTOS
// ============================================================================

async function cargarPresupuestos() {
    try {
        console.log('[CARGAR_PRESUPUESTOS] Iniciando...');
        
        const response = await fetch('/api/presupuestos/obtener');
        const data = await response.json();
        
        if (!data.success) {
            console.error('[CARGAR_PRESUPUESTOS] Error:', data.error);
            return;
        }
        
        console.log('[CARGAR_PRESUPUESTOS] ✓ Cargados', data.data?.length || 0, 'presupuestos');
        
        const tbody = document.getElementById('presupuestos-lista');
        
        if (!data.data || data.data.length === 0) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="10" class="px-4 py-6 text-center text-xs text-gray-500">
                        <i class="fas fa-inbox mr-2"></i>Sin presupuestos
                    </td>
                </tr>
            `;
            return;
        }
        
        tbody.innerHTML = data.data.map(p => {
            // Debug: ver qué datos llegan
            console.log('Presupuesto:', p);
            
            const estadoColor = {
                'PENDIENTE': 'bg-yellow-100 text-yellow-800',
                'APROBADO': 'bg-green-100 text-green-800',
                'RECHAZADO': 'bg-red-100 text-red-800'
            };
            
            // Formatear fecha_actualizacion
            let fechaFormateada = '-';
            if (p.fecha_actualizacion) {
                try {
                    const fecha = new Date(p.fecha_actualizacion);
                    fechaFormateada = fecha.toLocaleDateString('es-PE', {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    });
                } catch (e) {
                    console.error('Error formateando fecha:', e);
                }
            }
            
            return `
                <tr class="hover:bg-gray-50 dark:hover:bg-slate-800">
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${fechaFormateada}</td>
                    <td class="px-4 py-3 text-xs font-medium text-gray-900 dark:text-white">${p.numero_presupuesto}</td>
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${p.nombre_proyecto || '-'}</td>
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${p.nombre_obra || '-'}</td>
                    <td class="px-4 py-3 text-xs font-semibold text-gray-900 dark:text-white">S/. ${parseFloat(p.monto).toLocaleString('es-PE', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                    <td class="px-4 py-3 text-xs">
                        <span class="px-2 py-1 rounded-full text-xs font-semibold ${estadoColor[p.estado] || 'bg-gray-100 text-gray-800 dark:bg-slate-700 dark:text-gray-300'}">
                            ${p.estado}
                        </span>
                    </td>
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${p.creado_por || '-'}</td>
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${p.aprobado_rechazado_por || '-'}</td>
                    <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">${p.comentario_rechazo || '-'}</td>
                    <td class="px-4 py-3 text-xs">
                        <div class="flex gap-1">
                            <button onclick="descargarPresupuestoPDF(${p.id_presupuesto})" class="px-2 py-1 bg-green-600 hover:bg-green-700 text-white rounded text-xs transition" title="Descargar PDF">
                                <i class="fas fa-file-pdf"></i>
                            </button>
                            <button onclick="abrirModalEditar(${p.id_presupuesto})" class="px-2 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded text-xs transition">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button onclick="abrirModalEliminar(${p.id_presupuesto}, '${p.numero_presupuesto}')" class="px-2 py-1 bg-red-600 hover:bg-red-700 text-white rounded text-xs transition">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
        
    } catch (error) {
        console.error('[CARGAR_PRESUPUESTOS] Error:', error);
    }
}

// ============================================================================
// EDITAR PRESUPUESTO
// ============================================================================

async function abrirModalEditar(id_presupuesto) {
    try {
        console.log('[EDITAR_MODAL] Abriendo para ID:', id_presupuesto);
        
        const response = await fetch(`/api/presupuestos/${id_presupuesto}`);
        const data = await response.json();
        
        if (!data.success) {
            mostrarError('Error al cargar presupuesto');
            return;
        }
        
        const p = data.data;
        
        document.getElementById('editar-id-presupuesto').value = p.id_presupuesto;
        document.getElementById('editar-numero').value = p.numero_presupuesto;
        document.getElementById('editar-estado').value = p.estado;
        document.getElementById('editar-id-empresa').value = p.id_empresa;
        document.getElementById('editar-id-obra').value = p.id_obra;
        document.getElementById('editar-comentarios').value = p.observaciones || '';
        
        // Cargar opciones de empresa y obra en el modal de edición
        await cargarEmpresasEditar();
        await cargarObrasEditar();
        
        document.getElementById('modal-editar-presupuesto').classList.remove('hidden');
        
    } catch (error) {
        console.error('[EDITAR_MODAL] Error:', error);
        mostrarError('Error al abrir presupuesto');
    }
}

function cerrarModalEditar() {
    document.getElementById('modal-editar-presupuesto').classList.add('hidden');
}

async function cargarEmpresasEditar() {
    try {
        const response = await fetch('/api/presupuestos/empresas/listar');
        const data = await response.json();
        
        if (data.success && data.data) {
            const select = document.getElementById('editar-id-empresa');
            const actual = select.value;
            select.innerHTML = '<option value="">Seleccionar empresa...</option>';
            data.data.forEach(e => {
                select.innerHTML += `<option value="${e.id_empresa}">${e.nombre}</option>`;
            });
            select.value = actual;
        }
    } catch (error) {
        console.error('[CARGAR_EMPRESAS_EDITAR] Error:', error);
    }
}

async function cargarObrasEditar() {
    try {
        const response = await fetch('/api/presupuestos/combo/obras');
        const data = await response.json();
        
        if (data.success && data.data) {
            const select = document.getElementById('editar-id-obra');
            const actual = select.value;
            select.innerHTML = '<option value="">Seleccionar obra...</option>';
            data.data.forEach(o => {
                select.innerHTML += `<option value="${o.id_obra}">${o.nombre}</option>`;
            });
            select.value = actual;
        }
    } catch (error) {
        console.error('[CARGAR_OBRAS_EDITAR] Error:', error);
    }
}

async function guardarEdicion(e) {
    e.preventDefault();
    
    try {
        const id_presupuesto = document.getElementById('editar-id-presupuesto').value;
        const id_empresa = document.getElementById('editar-id-empresa').value;
        const id_obra = document.getElementById('editar-id-obra').value;
        const comentarios = document.getElementById('editar-comentarios').value;
        
        if (!id_empresa || !id_obra) {
            mostrarError('Por favor completa los campos obligatorios');
            return;
        }
        
        const response = await fetch(`/api/presupuestos/actualizar/${id_presupuesto}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                id_empresa: parseInt(id_empresa),
                id_obra: parseInt(id_obra),
                comentarios: comentarios,
                materiales: [],
                servicios: []
            })
        });
        
        const resultado = await response.json();
        
        if (!response.ok) {
            mostrarError('Error: ' + (resultado.error || 'Error desconocido'));
            return;
        }
        
        mostrarExito('Presupuesto actualizado exitosamente');
        cerrarModalEditar();
        await cargarPresupuestos();
        
    } catch (error) {
        console.error('[GUARDAR_EDICION] Error:', error);
        mostrarError('Error: ' + error.message);
    }
}

// ============================================================================
// ELIMINAR PRESUPUESTO
// ============================================================================

function abrirModalEliminar(id_presupuesto, numero) {
    document.getElementById('eliminar-numero').textContent = numero;
    document.getElementById('modal-eliminar-presupuesto').dataset.id = id_presupuesto;
    document.getElementById('modal-eliminar-presupuesto').classList.remove('hidden');
}

function cerrarModalEliminar() {
    document.getElementById('modal-eliminar-presupuesto').classList.add('hidden');
}

async function confirmarEliminar() {
    try {
        const id_presupuesto = document.getElementById('modal-eliminar-presupuesto').dataset.id;
        
        const response = await fetch(`/api/presupuestos/eliminar/${id_presupuesto}`, {
            method: 'DELETE'
        });
        
        const resultado = await response.json();
        
        if (!response.ok) {
            mostrarError('Error: ' + (resultado.error || 'Error desconocido'));
            return;
        }
        
        mostrarExito('Presupuesto eliminado exitosamente');
        cerrarModalEliminar();
        await cargarPresupuestos();
        
    } catch (error) {
        console.error('[ELIMINAR] Error:', error);
        mostrarError('Error: ' + error.message);
    }
}


// ============================================================================
// FUNCIÓN PARA CARGAR Y MOSTRAR EL FLUJO DE APROBACIÓN
// ============================================================================

/**
 * Carga el estado del flujo de aprobación y renderiza los círculos
 * @param {number} id_presupuesto - ID del presupuesto
 */
async function cargarFlujoAprobacion(id_presupuesto) {
    try {
        const response = await fetch(`/api/presupuestos/obtener-flujo-aprobacion/${id_presupuesto}`);
        const result = await response.json();
        
        if (!result.success) {
            console.error('[FLUJO] Error:', result.error);
            return;
        }
        
        // CRÍTICO: El endpoint retorna pasos DIRECTAMENTE, no dentro de result.data
        const pasos = result.pasos || (result.data && result.data.pasos) || [];
        const container = document.getElementById(`flujo-${id_presupuesto}`);
        
        if (!container) {
            console.warn(`[FLUJO] No se encontró contenedor para presupuesto ${id_presupuesto}`);
            return;
        }
        
        // Limpiar el contenedor
        container.innerHTML = '';
        
        // Crear HTML para los círculos del flujo
        let html = '';
        pasos.forEach((paso, index) => {
            // Determinar color según estado
            let colorCirculo = 'bg-gray-300';  // PENDIENTE (gris/neutro)
            let iconoEstado = '';
            let textoTooltip = '';
            
            if (paso.estado === 'APROBADO') {
                colorCirculo = 'bg-green-500';
                iconoEstado = '<i class="fas fa-check text-white text-xs"></i>';
                textoTooltip = paso.usuario_aprobador || 'Aprobado';
            } else if (paso.estado === 'RECHAZADO') {
                colorCirculo = 'bg-red-500';
                iconoEstado = '<i class="fas fa-times text-white text-xs"></i>';
                textoTooltip = paso.comentario ? `Rechazado: ${paso.comentario}` : 'Rechazado';
            } else {
                // PENDIENTE - sin ícono
                colorCirculo = 'bg-gray-300 text-gray-700';
                textoTooltip = 'Pendiente de aprobación';
            }
            
            // Crear círculo
            html += `<div class="relative group">
                        <div class="w-8 h-8 ${colorCirculo} rounded-full flex items-center justify-center cursor-pointer transition-transform hover:scale-125 font-semibold" 
                             title="${htmlEscape(textoTooltip)}"
                             data-paso="${paso.numero_paso}">
                            ${iconoEstado}
                        </div>
                        <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-gray-800 text-white text-xs rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10">
                            ${htmlEscape(textoTooltip)}
                        </div>
                    </div>`;
            
            // Agregar flecha entre círculos (excepto en el último)
            if (index < pasos.length - 1) {
                html += `<div class="w-6 h-0.5 bg-gray-300 dark:bg-slate-600 mx-0.5"></div>`;
            }
        });
        
        container.innerHTML = html;
        
    } catch (error) {
        console.error('[FLUJO] Error al cargar flujo:', error);
    }
}

/**
 * Escapa caracteres HTML para evitar XSS
 */
function htmlEscape(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;',
        '\n': '&#10;',
        '\r': '&#13;'
    };
    return text.replace(/[&<>"'\n\r]/g, m => map[m]);
}

/**
 * Modificar cargarPresupuestos para incluir el flujo de aprobación
 */
const originalCargarPresupuestos = window.cargarPresupuestos;
window.cargarPresupuestos = async function() {
    // Llamar a la función original
    await originalCargarPresupuestos.call(this);
    
    // Después de cargar, obtener todos los presupuestos y cargar su flujo
    try {
        const response = await fetch('/api/presupuestos/obtener');
        const data = await response.json();
        
        if (data.success && data.data) {
            const presupuestos = data.data;
            
            // Cargar flujo para cada presupuesto
            presupuestos.forEach(p => {
                cargarFlujoAprobacion(p.id_presupuesto);
            });
        }
    } catch (error) {
        console.error('[PRESUPUESTOS] Error al cargar flujos:', error);
    }
};


// ============================================================================
// MODAL: CREAR NUEVO MATERIAL
// ============================================================================

async function abrirModalNuevoMaterial() {
    console.log('[NUEVO_MATERIAL] Abriendo modal...');
    
    // Mostrar modal primero
    document.getElementById('modal-nuevo-material').classList.remove('hidden');
    
    // Limpiar formulario
    document.getElementById('form-nuevo-material').reset();
    
    // Mostrar que el código se generará automáticamente
    const codigoInput = document.getElementById('nuevo-codigo');
    codigoInput.value = 'Se generará automáticamente';
    codigoInput.disabled = true;
    
    // Cargar categorías y unidades
    await Promise.all([
        cargarCategoriasParaMaterial(),
        cargarUnidadesMedida()
    ]);
    
    // Focus en el campo de nombre (ya que código es automático)
    setTimeout(() => {
        document.getElementById('nuevo-nombre').focus();
    }, 100);
}

function cerrarModalNuevoMaterial() {
    document.getElementById('modal-nuevo-material').classList.add('hidden');
    document.getElementById('form-nuevo-material').reset();
}

async function cargarCategoriasParaMaterial() {
    try {
        const response = await fetch('/api/presupuestos/combo/categorias');
        const data = await response.json();
        
        if (data.success) {
            const select = document.getElementById('nuevo-categoria');
            select.innerHTML = '<option value="">Sin categoría</option>';
            data.data.forEach(c => {
                select.innerHTML += `<option value="${c.id_categoria}">${c.nombre}</option>`;
            });
        }
    } catch (error) {
        console.error('[NUEVO_MATERIAL] Error al cargar categorías:', error);
    }
}

async function cargarUnidadesMedida() {
    try {
        console.log('[UNIDADES] Cargando unidades de medida...');
        const response = await fetch('/api/presupuestos/combo/unidades');
        console.log('[UNIDADES] Response status:', response.status);
        
        const data = await response.json();
        console.log('[UNIDADES] Data recibida:', data);
        
        if (data.success) {
            const select = document.getElementById('nuevo-unidad');
            if (!select) {
                console.error('[UNIDADES] ❌ Elemento nuevo-unidad NO encontrado');
                return;
            }
            
            select.innerHTML = '<option value="">Seleccionar...</option>';
            data.data.forEach(u => {
                select.innerHTML += `<option value="${u.id_unidad}">${u.nombre}</option>`;
            });
            console.log('[UNIDADES] ✓ Cargadas', data.data.length, 'unidades');
        } else {
            console.error('[UNIDADES] ❌ Error:', data.error);
        }
    } catch (error) {
        console.error('[UNIDADES] ❌ Error al cargar unidades:', error);
    }
}

async function guardarNuevoMaterial() {
    console.log('[NUEVO_MATERIAL] Guardando...');
    
    // Validar formulario
    const form = document.getElementById('form-nuevo-material');
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    // Obtener valores (SIN código, precio, stocks - se generan/ponen en 0 automáticamente)
    const nombre = document.getElementById('nuevo-nombre').value.trim();
    const descripcion = document.getElementById('nuevo-descripcion').value.trim();
    const id_categoria = document.getElementById('nuevo-categoria').value || null;
    const id_unidad = document.getElementById('nuevo-unidad').value;
    const observaciones = document.getElementById('nuevo-observaciones').value.trim();
    
    if (!nombre || !id_unidad) {
        mostrarError('Complete los campos obligatorios: Nombre y Unidad de Medida');
        return;
    }
    
    const datos = {
        // ⭐ Solo campos esenciales, el resto va en 0
        nombre: nombre,
        descripcion: descripcion || null,
        id_categoria: id_categoria ? parseInt(id_categoria) : null,
        id_unidad: parseInt(id_unidad),
        observaciones: observaciones || null
        // precio_unitario: 0 (por defecto en SP)
        // cantidad_stock: 0 (por defecto en SP)
        // cantidad_minima: 0 (por defecto en SP)
    };
    
    console.log('[NUEVO_MATERIAL] Datos a enviar:', datos);
    
    try {
        const response = await fetch('/api/materiales/crear', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(datos)
        });
        
        const result = await response.json();
        
        if (result.success) {
            console.log('[NUEVO_MATERIAL] ✓ Material creado:', result.data);
            mostrarExito(`Material creado correctamente con código ${result.data.codigo_material}`);
            cerrarModalNuevoMaterial();
            
            // Agregar automáticamente el material recién creado al presupuesto
            const materialCreado = result.data;
            agregarMaterialDeBusqueda(
                materialCreado.id_material,
                materialCreado.nombre,
                materialCreado.codigo_material,
                materialCreado.categoria || 'Sin categoría',
                materialCreado.unidad_medida || 'Unidad'
            );
            
        } else {
            console.error('[NUEVO_MATERIAL] ✗ Error:', result.error);
            mostrarError(result.error || 'Error al crear material');
        }
    } catch (error) {
        console.error('[NUEVO_MATERIAL] Error de conexión:', error);
        mostrarError('Error de conexión');
    }
}

// ============================================================================
// IMPORTAR PDF - Extraer materiales y servicios desde un documento
// ============================================================================

async function importarPDF(input) {
    const archivo = input.files[0];
    if (!archivo) return;
    
    if (!archivo.name.toLowerCase().endsWith('.pdf')) {
        mostrarError('El archivo debe ser un PDF');
        input.value = '';
        return;
    }
    
    console.log('[IMPORTAR_PDF] Procesando:', archivo.name);
    
    // Mostrar indicador de carga
    const btnLabel = document.querySelector('label[for="input-pdf-importar"]');
    const iconoOriginal = btnLabel ? btnLabel.innerHTML : '';
    if (btnLabel) {
        btnLabel.innerHTML = '<i class="fas fa-spinner fa-spin text-lg"></i>';
        btnLabel.style.pointerEvents = 'none';
    }
    
    try {
        const formData = new FormData();
        formData.append('archivo', archivo);
        
        const response = await fetch('/api/presupuestos/importar-pdf', {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (!result.success) {
            mostrarError(result.error || 'Error al procesar el PDF');
            return;
        }
        
        console.log('[IMPORTAR_PDF] Resultado:', result);
        
        // Agregar materiales al array global
        if (result.materiales && result.materiales.length > 0) {
            result.materiales.forEach(m => {
                id_contador_material++;
                materiales_agregados.push({
                    id_temporal: id_contador_material,
                    id_material: m.id_material || null,
                    nombre: m.nombre,
                    codigo: '',
                    categoria: '',
                    unidad: m.unidad || 'Unidad',
                    cantidad: m.cantidad || 1,
                    precio_unitario: m.precio_unitario || 0,
                    subtotal: m.subtotal || 0
                });
            });
            renderizarMateriales();
        }
        
        // Agregar servicios al array global
        if (result.servicios && result.servicios.length > 0) {
            result.servicios.forEach(s => {
                id_contador_servicio++;
                servicios_agregados.push({
                    id_temporal: id_contador_servicio,
                    descripcion: s.descripcion,
                    cantidad: s.cantidad || 1,
                    precio_unitario: s.precio_unitario || 0,
                    subtotal: s.subtotal || 0
                });
            });
            renderizarServicios();
        }
        
        // Actualizar porcentajes desde el PDF
        if (result.porcentajes) {
            porcentajes_pdf.gastos_generales = result.porcentajes.gastos_generales || 10;
            porcentajes_pdf.utilidad = result.porcentajes.utilidad || 15;
            porcentajes_pdf.igv = result.porcentajes.igv || 18;
            // Supervisión no viene del PDF, mantener 0 si no está
            porcentajes_pdf.supervision = 0;
            
            // Resetear el flag para que recalcule con los nuevos porcentajes
            desglose_editado_manualmente = false;
            
            console.log('[IMPORTAR_PDF] Porcentajes del PDF:', porcentajes_pdf);
            
            // Actualizar inputs con los porcentajes del PDF
            document.getElementById('gastos-generales').value = '0.00';
            document.getElementById('utilidad').value = '0.00';
            document.getElementById('supervision-obra').value = '0.00';
        }
        
        // Recalcular totales con los porcentajes del PDF
        actualizarTotales();
        
        const totalMat = result.materiales ? result.materiales.length : 0;
        const totalServ = result.servicios ? result.servicios.length : 0;
        const nuevos = result.materiales_nuevos ? result.materiales_nuevos.length : 0;
        const existentes = result.materiales_existentes ? result.materiales_existentes.length : 0;
        
        // Construir mensaje detallado
        let mensaje = `PDF importado: ${totalMat} materiales y ${totalServ} servicios`;
        if (nuevos > 0 || existentes > 0) {
            mensaje += ` (${nuevos} nuevos, ${existentes} existentes)`;
        }
        
        mostrarExito(mensaje);
        console.log(`[IMPORTAR_PDF] ✅ completado: ${totalMat} materiales (${nuevos} nuevos, ${existentes} existentes), ${totalServ} servicios`);
        
    } catch (error) {
        console.error('[IMPORTAR_PDF] Error:', error);
        mostrarError('Error al conectar con el servidor: ' + error.message);
    } finally {
        // Restaurar botón
        if (btnLabel) {
            btnLabel.innerHTML = iconoOriginal;
            btnLabel.style.pointerEvents = '';
        }
        input.value = '';
    }
}

// ============================================================================
// IMPORTAR EXCEL - Extraer materiales y servicios desde un archivo Excel
// ============================================================================

async function importarExcel(input) {
    const archivo = input.files[0];
    if (!archivo) return;
    
    const nombreLower = archivo.name.toLowerCase();
    if (!nombreLower.endsWith('.xlsx') && !nombreLower.endsWith('.xls')) {
        mostrarError('El archivo debe ser un Excel (.xlsx o .xls)');
        input.value = '';
        return;
    }
    
    console.log('[IMPORTAR_EXCEL] Procesando:', archivo.name);
    
    // Mostrar indicador de carga
    const btnLabel = document.querySelector('label[for="input-excel-importar"]');
    const iconoOriginal = btnLabel ? btnLabel.innerHTML : '';
    if (btnLabel) {
        btnLabel.innerHTML = '<i class="fas fa-spinner fa-spin text-lg"></i>';
        btnLabel.style.pointerEvents = 'none';
    }
    
    try {
        const formData = new FormData();
        formData.append('archivo', archivo);
        
        const response = await fetch('/api/presupuestos/importar-excel', {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (!result.success) {
            mostrarError(result.error || 'Error al procesar el Excel');
            return;
        }
        
        console.log('[IMPORTAR_EXCEL] Resultado:', result);
        
        // Agregar materiales al array global (misma logica que importarPDF)
        if (result.materiales && result.materiales.length > 0) {
            result.materiales.forEach(m => {
                id_contador_material++;
                materiales_agregados.push({
                    id_temporal: id_contador_material,
                    id_material: m.id_material || null,
                    nombre: m.nombre,
                    codigo: '',
                    categoria: '',
                    unidad: m.unidad || 'Unidad',
                    cantidad: m.cantidad || 1,
                    precio_unitario: m.precio_unitario || 0,
                    subtotal: m.subtotal || 0
                });
            });
            renderizarMateriales();
        }
        
        // Agregar servicios al array global
        if (result.servicios && result.servicios.length > 0) {
            result.servicios.forEach(s => {
                id_contador_servicio++;
                servicios_agregados.push({
                    id_temporal: id_contador_servicio,
                    descripcion: s.descripcion,
                    cantidad: s.cantidad || 1,
                    precio_unitario: s.precio_unitario || 0,
                    subtotal: s.subtotal || 0
                });
            });
            renderizarServicios();
        }
        
        // Actualizar porcentajes desde el Excel
        if (result.porcentajes) {
            porcentajes_pdf.gastos_generales = result.porcentajes.gastos_generales || 0;
            porcentajes_pdf.utilidad = result.porcentajes.utilidad || 0;
            porcentajes_pdf.igv = result.porcentajes.igv || 18;
            porcentajes_pdf.supervision = 0;
            
            desglose_editado_manualmente = false;
            
            console.log('[IMPORTAR_EXCEL] Porcentajes del Excel:', porcentajes_pdf);
            
            document.getElementById('gastos-generales').value = '0.00';
            document.getElementById('utilidad').value = '0.00';
            document.getElementById('supervision-obra').value = '0.00';
        }
        
        // Recalcular totales
        actualizarTotales();
        
        const totalMat = result.materiales ? result.materiales.length : 0;
        const totalServ = result.servicios ? result.servicios.length : 0;
        const nuevos = result.materiales_nuevos ? result.materiales_nuevos.length : 0;
        const existentes = result.materiales_existentes ? result.materiales_existentes.length : 0;
        
        let mensaje = `Excel importado: ${totalMat} materiales y ${totalServ} servicios`;
        if (nuevos > 0 || existentes > 0) {
            mensaje += ` (${nuevos} nuevos, ${existentes} existentes)`;
        }
        
        mostrarExito(mensaje);
        console.log(`[IMPORTAR_EXCEL] completado: ${totalMat} materiales (${nuevos} nuevos, ${existentes} existentes), ${totalServ} servicios`);
        
    } catch (error) {
        console.error('[IMPORTAR_EXCEL] Error:', error);
        mostrarError('Error al conectar con el servidor: ' + error.message);
    } finally {
        if (btnLabel) {
            btnLabel.innerHTML = iconoOriginal;
            btnLabel.style.pointerEvents = '';
        }
        input.value = '';
    }
}
