# Documentación del sistema Kallpa

Empezar por **[CONTEXTO_SISTEMA.md](CONTEXTO_SISTEMA.md)**: qué es el sistema,
estructura, menús y rutas, flujos de aprobación y pendientes conocidos.

| Carpeta | Contenido |
|---|---|
| [`modulos/`](modulos/) | Cómo funciona cada módulo hoy |
| [`guias/`](guias/) | Ejecutar en local y resolver problemas frecuentes |
| [`pruebas/`](pruebas/) | Casos de prueba funcionales |
| [`historial/`](historial/) | Cambios grandes ya cerrados (solo consulta) |

## Índice

- [modulos/REQUERIMIENTOS.md](modulos/REQUERIMIENTOS.md): obra y administrativo,
  aprobaciones, notificaciones (campana), Requerimiento General.
- [modulos/INVENTARIO.md](modulos/INVENTARIO.md): ítems, códigos, secciones por
  tipo, unidades, stock y kardex, proveedores.
- [modulos/MEMO_AMONESTACIONES.md](modulos/MEMO_AMONESTACIONES.md): memos en
  PDF y envío por correo.
- [guias/EJECUCION_LOCAL.md](guias/EJECUCION_LOCAL.md): `.env`, venv y arranque.
- [guias/SOLUCION_PROBLEMAS.md](guias/SOLUCION_PROBLEMAS.md): túnel SSH,
  errores JSON, puerto ocupado, SP con varios result sets.
- [pruebas/PRUEBA_HORARIO_HISTORICO.md](pruebas/PRUEBA_HORARIO_HISTORICO.md).
- [historial/MIGRACION_MATERIALES_A_INVENTARIO.md](historial/MIGRACION_MATERIALES_A_INVENTARIO.md).

Scripts de base de datos: [`../database_scripts/README.md`](../database_scripts/README.md).

## Reglas

- **Nunca** escribir contraseñas, claves ni `SECRET_KEY` reales en estos
  documentos: usar `<...>`.
- Al terminar un cambio, actualizar el documento del módulo y la fecha de
  "Actualizado". Si cambian menús, flujos o pendientes, también
  `CONTEXTO_SISTEMA.md`.
- Un plan o análisis temporal, una vez aplicado, se resume en el documento del
  módulo y se borra (o pasa a `historial/` si es un cambio grande).
