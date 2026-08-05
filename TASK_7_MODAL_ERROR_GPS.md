# TASK 7: Modal Prominente de Error GPS

**FECHA**: 05 Agosto 2026  
**ESTADO**: ✅ COMPLETADO (Pendiente de pruebas)

## 📋 RESUMEN

Se implementó un modal de error prominente y persistente que se muestra cuando un usuario intenta marcar asistencia fuera del rango GPS permitido. El modal requiere que el usuario lo cierre explícitamente.

---

## 🎯 REQUERIMIENTOS DEL USUARIO

> "ese mensaje de Fuera del rango de marcación permitido debe ser notorio para el usuario y no se debe cerrar hasta que el usuario ponga cerrar"

### Requisitos:
1. ✅ Modal debe ser prominente y llamativo
2. ✅ NO debe cerrarse automáticamente
3. ✅ Usuario debe hacer clic explícitamente en "Cerrar"
4. ✅ Debe mostrar información clara del error

---

## 🛠️ IMPLEMENTACIÓN

### 1. **Nuevo Modal HTML** (`marcacion_kallpa.html`)

Se agregó un modal dedicado con las siguientes características:

```html
<div id="modalErrorGPS" class="fixed inset-0 bg-black/95 backdrop-blur-md z-[60] hidden flex items-center justify-center p-4">
```

#### Características visuales:
- **Fondo oscuro translúcido**: `bg-black/95 backdrop-blur-md` (95% opacidad + blur)
- **Z-index elevado**: `z-[60]` (superior al modal de detección facial que es z-50)
- **Animación pulsante**: `animate-pulse-slow` para llamar la atención
- **Borde rojo grueso**: `border-4 border-red-500`
- **Gradiente rojo**: `from-red-900/90 to-red-950/90`

#### Contenido del modal:
1. **Icono grande**: `fa-map-marker-alt-slash` (60px, en círculo rojo con sombra)
2. **Título en mayúsculas**: "⚠️ FUERA DE RANGO ⚠️" (3xl, negrita)
3. **Mensaje principal**: "No puedes marcar desde esta ubicación"
4. **Explicación detallada**: Texto en panel con borde rojo explicando por qué
5. **Información GPS**:
   - Coordenadas actuales del usuario
   - Distancia a la zona más cercana (si está disponible)
6. **Botón grande**: "ENTENDIDO" (blanco con texto rojo, ocupa todo el ancho)

---

### 2. **Lógica JavaScript**

#### Función: `mostrarModalErrorGPS(ubicacion, mensaje)`

```javascript
function mostrarModalErrorGPS(ubicacion, mensaje) {
    const modal = document.getElementById('modalErrorGPS');
    
    // Actualizar información GPS si está disponible
    if (ubicacion) {
        const gpsActualSpan = document.getElementById('gpsActual');
        const latitud = ubicacion.latitud ? ubicacion.latitud.toFixed(6) : '--';
        const longitud = ubicacion.longitud ? ubicacion.longitud.toFixed(6) : '--';
        gpsActualSpan.textContent = `Lat: ${latitud}, Lng: ${longitud}`;
        
        // Si el mensaje incluye distancia, extraerla
        const distanciaMatch = mensaje.match(/(\d+\.?\d*)\s*metros/i);
        if (distanciaMatch) {
            const distanciaSpan = document.getElementById('distanciaZona');
            distanciaSpan.textContent = `Distancia a zona más cercana: ${distanciaMatch[1]} metros`;
        }
    }
    
    // Mostrar modal
    modal.classList.remove('hidden');
    
    // Prevenir scroll del body
    document.body.style.overflow = 'hidden';
}
```

**Características**:
- ✅ Muestra coordenadas GPS actuales del usuario
- ✅ Extrae y muestra distancia a zona más cercana (si está en el mensaje)
- ✅ Bloquea el scroll de la página (modal modal verdadero)
- ✅ No tiene temporizador ni cierre automático

#### Función: `cerrarModalErrorGPS()`

