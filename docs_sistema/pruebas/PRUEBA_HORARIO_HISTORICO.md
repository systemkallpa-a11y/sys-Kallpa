# Prueba: el cambio de horario no altera la asistencia pasada

**Módulo:** RR.HH › Marcación / Reportes

## Qué se espera

Cuando se cambia el horario de un empleado, el cambio solo aplica **desde la
fecha de modificación en adelante**:

- Registros nuevos: horas laboradas, tardanzas, faltas y horas extra se
  calculan con el horario nuevo.
- Registros anteriores: se mantienen igual y siguen evaluándose con el horario
  que estaba vigente ese día (integridad para auditoría y planilla).

Soporte en la BD: `TblHorarioTrabajo.fecha_vigencia_inicio` y
`fecha_vigencia_fin`.

## Pasos

1. RR.HH › Marcación: elegir un empleado con marcaciones en fechas pasadas con
   su horario habitual (por ejemplo, entrada 8:00 a. m.).
2. Cambiarle el horario desde hoy o una fecha futura (por ejemplo, entrada
   9:00 a. m.).
3. RR.HH › Reportes: generar el reporte general de asistencia para un rango
   que incluya días anteriores y posteriores al cambio.

## Resultado esperado

- Días anteriores al cambio: evaluados con entrada 8:00 a. m. (no se
  recalculan).
- Días desde el cambio: evaluados con entrada 9:00 a. m.
