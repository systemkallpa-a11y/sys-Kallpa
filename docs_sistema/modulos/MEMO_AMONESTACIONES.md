# Memorandos de amonestación

**Actualizado:** 13/11/2026

Genera un memorando en PDF para un empleado, lo registra en la BD y, si el
empleado tiene correo, se lo envía como adjunto.

## Dónde

RR.HH › Marcación (`/marcacion`) › Reporte de asistencia → columna **Memos**
de cada empleado → modal "Generar Memorando de Amonestación".

## Flujo

1. El modal carga los tipos activos: `GET /api/marcacion/tipos-memo`
   (tabla `TblTipoMemo`: código, nombre, título, descripción, consecuencias).
   Los tipos son configurables en la BD (los iniciales: TARDANZA, FALTA,
   UNIFORME).
2. Se elige el tipo y la fecha del incidente.
3. `POST /api/marcacion/generar-memo` (`routes/memo_pdf.py`):
   - Datos del empleado con `sp_ObtenerDatosEmpleadoMemo` (nombre, cargo,
     área, correo).
   - Genera el PDF con reportlab: encabezado con logo, DE / PARA / CARGO /
     ÁREA / ASUNTO, descripción de la falta, consecuencias y firmas.
   - Lo registra con `sp_RegistrarMemo`.
   - Si el empleado tiene correo, lo envía con
     `app/utils/email_sender.py` (`enviar_email_con_adjunto`). Un error de
     correo no detiene la generación.
   - Devuelve el PDF para descargar.

## Configuración del correo (`.env`)

```env
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=<cuenta de envío>
SMTP_PASSWORD=<contraseña de aplicación>
```

Sin `SMTP_USER` / `SMTP_PASSWORD` el memo se genera igual, pero no se envía
(queda en el log: "Credenciales SMTP no configuradas").