```javascript
function cerrarModalErrorGPS() {
    const modal = document.getElementById('modalErrorGPS');
    modal.classList.add('hidden');
    
    // Restaurar scroll del body
    document.body.style.overflow = '';
}
```

**Características**:
- ✅ Solo se ejecuta cuando el usuario hace clic en "ENTENDIDO"
- ✅ Restaura el scroll de la página

---

### 3. **Detección de Error GPS**

Se modificó la función `enviarMarcacion()` para detectar errores GPS y mostrar el modal:

```javascript
} else {
    // Ocultar mensaje de "Registrando..."
    mensajeDiv.classList.add('hidden');
    
    // Verificar si es error de GPS (fuera de rango)
    const errorMensaje = data.error || '';
    const errorLower = errorMensaje.toLowerCase();
    
    // Detectar múltiples variantes del error GPS
    const esErrorGPS = errorLower.includes('fuera') || 
                      errorLower.includes('rango') ||
                      errorLower.includes('ubicación') ||
                      errorLower.includes('ubicacion') ||
                      errorLower.includes('acérquese') ||
                      errorLower.includes('acerquese');
    
    if (esErrorGPS) {
        // ⚠️ ERROR GPS - Mostrar modal prominente
        mostrarModalErrorGPS(ubicacion, errorMensaje);
    } else {
        // Otro tipo de error - mostrar mensaje normal
        mensajeDiv.className = 'glass-card rounded-2xl p-4 text-center border border-red-500';
        mensajeDiv.innerHTML = `
            <i class="fas fa-exclamation-circle text-3xl mb-2 block text-red-400"></i>
            <p class="font-bold text-white">Error</p>
            <p class="text-sm mt-1 text-red-300">${errorMensaje || 'No se pudo registrar'}</p>
        `;
        mensajeDiv.classList.remove('hidden');
        
        // Auto-ocultar después de 5 segundos
        setTimeout(() => {
            mensajeDiv.classList.add('hidden');
        }, 5000);
    }
}
```

**Detección robusta**:
- ✅ Detecta "fuera", "rango", "ubicación", "acérquese" (con y sin acento)
- ✅ Case-insensitive (funciona en mayúsculas/minúsculas)
- ✅ Otros errores se muestran con el método normal (temporal)

---

### 4. **Animación CSS**

Se agregó animación de pulsación lenta:

```css
@keyframes pulse-slow {
    0%, 100% { transform: scale(1); opacity: 1; }
    50% { transform: scale(1.02); opacity: 0.95; }
}

.animate-pulse-slow { 
    animation: pulse-slow 2s ease-in-out infinite; 
}
```

---

## 🔗 INTEGRACIÓN CON BACKEND

### Mensaje de error del SP:

```sql
SET p_mensaje = '❌ FUERA DE RANGO: Usted está fuera de su rango de marcación. Acérquese a una ubicación autorizada.';
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fuera del rango de marcación permitido';
```

El error es capturado por Python y devuelto como:

```python
return jsonify({
    'success': False,
    'error': f'Error en la base de datos: {str(e)}'
}), 500
```

La detección en JavaScript busca las palabras clave en el mensaje de error.

---

## 📄 ARCHIVOS MODIFICADOS

### ✅ Archivos editados:
- **`app/templates/marcacion_kallpa.html`**: 
  - Agregado modal de error GPS
  - Agregada animación CSS `pulse-slow`
  - Agregadas funciones JS: `mostrarModalErrorGPS()`, `cerrarModalErrorGPS()`
  - Modificada lógica de detección de errores en `enviarMarcacion()`

### 📋 Archivos relacionados (no modificados):
- `app/routes/marcacion.py`: Maneja respuesta de error del SP
- `database_scripts/sp_RegistrarMarcacionCompleta_FINAL.sql`: Genera el error GPS

---

## ✅ CHECKLIST DE FUNCIONALIDAD

