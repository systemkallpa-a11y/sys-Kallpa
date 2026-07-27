// ============================================================================
// TEST: Verificar que el modal "Crear Nuevo Presupuesto" se abra limpio
// ============================================================================

console.log('🧪 Iniciando test de limpieza del modal...');

// Función para verificar el estado del formulario
function verificarEstadoFormulario() {
    const resultados = {
        arrays_globales: {
            materiales: materiales_agregados ? materiales_agregados.length : 'undefined',
            servicios: servicios_agregados ? servicios_agregados.length : 'undefined',
            contador_material: typeof id_contador_material !== 'undefined' ? id_contador_material : 'undefined',
            contador_servicio: typeof id_contador_servicio !== 'undefined' ? id_contador_servicio : 'undefined'
        },
        campos_formulario: {},
        elementos_ui: {}
    };

    // Verificar campos específicos
    const campos_a_verificar = [
        'id_empresa',
        'id_proyecto', 
        'id_obra',
        'comentarios',
        'gastos-generales',
        'utilidad',
        'supervision-obra',
        'servicio-descripcion',
        'servicio-cantidad',
        'servicio-precio',
        'buscador-material'
    ];

    campos_a_verificar.forEach(id => {
        const elemento = document.getElementById(id);
        if (elemento) {
            resultados.campos_formulario[id] = {
                value: elemento.value,
                tipo: elemento.type || elemento.tagName
            };
        } else {
            resultados.campos_formulario[id] = 'NO ENCONTRADO';
        }
    });

    // Verificar elementos de UI
    const tabla_materiales = document.getElementById('tabla-materiales');
    const tabla_servicios = document.getElementById('tabla-servicios');
    const count_materiales = document.getElementById('count-materiales');
    const count_servicios = document.getElementById('count-servicios');
    const resultados_busqueda = document.getElementById('resultados-materiales');

    resultados.elementos_ui = {
        tabla_materiales: tabla_materiales ? tabla_materiales.innerHTML.length : 'NO ENCONTRADO',
        tabla_servicios: tabla_servicios ? tabla_servicios.innerHTML.length : 'NO ENCONTRADO',
        count_materiales: count_materiales ? count_materiales.textContent : 'NO ENCONTRADO',
        count_servicios: count_servicios ? count_servicios.textContent : 'NO ENCONTRADO',
        resultados_ocultos: resultados_busqueda ? resultados_busqueda.classList.contains('hidden') : 'NO ENCONTRADO'
    };

    return resultados;
}

// Función para mostrar resultados de manera legible
function mostrarResultados(estado, titulo) {
    console.log(`\n📊 ${titulo}`);
    console.log('=' .repeat(50));
    
    console.log('🗂️ Arrays Globales:');
    Object.keys(estado.arrays_globales).forEach(key => {
        const valor = estado.arrays_globales[key];
        const icono = valor === 0 || valor === 'undefined' ? '✅' : '❌';
        console.log(`  ${icono} ${key}: ${valor}`);
    });

    console.log('\n📝 Campos del Formulario:');
    Object.keys(estado.campos_formulario).forEach(key => {
        const campo = estado.campos_formulario[key];
        if (campo !== 'NO ENCONTRADO') {
            const valor = campo.value;
            let esperado_limpio = false;
            
            // Determinar qué valor se considera "limpio" para cada campo
            if (key.includes('cantidad')) {
                esperado_limpio = valor === '1';
            } else if (key.includes('gastos') || key.includes('utilidad') || key.includes('supervision')) {
                esperado_limpio = valor === '0.00' || valor === '0' || valor === '';
            } else {
                esperado_limpio = valor === '';
            }
            
            const icono = esperado_limpio ? '✅' : '❌';
            console.log(`  ${icono} ${key}: "${valor}" (${campo.tipo})`);
        } else {
            console.log(`  ⚠️ ${key}: ELEMENTO NO ENCONTRADO`);
        }
    });

    console.log('\n🎨 Elementos de UI:');
    Object.keys(estado.elementos_ui).forEach(key => {
        const valor = estado.elementos_ui[key];
        console.log(`  • ${key}: ${valor}`);
    });
}

// Test principal
function testLimpiezaModal() {
    console.log('\n🚀 EJECUTANDO TEST DE LIMPIEZA DEL MODAL\n');

    // Paso 1: Verificar estado inicial
    const estadoInicial = verificarEstadoFormulario();
    mostrarResultados(estadoInicial, 'Estado Inicial');

    // Paso 2: Simular datos sucios (si es posible)
    if (typeof materiales_agregados !== 'undefined') {
        console.log('\n🧹 Simulando datos sucios...');
        
        // Agregar datos sucios
        materiales_agregados = [
            {id_temporal: 1, nombre: 'Test Material', cantidad: 5, precio_unitario: 100}
        ];
        servicios_agregados = [
            {id_temporal: 1, descripcion: 'Test Servicio', cantidad: 2, precio_unitario: 50}
        ];
        id_contador_material = 1;
        id_contador_servicio = 1;

        // Llenar algunos campos
        const campos_a_ensuciar = [
            {id: 'gastos-generales', valor: '150.75'},
            {id: 'utilidad', valor: '200.50'},
            {id: 'buscador-material', valor: 'búsqueda test'},
            {id: 'servicio-descripcion', valor: 'servicio sucio'}
        ];

        campos_a_ensuciar.forEach(campo => {
            const elemento = document.getElementById(campo.id);
            if (elemento) {
                elemento.value = campo.valor;
            }
        });

        const estadoSucio = verificarEstadoFormulario();
        mostrarResultados(estadoSucio, 'Estado con Datos Sucios');

        // Paso 3: Ejecutar limpiarForm()
        console.log('\n🧽 Ejecutando limpiarForm()...');
        if (typeof limpiarForm === 'function') {
            limpiarForm();
            
            const estadoLimpio = verificarEstadoFormulario();
            mostrarResultados(estadoLimpio, 'Estado Después de limpiarForm()');

            // Verificar si la limpieza fue exitosa
            const esLimpio = 
                estadoLimpio.arrays_globales.materiales === 0 &&
                estadoLimpio.arrays_globales.servicios === 0 &&
                estadoLimpio.arrays_globales.contador_material === 0 &&
                estadoLimpio.arrays_globales.contador_servicio === 0;

            if (esLimpio) {
                console.log('\n✅ LIMPIEZA EXITOSA: Todos los arrays están vacíos');
            } else {
                console.log('\n❌ LIMPIEZA FALLÓ: Algunos arrays no están vacíos');
            }

        } else {
            console.log('❌ La función limpiarForm() no está disponible');
        }
    } else {
        console.log('⚠️ Las variables globales no están disponibles en este contexto');
    }

    console.log('\n🏁 Test completado');
}

// Ejecutar el test cuando se cargue el script
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', testLimpiezaModal);
} else {
    testLimpiezaModal();
}

// También exportar para uso manual
window.testLimpiezaModal = testLimpiezaModal;
window.verificarEstadoFormulario = verificarEstadoFormulario;

console.log('🧪 Test de limpieza cargado. Ejecuta testLimpiezaModal() para probar manualmente.');