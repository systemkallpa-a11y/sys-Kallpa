# 📋 Sistema de Memorandos de Amonestación

## 📌 Descripción
Sistema para generar documentos de amonestación (memorandos) en formato PDF para empleados que incurran en faltas laborales.

## 🎯 Ubicación
- **Ruta**: `http://127.0.0.1:5000/marcacion`
- **Sección**: Reporte de Asistencia
- **Columna**: Acciones (botón naranja "Memo")

## 📝 Tipos de Memorandos

### 1. 🕐 TARDANZA
- **Motivo**: Tardanzas reiteradas
- **Uso**: Cuando el empleado llega tarde al trabajo repetidamente
- **Contenido**: Amonestación por incumplimiento de horarios

### 2. ❌ FALTA
- **Motivo**: Inasistencia injustificada
- **Uso**: Cuando el empleado no asiste sin justificación válida
- **Contenido**: Amonestación por ausencia injustificada

### 3. 👕 UNIFORME
- **Motivo**: No portar uniforme reglamentario
- **Uso**: Cuando el empleado no cumple con las normas de presentación
- **Contenido**: Amonestación por incumplimiento de imagen corporativa

## 🚀 Cómo Usar

### Paso 1: Acceder al Reporte
```
1. Ir a: http://127.0.0.1:5000/marcacion
2. Verás la tabla con todos los empleados
```

### Paso 2: Seleccionar Empleado
```
1. En la columna "Acciones", busca al empleado
2. Haz clic en el botón naranja "Memo"
3. Se desplegará un menú con 3 opciones
```

### Paso 3: Generar Memo
```
1. Selecciona el tipo de memo:
   - ⏰ Tardanza
   - ❌ Falta
   - 👕 Uniforme
2. El PDF se generará automáticamente
3. Se descargará con el nombre: Memo_TIPO_NOMBRE_FECHA.pdf
```

## 📄 Contenido del PDF

### Encabezado
- Logo KALLPA
- Título del tipo de amonestación
- Fecha actual

### Datos del Empleado
- DE: Gerencia de Recursos Humanos
- PARA: Nombre completo del empleado
- CARGO: Cargo del empleado
- ÁREA: Área de trabajo
- ASUNTO: Motivo de la amonestación

### Cuerpo del Documento
1. **Saludo formal**
2. **Descripción de la falta**: Explicación detallada del problema
3. **Advertencia**: Consecuencias de reincidir
4. **Cierre**: Exhortación a corregir la situación

### Sección de Firma
- Firma de Recursos Humanos
- Espacio para firma del empleado
- Campo de fecha de recepción

## 🔧 Archivos Técnicos

### Backend
```
app/routes/memo_pdf.py
- Endpoint: POST /api/marcacion/generar-memo
- Genera PDF usando reportlab
- Consulta datos del empleado desde BD
```

### Frontend
```
app/templates/reporte_asistencia.html
- Botón "Memo" con dropdown
- Funciones JavaScript para toggle y generación
```

### Blueprints
```
app/__init__.py - Registro de memo_pdf_bp
app/routes/__init__.py - Import de memo_pdf
```

## 📊 Datos Utilizados

El PDF obtiene automáticamente:
- ✅ Nombre completo del empleado
- ✅ Número de documento
- ✅ Cargo actual
- ✅ Área de trabajo
- ✅ Email (opcional)
- ✅ Fecha actual del sistema

## 🎨 Diseño del PDF

### Colores
- **Título**: Rojo (#c00000)
- **Fuente principal**: Helvetica 11pt
- **Estilo**: Profesional y formal

### Estructura
- Márgenes: 0.75 pulgadas
- Tamaño: Letter (8.5" x 11")
- Justificación: Texto justificado
- Tablas con bordes

## ⚠️ Notas Importantes

1. **Requiere reportlab**: El PDF no se generará sin esta librería
2. **Requiere autenticación**: Solo usuarios logueados pueden generar memos
3. **Empleado debe existir**: El número de documento debe estar en la BD
4. **Descarga automática**: El PDF se descarga al generarse

## 🔐 Seguridad

- ✅ Decorador `@login_required` protege el endpoint
- ✅ Validación de datos antes de generar PDF
- ✅ Solo genera para empleados registrados en BD

## 📅 Registro de Cambios

### 16 Agosto 2026 - v1.0
- ✅ Implementación inicial
- ✅ 3 tipos de memorandos (Tardanza, Falta, Uniforme)
- ✅ Botón con dropdown en tabla de asistencia
- ✅ Generación automática de PDF
- ✅ Diseño profesional con logo KALLPA

## 🚀 Próximas Mejoras

- [ ] Guardar historial de memos en BD
- [ ] Enviar memo por email al empleado
- [ ] Firmas digitales
- [ ] Personalizar textos por empresa
- [ ] Agregar más tipos de amonestaciones
- [ ] Dashboard de memos generados

## 📞 Soporte

Si encuentras problemas:
1. Verifica que reportlab esté instalado: `pip install reportlab`
2. Revisa los logs en consola: `[MEMO_PDF]`
3. Verifica que el empleado exista en BD
4. Reinicia el servidor Flask

---

**Fecha de creación**: 16 Agosto 2026  
**Autor**: Sistema Kallpa  
**Versión**: 1.0