- [x] Modal se muestra solo para errores GPS
- [x] Modal tiene diseño prominente (rojo, grande, animado)
- [x] Modal NO se cierra automáticamente
- [x] Usuario DEBE hacer clic en "ENTENDIDO" para cerrar
- [x] Modal muestra coordenadas GPS del usuario
- [x] Modal muestra distancia a zona permitida (si está disponible)
- [x] Modal bloquea el scroll de la página
- [x] Otros errores usan el mensaje temporal normal (5 segundos)
- [x] Animación pulsante para llamar la atención
- [x] Z-index correcto (por encima de otros modales)

---

## 🧪 PRUEBAS PENDIENTES

### Escenario 1: Usuario SIN ubicaciones configuradas
- ✅ **Resultado esperado**: Marca libremente, NO muestra modal

### Escenario 2: Usuario CON ubicaciones, DENTRO del rango
- ✅ **Resultado esperado**: Marca exitosamente, NO muestra modal

### Escenario 3: Usuario CON ubicaciones, FUERA del rango
- ⚠️ **Resultado esperado**: 
  1. Muestra modal rojo prominente
  2. Modal NO se cierra solo
  3. Usuario hace clic en "ENTENDIDO"
  4. Modal se cierra
  5. Coordenadas GPS mostradas
  6. Distancia a zona más cercana mostrada (si está en mensaje)

### Escenario 4: Otro tipo de error (ej: secuencia incorrecta)
- ✅ **Resultado esperado**: Mensaje temporal normal (no modal GPS)

---

## 📝 NOTAS IMPORTANTES

### ⚠️ NO SUBIR A PRODUCCIÓN AÚN
El usuario pidió explícitamente: **"aun no lo subas a produccion"**

### 🔄 Siguiente paso:
1. Usuario debe probar en desarrollo
2. Verificar que el modal se muestra correctamente
3. Verificar que las coordenadas se muestran
4. Verificar que el botón "ENTENDIDO" funciona
5. Una vez validado → Commit y push a producción

---

## 🎨 CAPTURA DE DISEÑO

```
┌─────────────────────────────────────────────────┐
│                                                 │
│         ╔═══════════════════════════════╗       │
│         ║     [ICONO GRANDE ROJO]       ║       │
│         ║   fa-map-marker-alt-slash     ║       │
│         ╚═══════════════════════════════╝       │
│                                                 │
│        ⚠️ FUERA DE RANGO ⚠️                      │
│                                                 │
│    No puedes marcar desde esta ubicación       │
│                                                 │
│  ┌───────────────────────────────────────┐     │
│  │ Tu ubicación actual está fuera del    │     │
│  │ rango permitido para marcación de     │     │
│  │ asistencia. Debes estar dentro de     │     │
│  │ una de las zonas autorizadas.         │     │
│  └───────────────────────────────────────┘     │
│                                                 │
│  ┌───────────────────────────────────────┐     │
│  │ 📍 Lat: -12.046374, Lng: -77.042793   │     │
│  │ 📏 Distancia: 523 metros               │     │
│  └───────────────────────────────────────┘     │
│                                                 │
│  ┌───────────────────────────────────────┐     │
│  │          ✖ ENTENDIDO                   │     │
│  └───────────────────────────────────────┘     │
│                                                 │
└─────────────────────────────────────────────────┘

Características visuales:
- Fondo: Negro 95% + blur
- Card: Gradiente rojo oscuro con borde rojo grueso
- Animación: Pulsación suave (2 segundos)
- Botón: Blanco con texto rojo, ancho completo
```

---

## 🚀 PRÓXIMOS PASOS

1. ✅ **Implementación completada**
2. ⏳ **Pendiente**: Usuario debe probar en desarrollo
3. ⏳ **Pendiente**: Commit y push cuando usuario lo autorice
4. ⏳ **Opcional**: Agregar sonido de alerta cuando se muestre el modal

---

## 📞 CONTACTO

Si hay problemas o mejoras, contactar al desarrollador.

**Versión**: 1.0  
**Última actualización**: 05 Agosto 2026
